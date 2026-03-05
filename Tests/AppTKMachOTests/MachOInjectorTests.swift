import Foundation
import Testing

@testable import AppTKMachO

@Suite("MachOInjector")
struct MachOInjectorTests {
    /// Builds a minimal 64-bit Mach-O binary with valid headers and one LC_SEGMENT_64 command.
    /// Includes sufficient padding after load commands for injection.
    private func createMinimalMachO64() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("apptk-macho-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let binaryURL = tempDir.appendingPathComponent("test_binary")

        // Build a minimal Mach-O 64-bit binary:
        // Header (32 bytes) + one LC_SEGMENT_64 (72 bytes) + padding (zeros up to 4096)
        let pageSize = 4096
        var data = Data(count: pageSize)

        // mach_header_64
        data.writeUInt32(MachOMagic.mh64.rawValue, at: 0) // magic
        data.writeUInt32(0x0100000C, at: 4)               // cputype: ARM64
        data.writeUInt32(0x00000000, at: 8)               // cpusubtype
        data.writeUInt32(2, at: 12)                        // filetype: MH_EXECUTE
        data.writeUInt32(1, at: 16)                        // ncmds: 1
        data.writeUInt32(72, at: 20)                       // sizeofcmds: 72 (one segment_command_64)
        data.writeUInt32(0, at: 24)                        // flags
        data.writeUInt32(0, at: 28)                        // reserved

        // LC_SEGMENT_64 (72 bytes base + 0 sections)
        let segOffset = 32
        data.writeUInt32(0x19, at: segOffset)              // cmd: LC_SEGMENT_64
        data.writeUInt32(72, at: segOffset + 4)            // cmdsize: 72
        // segname: "__TEXT" (16 bytes, null padded) at offset 8
        let segName = "__TEXT".utf8
        for (i, byte) in segName.enumerated() {
            data[segOffset + 8 + i] = byte
        }
        // vmaddr (8 bytes) at 24
        data.writeUInt32(0, at: segOffset + 24)
        data.writeUInt32(0, at: segOffset + 28)
        // vmsize (8 bytes) at 32
        data.writeUInt32(UInt32(pageSize), at: segOffset + 32)
        data.writeUInt32(0, at: segOffset + 36)
        // fileoff (8 bytes) at 40
        data.writeUInt32(0, at: segOffset + 40)
        data.writeUInt32(0, at: segOffset + 44)
        // filesize (8 bytes) at 48
        data.writeUInt32(UInt32(pageSize), at: segOffset + 48)
        data.writeUInt32(0, at: segOffset + 52)
        // maxprot at 56
        data.writeUInt32(7, at: segOffset + 56)
        // initprot at 60
        data.writeUInt32(5, at: segOffset + 60)
        // nsects at 64
        data.writeUInt32(0, at: segOffset + 64)
        // flags at 68
        data.writeUInt32(0, at: segOffset + 68)

        try data.write(to: binaryURL)
        return binaryURL
    }

    @Test("Parses a valid 64-bit Mach-O binary")
    func testParse64Bit() throws {
        let binaryURL = try createMinimalMachO64()
        defer { try? FileManager.default.removeItem(at: binaryURL.deletingLastPathComponent()) }

        let binary = try MachOBinary(url: binaryURL)
        #expect(binary.is64Bit == true)
        #expect(binary.numberOfCommands == 1)
        #expect(binary.sizeOfCommands == 72)
    }

