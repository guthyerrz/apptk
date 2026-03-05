import AppTKCore
import Foundation

public struct IPAPatchPipeline {
    private let steps: [any PatchStep]

    public var stepCount: Int { steps.count }

    public init(context: IPAPatchContext) {
        var steps: [any PatchStep] = [
            IPAUnpackStep(),
            FrameworkInjectStep(),
            LoadCommandInjectStep(),
        ]

        if context.bundleID != nil {
            steps.append(BundleIDPatchStep())
        }

        if context.provisioningProfile != nil {
            steps.append(ProvisioningReplaceStep())
        }

        if context.signingIdentity != nil {
            steps.append(CodeSignStep())
        }

        steps.append(IPARepackStep())

        self.steps = steps
    }

    public func run(context: inout IPAPatchContext) throws {
        for step in steps {
            Formatter.printStep(step.name, "Running...")
            do {
                try step.execute(context: &context)
            } catch {
                Formatter.printError("\(step.name) failed: \(error.localizedDescription)")
                // Cleanup temp dir on failure
                if let tempDir = context.tempDir {
                    try? FileManager.default.removeItem(at: tempDir)
                }
                throw error
            }
        }
        Formatter.printSuccess("Patched IPA written to \(context.outputIPA)")
    }
}
