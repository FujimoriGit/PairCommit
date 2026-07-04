// swift-tools-version: 6.0
import PackageDescription

// アプリ本体から独立したコアモジュール群。
// - Domain: 純粋なドメイン層。フレームワーク（CloudKit / UIKit / SwiftUI）を一切知らない。
// - Application: ドメインとUI・同期実装をつなぐ層（Store、リポジトリのインメモリ実装）。
// Presentation モジュールはロール別UIの実装時に切り出す（VRT設定と同時に移すため）。
let package = Package(
    name: "PairCommitCore",
    platforms: [
        .iOS("26.2"),
        // SwiftLint プラグイン・Observation の実行要件（アプリは iOS 専用のまま）
        .macOS("14.0"),
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
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
    ],
    swiftLanguageModes: [.v6]
)
