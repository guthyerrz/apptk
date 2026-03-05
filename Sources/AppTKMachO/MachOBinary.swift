import Foundation

public struct MachOBinary {
    public let url: URL
    public internal(set) var data: Data
    public let is64Bit: Bool
    public let headerSize: Int

    /// Number of load commands (from header)
    public var numberOfCommands: UInt32 {
        data.readUInt32(at: headerOffset(for: .ncmds))
    }

    /// Total size of all load commands (from header)
    public var sizeOfCommands: UInt32 {
        data.readUInt32(at: headerOffset(for: .sizeofcmds))
    }

    public init(url: URL) throws {
        self.url = url
        self.data = try Data(contentsOf: url)

        guard data.count >= 4 else {
            throw MachOError.invalidBinary("File too small to be a Mach-O binary")
        }

        let magic = data.readUInt32(at: 0)

        switch magic {
        case MachOMagic.mh64.rawValue:
            is64Bit = true
            headerSize = MachOHeaderSize.header64
        case MachOMagic.mh32.rawValue:
            is64Bit = false
            headerSize = MachOHeaderSize.header32
        default:
            throw MachOError.unsupportedFormat(
                "Unsupported Mach-O format (magic: 0x\(String(magic, radix: 16))). Fat binaries must be thinned first."
            )
        }
    }

    /// Check if a load command for the given dylib path already exists.
    public func containsLoadCommand(for dylibPath: String) -> Bool {
        var offset = headerSize
        let ncmds = Int(numberOfCommands)

        for _ in 0..<ncmds {
            guard offset + 8 <= data.count else { break }

            let cmdType = data.readUInt32(at: offset)
            let cmdSize = Int(data.readUInt32(at: offset + 4))
            guard cmdSize > 0 else { break }

            if cmdType == LoadCommandType.loadDylib.rawValue ||
               cmdType == LoadCommandType.loadWeakDylib.rawValue ||
               cmdType == LoadCommandType.lazyLoadDylib.rawValue ||
               cmdType == LoadCommandType.reexportDylib.rawValue {
                // dylib_command: the name string offset is at byte 8 of the load command
                let nameOffset = Int(data.readUInt32(at: offset + 8))
                let nameStart = offset + nameOffset
                if nameStart < data.count {
                    let nameEnd = min(offset + cmdSize, data.count)
                    if let name = extractCString(from: nameStart, to: nameEnd) {
                        if name == dylibPath {
                            return true
                        }
                    }
                }
            }

            offset += cmdSize
        }

        return false
    }

    /// Write the (possibly modified) binary data back to disk.
    public func writeToDisk() throws {
        try data.write(to: url)
    }

    // MARK: - Internal

    private func extractCString(from start: Int, to end: Int) -> String? {
        guard start < end, start < data.count else { return nil }
        let slice = data[start..<min(end, data.count)]
        guard let nullIndex = slice.firstIndex(of: 0) else {
            return String(data: slice, encoding: .utf8)
        }
        return String(data: data[start..<nullIndex], encoding: .utf8)
    }

    private enum HeaderField {
        case ncmds
        case sizeofcmds
    }

    private func headerOffset(for field: HeaderField) -> Int {
        // mach_header / mach_header_64 layout:
        // 0: magic (4), 4: cputype (4), 8: cpusubtype (4), 12: filetype (4)
        // 16: ncmds (4), 20: sizeofcmds (4), 24: flags (4), [28: reserved (4) for 64-bit]
        switch field {
        case .ncmds: return 16
        case .sizeofcmds: return 20
        }
    }
}
