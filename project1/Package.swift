// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FrameScript",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FrameScriptCore", targets: ["FrameScriptCore"]),
        .executable(name: "FrameScript", targets: ["FrameScriptApp"])
    ],
    targets: [
        .target(name: "FrameScriptCore", path: "Sources/FrameScriptCore"),
        .executableTarget(
            name: "FrameScriptApp",
            dependencies: ["FrameScriptCore"],
            path: "Sources/FrameScriptApp"
        ),
        .testTarget(
            name: "FrameScriptCoreTests",
            dependencies: ["FrameScriptCore"],
            path: "Tests/FrameScriptCoreTests"
        )
    ]
)
