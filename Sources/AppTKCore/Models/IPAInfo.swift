import Foundation

public struct IPAInfo {
    public let bundleId: String
    public let appName: String
    public let version: String
    public let buildNumber: String
    public let minimumOSVersion: String
    public let sdkVersion: String?
    public let architectures: [String]
    public let signingIdentity: String?
    public let teamName: String?
    public let provisioningProfile: ProvisioningInfo?
    public let entitlements: [String: Any]?
    public let fileSize: UInt64
    public let deviceFamily: [String]

    public init(
        bundleId: String,
        appName: String,
        version: String,
        buildNumber: String,
        minimumOSVersion: String,
        sdkVersion: String?,
        architectures: [String],
        signingIdentity: String?,
        teamName: String?,
        provisioningProfile: ProvisioningInfo?,
        entitlements: [String: Any]?,
        fileSize: UInt64,
        deviceFamily: [String]
    ) {
        self.bundleId = bundleId
        self.appName = appName
        self.version = version
        self.buildNumber = buildNumber
        self.minimumOSVersion = minimumOSVersion
        self.sdkVersion = sdkVersion
        self.architectures = architectures
        self.signingIdentity = signingIdentity
        self.teamName = teamName
        self.provisioningProfile = provisioningProfile
        self.entitlements = entitlements
        self.fileSize = fileSize
        self.deviceFamily = deviceFamily
    }
}

public struct ProvisioningInfo {
    public let name: String
    public let teamName: String?
    public let expirationDate: Date?
    public let type: String

    public init(
        name: String,
        teamName: String?,
        expirationDate: Date?,
        type: String
    ) {
        self.name = name
        self.teamName = teamName
        self.expirationDate = expirationDate
        self.type = type
    }
}
