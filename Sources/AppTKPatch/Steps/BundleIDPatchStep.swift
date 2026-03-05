import AppTKCore
import Foundation

struct BundleIDPatchStep: PatchStep {
    let name = "Patch Bundle ID"

    func execute(context: inout IPAPatchContext) throws {
        guard let appDir = context.appDir else {
            throw IPAPatchError.missingContext("appDir")
        }
        guard let newBundleID = context.bundleID else {
            return
        }

        let plistURL = appDir.appendingPathComponent("Info.plist")
        var plist = try PlistReader.read(at: plistURL)

        let oldBundleID = plist["CFBundleIdentifier"] as? String ?? "unknown"
        plist["CFBundleIdentifier"] = newBundleID
        try PlistReader.write(at: plistURL, dict: plist)

        Formatter.printStep(name, "\(oldBundleID) → \(newBundleID)")
    }
}
