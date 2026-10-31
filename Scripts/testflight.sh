#!/bin/bash
# アーカイブして TestFlight に上げる。ローカルでも CI でも同じ手順で動く。
set -euo pipefail

cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?App Store Connect の API キーの ID を渡すこと}"
: "${ASC_ISSUER_ID:?App Store Connect の API キーの Issuer ID を渡すこと}"
: "${ASC_KEY_PATH:?App Store Connect の API キー（.p8）のパスを渡すこと}"

ARCHIVE=build/PairCommit.xcarchive
SOURCE_PACKAGES=build/SourcePackages
CONTAINER=iCloud.com.fujimori.PairCommit

AUTH=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

rm -rf "$ARCHIVE" build/Export build/Upload

# アーカイブでは署名しない。署名すると、証明書のない CI では毎回開発用の証明書が新しく作られ、アカウントの上限に達する。
# 署名は書き出しのときに、Apple が預かる配布用の証明書で行う（WWDC21「Distribute apps in Xcode with cloud signing」）。
# -skipPackagePluginValidation / -skipMacroValidation: CLI では、パッケージのプラグインとマクロを信頼する確認に答えられない
xcodebuild \
  -scheme PairCommit \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive

# manageAppVersionAndBuildNumber: ビルド番号は、App Store Connect に上がっている最大の番号の次を Xcode がつける
export_options() {
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$1</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key>
	<true/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
}

export_options export > build/ExportOptions-export.plist
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions-export.plist \
  -exportPath build/Export \
  "${AUTH[@]}"

# 署名せずにアーカイブすると、書き出したアプリに iCloud と通知の権限が入るかは文書で確かめられていない。
# 入っていない版を上げると、TestFlight の版で iCloud が使えなくなるので、上げる前に止める。
rm -rf build/Export/Payload
unzip -q build/Export/*.ipa -d build/Export
ENTITLEMENTS=$(codesign -d --entitlements - --xml build/Export/Payload/*.app | plutil -convert json -o - - || echo '{}')
echo "$ENTITLEMENTS"
jq -e --arg container "$CONTAINER" '
  (."com.apple.developer.icloud-container-identifiers" | index($container)) != null
  and (."com.apple.developer.icloud-services" | index("CloudKit")) != null
  and ."aps-environment" == "production"
' <<<"$ENTITLEMENTS" >/dev/null || {
  echo "書き出したアプリに iCloud か通知の権限が入っていないので、上げずに止める" >&2
  exit 1
}

export_options upload > build/ExportOptions-upload.plist
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions-upload.plist \
  -exportPath build/Upload \
  "${AUTH[@]}"
