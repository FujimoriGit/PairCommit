#!/bin/bash
# iCloud の公開データベースに送られた診断の記録を、新しい順に読む。
# 使い方: Scripts/diagnostics.sh [さかのぼる時間（既定 24）] [development|production（既定 production）]
set -euo pipefail

HOURS="${1:-24}"
ENVIRONMENT="${2:-production}"
CONFIG_DIR="$HOME/.config/paircommit"
KEY_PATH="${CLOUDKIT_KEY_PATH:-$CONFIG_DIR/cloudkit-server.pem}"
# サーバー間キーは、CloudKit Console で登録した環境でしか通らない。
KEY_ID="${CLOUDKIT_KEY_ID:-$(cat "$CONFIG_DIR/cloudkit-key-id-$ENVIRONMENT" 2>/dev/null || true)}"
: "${KEY_ID:?CloudKit Console の $ENVIRONMENT で登録したサーバー間キーの ID を、$CONFIG_DIR/cloudkit-key-id-$ENVIRONMENT に書くか CLOUDKIT_KEY_ID で渡すこと}"

SUBPATH="/database/1/iCloud.com.fujimori.PairCommit/$ENVIRONMENT/public/records/query"
SINCE=$(( ($(date +%s) - HOURS * 3600) * 1000 ))
BODY=$(jq -cn --argjson since "$SINCE" '{
  resultsLimit: 200,
  query: {
    recordType: "Diagnostic",
    filterBy: [{fieldName: "occurredAt", comparator: "GREATER_THAN", fieldValue: {value: $since, type: "TIMESTAMP"}}],
    sortBy: [{fieldName: "occurredAt", ascending: false}]
  }
}')

# 署名の形は CloudKit Web Services の決まり（日時:本文の SHA-256 の base64:パス）。
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BODY_HASH=$(printf '%s' "$BODY" | openssl dgst -sha256 -binary | base64)
SIGNATURE=$(printf '%s:%s:%s' "$DATE" "$BODY_HASH" "$SUBPATH" | openssl dgst -sha256 -sign "$KEY_PATH" | base64)

RESPONSE=$(curl -sS "https://api.apple-cloudkit.com$SUBPATH" \
  -H "Content-Type: application/json" \
  -H "X-Apple-CloudKit-Request-KeyID: $KEY_ID" \
  -H "X-Apple-CloudKit-Request-ISO8601Date: $DATE" \
  -H "X-Apple-CloudKit-Request-SignatureV1: $SIGNATURE" \
  -d "$BODY")

if ! jq -e '.records' >/dev/null <<<"$RESPONSE"; then
  echo "$RESPONSE" >&2
  exit 1
fi

jq -r '.records[] | [
  (.fields.occurredAt.value / 1000 | localtime | strftime("%Y-%m-%d %H:%M:%S")),
  .created.userRecordName,
  .fields.device.value,
  .fields.appVersion.value,
  .fields.kind.value,
  .fields.category.value,
  .fields.operation.value,
  .fields.detail.value
] | @tsv' <<<"$RESPONSE"
