import AppTKCore
import Foundation

struct IPARepackStep: PatchStep {
    let name = "Repack"

    func execute(context: inout IPAPatchContext) throws {
        guard let tempDir = context.tempDir else {
            throw IPAPatchError.missingContext("tempDir")
        }

        let outputURL = URL(fileURLWithPath: context.outputIPA)
        let fileManager = FileManager.default

        // Remove existing output if present
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        // Create output directory if needed
        let outputDir = outputURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: outputDir.path) {
            try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }

        // Zip Payload/ back into IPA from the temp directory
        try Shell.run("/usr/bin/zip", arguments: ["-r", "-q", outputURL.path, "Payload"], workingDirectory: tempDir.path)

        // Cleanup temp directory
        try? fileManager.removeItem(at: tempDir)
        context.tempDir = nil

        Formatter.printStep(name, "Created \(outputURL.lastPathComponent)")
    }
}
