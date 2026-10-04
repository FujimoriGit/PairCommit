#!/bin/bash
# ユニットテストを、ローカルと CI で同一条件で実行する。
# swift test はテストが使わないターゲットまでビルドし、Apple のフレームワークを使う Infrastructure が
# ubuntu と macOS ホストではビルドできない。テストが依存するものだけをビルドしてから走らせる。
set -euo pipefail

cd "$(dirname "$0")/../LocalPackage"

swift build --product LocalPackagePackageTests
swift test --skip-build "$@"
