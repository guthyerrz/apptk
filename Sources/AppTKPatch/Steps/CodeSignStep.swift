import AppTKCore
import Foundation

struct CodeSignStep: PatchStep {
    let name = "Code Sign"

    func execute(context: inout IPAPatchContext) throws {
        guard let appDir = context.appDir else {
            throw IPAPatchError.missingContext("appDir")
        }
        guard let identity = context.signingIdentity else {
            return
        }

        let fileManager = FileManager.default

        // Build entitlements args
        var entitlementsArgs: [String] = []
        if let entPlist = context.entitlementsPlist {
            entitlementsArgs = ["--entitlements", entPlist.path]
        }

        // 1. Sign frameworks (inner-most first)
        let frameworksDir = appDir.appendingPathComponent("Frameworks")
        if fileManager.fileExists(atPath: frameworksDir.path) {
            let frameworks = try fileManager.contentsOfDirectory(at: frameworksDir, includingPropertiesForKeys: nil)
            for fw in frameworks {
                try codesign(path: fw.path, identity: identity, entitlements: nil)
                Formatter.printStep(name, "Signed \(fw.lastPathComponent)")
            }
        }

        // 2. Sign app extensions
        let pluginsDir = appDir.appendingPathComponent("PlugIns")
        if fileManager.fileExists(atPath: pluginsDir.path) {
            let plugins = try fileManager.contentsOfDirectory(at: pluginsDir, includingPropertiesForKeys: nil)
            for plugin in plugins where plugin.pathExtension == "appex" {
                try codesign(path: plugin.path, identity: identity, entitlements: entitlementsArgs.isEmpty ? nil : context.entitlementsPlist?.path)
                Formatter.printStep(name, "Signed \(plugin.lastPathComponent)")
            }
        }

        // 3. Sign the main app bundle (outermost)
        try codesign(path: appDir.path, identity: identity, entitlements: context.entitlementsPlist?.path)
        Formatter.printStep(name, "Signed \(appDir.lastPathComponent)")
    }

    private func codesign(path: String, identity: String, entitlements: String?) throws {
        var args = ["-f", "-s", identity]
        if let ent = entitlements {
            args += ["--entitlements", ent]
        }
        args.append(path)
        try Shell.run("/usr/bin/codesign", arguments: args)
    }
}
