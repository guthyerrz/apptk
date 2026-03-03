import Foundation

public enum Shell {
    @discardableResult
    public static func run(_ command: String, arguments: [String] = []) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw ShellError.nonZeroExit(command: command, status: process.terminationStatus, output: output)
        }

        return output
    }
}

public enum ShellError: LocalizedError {
    case nonZeroExit(command: String, status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .nonZeroExit(let command, let status, let output):
            return "\(command) exited with code \(status): \(output)"
        }
    }
}
