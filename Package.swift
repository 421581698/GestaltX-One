// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GestaltXOne",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "GestaltXOneCore", targets: ["GestaltXOneCore"])
    ],
    targets: [
        .target(name: "GestaltXOneCore"),
        .testTarget(name: "GestaltXOneCoreTests", dependencies: ["GestaltXOneCore"])
    ]
)
