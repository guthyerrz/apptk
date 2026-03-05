// swift-tools-version: 6.2

import PackageDescription

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

        // MARK: - Mach-O (pure Foundation, zero external deps)

        .target(
            name: "AppTKMachO"
        ),

        // MARK: - Feature: Info

        .target(
            name: "AppTKInfo",
            dependencies: [
                "AppTKCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MARK: - Feature: Patch

        .target(
            name: "AppTKPatch",
            dependencies: [
                "AppTKCore",
                "AppTKMachO",
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
            name: "AppTKMachOTests",
            dependencies: ["AppTKMachO"]
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
