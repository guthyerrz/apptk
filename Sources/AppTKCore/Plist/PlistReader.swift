import Foundation

public enum PlistReader {
    public static func read(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw IPAParserError.invalidIPA("Failed to parse plist at \(url.lastPathComponent)")
        }
        return plist
    }

    public static func write(at url: URL, dict: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: url)
    }

    public static func setValue(_ value: Any, forKeyPath components: [String], in dict: inout [String: Any]) throws {
        guard let first = components.first else { return }

        if components.count == 1 {
            dict[first] = value
            return
        }

        let remaining = Array(components.dropFirst())
        var nested = dict[first] as? [String: Any] ?? [:]

        if dict[first] != nil && !(dict[first] is [String: Any]) {
            throw IPAParserError.invalidIPA(
                "Cannot traverse key path: '\(first)' exists but is not a dictionary"
            )
        }

        try setValue(value, forKeyPath: remaining, in: &nested)
        dict[first] = nested
    }
}
