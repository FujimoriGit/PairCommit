# CLAUDE.md

このリポジトリで作業する際のガイドライン。

## プロジェクト

PairCommit ── 2人で使うコミットメントデバイス（アカウンタビリティパートナーのアプリ化）。
設計の意図・決定事項・データモデルは [`design.md`](./design.md) を必ず参照すること。設計の中心は機能ではなく **ロールの非対称性（Manager / Player）**。

## コーディング規約

- **Swift のセマンティクスに沿って書く。**
  - 値型（struct / enum）を既定に。参照セマンティクスが要る所だけ class。
  - Optional・エラーは握り潰さず型で表現する。force unwrap (`!`) は避ける。
  - API は Swift API Design Guidelines に沿った命名にする。
- **Swift 6 / strict concurrency に準拠する。**
  - `Sendable`・actor isolation・`@MainActor` を正しく付ける。データ競合を型で排除する。
  - UI に触れる状態・処理は `@MainActor`。非同期は `async/await`（コールバック地獄や生 `DispatchQueue` の濫用をしない）。
  - 共有可変状態は actor かメインアクターに隔離する。
- **状態の監視は Observation を使う。**
  - `@Observable` を使う。`ObservableObject` / `@Published` は使わない。
  - View 側は `@State`（旧 `@StateObject` は使わない）。
- **`private` メソッドは `private extension` にまとめる。** 型本体には格納プロパティと公開 API を置き、private な実装は `// MARK: - Private` の `private extension` に分離する。
- **不要な条件コンパイルを足さない。** 本アプリは iOS 専用（`SDKROOT = iphoneos`, iPhone/iPad）。UIKit は常に使えるので `#if canImport(UIKit)` のようなプラットフォーム分岐は書かない。
- **ファイルヘッダーは既存テンプレートに揃える。**
  ```
  //
  //  <FileName>.swift
  //  PairCommit
  //
  //  Created by Daiki Fujimori on <作成日>
  //
  ```
  （空コメント行は `//` のあとに半角スペース2つ。Xcode 既定テンプレートに準拠）
- ファイルの役割説明は、ヘッダーに混ぜず型の上に `///` ドキュメントコメントで書く。

## アーキテクチャ方針（design.md より）

- ドメイン層は CloudKit を知らない。同期は `SyncRepository` 的なプロトコルの裏に隔離し、CloudKit はその実装の一つにする。
- 中心の不変条件: **アクティブな Vision は常に1個**。

## プロジェクト構成メモ

- Xcode 16 の同期グループ（`PBXFileSystemSynchronizedRootGroup`）。`PairCommit/` 配下にファイルを置けば pbxproj を編集せずターゲットに自動で入る。
- Bundle ID: `com.daiki.paircommit` / CloudKit コンテナ: `iCloud.com.daiki.paircommit`
