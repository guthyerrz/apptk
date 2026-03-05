import Foundation

public enum MachOInjector {
    /// Inject an `LC_LOAD_DYLIB` command for the given dylib path into a Mach-O binary.
    ///
    /// The dylib path is typically `@rpath/SomeName.framework/SomeName`.
    /// The load command is appended into the header padding space after existing load commands.
    public static func injectLoadDylib(into binary: inout MachOBinary, dylibPath: String) throws {
        if binary.containsLoadCommand(for: dylibPath) {
            throw MachOError.alreadyInjected("Load command for '\(dylibPath)' already exists")
        }

        let loadCommand = buildDylibCommand(path: dylibPath)

        // The load commands live right after the header, occupying `sizeOfCommands` bytes.
        // Any padding between the end of load commands and the first section is available.
        let insertionPoint = binary.headerSize + Int(binary.sizeOfCommands)
        let endOfPadding = findFirstSectionOffset(in: binary)

        var currentEndOfPadding = endOfPadding
        var availableSpace = currentEndOfPadding - insertionPoint
        if availableSpace < loadCommand.count {
            try expandHeader(in: &binary, expansionPoint: currentEndOfPadding)
            currentEndOfPadding = findFirstSectionOffset(in: binary)
            availableSpace = currentEndOfPadding - insertionPoint
            guard availableSpace >= loadCommand.count else {
                throw MachOError.insufficientSpace(
                    "Not enough header padding after expansion (\(loadCommand.count) bytes needed, \(availableSpace) available)"
                )
            }
        }

        // Write the load command into the padding
        binary.data.replaceSubrange(insertionPoint..<(insertionPoint + loadCommand.count), with: loadCommand)

        // Update header: ncmds += 1, sizeofcmds += loadCommand.count
        let newNcmds = binary.numberOfCommands + 1
        let newSizeOfCmds = binary.sizeOfCommands + UInt32(loadCommand.count)
        binary.data.writeUInt32(newNcmds, at: 16)
        binary.data.writeUInt32(newSizeOfCmds, at: 20)
    }

    // MARK: - Private

    /// Build a raw `LC_LOAD_DYLIB` command.
    ///
    /// Layout of `dylib_command`:
    /// ```
    /// struct dylib_command {
    ///     uint32_t cmd;            // LC_LOAD_DYLIB
    ///     uint32_t cmdsize;        // total size, 4-byte aligned
    ///     struct dylib {
    ///         uint32_t name;       // offset from start of cmd to path string
    ///         uint32_t timestamp;
    ///         uint32_t current_version;
    ///         uint32_t compat_version;
    ///     };
    /// };
    /// // followed by the null-terminated path string
    /// ```
    private static func buildDylibCommand(path: String) -> Data {
        let pathBytes = Array(path.utf8) + [0] // null-terminated
        let headerPartSize = 24  // cmd(4) + cmdsize(4) + name_offset(4) + timestamp(4) + current_version(4) + compat_version(4)
        let rawSize = headerPartSize + pathBytes.count
        // Align to 4 bytes (pointer size for load commands)
        let cmdSize = (rawSize + 3) & ~3

        var cmd = Data(count: cmdSize)

        // cmd type
        cmd.writeUInt32(LoadCommandType.loadDylib.rawValue, at: 0)
        // cmdsize
        cmd.writeUInt32(UInt32(cmdSize), at: 4)
        // name offset (from start of this command)
        cmd.writeUInt32(UInt32(headerPartSize), at: 8)
        // timestamp
        cmd.writeUInt32(2, at: 12)
        // current_version (1.0.0 encoded: major << 16 | minor << 8 | patch)
        cmd.writeUInt32(0x00010000, at: 16)
        // compat_version
        cmd.writeUInt32(0x00010000, at: 20)

        // Write the path string
        for (i, byte) in pathBytes.enumerated() {
            cmd[headerPartSize + i] = byte
        }

        return cmd
    }

