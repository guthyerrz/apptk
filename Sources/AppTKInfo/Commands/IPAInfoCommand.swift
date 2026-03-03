import AppTKCore
import ArgumentParser
import Foundation

public struct IPAInfoCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show IPA metadata"
    )

    @Argument(help: "Path to an .ipa file")
    var path: String

    public init() {}

    public mutating func run() throws {
        let fullPath = (path as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: fullPath) else {
            throw ValidationError("File not found: \(path)")
        }
        guard fullPath.hasSuffix(".ipa") else {
            throw ValidationError("Expected an .ipa file, got: \(path)")
        }

        let info = try IPAInfoParser.parse(ipaPath: fullPath)
        Formatter.printIPAInfo(info)
    }
}
