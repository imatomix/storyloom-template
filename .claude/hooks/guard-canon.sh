#!/bin/bash
# canon/ は正典。/canonize で作者が承認した変更だけを入れるため、書き込みのたびに確認を挟む。
set -u

ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  ask "jq が見つからないため、canon/（正典）への書き込みか判定できません。対象ファイルを確認してください。"
fi

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) \
  || ask "フックの入力を解釈できませんでした。対象ファイルを確認してください。"
[ -n "$file_path" ] || exit 0

logical_root="${CLAUDE_PROJECT_DIR:-$PWD}"
# macOS の /var → /private/var のように、実体パスで渡される場合にも対応する
physical_root=$(cd "$logical_root" 2>/dev/null && pwd -P || printf '%s' "$logical_root")

verdict=$(jq -rn --arg path "$file_path" --arg logical "$logical_root" --arg physical "$physical_root" '
  def normalize:
    split("/") | reduce .[] as $s ([];
      if $s == "" or $s == "." then .
      elif $s == ".." then .[:-1]
      else . + [$s] end);
  def relative_to($root):
    ($root | normalize) as $r
    | if .[:($r | length)] == $r then .[($r | length):] else null end;
  ($path | (if startswith("/") then . else $logical + "/" + . end) | normalize) as $abs
  | [$logical, $physical]
  | map(. as $root | $abs | relative_to($root))
  | map(select(. != null and length > 0))
  | first // empty
  | if (.[0] | ascii_downcase) == "canon" then "canon" else empty end
') || ask "パスの判定に失敗しました。対象ファイルを確認してください。"

if [ "$verdict" = canon ]; then
  ask "canon/（正典）への変更です。/canonize で作者が承認した内容か確認してください。"
fi
exit 0
