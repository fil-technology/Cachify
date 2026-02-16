// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "cachify",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "cachify", targets: ["cachify"])
    ],
    targets: [
        .executableTarget(
            name: "cachify"
        )
    ]
)
