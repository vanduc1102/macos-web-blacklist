// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebBlacklist",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WebBlacklist", targets: ["WebBlacklist"])
    ],
    targets: [
        .executableTarget(
            name: "WebBlacklist",
            path: "Sources/WebBlacklist"
        )
    ]
)
