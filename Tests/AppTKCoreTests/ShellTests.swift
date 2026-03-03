import Foundation
import Testing

@testable import AppTKCore

@Suite("Shell")
struct ShellTests {
    @Test("Runs a simple command successfully")
    func testRunEcho() throws {
        let output = try Shell.run("/bin/echo", arguments: ["hello"])
        #expect(output == "hello")
    }

    @Test("Throws on non-zero exit")
    func testNonZeroExit() throws {
        #expect(throws: ShellError.self) {
            try Shell.run("/usr/bin/false")
        }
    }
}
