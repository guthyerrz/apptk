import AppTKCore
import Foundation
import Testing

@testable import AppTKInfo

@Suite("IPAInfoParser")
struct IPAInfoParserTests {
    /// Creates a minimal .app structure inside a temp directory and zips it as an IPA.
    private func createMinimalIPA(
        bundleId: String = "com.test.app",
        appName: String = "TestApp",
        version: String = "1.0.0",
        build: String = "1",
        minOS: String = "15.0",
        deviceFamily: [Int] = [1]
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("apptk-test-\(UUID().uuidString)")
        let payloadDir = tempDir.appendingPathComponent("Payload")
        let appDir = payloadDir.appendingPathComponent("\(appName).app")
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        // Write a minimal Info.plist
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleId,
            "CFBundleDisplayName": appName,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": build,
            "CFBundleExecutable": appName,
            "MinimumOSVersion": minOS,
            "UIDeviceFamily": deviceFamily,
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: appDir.appendingPathComponent("Info.plist"))

        // Write a dummy binary (just so the file exists — lipo will fail gracefully)
        try Data("fake binary".utf8).write(to: appDir.appendingPathComponent(appName))

        // Zip into IPA (must zip from parent so archive contains Payload/ prefix)
        let ipaPath = tempDir.appendingPathComponent("test.ipa")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", ipaPath.path, "Payload"]
        process.currentDirectoryURL = tempDir
        try process.run()
        process.waitUntilExit()

        return ipaPath
    }

    @Test("Parses basic plist fields from a minimal IPA")
    func testBasicParsing() throws {
        let ipaPath = try createMinimalIPA(
            bundleId: "com.example.test",
            appName: "MyTestApp",
            version: "2.1.0",
            build: "42",
            minOS: "16.0",
            deviceFamily: [1, 2]
        )
        defer { try? FileManager.default.removeItem(at: ipaPath.deletingLastPathComponent()) }

        let info = try IPAInfoParser.parse(ipaPath: ipaPath.path)

        #expect(info.bundleId == "com.example.test")
        #expect(info.appName == "MyTestApp")
        #expect(info.version == "2.1.0")
        #expect(info.buildNumber == "42")
        #expect(info.minimumOSVersion == "16.0")
        #expect(info.deviceFamily == ["iPhone", "iPad"])
        #expect(info.fileSize > 0)
    }

    @Test("Rejects non-existent file")
    func testMissingFile() throws {
        #expect(throws: (any Error).self) {
            try IPAInfoParser.parse(ipaPath: "/nonexistent/path/test.ipa")
        }
    }

    @Test("Reads plist correctly")
    func testReadPlist() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("apptk-plist-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let plist: [String: Any] = ["key": "value", "number": 42]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let plistURL = tempDir.appendingPathComponent("test.plist")
        try data.write(to: plistURL)

        let result = try IPAInfoParser.readPlist(at: plistURL)
        #expect(result["key"] as? String == "value")
        #expect(result["number"] as? Int == 42)
    }
}
