// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SideKitCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SideKitCore", targets: ["SideKitCore"])
    ],
    targets: [
        .target(name: "SideKitCore"),
        .testTarget(name: "SideKitCoreTests", dependencies: ["SideKitCore"])
    ]
)
