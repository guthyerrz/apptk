import AppTKCore
import ArgumentParser
import Foundation

public struct InfoCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show IPA app metadata"
    )

    @Argument(help: "Path to an .ipa file")
    var path: String

    public init() {}

    public mutating func run() throws {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "ipa":
            var cmd = IPAInfoCommand()
            cmd.path = path
            try cmd.run()
        default:
            throw ValidationError("Unsupported file type '.\(ext)'. Expected .ipa")
        }
    }
}
