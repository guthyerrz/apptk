import Foundation

public enum IPAParserError: LocalizedError {
    case invalidIPA(String)

    public var errorDescription: String? {
        switch self {
        case .invalidIPA(let reason): return "Invalid IPA: \(reason)"
        }
    }
}