    /// Find the offset of the first section in the binary.
    /// This tells us where the header padding ends.
    private static func findFirstSectionOffset(in binary: MachOBinary) -> Int {
        var offset = binary.headerSize
        let ncmds = Int(binary.numberOfCommands)
        var firstSectionOffset = binary.data.count // fallback

        // Segment command types
        let lcSegment: UInt32 = 0x01    // LC_SEGMENT
        let lcSegment64: UInt32 = 0x19  // LC_SEGMENT_64

        for _ in 0..<ncmds {
            guard offset + 8 <= binary.data.count else { break }

            let cmdType = binary.data.readUInt32(at: offset)
            let cmdSize = Int(binary.data.readUInt32(at: offset + 4))
            guard cmdSize > 0 else { break }

            if cmdType == lcSegment64 || cmdType == lcSegment {
                // For segment commands, read the file offset of the segment.
                // segment_command_64: fileoff is at offset 40 (8 bytes)
                // segment_command: fileoff is at offset 36 (4 bytes)
                let nsects: UInt32
                let sectionStartOffset: Int
                let sectionSize: Int

                if cmdType == lcSegment64 {
                    // segment_command_64 layout:
                    // 0: cmd(4), 4: cmdsize(4), 8: segname(16), 24: vmaddr(8),
                    // 32: vmsize(8), 40: fileoff(8), 48: filesize(8),
                    // 56: maxprot(4), 60: initprot(4), 64: nsects(4), 68: flags(4)
                    nsects = binary.data.readUInt32(at: offset + 64)
                    sectionStartOffset = offset + 72  // sizeof(segment_command_64)
                    sectionSize = 80  // sizeof(section_64)
                } else {
                    nsects = binary.data.readUInt32(at: offset + 48)
                    sectionStartOffset = offset + 56
                    sectionSize = 68
                }

                // Check each section's file offset
                for s in 0..<Int(nsects) {
                    let secOffset = sectionStartOffset + s * sectionSize
                    let fileOff: Int
                    if cmdType == lcSegment64 {
                        // section_64: offset field is at byte 48 of the section struct (4 bytes)
                        fileOff = Int(binary.data.readUInt32(at: secOffset + 48))
                    } else {
                        fileOff = Int(binary.data.readUInt32(at: secOffset + 40))
                    }
                    if fileOff > 0 && fileOff < firstSectionOffset {
                        firstSectionOffset = fileOff
                    }
                }
            }

            offset += cmdSize
        }

        return firstSectionOffset
    }

    // MARK: - Header Expansion

