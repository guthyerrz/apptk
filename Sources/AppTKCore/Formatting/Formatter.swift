import Foundation

public enum Formatter {
    // MARK: - ANSI Colors

    private static let bold = "\u{1B}[1m"
    private static let dim = "\u{1B}[2m"
    private static let cyan = "\u{1B}[36m"
    private static let green = "\u{1B}[32m"
    private static let yellow = "\u{1B}[33m"
    private static let red = "\u{1B}[31m"
    private static let reset = "\u{1B}[0m"

    // MARK: - Progress Output

    public static func printStep(_ name: String, _ message: String) {
        print("\(bold)\(cyan)[\(name)]\(reset) \(message)")
    }

    public static func printSuccess(_ message: String) {
        print("\(bold)\(green)✓\(reset) \(message)")
    }

    public static func printWarning(_ message: String) {
        print("\(bold)\(yellow)⚠\(reset) \(message)")
    }

    public static func printError(_ message: String) {
        print("\(bold)\(red)✗\(reset) \(message)")
    }

    // MARK: - IPA Info

    public static func printIPAInfo(_ info: IPAInfo) {
        let divider = "\(dim)─── IPA Info ─────────────────────────────\(reset)"
        print(divider)
        print()

        printSection("GENERAL") {
            printField("Bundle ID", info.bundleId)
            printField("Name", info.appName)
            printField("Version", "\(info.version) (\(info.buildNumber))")
            printField("Min iOS", info.minimumOSVersion)
            if let sdk = info.sdkVersion {
                printField("SDK", sdk)
            }
            printField("Architectures", info.architectures.joined(separator: ", "))
            printField("Device Family", info.deviceFamily.joined(separator: ", "))
            printField("File Size", formatFileSize(info.fileSize))
        }

        if info.signingIdentity != nil || info.teamName != nil || info.provisioningProfile != nil {
            printSection("SIGNING") {
                if let identity = info.signingIdentity {
                    printField("Identity", identity)
                }
                if let team = info.teamName {
                    printField("Team", team)
                }
                if let profile = info.provisioningProfile {
                    printField("Profile", profile.name)
                    if let exp = profile.expirationDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        printField("Expires", formatter.string(from: exp))
                    }
                    printField("Type", profile.type)
                }
            }
        }

        if let entitlements = info.entitlements, !entitlements.isEmpty {
            printSection("ENTITLEMENTS") {
                for (key, value) in entitlements.sorted(by: { $0.key < $1.key }) {
                    printField(key, "\(value)")
                }
            }
        }
    }

    // MARK: - Helpers

    private static func printSection(_ title: String, content: () -> Void) {
        print("\(bold)\(cyan)\(title)\(reset)")
        content()
        print()
    }

    private static func printField(_ label: String, _ value: String) {
        let padded = label.padding(toLength: 22, withPad: " ", startingAt: 0)
        print("  \(green)\(padded)\(reset)\(value)")
    }

    private static func formatFileSize(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(bytes)
        var unitIndex = 0
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", size, units[unitIndex])
    }
}
