// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AntennaPodCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "AntennaPodCore", targets: ["AntennaPodCore"])
    ],
    targets: [
        .target(name: "AntennaPodCore"),
        .testTarget(name: "AntennaPodCoreTests", dependencies: ["AntennaPodCore"])
    ]
)
