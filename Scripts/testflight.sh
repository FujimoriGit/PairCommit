#!/bin/bash
# アーカイブして TestFlight に上げる。ローカルでも CI でも同じ手順で動く。
set -euo pipefail

cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?App Store Connect の API キーの ID を渡すこと}"
: "${ASC_ISSUER_ID:?App Store Connect の API キーの Issuer ID を渡すこと}"
: "${ASC_KEY_PATH:?App Store Connect の API キー（.p8）のパスを渡すこと}"

ARCHIVE=build/PairCommit.xcarchive
EXPORT_OPTIONS=build/ExportOptions.plist
SOURCE_PACKAGES=build/SourcePackages

# App Store Connect は、同じバージョンでは前より大きいビルド番号しか受け付けない。
# 各部分は 32 ビットの整数に収める必要があるので、日付と時刻を分ける（例: 20261006.930）
NOW=$(date -u +%Y%m%d%H%M)
BUILD_NUMBER="${NOW:0:8}.$((10#${NOW:8:4}))"

AUTH=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

rm -rf "$ARCHIVE" build/Export

# -skipPackagePluginValidation / -skipMacroValidation: CLI では、パッケージのプラグインとマクロを信頼する確認に答えられない
xcodebuild \
  -scheme PairCommit \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  "${AUTH[@]}" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive

cat > "$EXPORT_OPTIONS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath build/Export \
  "${AUTH[@]}"

echo "ビルド ${BUILD_NUMBER} を App Store Connect に上げた。"
