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
}
