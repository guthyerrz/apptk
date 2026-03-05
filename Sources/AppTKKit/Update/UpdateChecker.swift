import ArgumentParser
import Foundation

struct CheckUpdateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_check-update",
        shouldDisplay: false
    )

    func run() async throws {
        let apiURL = URL(
            string: "https://api.github.com/repos/guthyerrz/apptk/releases/latest")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
        else {
            return
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tagName = json["tag_name"] as? String
        else {
            return
        }

        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".apptk")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let cacheFile = cacheDir.appendingPathComponent("version-check.json")
        let payload: [String: String] = [
            "latest_version": version,
            "checked_at": ISO8601DateFormatter().string(from: Date()),
        ]
        let encoded = try JSONSerialization.data(
            withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try encoded.write(to: cacheFile)
    }
}
