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

    @Option(name: .long, help: "Path to the .framework to inject")
    var framework: String

    @Option(name: [.short, .long], help: "Output path for the patched IPA (default: <name>-patched.ipa)")
    var output: String?

    @Option(name: .long, help: "Code signing identity (e.g. 'Apple Development: ...')")
    var signingIdentity: String?

    @Option(name: .long, help: "Path to a .mobileprovision file")
    var provisioningProfile: String?

    @Option(name: .long, help: "New CFBundleIdentifier to set")
    var bundleId: String?

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

    public mutating func run() throws {
        let resolvedIPA = (ipaPath as NSString).standardizingPath
        let resolvedFW = (framework as NSString).standardizingPath

        let outputPath = output ?? {
            let url = URL(fileURLWithPath: resolvedIPA)
            let name = url.deletingPathExtension().lastPathComponent
            return url.deletingLastPathComponent().appendingPathComponent("\(name)-patched.ipa").path
        }()

        var context = IPAPatchContext(
            inputIPA: resolvedIPA,
            frameworkPath: resolvedFW,
            outputIPA: outputPath,
            signingIdentity: signingIdentity,
            provisioningProfile: provisioningProfile.map { ($0 as NSString).standardizingPath },
            bundleID: bundleId
        )

        let pipeline = IPAPatchPipeline(context: context)
        try pipeline.run(context: &context)
    }
}
