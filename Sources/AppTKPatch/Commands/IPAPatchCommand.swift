import AppTKCore
import ArgumentParser
import Foundation

public struct IPAPatchCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ipa",
        abstract: "Patch an IPA file with a framework injection"
    )

    @Argument(help: "Path to the input .ipa file")
    var ipaPath: String

    @Option(name: .long, help: "Path to the .framework or .xcframework to inject")
    var framework: String

    @Option(name: [.short, .long], help: "Output path for the patched IPA (default: <name>-patched.ipa)")
    var output: String?

    @Option(name: .long, help: "Code signing identity (auto-detected from IPA if omitted)")
    var signingIdentity: String?

    @Option(name: .long, help: "Path to a .mobileprovision file (auto-detected from IPA if omitted)")
    var provisioningProfile: String?

    @Option(name: .long, help: "New CFBundleIdentifier to set")
    var bundleId: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Add a string plist entry (KEY=VALUE, use : for nested keys)")
    var plistString: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "Add a boolean plist entry (KEY=true|false, use : for nested keys)")
    var plistBool: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "Add an integer plist entry (KEY=VALUE, use : for nested keys)")
    var plistInt: [String] = []

    public init() {}

    public mutating func validate() throws {
        let fm = FileManager.default

        let resolvedIPA = (ipaPath as NSString).standardizingPath
        guard fm.fileExists(atPath: resolvedIPA) else {
            throw ValidationError("Input IPA not found: \(ipaPath)")
        }
        guard ipaPath.hasSuffix(".ipa") else {
            throw ValidationError("Input file must be an .ipa")
        }

        let resolvedFW = (framework as NSString).standardizingPath
        guard fm.fileExists(atPath: resolvedFW) else {
            throw ValidationError("Framework not found: \(framework)")
        }

        if let profile = provisioningProfile {
            let resolvedProfile = (profile as NSString).standardizingPath
            guard fm.fileExists(atPath: resolvedProfile) else {
                throw ValidationError("Provisioning profile not found: \(profile)")
            }
        }
    }

    private func parsePlistEntries() throws -> [PlistEntry] {
        var entries: [PlistEntry] = []

        for raw in plistString {
            let (key, rawValue) = try splitEntry(raw, typeName: "string")
            entries.append(PlistEntry(keyPath: key, value: rawValue))
        }

        for raw in plistBool {
            let (key, rawValue) = try splitEntry(raw, typeName: "bool")
            guard rawValue == "true" || rawValue == "false" else {
                throw ValidationError("Invalid bool value for '\(key)': '\(rawValue)' (must be true or false)")
            }
            entries.append(PlistEntry(keyPath: key, value: rawValue == "true"))
        }

        for raw in plistInt {
            let (key, rawValue) = try splitEntry(raw, typeName: "int")
            guard let intValue = Int(rawValue) else {
                throw ValidationError("Invalid int value for '\(key)': '\(rawValue)'")
            }
            entries.append(PlistEntry(keyPath: key, value: intValue))
        }

        return entries
    }

    private func splitEntry(_ raw: String, typeName: String) throws -> (String, String) {
        guard let eqIndex = raw.firstIndex(of: "=") else {
            throw ValidationError("Invalid --plist-\(typeName) format: '\(raw)' (expected KEY=VALUE)")
        }
        let key = String(raw[raw.startIndex..<eqIndex])
        let value = String(raw[raw.index(after: eqIndex)...])

        guard !key.isEmpty else {
            throw ValidationError("Empty key in --plist-\(typeName): '\(raw)'")
        }

        let components = key.split(separator: ":")
        for component in components {
            guard !component.isEmpty else {
                throw ValidationError("Empty key component in --plist-\(typeName): '\(key)'")
            }
        }

        return (key, value)
    }

    private func resolveFrameworkPath(_ path: String) throws -> String {
        guard path.hasSuffix(".xcframework") else { return path }

        let plistPath = (path as NSString).appendingPathComponent("Info.plist")
        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let libraries = plist["AvailableLibraries"] as? [[String: Any]] else {
            throw ValidationError("Unable to read Info.plist from xcframework: \(path)")
        }

        guard let deviceLib = libraries.first(where: {
            ($0["SupportedPlatform"] as? String) == "ios" && $0["SupportedPlatformVariant"] == nil
        }) else {
            throw ValidationError("No ios-arm64 (device) slice found in xcframework: \(path)")
        }

        guard let identifier = deviceLib["LibraryIdentifier"] as? String,
              let libraryPath = deviceLib["LibraryPath"] as? String else {
            throw ValidationError("Invalid library entry in xcframework Info.plist: \(path)")
        }

        let resolved = (path as NSString).appendingPathComponent(identifier)
        let frameworkPath = (resolved as NSString).appendingPathComponent(libraryPath)

        guard FileManager.default.fileExists(atPath: frameworkPath) else {
            throw ValidationError("Resolved framework slice not found: \(frameworkPath)")
        }

        print("Resolved xcframework to: \(frameworkPath)")
        return frameworkPath
    }

    public mutating func run() throws {
        let resolvedIPA = (ipaPath as NSString).standardizingPath
        let resolvedFW = try resolveFrameworkPath((framework as NSString).standardizingPath)

        let outputPath = output ?? {
            let url = URL(fileURLWithPath: resolvedIPA)
            let name = url.deletingPathExtension().lastPathComponent
            return url.deletingLastPathComponent().appendingPathComponent("\(name)-patched.ipa").path
        }()

        let plistEntries = try parsePlistEntries()

        var context = IPAPatchContext(
            inputIPA: resolvedIPA,
            frameworkPath: resolvedFW,
            outputIPA: outputPath,
            signingIdentity: signingIdentity,
            provisioningProfile: provisioningProfile.map { ($0 as NSString).standardizingPath },
            bundleID: bundleId,
            plistEntries: plistEntries
        )

        let pipeline = IPAPatchPipeline(context: context)
        try pipeline.run(context: &context)
    }
}
