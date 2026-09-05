# CLAUDE.md

このリポジトリで作業する際のガイドライン。

## プロジェクト

PairCommit ── 2人で使うコミットメントデバイス（アカウンタビリティパートナーのアプリ化）。
設計の意図・決定事項・データモデルは [`design.md`](./design.md) を必ず参照すること。設計の中心は機能ではなく **ロールの非対称性（Manager / Player）**。

## 設計原則

- **値型中心。** struct / enum を既定に。参照セマンティクスは「同一性・ライフサイクルを持つもの」（Store、セッション）だけに使う。
- **Functional core, imperative shell。**
  - ドメインの操作は決定的な純粋関数に保つ。`Date()` / `UUID()` は既定値付き引数で注入し、テストから制御できるようにする。
  - 副作用（I/O・通信・永続化）は端（同期層の実装・Store・UI）へ押し出す。ドメインの中で `Task {}` を起動したり通信したりしない。
- **ドメインに `mutating` を書かない。** 状態を変える操作は、受け取った値を変更せず**新しい値を返す関数**にする（`func 〜() throws -> PartnershipState`）。
  - 格納プロパティは `var` ではなく `let`。書き換えられないことを型で示す。
  - 命名は Swift API Design Guidelines の非破壊側に倣い `-ing` / `-ed` 形にする（`approvingVision`）。
  - **型が文脈から決まるところで型名を繰り返さない。** 自分自身を返すなら戻り値の型は `Self`、生成は `.init(...)`。リネームに強く、読み手も型名の一致を確かめずに済む。
  - 可変状態を持ってよいのは、同一性とライフサイクルを持つ端（Store・セッション）だけ。
- **依存方向ルール（軽量クリーンアーキテクチャ）。**
  - `Domain` ← `Application` ← アプリ（UI / Infrastructure）。内側は外側を知らない。**ドメインは CloudKit / UIKit / SwiftUI を import しない。**
  - 境界は protocol で抽象化する。外部サービスへの依存は、その protocol の実装の一つとして差し替えられる状態を保つ。
  - UseCase クラスや Presenter 層などの儀式は導入しない。ドメインロジックは集約ルート（`PartnershipState`）のメソッド、アプリケーションロジックは Store に置く。層を増やすのは痛みが出てから。
- **不変条件はドメインが守る。** active な Vision は高々1個 / ロール権限 / 状態遷移 ── すべて `PartnershipState` で強制し、UI や同期層に分散させない。
- **モジュール構成**: `LocalPackage` に `Domain` / `Application` / `Infrastructure`。View はアプリターゲットに置く（パッケージの外側なので、公開APIの境界はそれで効く）。SwiftUI や Apple のフレームワークに依存するものをパッケージに入れると、ubuntu で回している `swift test` が壊れる。モジュール境界 = 公開APIの境界として使う（安易に `public` を増やさない）。

## コーディング規約

規約のうち機械化できるものは **SwiftLint（SPMプラグイン、ビルドごとに実行）** が強制する。ルールの実体はリポジトリルートの `.swiftlint.yml` のみ（Packages 配下は `parent_config` で継承）。

- **Swift のセマンティクスに沿って書く。**
  - Optional・エラーは握り潰さず型で表現する。force unwrap (`!`) は禁止（lint error）。
  - API は Swift API Design Guidelines に沿った命名にする。
  - **protocol の命名**: 「何であるか」を表すものは名詞（`Collection`, `Sequence`）、「能力」を表すものは `-able` / `-ible` / `-ing`（`Equatable`, `ProgressReporting`）。`〜Protocol` サフィックスは使わない。
  - **他言語由来の型名サフィックスを持ち込まない。** `Repository` / `Service` / `Helper` / `Util` などは使わない。
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
- **コメントは書かない方に倒す。** コメントもコードと同じく保守対象で、放置されれば嘘になる。書く前に「これは消せないか」を問う。
  - **名前・シグネチャ・型から読めることは書かない。** 引数や戻り値の言い換え、メソッド名の和訳、enum ケースの説明は消す。
  - **実装の詳細・手順を書かない。** 何をどの順で処理するかはコードが語る。書くなら「なぜそうしたか」だけ。
  - **他の型名を本文に書かない。** リネームのたびに追随が必要になる。関係は import と型で辿れる。
  - **設計の意図・思想は `design.md` に書く。** コードに置くと、設計が変わったとき2箇所直すことになる。
  - **`///` と `//` を使い分ける。** `///` は公開APIの**利用者向けの説明**（呼ぶ側が知る必要のあること）。実装の事情・背景・そう書いた理由は `///` ではなく `//` で書く。事情を `///` に書かない。
  - **事情は原則書かない。** 書いてよいのは、**コードを読んでも導けないもの**だけ ── OS やライブラリ側の癖・制約、外部仕様の要求。「なぜこの実装にしたか」がコードを追えば分かるなら書かない。
- ファイルの役割説明は、ヘッダーに混ぜず型の上に `///` ドキュメントコメントで書く（不要なら書かない）。

## テスト原則（Khorikov『単体テストの考え方/使い方』準拠）

- **公開APIで観測可能な振る舞いをテストする。** 実装詳細（内部の呼び出し順・中間状態）に結合しない。`@testable` は使わず、モジュールの公開APIを通す（リファクタリング耐性の担保）。
- **ドメインのテストにモックを使わない**（古典派）。値型のドメインは実物をそのまま使えばよい。テストダブルはプロセス外依存（将来の CloudKit）の境界だけに限る。
- **書き方**: Given-When-Then。関数名は英語で「ビジネスルールとして何が成り立つか」を語る（例: `approvingSecondVisionWhileOneIsActiveFails`）。`@Test("...")` に日本語で仕様を書く。
- **良いテストの基準**: 退行の検出力 / リファクタリング耐性 / 実行速度 / 保守性。ドメインの1ルールに1テスト。壊れたらビジネスルールが壊れたことを意味するテストだけを残す。

