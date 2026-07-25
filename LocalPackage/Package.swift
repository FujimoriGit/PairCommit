// swift-tools-version: 6.0
import PackageDescription

// Domain（依存ゼロ）← Application / Infrastructure。Presentation はUI実装時に追加する。
// Data ではなく Infrastructure なのは、モジュール名 `Data` が Foundation.Data と衝突するため。
let package = Package(
    name: "LocalPackage",
    platforms: [
        .iOS("26.2"),
        .macOS("14.0"),
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.65.0"),
    ],
    targets: [
        .target(
            name: "Domain",
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .target(
            name: "Application",
            dependencies: ["Domain"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .target(
            name: "Infrastructure",
            dependencies: ["Domain"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", "Infrastructure"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: ["Infrastructure"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
