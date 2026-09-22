// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SeeUsage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SeeUsage", targets: ["SeeUsage"])
    ],
    targets: [
        .executableTarget(
            name: "SeeUsage",
            path: "Sources/SeeUsage"
        ),
        .testTarget(
            name: "SeeUsageTests",
            dependencies: ["SeeUsage"],
            path: "Tests/SeeUsageTests"
        )
    ]
)
