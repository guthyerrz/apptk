import Foundation

public enum MachOError: LocalizedError {
    case invalidBinary(String)
    case unsupportedFormat(String)
    case alreadyInjected(String)
    case insufficientSpace(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBinary(let msg): return "Invalid Mach-O binary: \(msg)"
        case .unsupportedFormat(let msg): return "Unsupported format: \(msg)"
        case .alreadyInjected(let msg): return msg
        case .insufficientSpace(let msg): return msg
        }
    }
}
