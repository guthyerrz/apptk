import ArgumentParser

public struct PatchCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "patch",
        abstract: "Patch mobile app binaries",
        subcommands: [IPAPatchCommand.self]
    )

    public init() {}
}
