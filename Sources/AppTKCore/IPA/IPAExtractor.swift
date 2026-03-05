import Foundation

public struct IPAExtractResult: Sendable {
    public let tempDir: URL
    public let appDir: URL
    public let executableName: String
    public let binaryURL: URL
}

public enum IPAExtractor {
    public static func extract(ipaPath: String) throws -> IPAExtractResult {
        let fileManager = FileManager.default
        let ipaURL = URL(fileURLWithPath: ipaPath)

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("apptk-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try Shell.run("/usr/bin/unzip", arguments: ["-o", "-q", ipaURL.path, "-d", tempDir.path])

        let payloadDir = tempDir.appendingPathComponent("Payload")
        guard fileManager.fileExists(atPath: payloadDir.path) else {
            throw IPAParserError.invalidIPA("No Payload directory found")
        }

        let contents = try fileManager.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        guard let appDir = contents.first(where: { $0.pathExtension == "app" }) else {
            throw IPAParserError.invalidIPA("No .app bundle found in Payload/")
        }

        let plist = try PlistReader.read(at: appDir.appendingPathComponent("Info.plist"))
        let executableName = plist["CFBundleExecutable"] as? String
            ?? appDir.deletingPathExtension().lastPathComponent
        let binaryURL = appDir.appendingPathComponent(executableName)

        return IPAExtractResult(
            tempDir: tempDir,
            appDir: appDir,
            executableName: executableName,
            binaryURL: binaryURL
        )
    }

    public static func cleanup(tempDir: URL) {
        try? FileManager.default.removeItem(at: tempDir)
    }
}
