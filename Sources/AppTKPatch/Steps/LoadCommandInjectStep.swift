import AppTKCore
import AppTKMachO
import Foundation

struct LoadCommandInjectStep: PatchStep {
    let name = "Inject Load Command"

    func execute(context: inout IPAPatchContext) throws {
        guard let binaryURL = context.binaryURL else {
            throw IPAPatchError.missingContext("binaryURL")
        }

        let frameworkURL = URL(fileURLWithPath: context.frameworkPath)
        let frameworkName = frameworkURL.deletingPathExtension().lastPathComponent
        let dylibPath = "@rpath/\(frameworkURL.lastPathComponent)/\(frameworkName)"

        var binary = try MachOBinary(url: binaryURL)

        if binary.containsLoadCommand(for: dylibPath) {
            Formatter.printWarning("Load command for \(frameworkName) already exists, skipping")
            return
        }

        try MachOInjector.injectLoadDylib(into: &binary, dylibPath: dylibPath)
        try binary.writeToDisk()

        Formatter.printStep(name, "Injected LC_LOAD_DYLIB for \(frameworkName)")
    }
}
