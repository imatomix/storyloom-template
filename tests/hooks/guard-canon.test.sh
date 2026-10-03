#!/bin/bash
# guard-canon.sh が canon/ への書き込みだけに確認を出すことを検査する。
set -u
cd "$(dirname "$0")/../.."
hook="$PWD/.claude/hooks/guard-canon.sh"
failures=0

run_hook() {
  CLAUDE_PROJECT_DIR="$1" /bin/bash "$hook" <<<"$2"
}

input_for() {
  jq -cn --arg p "$1" '{tool_name:"Write",tool_input:{file_path:$p,content:"x"}}'
}

expect() {
  local expected=$1 description=$2 root=$3 json=$4 output status decision
  output=$(run_hook "$root" "$json"); status=$?
  decision=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  if [ "$status" -ne 0 ]; then
    echo "NG: ${description}（exit ${status}）"; failures=$((failures + 1))
  elif [ "$expected" = ask ] && [ "$decision" != ask ]; then
    echo "NG: ${description}（確認が出ない。出力: ${output}）"; failures=$((failures + 1))
  elif [ "$expected" = pass ] && [ -n "$output" ]; then
    echo "NG: ${description}（確認が出てしまう。出力: ${output}）"; failures=$((failures + 1))
  else
    echo "ok: $description"
  fi
}

expect ask  "canon 直下の絶対パス"        /proj "$(input_for /proj/canon/premise.md)"
expect ask  "canon のサブフォルダ"        /proj "$(input_for /proj/canon/characters/hero.md)"
expect ask  "相対パス"                    /proj "$(input_for canon/glossary.md)"
expect ask  ".. で canon に入る"          /proj "$(input_for /proj/story/../canon/timeline.md)"
expect ask  "大文字の Canon"              /proj "$(input_for /proj/Canon/premise.md)"
expect ask  "プロジェクトパス末尾の /"    /proj/ "$(input_for /proj/canon/premise.md)"
expect pass "story 配下"                  /proj "$(input_for /proj/story/scenes/010-opening.md)"
expect pass "canon に似た名前"            /proj "$(input_for /proj/canon-notes/x.md)"
expect pass "examples 内の canon"         /proj "$(input_for /proj/examples/kaze-no-tegami/canon/premise.md)"
expect pass "workshop 内の canon"         /proj "$(input_for /proj/workshop/canon/x.md)"
expect pass "canon から .. で出る"        /proj "$(input_for /proj/canon/../story/x.md)"
expect pass "プロジェクト外の canon"      /proj "$(input_for /other/canon/x.md)"
expect pass "file_path が無い入力"        /proj '{"tool_name":"Bash","tool_input":{"command":"ls"}}'

# プロジェクトパスがシンボリックリンクでも、実体パスで書き込まれたら確認を出す
tmp=$(mktemp -d)
mkdir "$tmp/real"
ln -s "$tmp/real" "$tmp/link"
physical=$(cd "$tmp/real" && pwd -P)
expect ask "シンボリックリンク経由のプロジェクト" "$tmp/link" "$(input_for "$physical/canon/premise.md")"

# jq が無い環境では判定できないので確認を出す
mkdir "$tmp/bin"
ln -s /bin/cat "$tmp/bin/cat"
story_input=$(input_for /proj/story/x.md)
output=$(PATH="$tmp/bin" CLAUDE_PROJECT_DIR=/proj /bin/bash "$hook" <<<"$story_input")
if printf '%s' "$output" | grep -q '"permissionDecision":"ask"'; then
  echo "ok: jq が無いときは確認を出す"
else
  echo "NG: jq が無いときに確認が出ない（出力: ${output}）"; failures=$((failures + 1))
fi
rm -rf "$tmp"

[ "$failures" -eq 0 ] || { echo "フックのテスト失敗: $failures 件"; exit 1; }
echo "フックのテスト: すべて成功"
