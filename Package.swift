// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ScreenTime",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenTime",
            path: "Sources/ScreenTime",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "ScreenTimeTests",
            dependencies: ["ScreenTime"],
            path: "Tests/ScreenTimeTests"
        )
    ]
)
