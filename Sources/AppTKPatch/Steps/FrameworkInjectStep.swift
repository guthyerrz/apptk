import AppTKCore
import Foundation

struct FrameworkInjectStep: PatchStep {
    let name = "Inject Framework"

    func execute(context: inout IPAPatchContext) throws {
        guard let appDir = context.appDir else {
            throw IPAPatchError.missingContext("appDir")
        }

        let frameworkURL = URL(fileURLWithPath: context.frameworkPath)
        let frameworkName = frameworkURL.lastPathComponent

        let frameworksDir = appDir.appendingPathComponent("Frameworks")
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: frameworksDir.path) {
            try fileManager.createDirectory(at: frameworksDir, withIntermediateDirectories: true)
        }

        let destination = frameworksDir.appendingPathComponent(frameworkName)

        // Remove existing copy if present
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: frameworkURL, to: destination)
        Formatter.printStep(name, "Copied \(frameworkName) into Frameworks/")
    }
}
