// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RKNChecker",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RKNChecker",
            targets: ["RKNChecker"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RKNChecker",
            path: "RKNChecker",
            exclude: ["App/Info.plist", "Resources", "App/RKNCheckerApp.swift"]
        ),
        .testTarget(
            name: "RKNCheckerTests",
            dependencies: ["RKNChecker"],
            path: "Tests/RKNCheckerTests"
        )
    ]
)
