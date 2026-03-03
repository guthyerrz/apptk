// swift-tools-version: 6.2

import PackageDescription
import class Foundation.ProcessInfo

let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"]
    ?? "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
let javaIncludePath = "\(javaHome)/include"
#if os(macOS)
let javaPlatformIncludePath = "\(javaIncludePath)/darwin"
#elseif os(Linux)
let javaPlatformIncludePath = "\(javaIncludePath)/linux"
#endif

let package = Package(
    name: "apptk",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "apptk", targets: ["apptk"]),
        .library(name: "AppTKKit", targets: ["AppTKKit"]),
        .library(name: "AppTKCore", targets: ["AppTKCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-java.git", branch: "main"),
    ],
    targets: [
        // MARK: - Executable

        .executableTarget(
            name: "apptk",
            dependencies: ["AppTKKit"]
        ),

        // MARK: - Aggregator

        .target(
            name: "AppTKKit",
            dependencies: [
                "AppTKCore",
                "AppTKInfo",
                "AppTKPatch",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MARK: - Core (pure Foundation, zero external deps)

        .target(
            name: "AppTKCore"
        ),

        // MARK: - Feature: Info

        .target(
            name: "AppTKInfo",
            dependencies: [
                "AppTKCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            swiftSettings: [
                .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
            ],
            plugins: [
                .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
            ]
        ),

        // MARK: - Feature: Patch

        .target(
            name: "AppTKPatch",
            dependencies: [
                "AppTKCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "AppTKCoreTests",
            dependencies: ["AppTKCore"]
        ),
        .testTarget(
            name: "AppTKInfoTests",
            dependencies: [
                "AppTKInfo",
                "AppTKCore",
            ]
        ),
        .testTarget(
            name: "AppTKPatchTests",
            dependencies: [
                "AppTKPatch",
                "AppTKCore",
            ]
        ),
    ]
)