## テスト・検証の実行

- **ユニットテスト**: `swift test --package-path LocalPackage`。シミュレータもアプリのビルドも要らない。ドメインを触っている間はこれだけでよい。
- **アプリのビルドと VRT**: `./Scripts/test.sh`（既定は iPhone 17 シミュレータ、なければ利用可能な iPhone にフォールバック）。
- **`#Preview` を足したら、テストターゲットのビルドまで通す**: `xcodebuild -scheme PairCommit -destination "platform=iOS Simulator,name=iPhone 17" -skipPackagePluginValidation -skip-testing:PairCommitUITests build-for-testing`。基準画像を record せずに、自動生成されたテストがコンパイルできるかだけを確かめられる。アプリターゲットの `build` は生成テストを作らないので、ここは通らない。
- **UI に関係しないテストはパッケージ側に置く。** アプリのテストターゲットに置くとシミュレータ起動が要る。
- テストの層:
  - **ドメイン**（`Tests/DomainTests`）── 不変条件・ロールガード・状態遷移。ドメインを変えたら必ずここに足す。
  - **アプリケーション**（`Tests/ApplicationTests`）── Store の楽観適用・巻き戻し・リモート変更の反映。
  - **インフラ**（`Tests/InfrastructureTests`）── 同期実装のセマンティクス。
  - **VRT**（Prefire・`PairCommitTests`）── `#Preview` からスナップショットテストを**ビルド時に自動生成**。View を作ったら `#Preview` を書くだけで対象になる（除外は `.prefireIgnored()`）。シミュレータが要るのはここだけ。
- VRT の運用:
  - 基準画像は `PairCommitTests/__Snapshots__/` にコミットする。**record は CI でしかしない**（手元で撮らない）。手元の Mac と CI ではアンチエイリアスが一致しないため、記録する環境を1つに固定する。
  - **基準画像がまだない `#Preview` は、`ci.yml` が撮って PR に足す。** 比べる相手がいないので、自動で取り込んでも退行を見逃さない。撮られた画像は PR の差分に出るので、そこで見る。
  - **`#Preview` の名前を変えるコミットで、その View の見た目を変えない。** 名前がそのまま基準画像の名前になるので、名前を変えると比べる相手が消え、変えたあとの見た目がそのまま基準画像として取り込まれる。両方やるときは `update-snapshots` を手動実行して差分をレビューする（古い名前の画像もそこで消える）。
  - **既存の基準画像との差分は自動で取り込まない。** 意図した変更か退行かはコードから判定できず、自動で取り込むと VRT が何も検出しなくなる。意図した変更のときは、そのブランチで `update-snapshots` を手動実行する。基準画像がコミットされて返るので、差分をレビューする。
  - レンダリングは `.prefire.yml` の `snapshot_devices`（論理デバイス）と `required_os`、`ci.yml` の Xcode バージョンで固定してある。
  - 差分が出たときに `.snapshot(precision:)` で許容値を緩めない。退行を見逃す。ずれたら基準画像を record し直す。
  - `#Preview` に付けた名前がそのままテスト関数名になり、View 名は入らない。**リポジトリ全体で一意になる名前を付ける**（`承認待ち` ではなく `管理者の承認待ち`）。
  - 生成されるテストには元ファイルの import が引き継がれない。プレビューがパッケージの型に触れるなら、`.prefire.yml` の `imports` に足す。
- CI は PR と main push で2つ動く。`unit-tests.yml`（ubuntu・`swift test`）と `ci.yml`（macOS・アプリのビルドと VRT）。同じテストを2度走らせない。失敗時は xcresult がアーティファクトに上がる。

## 文章の書き方（PR・コミット・報告）

コメントの原則（「書かない方に倒す」）は、コードの外の文章にもそのまま効く。

- **普通の言葉で書く。** 「ポートを切る」「〜の裏に隔離する」のような言い回しを使わず、`protocol` で抽象化した、と書く。造語や比喩を持ち込まない。
- **書くのは、コードを読んでも導けない決定とその理由だけ。** 差分を読めば分かること、CI が判定することは書かない。
- **理由は、反対の選択肢では成り立たない文だけを書く。** どちらを選んでも同じことが言える文は理由になっていない（例: Xcode を 26.2 に固定した理由として「既定に追随すると固定の意味がなくなる」── 26.6 に固定しても同じことが言えるので、選んだ根拠を何も説明していない）。書いたら反対の選択肢を代入して読み返す。
- **PR の節を勝手に増やさない。** テンプレートの「概要 / 変更内容 / 検証」で書く。収まらない内容は、節を作るのではなく概要か変更内容に畳む。

## プロジェクト構成メモ

- モジュール: `LocalPackage`（`Sources/` に Domain / Application / Infrastructure、`Tests/` に各層のテスト）。アプリターゲットはこのローカルパッケージに依存する。
- アプリターゲットは Xcode の同期グループ（`PBXFileSystemSynchronizedRootGroup`）。`PairCommit/` 配下にファイルを置けば pbxproj を編集せずターゲットに自動で入る。パッケージ配下も `Sources/<Target>/` に置くだけでよい。
- Bundle ID: `com.daiki.paircommit` / CloudKit コンテナ: `iCloud.com.daiki.paircommit`