    private static func expandHeader(in binary: inout MachOBinary, expansionPoint: Int) throws {
        let pageSize = 4096
        var expanded = Data(capacity: binary.data.count + pageSize)
        expanded.append(binary.data[0..<expansionPoint])
        expanded.append(Data(count: pageSize))
        expanded.append(binary.data[expansionPoint...])
        binary.data = expanded
        patchAllOffsets(in: &binary, expansionPoint: expansionPoint, shift: pageSize)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private static func patchAllOffsets(in binary: inout MachOBinary, expansionPoint: Int, shift: Int) {
        var offset = binary.headerSize
        let ncmds = Int(binary.numberOfCommands)

        for _ in 0..<ncmds {
            guard offset + 8 <= binary.data.count else { break }

            let cmdType = binary.data.readUInt32(at: offset)
            let cmdSize = Int(binary.data.readUInt32(at: offset + 4))
            guard cmdSize > 0 else { break }

            switch cmdType {
            // LC_SEGMENT_64
            case 0x19:
                let segName = extractSegmentName(from: binary.data, at: offset + 8)
                let fileoff = binary.data.readUInt64(at: offset + 40)

                if segName == "__TEXT" && fileoff == 0 {
                    // __TEXT maps from file offset 0; grow its filesize and vmsize
                    let filesize = binary.data.readUInt64(at: offset + 48)
                    binary.data.writeUInt64(filesize + UInt64(shift), at: offset + 48)
                    let vmsize = binary.data.readUInt64(at: offset + 32)
                    binary.data.writeUInt64(vmsize + UInt64(shift), at: offset + 32)
                } else if fileoff > 0 && fileoff >= UInt64(expansionPoint) {
                    binary.data.writeUInt64(fileoff + UInt64(shift), at: offset + 40)
                    // Also shift filesize? No — filesize stays the same, only the offset moves.
                }

                // Patch sections within this segment
                let nsects = Int(binary.data.readUInt32(at: offset + 64))
                for s in 0..<nsects {
                    let secOff = offset + 72 + s * 80
                    shiftUInt32IfNeeded(in: &binary.data, at: secOff + 48, expansionPoint: expansionPoint, shift: shift) // offset
                    shiftUInt32IfNeeded(in: &binary.data, at: secOff + 56, expansionPoint: expansionPoint, shift: shift) // reloff
                }

            // LC_SEGMENT (32-bit)
            case 0x01:
                let segName = extractSegmentName(from: binary.data, at: offset + 8)
                let fileoff = UInt64(binary.data.readUInt32(at: offset + 36))

                if segName == "__TEXT" && fileoff == 0 {
                    let filesize = binary.data.readUInt32(at: offset + 40)
                    binary.data.writeUInt32(filesize + UInt32(shift), at: offset + 40)
                    let vmsize = binary.data.readUInt32(at: offset + 28)
                    binary.data.writeUInt32(vmsize + UInt32(shift), at: offset + 28)
                } else if fileoff > 0 && fileoff >= UInt64(expansionPoint) {
                    binary.data.writeUInt32(UInt32(fileoff) + UInt32(shift), at: offset + 36)
                }

                let nsects = Int(binary.data.readUInt32(at: offset + 48))
                for s in 0..<nsects {
                    let secOff = offset + 56 + s * 68
                    shiftUInt32IfNeeded(in: &binary.data, at: secOff + 40, expansionPoint: expansionPoint, shift: shift) // offset
                    shiftUInt32IfNeeded(in: &binary.data, at: secOff + 48, expansionPoint: expansionPoint, shift: shift) // reloff
                }

            // LC_SYMTAB
            case 0x02:
                shiftUInt32IfNeeded(in: &binary.data, at: offset + 8, expansionPoint: expansionPoint, shift: shift)  // symoff
                shiftUInt32IfNeeded(in: &binary.data, at: offset + 16, expansionPoint: expansionPoint, shift: shift) // stroff

            // LC_DYSYMTAB
            case 0x0B:
                for fieldOffset in [32, 40, 48, 56, 64, 72] {
                    shiftUInt32IfNeeded(in: &binary.data, at: offset + fieldOffset, expansionPoint: expansionPoint, shift: shift)
                }

            // LC_DYLD_INFO / LC_DYLD_INFO_ONLY
            case 0x22, 0x80000022:
                for fieldOffset in [8, 16, 24, 32, 40] {
                    shiftUInt32IfNeeded(in: &binary.data, at: offset + fieldOffset, expansionPoint: expansionPoint, shift: shift)
                }

            // linkedit_data_command types:
            // LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO, LC_FUNCTION_STARTS,
            // LC_DATA_IN_CODE, LC_LINKER_OPTIMIZATION_HINT,
            // LC_DYLD_EXPORTS_TRIE, LC_DYLD_CHAINED_FIXUPS
            case 0x1D, 0x1E, 0x26, 0x29, 0x2E, 0x80000033, 0x80000034:
                shiftUInt32IfNeeded(in: &binary.data, at: offset + 8, expansionPoint: expansionPoint, shift: shift) // dataoff

            // LC_MAIN
            case 0x80000028:
                let entryoff = binary.data.readUInt64(at: offset + 8)
                if entryoff > 0 && entryoff >= UInt64(expansionPoint) {
                    binary.data.writeUInt64(entryoff + UInt64(shift), at: offset + 8)
                }

            // LC_ENCRYPTION_INFO / LC_ENCRYPTION_INFO_64
            case 0x21, 0x2C:
                shiftUInt32IfNeeded(in: &binary.data, at: offset + 8, expansionPoint: expansionPoint, shift: shift) // cryptoff

            // LC_NOTE
            case 0x31:
                let noteOff = binary.data.readUInt64(at: offset + 24)
                if noteOff > 0 && noteOff >= UInt64(expansionPoint) {
                    binary.data.writeUInt64(noteOff + UInt64(shift), at: offset + 24)
                }

            // LC_TWO_LEVEL_HINTS
            case 0x16:
                shiftUInt32IfNeeded(in: &binary.data, at: offset + 8, expansionPoint: expansionPoint, shift: shift)

            default:
                break
            }

            offset += cmdSize
        }
    }

    private static func shiftUInt32IfNeeded(in data: inout Data, at offset: Int, expansionPoint: Int, shift: Int) {
        let value = data.readUInt32(at: offset)
        if value > 0 && value >= UInt32(expansionPoint) {
            data.writeUInt32(value + UInt32(shift), at: offset)
        }
    }

    private static func extractSegmentName(from data: Data, at offset: Int) -> String {
        var bytes: [UInt8] = []
        for i in 0..<16 {
            let byte = data[offset + i]
            if byte == 0 { break }
            bytes.append(byte)
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
