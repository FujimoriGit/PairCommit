#!/bin/bash
# ローカルと CI で同一条件のビルド＆テストを実行する。
# VRT（Prefire）は required_os / snapshot_devices を固定しているため、
# シミュレータの選択もここで一元化する。
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME=PairCommit
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
RESULT_BUNDLE=build/TestResults.xcresult

# 指定デバイスがなければ、利用可能な iPhone シミュレータの先頭にフォールバック
if ! xcrun simctl list devices available | grep -q "${DEVICE_NAME} ("; then
  DEVICE_NAME=$(xcrun simctl list devices available | grep -oE "^ *iPhone [^(]+" | head -1 | sed -E 's/^ +| +$//g')
  echo "warning: 既定のシミュレータが見つからないため '${DEVICE_NAME}' を使います" >&2
fi

rm -rf "$RESULT_BUNDLE"

# -skipPackagePluginValidation: PrefireTestsPlugin（テスト自動生成）を CLI から動かすのに必要
# PairCommitUITests はテンプレートのままで起動計測だけに数分かかるため除外（中身ができたら外す）
xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=${DEVICE_NAME}" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -skipPackagePluginValidation \
  -skip-testing:PairCommitUITests \
  test
