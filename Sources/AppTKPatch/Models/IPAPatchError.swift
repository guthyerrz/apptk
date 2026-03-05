import Foundation

public enum IPAPatchError: LocalizedError {
    case inputNotFound(String)
    case frameworkNotFound(String)
    case provisioningNotFound(String)
    case missingContext(String)
    case stepFailed(step: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .inputNotFound(let path):
            return "Input IPA not found: \(path)"
        case .frameworkNotFound(let path):
            return "Framework not found: \(path)"
        case .provisioningNotFound(let path):
            return "Provisioning profile not found: \(path)"
        case .missingContext(let field):
            return "Missing context field: \(field) — did a previous step fail?"
        case .stepFailed(let step, let reason):
            return "Step '\(step)' failed: \(reason)"
        }
    }
}
