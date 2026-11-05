// swift-tools-version:5.9
import PackageDescription

// qui c'è solo il core: l'app iOS è in GestionaleFenice.xcodeproj.
// Il core si compila (e si testa) anche su macOS e Linux.
let package = Package(
    name: "GestionaleFenice",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeniceCore", targets: ["FeniceCore"])
    ],
    targets: [
        .target(name: "FeniceCore"),
        .testTarget(name: "FeniceCoreTests", dependencies: ["FeniceCore"])
    ]
)
