import ArgumentParser

public struct APKCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "apk",
        abstract: "Android APK tools",
        subcommands: [APKInfoCommand.self]
    )

    public init() {}
}
