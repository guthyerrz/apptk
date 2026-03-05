import AppTKCore
import Foundation

struct ProvisioningReplaceStep: PatchStep {
    let name = "Replace Provisioning"

    func execute(context: inout IPAPatchContext) throws {
        guard let appDir = context.appDir else {
            throw IPAPatchError.missingContext("appDir")
        }
        guard let profilePath = context.provisioningProfile else {
            return
        }

        let profileURL = URL(fileURLWithPath: profilePath)
        let destination = appDir.appendingPathComponent("embedded.mobileprovision")

        // Copy provisioning profile
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: profileURL, to: destination)

        // Extract entitlements from the profile for codesigning
        let decoded = try Shell.run("/usr/bin/security", arguments: ["cms", "-D", "-i", profilePath])
        guard let data = decoded.data(using: .utf8),
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else {
            throw IPAPatchError.stepFailed(step: name, reason: "Failed to extract entitlements from provisioning profile")
        }

        // Write entitlements to a temp file for codesign --entitlements
        let tempDir = context.tempDir ?? fileManager.temporaryDirectory
        let entitlementsURL = tempDir.appendingPathComponent("entitlements.plist")
        let entData = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
        try entData.write(to: entitlementsURL)

        context.entitlementsPlist = entitlementsURL
        Formatter.printStep(name, "Provisioning profile replaced, entitlements extracted")
    }
}
