import AppTKInfo
import AppTKPatch
import ArgumentParser

public struct AppTKRoot: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "apptk",
        abstract: "Unified mobile app inspection CLI",
        version: apptkVersion,
        subcommands: [
            IPACommand.self, InfoCommand.self, PatchCommand.self,
            UpgradeCommand.self, CheckUpdateCommand.self,
        ]
    )

    public init() {}

    public func validate() throws {
        UpdateNotifier.checkAndNotify()
    }
}
