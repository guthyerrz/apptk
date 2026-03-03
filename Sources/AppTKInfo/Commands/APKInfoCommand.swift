import ArgumentParser
import Foundation
import SwiftJava

public struct APKInfoCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show APK metadata"
    )

    @Argument(help: "Path to an .apk file")
    var path: String

    public init() {}

    public mutating func run() throws {
        let fullPath = (path as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: fullPath) else {
            throw ValidationError("File not found: \(path)")
        }
        guard fullPath.hasSuffix(".apk") else {
            throw ValidationError("Expected an .apk file, got: \(path)")
        }

        let jarPath = "kotlin/build/libs/apptk-kotlin.jar"
        guard FileManager.default.fileExists(atPath: jarPath) else {
            throw CleanExit.message(
                "Kotlin JAR not found at \(jarPath). Run 'just build-jar' first."
            )
        }

        let jvm = try JavaVirtualMachine.shared(classpath: [jarPath])
        let environment = try jvm.environment()
        let inspector = APKInspector(environment: environment)
        let result = inspector.getInfo(fullPath)

        print(result)
    }
}
