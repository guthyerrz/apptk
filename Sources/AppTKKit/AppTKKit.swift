import AppTKInfo
import AppTKPatch
import ArgumentParser

public struct AppTKRoot: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "apptk",
        abstract: "Unified mobile app inspection CLI",
        subcommands: [IPACommand.self, InfoCommand.self, PatchCommand.self]
    )

    public init() {}
}
