import AppTKCore
import Foundation

struct SigningDetectStep: PatchStep {
    let name = "Detect Signing"

    func execute(context: inout IPAPatchContext) throws {
        guard let appDir = context.appDir else {
            throw IPAPatchError.missingContext("appDir")
        }

        // Auto-detect signing identity if not provided
        var team: String?
        if context.signingIdentity == nil {
            let (identity, detectedTeam) = SigningDetector.detectIdentity(appDir: appDir)
            team = detectedTeam
            if let identity, SigningDetector.isIdentityInstalled(identity) {
                context.signingIdentity = identity
                Formatter.printStep(name, "Found signing identity: \(identity)")
            } else if let identity {
                Formatter.printWarning("Signing identity not in keychain: \(identity)")
            } else {
                Formatter.printWarning("No signing identity found in app bundle")
            }
        }

        // Auto-detect provisioning profile if not provided
        if context.provisioningProfile == nil {
            let plist = try? PlistReader.read(at: appDir.appendingPathComponent("Info.plist"))
            let bundleID = context.bundleID ?? (plist?["CFBundleIdentifier"] as? String)
            if let bundleID, let teamID = team {
                if let path = SigningDetector.findProvisioningProfile(bundleID: bundleID, teamID: teamID) {
                    context.provisioningProfile = path
                    Formatter.printStep(name, "Found provisioning profile: \(path)")
                } else {
                    Formatter.printWarning("No matching provisioning profile found for \(bundleID)")
                }
            }
        }
    }
}
