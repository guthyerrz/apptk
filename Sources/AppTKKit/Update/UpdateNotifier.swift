import AppTKCore
import Foundation

enum UpdateNotifier {
    static func checkAndNotify() {
        let cacheFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".apptk/version-check.json")

        var shouldSpawnCheck = true

        if let data = try? Data(contentsOf: cacheFile),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
            let latestVersion = json["latest_version"],
            let checkedAtString = json["checked_at"],
            let checkedAt = ISO8601DateFormatter().date(from: checkedAtString)
        {
            if latestVersion != apptkVersion, apptkVersion != "dev" {
                Formatter.printWarning(
                    "A new version of apptk is available: v\(latestVersion) (current: v\(apptkVersion)). Run `apptk upgrade` to update."
                )
            }

            let age = Date().timeIntervalSince(checkedAt)
            if age < 24 * 60 * 60 {
                shouldSpawnCheck = false
            }
        }

        if shouldSpawnCheck {
            spawnBackgroundCheck()
        }
    }

    private static func spawnBackgroundCheck() {
        let binaryPath = resolveCurrentBinaryPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["_check-update"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private static func resolveCurrentBinaryPath() -> String {
        let arg0 = ProcessInfo.processInfo.arguments[0]
        return (arg0 as NSString).standardizingPath
    }
}
