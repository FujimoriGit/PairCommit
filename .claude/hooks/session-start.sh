#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

# クラウドの環境の既定は別の名義と、その名義の鍵による署名。名義だけ持ち主に変えると、
# 鍵が持ち主のアカウントに登録されていないので GitHub が署名を無効と表示する。署名も切る。
git config user.name "Daiki Fujimori"
git config user.email "G016C1102@outlook.jp"
git config commit.gpgsign false
