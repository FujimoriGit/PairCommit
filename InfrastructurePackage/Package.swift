// swift-tools-version: 6.0
import PackageDescription

// Data ではなく Infrastructure なのは、モジュール名 `Data` が Foundation.Data と衝突するため。
let package = Package(
    name: "InfrastructurePackage",
    platforms: [
        .iOS("18.6"),
    ],
    products: [
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
    ],
    dependencies: [
        .package(path: "../LocalPackage"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.65.0"),
    ],
    targets: [
        .target(
            name: "Infrastructure",
            dependencies: [
                .product(name: "Domain", package: "LocalPackage"),
                .product(name: "Application", package: "LocalPackage"),
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
