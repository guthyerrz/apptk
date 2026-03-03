import AppTKCore
import Foundation

public enum IPAInfoParser {
    public static func parse(ipaPath: String) throws -> IPAInfo {
        let fileManager = FileManager.default
        let ipaURL = URL(fileURLWithPath: ipaPath)

        // File size
        let attrs = try fileManager.attributesOfItem(atPath: ipaPath)
        let fileSize = attrs[.size] as? UInt64 ?? 0

        // Create temp directory and unzip
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("apptk-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        try Shell.run("/usr/bin/unzip", arguments: ["-o", "-q", ipaURL.path, "-d", tempDir.path])

        // Find .app bundle
        let payloadDir = tempDir.appendingPathComponent("Payload")
        guard fileManager.fileExists(atPath: payloadDir.path) else {
            throw IPAParserError.invalidIPA("No Payload directory found")
        }

        let contents = try fileManager.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        guard let appDir = contents.first(where: { $0.pathExtension == "app" }) else {
            throw IPAParserError.invalidIPA("No .app bundle found in Payload/")
        }

        // Read Info.plist
        let plist = try readPlist(at: appDir.appendingPathComponent("Info.plist"))

        let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown"
        let appName = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? appDir.deletingPathExtension().lastPathComponent
        let version = plist["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = plist["CFBundleVersion"] as? String ?? "unknown"
        let minimumOSVersion = plist["MinimumOSVersion"] as? String ?? "unknown"
        let sdkVersion = plist["DTSDKName"] as? String
        let deviceFamily = resolveDeviceFamily(plist["UIDeviceFamily"] as? [Int] ?? [])

        // Get executable name and architectures
        let executableName = plist["CFBundleExecutable"] as? String ?? appDir.deletingPathExtension().lastPathComponent
        let binaryPath = appDir.appendingPathComponent(executableName)
        let architectures = parseArchitectures(binaryPath: binaryPath)

        // Signing info
        let (signingIdentity, teamName) = parseCodesign(appDir: appDir)

        // Provisioning profile
        let provisioningProfile = parseProvisioningProfile(appDir: appDir)

        // Entitlements
        let entitlements = parseEntitlements(appDir: appDir)

        return IPAInfo(
            bundleId: bundleId,
            appName: appName,
            version: version,
            buildNumber: buildNumber,
            minimumOSVersion: minimumOSVersion,
            sdkVersion: sdkVersion,
            architectures: architectures,
            signingIdentity: signingIdentity,
            teamName: teamName,
            provisioningProfile: provisioningProfile,
            entitlements: entitlements,
            fileSize: fileSize,
            deviceFamily: deviceFamily
        )
    }

    // MARK: - Plist

    public static func readPlist(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw IPAParserError.invalidIPA("Failed to parse plist at \(url.lastPathComponent)")
        }
        return plist
    }

    // MARK: - Architectures

    private static func parseArchitectures(binaryPath: URL) -> [String] {
        guard let output = try? Shell.run("/usr/bin/lipo", arguments: ["-info", binaryPath.path]) else {
            return ["unknown"]
        }
        // Output: "Architectures in the fat file: binary are: arm64 x86_64"
        // or: "Non-fat file: binary is architecture: arm64"
        if let range = output.range(of: "are: ") {
            return output[range.upperBound...].split(separator: " ").map(String.init)
        }
        if let range = output.range(of: "architecture: ") {
            return [String(output[range.upperBound...]).trimmingCharacters(in: .whitespaces)]
        }
        return ["unknown"]
    }

    // MARK: - Codesign

    private static func parseCodesign(appDir: URL) -> (identity: String?, team: String?) {
        guard let output = try? Shell.run("/usr/bin/codesign", arguments: ["-dvv", appDir.path]) else {
            return (nil, nil)
        }

        var identity: String?
        var team: String?

        for line in output.split(separator: "\n") {
            if line.hasPrefix("Authority=") {
                if identity == nil {
                    identity = String(line.dropFirst("Authority=".count))
                }
            }
            if line.hasPrefix("TeamIdentifier=") {
                team = String(line.dropFirst("TeamIdentifier=".count))
            }
        }

        return (identity, team)
    }

    // MARK: - Provisioning Profile

    private static func parseProvisioningProfile(appDir: URL) -> ProvisioningInfo? {
        let mobileprovision = appDir.appendingPathComponent("embedded.mobileprovision")
        guard FileManager.default.fileExists(atPath: mobileprovision.path) else {
            return nil
        }

        guard let decoded = try? Shell.run("/usr/bin/security", arguments: ["cms", "-D", "-i", mobileprovision.path]) else {
            return nil
        }

        guard let data = decoded.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let name = plist["Name"] as? String ?? "unknown"
        let teamName = (plist["TeamName"] as? String)
        let expirationDate = plist["ExpirationDate"] as? Date
        let entitlements = plist["Entitlements"] as? [String: Any]

        // Determine profile type
        let type: String
        if let provisionsAllDevices = plist["ProvisionsAllDevices"] as? Bool, provisionsAllDevices {
            type = "Enterprise"
        } else if let getTaskAllow = entitlements?["get-task-allow"] as? Bool, getTaskAllow {
            type = "Development"
        } else if plist["ProvisionedDevices"] != nil {
            type = "Ad Hoc"
        } else {
            type = "App Store"
        }

        return ProvisioningInfo(
            name: name,
            teamName: teamName,
            expirationDate: expirationDate,
            type: type
        )
    }

    // MARK: - Entitlements

    private static func parseEntitlements(appDir: URL) -> [String: Any]? {
        guard let output = try? Shell.run("/usr/bin/codesign", arguments: ["-d", "--entitlements", ":-", appDir.path]) else {
            return nil
        }

        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        return plist.isEmpty ? nil : plist
    }

    // MARK: - Device Family

    private static func resolveDeviceFamily(_ ids: [Int]) -> [String] {
        ids.map { id in
            switch id {
            case 1: return "iPhone"
            case 2: return "iPad"
            case 3: return "Apple TV"
            case 4: return "Apple Watch"
            default: return "Unknown (\(id))"
            }
        }
    }
}
