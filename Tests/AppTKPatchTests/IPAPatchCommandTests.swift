import Foundation
import Testing

@testable import AppTKPatch

@Suite("IPAPatchCommand")
struct IPAPatchCommandTests {
    @Test("PatchCommand has correct command name")
    func testCommandName() {
        #expect(PatchCommand.configuration.commandName == "patch")
    }

    @Test("IPAPatchCommand has correct command name")
    func testSubcommandName() {
        #expect(IPAPatchCommand.configuration.commandName == "ipa")
    }

    @Test("IPAPatchContext stores all inputs correctly")
    func testContextInit() {
        let ctx = IPAPatchContext(
            inputIPA: "/tmp/test.ipa",
            frameworkPath: "/tmp/SDK.framework",
            outputIPA: "/tmp/patched.ipa",
            signingIdentity: "Apple Development",
            provisioningProfile: "/tmp/dev.mobileprovision",
            bundleID: "com.new.id"
        )

        #expect(ctx.inputIPA == "/tmp/test.ipa")
        #expect(ctx.frameworkPath == "/tmp/SDK.framework")
        #expect(ctx.outputIPA == "/tmp/patched.ipa")
        #expect(ctx.signingIdentity == "Apple Development")
        #expect(ctx.provisioningProfile == "/tmp/dev.mobileprovision")
        #expect(ctx.bundleID == "com.new.id")
        #expect(ctx.tempDir == nil)
        #expect(ctx.appDir == nil)
    }

    @Test("IPAPatchPipeline skips optional steps when not configured")
    func testPipelineSkipsOptionalSteps() {
        let ctx = IPAPatchContext(
            inputIPA: "/tmp/test.ipa",
            frameworkPath: "/tmp/SDK.framework",
            outputIPA: "/tmp/patched.ipa"
        )

        // No signing identity, no provisioning, no bundle ID
        // Pipeline: Unpack, SigningDetect, FrameworkInject, LoadCommandInject, ProvisioningReplace, CodeSign, Repack
        let pipeline = IPAPatchPipeline(context: ctx)
        #expect(pipeline.stepCount == 7)
    }

    @Test("IPAPatchPipeline includes all steps when fully configured")
    func testPipelineAllSteps() {
        let ctx = IPAPatchContext(
            inputIPA: "/tmp/test.ipa",
            frameworkPath: "/tmp/SDK.framework",
            outputIPA: "/tmp/patched.ipa",
            signingIdentity: "Apple Development",
            provisioningProfile: "/tmp/dev.mobileprovision",
            bundleID: "com.new.id"
        )

        // Pipeline: Unpack, SigningDetect, FrameworkInject, LoadCommandInject, BundleIDPatch, ProvisioningReplace, CodeSign, Repack
        let pipeline = IPAPatchPipeline(context: ctx)
        #expect(pipeline.stepCount == 8)
    }

    @Test("IPAPatchError has descriptive messages")
    func testErrorDescriptions() {
        let err1 = IPAPatchError.inputNotFound("/tmp/missing.ipa")
        #expect(err1.localizedDescription.contains("missing.ipa"))

        let err2 = IPAPatchError.frameworkNotFound("/tmp/missing.framework")
        #expect(err2.localizedDescription.contains("missing.framework"))

        let err3 = IPAPatchError.missingContext("appDir")
        #expect(err3.localizedDescription.contains("appDir"))

        let err4 = IPAPatchError.stepFailed(step: "Unpack", reason: "bad zip")
        #expect(err4.localizedDescription.contains("Unpack"))
    }
}
