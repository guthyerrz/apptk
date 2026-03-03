import ArgumentParser

public struct IPAPatchCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ipa",
        abstract: "Patch an IPA file"
    )

    @Argument(help: "Path to an .ipa file")
    var ipaPath: String

    @Option(name: .long, help: "Framework to inject")
    var framework: String

    @Option(name: .long, help: "Output path (default: patched copy next to input)")
    var output: String?

    public init() {}

    public mutating func run() throws {
        print("patch ipa: not yet implemented (ipa: \(ipaPath), framework: \(framework), output: \(output ?? "default"))")
    }
}
