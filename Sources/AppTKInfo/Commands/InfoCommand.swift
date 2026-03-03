import AppTKCore
import ArgumentParser
import Foundation

public struct InfoCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show app metadata (auto-detects APK or IPA by extension)"
    )

    @Argument(help: "Path to an .ipa or .apk file")
    var path: String

    public init() {}

    public mutating func run() throws {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "ipa":
            var cmd = IPAInfoCommand()
            cmd.path = path
            try cmd.run()
        case "apk":
            var cmd = APKInfoCommand()
            cmd.path = path
            try cmd.run()
        default:
            throw ValidationError("Unsupported file type '.\(ext)'. Expected .ipa or .apk")
        }
    }
}
