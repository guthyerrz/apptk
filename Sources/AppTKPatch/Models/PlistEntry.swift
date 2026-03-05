import Foundation

public struct PlistEntry {
    public let keyPath: String
    public let value: Any

    public var keyComponents: [String] {
        keyPath.split(separator: ":").map(String.init)
    }

    public init(keyPath: String, value: Any) {
        self.keyPath = keyPath
        self.value = value
    }
}
