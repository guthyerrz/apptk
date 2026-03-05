import Foundation

// MARK: - Magic Numbers

public enum MachOMagic: UInt32 {
    case mh64 = 0xFEEDFACF   // MH_MAGIC_64
    case mh32 = 0xFEEDFACE   // MH_MAGIC
    case fat   = 0xBEBAFECA  // FAT_MAGIC
    case fatCigam = 0xCAFEBABE // FAT_CIGAM (big-endian fat)
}

// MARK: - Architecture

public enum MachOArch {
    case x86
    case x64
    case arm64
    case unknown
}

// MARK: - Load Command Types

public enum LoadCommandType: UInt32 {
    case loadDylib = 0x0C           // LC_LOAD_DYLIB
    case idDylib = 0x0D             // LC_ID_DYLIB
    case loadWeakDylib = 0x80000018 // LC_LOAD_WEAK_DYLIB
    case reexportDylib = 0x8000001F // LC_REEXPORT_DYLIB
    case lazyLoadDylib = 0x80000020 // LC_LAZY_LOAD_DYLIB
}

// MARK: - Header Sizes

public enum MachOHeaderSize {
    public static let header64: Int = 32  // sizeof(mach_header_64)
    public static let header32: Int = 28  // sizeof(mach_header)
}

// MARK: - Data Helpers

extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        self.withUnsafeBytes { buf in
            buf.load(fromByteOffset: offset, as: UInt32.self)
        }
    }

    mutating func writeUInt32(_ value: UInt32, at offset: Int) {
        withUnsafeMutableBytes { buf in
            buf.storeBytes(of: value, toByteOffset: offset, as: UInt32.self)
        }
    }

    func readUInt64(at offset: Int) -> UInt64 {
        self.withUnsafeBytes { buf in
            buf.load(fromByteOffset: offset, as: UInt64.self)
        }
    }

    mutating func writeUInt64(_ value: UInt64, at offset: Int) {
        withUnsafeMutableBytes { buf in
            buf.storeBytes(of: value, toByteOffset: offset, as: UInt64.self)
        }
    }
}
