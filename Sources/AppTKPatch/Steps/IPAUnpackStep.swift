import AppTKCore
import Foundation

struct IPAUnpackStep: PatchStep {
    let name = "Unpack"

    func execute(context: inout IPAPatchContext) throws {
        let result = try IPAExtractor.extract(ipaPath: context.inputIPA)

        context.tempDir = result.tempDir
        context.appDir = result.appDir
        context.executableName = result.executableName
        context.binaryURL = result.binaryURL

        Formatter.printStep(name, "Extracted \(result.appDir.lastPathComponent)")
    }
}
