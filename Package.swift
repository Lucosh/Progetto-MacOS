// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GestionaleFenice",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "FeniceCore"),
        .testTarget(name: "FeniceCoreTests", dependencies: ["FeniceCore"])
    ]
)
