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
  archive

# manageAppVersionAndBuildNumber: ビルド番号は、App Store Connect に上がっている最大の番号の次を Xcode がつける
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
	<true/>
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

