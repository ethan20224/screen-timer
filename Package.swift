// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ScreenTime",
    platforms: [.macOS(.v26)],
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
