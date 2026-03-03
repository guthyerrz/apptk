import AppTKInfo
import AppTKPatch
import ArgumentParser

public struct AppTKRoot: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "apptk",
        abstract: "Unified mobile app inspection CLI",
        subcommands: [APKCommand.self, IPACommand.self, InfoCommand.self, PatchCommand.self]
    )

    public init() {}
}
