#!/bin/bash
# テンプレートの構造・frontmatter・スキル書式を検査する。
set -u
cd "$(dirname "$0")/.."
failures=0
fail() { echo "NG: $1"; failures=$((failures + 1)); }

REQUIRED_FILES=(
  .gitignore
  .claude/settings.json
  .claude/hooks/guard-canon.sh
)

for f in "${REQUIRED_FILES[@]}"; do
  [ -e "$f" ] || fail "$f がない"
done

[ -x .claude/hooks/guard-canon.sh ] || fail ".claude/hooks/guard-canon.sh に実行権限がない"
jq -e '.hooks.PreToolUse[0].hooks[0].command | test("guard-canon.sh")' .claude/settings.json >/dev/null 2>&1 \
  || fail ".claude/settings.json に guard-canon.sh が登録されていない"

while IFS= read -r f; do
  if [ "$(head -1 "$f")" != "---" ]; then
    fail "$f: frontmatter がない"
    continue
  fi
  sed -n '2,/^---$/p' "$f" | grep -Eq '^status: (draft|review|fixed)( |$)' \
    || fail "$f: status が draft | review | fixed のどれでもない"
done < <(find canon story output examples -name '*.md' ! -name 'README.md' 2>/dev/null)

for dir in .claude/skills/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  skill="${dir}SKILL.md"
  [ -f "$skill" ] || { fail "$skill がない"; continue; }
  grep -qx "name: $name" "$skill" || fail "$skill: name がディレクトリ名 $name と一致しない"
  grep -Eq '^description: .+' "$skill" || fail "$skill: description がない"
done

for agent in .claude/agents/*.md; do
  [ -f "$agent" ] || continue
  name=$(basename "$agent" .md)
  grep -qx "name: $name" "$agent" || fail "$agent: name がファイル名 $name と一致しない"
  grep -Eq '^description: .+' "$agent" || fail "$agent: description がない"
  grep -Eq '^tools: .+' "$agent" || fail "$agent: tools がない"
done

bash tests/hooks/guard-canon.test.sh >/dev/null || fail "フックのテストが失敗（bash tests/hooks/guard-canon.test.sh で詳細を確認）"

[ "$failures" -eq 0 ] || { echo "検査失敗: $failures 件"; exit 1; }
echo "テンプレート検査: すべて成功"
