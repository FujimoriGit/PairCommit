#!/bin/bash
# アプリのビルドと VRT を、ローカルと CI で同一条件で実行する。
# ユニットテストは swift test --package-path LocalPackage（シミュレータ不要）。
# VRT は required_os / snapshot_devices を固定しているため、
# シミュレータの選択もここで一元化する。
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME=PairCommit
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
RESULT_BUNDLE=build/TestResults.xcresult

# simctl は選択中の Xcode に関係なく、入っているランタイムをすべて並べる。
# 新しいランタイムの端末を選ぶと、Xcode を固定していても描画が変わるので、SDK と同じ版に絞る
SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
DEVICES=$(xcrun simctl list devices available "iOS ${SDK_VERSION}")

# 指定デバイスがなければ、利用可能な iPhone シミュレータの先頭にフォールバック
if ! grep -qE "^ +${DEVICE_NAME} \(" <<< "$DEVICES"; then
  DEVICE_NAME=$(grep -oE "^ *iPhone [^(]+" <<< "$DEVICES" | head -1 | sed -E 's/^ +| +$//g')
  echo "warning: 既定のシミュレータが見つからないため '${DEVICE_NAME}' を使います" >&2
fi

DEVICE_ID=$(grep -E "^ +${DEVICE_NAME} \(" <<< "$DEVICES" | head -1 | grep -oE "[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}")

# 起動に数分かかるので、ビルドと重ねる。起動済みなら失敗するが構わない
xcrun simctl boot "$DEVICE_ID" 2>/dev/null &

rm -rf "$RESULT_BUNDLE"

# -skipPackagePluginValidation: PrefireTestsPlugin（テスト自動生成）を CLI から動かすのに必要
# PairCommitUITests はテンプレートのままで起動計測だけに数分かかるため除外（中身ができたら外す）
# -parallel-testing-enabled NO: 並列はクラス単位で振り分けるが、テストは生成される1クラスだけなので速くならない。
# 複製したシミュレータでアプリが起動できず、10分ほど待たされることがある
xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=${DEVICE_ID}" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -skipPackagePluginValidation \
  -skip-testing:PairCommitUITests \
  -parallel-testing-enabled NO \
  test