    @Test("Rejects non-Mach-O file")
    func testRejectInvalid() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("apptk-macho-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fakeURL = tempDir.appendingPathComponent("fake")
        try Data("not a mach-o".utf8).write(to: fakeURL)

        #expect(throws: MachOError.self) {
            try MachOBinary(url: fakeURL)
        }
    }

    @Test("Injects LC_LOAD_DYLIB into header padding")
    func testInjectLoadDylib() throws {
        let binaryURL = try createMinimalMachO64()
        defer { try? FileManager.default.removeItem(at: binaryURL.deletingLastPathComponent()) }

        var binary = try MachOBinary(url: binaryURL)
        let dylibPath = "@rpath/Test.framework/Test"

        #expect(binary.containsLoadCommand(for: dylibPath) == false)

        try MachOInjector.injectLoadDylib(into: &binary, dylibPath: dylibPath)

        #expect(binary.numberOfCommands == 2)
        #expect(binary.containsLoadCommand(for: dylibPath) == true)
    }

    @Test("Prevents duplicate injection")
    func testPreventsDuplicate() throws {
        let binaryURL = try createMinimalMachO64()
        defer { try? FileManager.default.removeItem(at: binaryURL.deletingLastPathComponent()) }

        var binary = try MachOBinary(url: binaryURL)
        let dylibPath = "@rpath/Test.framework/Test"

        try MachOInjector.injectLoadDylib(into: &binary, dylibPath: dylibPath)

        #expect(throws: MachOError.self) {
            try MachOInjector.injectLoadDylib(into: &binary, dylibPath: dylibPath)
        }
    }

    // MARK: - Header Expansion Tests

    /// Creates a Mach-O 64-bit binary with tight padding: one __TEXT segment with one section
    /// whose offset leaves only ~24 bytes of padding. Also includes LC_SYMTAB to verify offset patching.
    private func createTightPaddingMachO64() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("apptk-macho-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let binaryURL = tempDir.appendingPathComponent("test_binary_tight")

        // Layout:
        // Header (32 bytes)
        // LC_SEGMENT_64 with 1 section (72 + 80 = 152 bytes) — ends at offset 184
        // LC_SYMTAB (24 bytes) — ends at offset 208
        // That leaves padding up to the first section offset.
        // We'll place the section at offset 232, leaving only 24 bytes free.
        let sectionFileOffset: UInt32 = 232
        let totalSize = 8192 // two pages to have room for content
        var data = Data(count: totalSize)

        // -- mach_header_64 (32 bytes) --
        data.writeUInt32(MachOMagic.mh64.rawValue, at: 0)
        data.writeUInt32(0x0100000C, at: 4)  // cputype: ARM64
        data.writeUInt32(0x00000000, at: 8)  // cpusubtype
        data.writeUInt32(2, at: 12)          // filetype: MH_EXECUTE
        data.writeUInt32(2, at: 16)          // ncmds: 2
        data.writeUInt32(176, at: 20)        // sizeofcmds: 152 + 24
        data.writeUInt32(0, at: 24)          // flags
        data.writeUInt32(0, at: 28)          // reserved

        // -- LC_SEGMENT_64 with 1 section (152 bytes) --
        let seg = 32
        data.writeUInt32(0x19, at: seg)           // cmd: LC_SEGMENT_64
        data.writeUInt32(152, at: seg + 4)        // cmdsize
        // segname: "__TEXT"
        for (i, byte) in "__TEXT".utf8.enumerated() { data[seg + 8 + i] = byte }
        // vmaddr = 0
        data.writeUInt64(0, at: seg + 24)
        // vmsize = totalSize
        data.writeUInt64(UInt64(totalSize), at: seg + 32)
        // fileoff = 0 (__TEXT starts at 0)
        data.writeUInt64(0, at: seg + 40)
        // filesize = totalSize
        data.writeUInt64(UInt64(totalSize), at: seg + 48)
        data.writeUInt32(7, at: seg + 56)         // maxprot
        data.writeUInt32(5, at: seg + 60)         // initprot
        data.writeUInt32(1, at: seg + 64)         // nsects: 1
        data.writeUInt32(0, at: seg + 68)         // flags

        // section_64 (80 bytes) starting at seg + 72
        let sec = seg + 72
        // sectname: "__text"
        for (i, byte) in "__text".utf8.enumerated() { data[sec + i] = byte }
        // segname: "__TEXT"
        for (i, byte) in "__TEXT".utf8.enumerated() { data[sec + 16 + i] = byte }
        // addr (8 bytes at sec+32)
        data.writeUInt64(UInt64(sectionFileOffset), at: sec + 32)
        // size (8 bytes at sec+40)
        data.writeUInt64(64, at: sec + 40)
        // offset (4 bytes at sec+48) — this is the key: tight to load commands
        data.writeUInt32(sectionFileOffset, at: sec + 48)
        // align (sec+52)
        data.writeUInt32(2, at: sec + 52)
        // reloff (sec+56)
        data.writeUInt32(0, at: sec + 56)
        // nreloc (sec+60)
        data.writeUInt32(0, at: sec + 60)

        // -- LC_SYMTAB (24 bytes) --
        let symtab = seg + 152  // offset 184
        data.writeUInt32(0x02, at: symtab)        // cmd: LC_SYMTAB
        data.writeUInt32(24, at: symtab + 4)      // cmdsize
        data.writeUInt32(4096, at: symtab + 8)    // symoff: points into second page
        data.writeUInt32(10, at: symtab + 12)     // nsyms
        data.writeUInt32(5000, at: symtab + 16)   // stroff: also in second page
        data.writeUInt32(100, at: symtab + 20)    // strsize

        try data.write(to: binaryURL)
        return binaryURL
    }

    @Test("Expands header when padding is insufficient")
    func testExpandHeaderOnTightPadding() throws {
        let binaryURL = try createTightPaddingMachO64()
        defer { try? FileManager.default.removeItem(at: binaryURL.deletingLastPathComponent()) }

        var binary = try MachOBinary(url: binaryURL)
        let originalSize = binary.data.count

        try MachOInjector.injectLoadDylib(into: &binary, dylibPath: "@rpath/AutoProxy.framework/AutoProxy")

        #expect(binary.data.count == originalSize + 4096)
        #expect(binary.containsLoadCommand(for: "@rpath/AutoProxy.framework/AutoProxy"))
    }

    @Test("Offsets are correctly shifted after expansion")
    func testOffsetsShiftedAfterExpansion() throws {
        let binaryURL = try createTightPaddingMachO64()
        defer { try? FileManager.default.removeItem(at: binaryURL.deletingLastPathComponent()) }

        var binary = try MachOBinary(url: binaryURL)

        // Original values
        let origSectionOffset: UInt32 = 232
        let origSymoff: UInt32 = 4096
        let origStroff: UInt32 = 5000

        try MachOInjector.injectLoadDylib(into: &binary, dylibPath: "@rpath/AutoProxy.framework/AutoProxy")

        // Find the section offset (first section in first segment, at seg+72+48)
        // Header is 32 bytes, segment starts at 32, section at 32+72=104, offset field at 104+48=152
        let newSectionOffset = binary.data.readUInt32(at: 152)
        #expect(newSectionOffset == origSectionOffset + 4096)

        // LC_SYMTAB starts at 32+152=184
        let newSymoff = binary.data.readUInt32(at: 184 + 8)
        let newStroff = binary.data.readUInt32(at: 184 + 16)
        #expect(newSymoff == origSymoff + 4096)
        #expect(newStroff == origStroff + 4096)
    }

    @Test("Expanded binary re-parses correctly after write and read back")
    func testExpandedBinaryReparse() throws {
        let binaryURL = try createTightPaddingMachO64()
        defer { try? FileManager.default.removeItem(at: binaryURL.deletingLastPathComponent()) }

        var binary = try MachOBinary(url: binaryURL)
        try MachOInjector.injectLoadDylib(into: &binary, dylibPath: "@rpath/AutoProxy.framework/AutoProxy")
        try binary.writeToDisk()

        let reloaded = try MachOBinary(url: binaryURL)
        #expect(reloaded.numberOfCommands == 3) // original 2 + injected 1
        #expect(reloaded.containsLoadCommand(for: "@rpath/AutoProxy.framework/AutoProxy"))
    }

    @Test("Writes modified binary to disk and reads it back")
    func testWriteAndReadBack() throws {
        let binaryURL = try createMinimalMachO64()
        defer { try? FileManager.default.removeItem(at: binaryURL.deletingLastPathComponent()) }

        var binary = try MachOBinary(url: binaryURL)
        try MachOInjector.injectLoadDylib(into: &binary, dylibPath: "@rpath/SDK.framework/SDK")
        try binary.writeToDisk()

        // Read back from disk
        let reloaded = try MachOBinary(url: binaryURL)
        #expect(reloaded.numberOfCommands == 2)
        #expect(reloaded.containsLoadCommand(for: "@rpath/SDK.framework/SDK") == true)
    }
}
