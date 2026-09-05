#!/bin/bash
# 基準画像をコミットして push する。record に10分近くかかる間にブランチが進むと、
# そのままでは push が弾かれ、録れているのに結果が捨てられる。
set -euo pipefail

cd "$(dirname "$0")/.."

BRANCH="${1:?push 先のブランチ名を渡すこと}"
MODE="${2:?replace か add を渡すこと}"
MESSAGE="${3:?コミットメッセージを渡すこと}"
SNAPSHOTS=PairCommitTests/__Snapshots__

# 載せ替えのたびに reset で作業ツリーが戻るので、載せるものは先に控えておく。
# replace は全部を撮り直した結果なので、先端側にも画像の変更があれば録ったほうで
# 置き換える（こちらが新しい）。add は撮り直していないので、増えたぶんだけ載せる。
case "$MODE" in
  replace)
    recorded="$RUNNER_TEMP/recorded-snapshots"
    rm -rf "$recorded"
    cp -R "$SNAPSHOTS" "$recorded"
    ;;
  add)
    added="$RUNNER_TEMP/added-snapshots.tar"
    if [ -z "$(git ls-files --others --exclude-standard "$SNAPSHOTS")" ]; then
      echo "基準画像に変更なし"
      exit 0
    fi
    git ls-files --others --exclude-standard -z "$SNAPSHOTS" | tar -cf "$added" --null -T -
    ;;
  *)
    echo "不明なモード: $MODE" >&2
    exit 1
    ;;
esac

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for attempt in 1 2 3; do
  git fetch origin "$BRANCH"
  git reset --hard "origin/$BRANCH"

  if [ "$MODE" = replace ]; then
    rm -rf "$SNAPSHOTS"
    cp -R "$recorded" "$SNAPSHOTS"
  else
    tar -xf "$added"
  fi
  git add "$SNAPSHOTS"

  if git diff --cached --quiet; then
    echo "基準画像に変更なし"
    exit 0
  fi

  git commit -m "$MESSAGE"
  if git push origin "HEAD:$BRANCH"; then
    exit 0
  fi
  echo "先端が動いたので載せ替えて再試行する（$attempt 回目）"
done

exit 1
