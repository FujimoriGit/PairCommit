# CLAUDE.md

このリポジトリで作業する際のガイドライン。

## プロジェクト

PairCommit ── 2人で使うコミットメントデバイス（アカウンタビリティパートナーのアプリ化）。
設計の意図・決定事項・データモデルは [`design.md`](./design.md) を必ず参照すること。設計の中心は機能ではなく **ロールの非対称性（Manager / Player）**。

## 設計原則

- **値型中心。** struct / enum を既定に。参照セマンティクスは「同一性・ライフサイクルを持つもの」（Store、セッション）だけに使う。
- **Functional core, imperative shell。**
  - ドメイン（`PartnershipState` の操作）は決定的な純粋関数に保つ。`Date()` / `UUID()` は既定値付き引数で注入し、テストから制御できるようにする。
  - 副作用（I/O・通信・永続化）は端（リポジトリ実装・Store・UI）へ押し出す。ドメインの中で `Task {}` を起動したり通信したりしない。
- **依存方向ルール（軽量クリーンアーキテクチャ）。**
  - `Domain` ← `Application` ← アプリ（UI / Infrastructure）。内側は外側を知らない。**ドメインは CloudKit / UIKit / SwiftUI を import しない。**
  - 境界はプロトコル（ポート）で切る。同期は `SyncRepository` の裏に隔離し、CloudKit は「実装の一つ」。
  - UseCase クラスや Presenter 層などの儀式は導入しない。ドメインロジックは集約ルート（`PartnershipState`）のメソッド、アプリケーションロジックは Store に置く。層を増やすのは痛みが出てから。
- **不変条件はドメインが守る。** active な Vision は高々1個 / ロール権限 / 状態遷移 ── すべて `PartnershipState` で強制し、UI や同期層に分散させない。
- **モジュール構成**: `Packages/PairCommitCore` に `Domain` / `Application`。Presentation モジュールはロール別UIの実装時に切り出す（VRT 設定と同時に移す）。モジュール境界 = 公開APIの境界として使う（安易に `public` を増やさない）。

## コーディング規約

規約のうち機械化できるものは **SwiftLint（SPMプラグイン、ビルドごとに実行）** が強制する。ルールの実体はリポジトリルートの `.swiftlint.yml` のみ（Packages 配下は `parent_config` で継承）。

- **Swift のセマンティクスに沿って書く。**
  - Optional・エラーは握り潰さず型で表現する。force unwrap (`!`) は禁止（lint error）。
  - API は Swift API Design Guidelines に沿った命名にする。
  - **protocol の命名**: 「何であるか」を表すものは名詞（`Collection`, `SyncRepository`）、「能力」を表すものは `-able` / `-ible` / `-ing`（`Equatable`, `ProgressReporting`）。`〜Protocol` サフィックスは使わない。
- **Swift 6 / strict concurrency に準拠する。**
  - `Sendable`・actor isolation・`@MainActor` を正しく付ける。データ競合を型で排除する。
  - UI に触れる状態・処理は `@MainActor`。非同期は `async/await`（コールバック地獄や生 `DispatchQueue` の濫用をしない）。デリゲート等のコールバック境界は `AsyncStream` で async/await の世界へ変換する。
  - 共有可変状態は actor かメインアクターに隔離する。
- **状態の監視は Observation を使う。**
  - `@Observable` を使う。`ObservableObject` / `@Published` は使わない。
  - View 側は `@State`（旧 `@StateObject` は使わない）。
- **`private` メソッドは `private extension` にまとめる。** 型本体には格納プロパティと公開 API を置き、private な実装は `// MARK: - Private` の `private extension` に分離する。
- **不要な条件コンパイルを足さない。** 本アプリは iOS 専用（`SDKROOT = iphoneos`, iPhone/iPad）。UIKit は常に使えるので `#if canImport(UIKit)` のようなプラットフォーム分岐は書かない。
- **ファイルヘッダーはテンプレートに揃える**（lint の `file_header` が強制。空コメント行は `//` のみ・末尾空白なし、ヘッダー後の空行は1行）。
  ```
  //
  //  <FileName>.swift
  //  PairCommit
  //
  //  Created by Daiki Fujimori on <yyyy/MM/dd>
  //
  ```
- ファイルの役割説明は、ヘッダーに混ぜず型の上に `///` ドキュメントコメントで書く。

## テスト原則（Khorikov『単体テストの考え方/使い方』準拠）

- **公開APIで観測可能な振る舞いをテストする。** 実装詳細（内部の呼び出し順・中間状態）に結合しない。`@testable` は使わず、モジュールの公開APIを通す（リファクタリング耐性の担保）。
- **ドメインのテストにモックを使わない**（古典派）。値型のドメインは実物をそのまま使えばよい。テストダブルはプロセス外依存（将来の CloudKit）の境界だけに限る。
- **書き方**: Given-When-Then。関数名は英語で「ビジネスルールとして何が成り立つか」を語る（例: `approvingSecondVisionWhileOneIsActiveFails`）。`@Test("...")` に日本語で仕様を書く。
- **良いテストの基準**: 退行の検出力 / リファクタリング耐性 / 実行速度 / 保守性。ドメインの1ルールに1テスト。壊れたらビジネスルールが壊れたことを意味するテストだけを残す。

## テスト・検証の実行

- 実行は `./Scripts/test.sh`（CIと同一条件。既定は iPhone 17 シミュレータ、なければ利用可能な iPhone にフォールバック）。
- テストの層:
  - **ドメイン**（`PartnershipStateTests`）── 不変条件・ロールガード・状態遷移。純粋・高速。ドメインを変えたら必ずここに足す。
  - **同期**（`SyncRepositoryTests`）── `SyncRepository` のセマンティクスと `PartnershipStore`。
  - **VRT**（Prefire）── `#Preview` からスナップショットテストを**ビルド時に自動生成**。View を作ったら `#Preview` を書くだけで対象になる（除外は `.prefireIgnored()`）。
- VRT の運用:
  - 基準画像は `PairCommitTests/__Snapshots__/` にコミットする。初回実行で自動記録、以後は差分で落ちる。
  - 意図した見た目変更のときは該当 PNG を削除して再実行し、新基準画像を PR に含めて差分をレビューする。
  - レンダリングは `.prefire.yml` の `snapshot_devices`（論理デバイス）と `required_os` で固定してある。実行シミュレータ差で揺らさないこと。
- CI は `.github/workflows/ci.yml`（PR と main push でビルド＋全テスト）。失敗時は xcresult がアーティファクトに上がる。

## プロジェクト構成メモ

- モジュール: `Packages/PairCommitCore`（`Sources/Domain`, `Sources/Application`）。アプリターゲットはこのローカルパッケージに依存する。
- アプリターゲットは Xcode の同期グループ（`PBXFileSystemSynchronizedRootGroup`）。`PairCommit/` 配下にファイルを置けば pbxproj を編集せずターゲットに自動で入る。パッケージ配下も `Sources/<Target>/` に置くだけでよい。
- Bundle ID: `com.daiki.paircommit` / CloudKit コンテナ: `iCloud.com.daiki.paircommit`
