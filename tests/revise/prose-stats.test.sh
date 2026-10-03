#!/bin/bash
# prose-stats.py の計測値と終了コードを検査する。
set -u
cd "$(dirname "$0")/../.."
script=.claude/skills/revise/scripts/prose-stats.py
failures=0

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 が無いため prose-stats のテストを省略"
  exit 0
fi

output=$(python3 "$script" tests/revise/fixture.md 2>&1)
expected='地の文: 6 文 / 会話: 1 行（会話の比率 14%）
文の長さ: 平均 12.3 字 / 最長 44 字 / 短 83% / 中 0% / 長 17%
語尾: た 33% / 現在形 50% / 体言止め・その他 17% / 同じ語尾の最大連続 3
段落: 5 / 地の文の段落あたり 1.5 文 / 1 文だけの段落 75%'
if [ "$output" = "$expected" ]; then
  echo "ok: 計測値"
else
  echo "NG: 計測値が期待と違う"; echo "--- 実際"; echo "$output"; failures=$((failures + 1))
fi

# 空行の無い原稿、会話の後ろの地の文、括弧内の句点、「〜んだ」の過去形
edge=$(python3 "$script" tests/revise/fixture-edge.md 2>&1)
expected_edge='地の文: 4 文 / 会話: 1 行（会話の比率 20%）
文の長さ: 平均 9.0 字 / 最長 12 字 / 短 100% / 中 0% / 長 0%
語尾: た 75% / 現在形 25% / 体言止め・その他 0% / 同じ語尾の最大連続 3
段落: 4 / 地の文の段落あたり 1.0 文 / 1 文だけの段落 100%'
if [ "$edge" = "$expected_edge" ]; then
  echo "ok: 境界ケースの計測値"
else
  echo "NG: 境界ケースの計測値が期待と違う"; echo "--- 実際"; echo "$edge"; failures=$((failures + 1))
fi

empty=$(mktemp)
printf -- '---\nstatus: draft\n---\n' > "$empty"
python3 "$script" "$empty" >/dev/null 2>&1 && echo "ok: 本文が空でも落ちない" || { echo "NG: 本文が空で失敗"; failures=$((failures + 1)); }
rm -f "$empty"

python3 "$script" >/dev/null 2>&1; [ $? -eq 2 ] && echo "ok: 引数なしは終了コード 2" || { echo "NG: 引数なしの終了コード"; failures=$((failures + 1)); }
python3 "$script" /nonexistent.md >/dev/null 2>&1; [ $? -eq 2 ] && echo "ok: ファイルなしは終了コード 2" || { echo "NG: ファイルなしの終了コード"; failures=$((failures + 1)); }

[ "$failures" -eq 0 ] || { echo "prose-stats のテスト失敗: $failures 件"; exit 1; }
echo "prose-stats のテスト: すべて成功"
