# PairCommit

2人で使うコミットメントデバイス（アカウンタビリティパートナーのアプリ化）。
目的（ビジョン）はプレイヤーが選び、執行（タスク・承認・催促）は管理者が握る ── **ロールの非対称性（Manager / Player）** が設計の中心。

## ドキュメント

| ファイル | 内容 |
|---|---|
| [`design.md`](./design.md) | 設計の意図・決定事項・データモデル・現状とロードマップ |
| [`CLAUDE.md`](./CLAUDE.md) | 設計原則・コーディング規約・テスト原則（SwiftLint が機械的に強制） |

## 構成

```
PairCommit/               アプリ本体（UI・MC+CloudKit ペアリングスパイク）
LocalPackage/             Domain / Application / Infrastructure モジュール（ローカルSPM）
PairCommitTests/          VRT基準画像（__Snapshots__/）。ユニットテストは LocalPackage/Tests/
Scripts/test.sh           ビルド＆全テスト（CIと同一条件）
```

## 開発

- 必要環境: Xcode 26.x
- ユニットテスト: `swift test --package-path LocalPackage`（シミュレータ不要）
- アプリのビルドと VRT: `./Scripts/test.sh`（VRT は `#Preview` から自動生成される）
- CI: GitHub Actions（PR / main push で `unit-tests.yml` と `ci.yml` の2本）
- CloudKit の実機検証は Apple Developer Program 加入待ち（`design.md` 未決事項参照）
