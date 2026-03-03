import ArgumentParser

public struct IPACommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ipa",
        abstract: "iOS IPA tools",
        subcommands: [IPAInfoCommand.self]
    )

    public init() {}
}
