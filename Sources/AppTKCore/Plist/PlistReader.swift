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
}
