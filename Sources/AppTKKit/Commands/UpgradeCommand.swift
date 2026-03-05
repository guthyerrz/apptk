import AppTKCore
import ArgumentParser
import Foundation

struct UpgradeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "upgrade",
        abstract: "Upgrade apptk to the latest version"
    )

    func run() async throws {
        Formatter.printStep("upgrade", "Checking for latest version...")

        let (latestVersion, assetURL) = try await fetchLatestRelease()

        if latestVersion == apptkVersion {
            Formatter.printSuccess("Already up to date (v\(apptkVersion))")
            return
        }

        Formatter.printStep("upgrade", "Downloading v\(latestVersion)...")

        let (tempURL, _) = try await URLSession.shared.download(from: assetURL)
        let tempBinary = tempURL

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: tempBinary.path)

        let currentPath = resolveCurrentBinaryPath()
        let currentURL = URL(fileURLWithPath: currentPath)

        let resultURL = try FileManager.default.replaceItemAt(currentURL, withItemAt: tempBinary)
        guard resultURL != nil else {
            throw ValidationError("Failed to replace binary at \(currentPath)")
        }

        Formatter.printSuccess("Upgraded to v\(latestVersion)")
    }

    private func fetchLatestRelease() async throws -> (String, URL) {
        let apiURL = URL(
            string: "https://api.github.com/repos/guthyerrz/apptk/releases/latest")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
        else {
            throw ValidationError("Failed to fetch latest release from GitHub")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tagName = json["tag_name"] as? String,
            let assets = json["assets"] as? [[String: Any]]
        else {
            throw ValidationError("Invalid release response from GitHub")
        }

        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        guard
            let asset = assets.first(where: { ($0["name"] as? String) == "apptk" }),
            let downloadURLString = asset["browser_download_url"] as? String,
            let downloadURL = URL(string: downloadURLString)
        else {
            throw ValidationError("No apptk binary found in release assets")
        }

        return (version, downloadURL)
    }

    private func resolveCurrentBinaryPath() -> String {
        let arg0 = ProcessInfo.processInfo.arguments[0]
        let fileManager = FileManager.default
        if let resolved = fileManager.destinationOfSymbolicLink(atPath: arg0) {
            return resolved
        }
        return (arg0 as NSString).standardizingPath
    }
}

extension FileManager {
    fileprivate func destinationOfSymbolicLink(atPath path: String) -> String? {
        guard let attrs = try? attributesOfItem(atPath: path),
            attrs[.type] as? FileAttributeType == .typeSymbolicLink,
            let dest = try? self.destinationOfSymbolicLink(atPath: path) as String
        else {
            return nil
        }
        if (dest as NSString).isAbsolutePath {
            return dest
        }
        let dir = (path as NSString).deletingLastPathComponent
        return (dir as NSString).appendingPathComponent(dest)
    }
}
