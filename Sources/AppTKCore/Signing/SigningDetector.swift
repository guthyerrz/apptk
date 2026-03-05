import Foundation

public enum SigningDetector {
    /// Extract signing identity and team from a .app bundle via `codesign -dvv`
    public static func detectIdentity(appDir: URL) -> (identity: String?, team: String?) {
        guard let output = try? Shell.run("/usr/bin/codesign", arguments: ["-dvv", appDir.path]) else {
            return (nil, nil)
        }

        var identity: String?
        var team: String?

        for line in output.split(separator: "\n") {
            if line.hasPrefix("Authority=") {
                if identity == nil {
                    identity = String(line.dropFirst("Authority=".count))
                }
            }
            if line.hasPrefix("TeamIdentifier=") {
                team = String(line.dropFirst("TeamIdentifier=".count))
            }
        }

        return (identity, team)
    }

    /// Check if a signing identity is installed in the local keychain
    public static func isIdentityInstalled(_ identity: String) -> Bool {
        guard let output = try? Shell.run(
            "/usr/bin/security",
            arguments: ["find-identity", "-v", "-p", "codesigning"]
        ) else {
            return false
        }
        return output.contains(identity)
    }

    /// Find a valid provisioning profile on disk that can sign the given bundle ID with the given team
    public static func findProvisioningProfile(bundleID: String, teamID: String) -> String? {
        let profilesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: profilesDir,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        struct Candidate {
            let path: String
            let isExactMatch: Bool
            let expirationDate: Date
        }

        var candidates: [Candidate] = []
        let now = Date()

        for file in files where file.pathExtension == "mobileprovision" {
            guard let decoded = try? Shell.run(
                "/usr/bin/security",
                arguments: ["cms", "-D", "-i", file.path]
            ),
                  let data = decoded.data(using: .utf8),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                continue
            }

            // Check expiration
            guard let expirationDate = plist["ExpirationDate"] as? Date, expirationDate > now else {
                continue
            }

            // Check team
            guard let teams = plist["TeamIdentifier"] as? [String], teams.contains(teamID) else {
                continue
            }

            // Check bundle ID via entitlements application-identifier
            guard let entitlements = plist["Entitlements"] as? [String: Any],
                  let appID = entitlements["application-identifier"] as? String else {
                continue
            }

            let isExactMatch: Bool
            let expectedPrefix = "\(teamID)."
            if appID == "\(teamID).\(bundleID)" {
                isExactMatch = true
            } else if appID == "\(teamID).*" || (appID.hasPrefix(expectedPrefix) && appID.hasSuffix(".*") && bundleID.hasPrefix(String(appID.dropFirst(expectedPrefix.count).dropLast(2)))) {
                isExactMatch = false
            } else {
                continue
            }

            candidates.append(Candidate(path: file.path, isExactMatch: isExactMatch, expirationDate: expirationDate))
        }

        // Rank: exact match first, then by latest expiration
        candidates.sort { a, b in
            if a.isExactMatch != b.isExactMatch {
                return a.isExactMatch
            }
            return a.expirationDate > b.expirationDate
        }

        return candidates.first?.path
    }
}
