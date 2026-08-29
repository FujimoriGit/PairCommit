#!/bin/bash
# 基準画像をコミットして push する。record に10分近くかかる間にブランチが
# 進むことがあるので、録った画像をそのときの先端に載せ替えてから push する。
set -euo pipefail

cd "$(dirname "$0")/.."

BRANCH="${1:?push 先のブランチ名を渡すこと}"
SNAPSHOTS=PairCommitTests/__Snapshots__

recorded="${RUNNER_TEMP:-/tmp}/recorded-snapshots"
rm -rf "$recorded"
cp -R "$SNAPSHOTS" "$recorded"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for attempt in 1 2 3; do
  git fetch origin "$BRANCH"
  git reset --hard "origin/$BRANCH"

  rm -rf "$SNAPSHOTS"
  cp -R "$recorded" "$SNAPSHOTS"
  git add "$SNAPSHOTS"

  if git diff --cached --quiet; then
    echo "基準画像に変更なし"
    exit 0
  fi

  git commit -m "VRT の基準画像を CI で record し直す"
  if git push origin "HEAD:$BRANCH"; then
    exit 0
  fi
  echo "先端が動いたので載せ替えて再試行する（$attempt 回目）"
done

exit 1
