import Foundation

public struct IPAPatchContext {
    // MARK: - Inputs (set before pipeline runs)

    public let inputIPA: String
    public let frameworkPath: String
    public let outputIPA: String
    public var signingIdentity: String?
    public var provisioningProfile: String?
    public let bundleID: String?
    public let plistEntries: [PlistEntry]

    // MARK: - Working state (set by steps during pipeline)

    public var tempDir: URL?
    public var appDir: URL?
    public var executableName: String?
    public var binaryURL: URL?
    public var entitlementsPlist: URL?

    public init(
        inputIPA: String,
        frameworkPath: String,
        outputIPA: String,
        signingIdentity: String? = nil,
        provisioningProfile: String? = nil,
        bundleID: String? = nil,
        plistEntries: [PlistEntry] = []
    ) {
        self.inputIPA = inputIPA
        self.frameworkPath = frameworkPath
        self.outputIPA = outputIPA
        self.signingIdentity = signingIdentity
        self.provisioningProfile = provisioningProfile
        self.bundleID = bundleID
        self.plistEntries = plistEntries
    }
}
