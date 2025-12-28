// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalBloom",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [.library(name: "MetalBloom", targets: ["MetalBloom"])],
    dependencies: [
        .package(url: "https://github.com/schwa/MetalCompilerPlugin", .upToNextMajor(from: "0.1.5")),
        .package(url: "https://github.com/banjun/ShaderGraphCoder", branch: "macos"),
    ],
    targets: [
        .target(name: "MetalBloomBridgingHeader", publicHeadersPath: "include"),
        .target(
            name: "MetalBloom",
            dependencies: ["ShaderGraphCoder", "MetalBloomBridgingHeader"],
            resources: [],
            plugins: [
                .plugin(name: "MetalCompilerPlugin", package: "MetalCompilerPlugin")
            ],
        ),
    ]
)
