import AppTKCore
import Foundation

struct PlistAddStep: PatchStep {
    let name = "Add Plist Entries"

    func execute(context: inout IPAPatchContext) throws {
        guard let appDir = context.appDir else {
            throw IPAPatchError.missingContext("appDir")
        }
        guard !context.plistEntries.isEmpty else {
            return
        }

        let plistURL = appDir.appendingPathComponent("Info.plist")
        var plist = try PlistReader.read(at: plistURL)

        for entry in context.plistEntries {
            try PlistReader.setValue(entry.value, forKeyPath: entry.keyComponents, in: &plist)
            Formatter.printStep(name, "Set \(entry.keyPath) = \(entry.value)")
        }

        try PlistReader.write(at: plistURL, dict: plist)
    }
}
