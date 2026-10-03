#!/bin/bash
# テンプレートの構造・frontmatter・スキル書式を検査する。
set -u
cd "$(dirname "$0")/.."
failures=0
fail() { echo "NG: $1"; failures=$((failures + 1)); }

REQUIRED_FILES=(
  .gitignore
  .claude/skills/revise/scripts/prose-stats.py
  tests/revise/prose-stats.test.sh
  tests/revise/fixture.md
  LICENSE
  README.en.md
  .claude/settings.json
  .claude/hooks/guard-canon.sh
  canon/README.md
  canon/premise.md
  canon/glossary.md
  canon/timeline.md
  canon/world/_template.md
  canon/characters/_template.md
  workshop/README.md
  workshop/ideas.md
  workshop/rejected.md
  workshop/sessions/.gitkeep
  story/README.md
  story/synopsis.md
  story/structure.md
  story/scenes/_template.md
  output/README.md
  output/film/.gitkeep
  output/novel/README.md
  output/manga/.gitkeep
  story/state.md
  story/threads.md
  canon/locations/_template.md
  workshop/research/.gitkeep
  CLAUDE.md
  README.md
  STATUS.md
  .claude/skills/kickoff/SKILL.md
  .claude/skills/brainstorm/SKILL.md
  .claude/skills/develop/SKILL.md
  .claude/skills/canonize/SKILL.md
  .claude/skills/status/SKILL.md
  .claude/agents/continuity-checker.md
  .claude/skills/check/SKILL.md
  .claude/skills/draft/SKILL.md
  .claude/skills/draft/references/film.md
  .claude/skills/draft/references/novel.md
  .claude/skills/draft/references/manga.md
  .claude/skills/finalize/SKILL.md
  .claude/skills/develop/references/structure.md
)

# examples/ は削除してよいと案内しているので、残っているときだけ中身を検査する
if [ -d examples ]; then
  REQUIRED_FILES+=(
    examples/README.md
    examples/kaze-no-tegami/canon/premise.md
    examples/kaze-no-tegami/canon/characters/tsumugi.md
    examples/kaze-no-tegami/canon/characters/rokuro.md
    examples/kaze-no-tegami/canon/glossary.md
    examples/kaze-no-tegami/story/scenes/010-arrival.md
    examples/kaze-no-tegami/output/novel/010-arrival.md
    examples/kaze-no-tegami/output/film/010-arrival.md
    examples/kaze-no-tegami/output/manga/010-arrival.md
    examples/kaze-no-tegami/story/state.md
    examples/kaze-no-tegami/story/threads.md
    examples/kaze-no-tegami/canon/locations/sakaue-yubinkyoku.md
    examples/shoutou-no-hi/README.md
    examples/shoutou-no-hi/STATUS.md
    examples/shoutou-no-hi/canon/premise.md
    examples/shoutou-no-hi/canon/glossary.md
    examples/shoutou-no-hi/canon/timeline.md
    examples/shoutou-no-hi/canon/world/era.md
    examples/shoutou-no-hi/canon/characters/shiori.md
    examples/shoutou-no-hi/canon/characters/lk-7.md
    examples/shoutou-no-hi/canon/locations/todai.md
    examples/shoutou-no-hi/story/state.md
    examples/shoutou-no-hi/story/threads.md
    examples/shoutou-no-hi/story/scenes/010-shinobikomi.md
    examples/shoutou-no-hi/story/scenes/020-nana.md
    examples/shoutou-no-hi/story/scenes/030-haikou.md
    examples/shoutou-no-hi/output/novel/README.md
    examples/shoutou-no-hi/output/novel/010-shinobikomi.md
    examples/shoutou-no-hi/output/novel/020-nana.md
    examples/shoutou-no-hi/output/film/010-shinobikomi.md
    examples/shoutou-no-hi/workshop/ideas.md
    examples/shoutou-no-hi/workshop/rejected.md
  )
fi

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
# 記入例の workshop/ と STATUS.md は frontmatter を持たないので、作品の canon・story・output だけを見る
done < <(find canon story output examples/*/canon examples/*/story examples/*/output -name '*.md' ! -name 'README.md' 2>/dev/null)

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

grep -q '^summary:' story/scenes/_template.md 2>/dev/null \
  || fail "story/scenes/_template.md の frontmatter に summary がない"
grep -qx '| ID | 種類 | 内容 | 張ったシーン | 回収予定 | 回収したシーン | 状態 |' story/threads.md 2>/dev/null \
  || fail "story/threads.md に台帳の見出し行がない"

for skill in draft develop status finalize; do
  grep -q 'story/threads.md' ".claude/skills/$skill/SKILL.md" 2>/dev/null \
    || fail ".claude/skills/$skill/SKILL.md が story/threads.md を参照していない"
done
for skill in draft finalize; do
  grep -q 'story/state.md' ".claude/skills/$skill/SKILL.md" 2>/dev/null \
    || fail ".claude/skills/$skill/SKILL.md が story/state.md を参照していない"
done

grep -q '^## 伏線' .claude/agents/continuity-checker.md 2>/dev/null \
  || fail "continuity-checker の出力形式に「伏線」節がない"
grep -qx 'model: sonnet' .claude/agents/continuity-checker.md 2>/dev/null \
  || fail "continuity-checker に model: sonnet がない"

for doc in CLAUDE.md README.md; do
  grep -q '/finalize' "$doc" 2>/dev/null || fail "$doc に /finalize の説明がない"
done

finalize=.claude/skills/finalize/SKILL.md
grep -q '台帳の既存行' "$finalize" || fail "/finalize に、/develop で登録済みの伏線との照合手順がない"
grep -q '既に fixed' "$finalize" || fail "/finalize に、確定済みシーンの再確定の扱いがない"
grep -q '対象より後のシーン' "$finalize" || fail "/finalize に、後のシーンの状態を上書きしない規則がない"
grep -q '骨格の修正案' "$finalize" || fail "/finalize に、原稿と骨格の食い違いの同期がない"
grep -q '行は消さず' story/threads.md || fail "story/threads.md に、行を消さず dropped にする規則がない"
grep -E '^\| `story/` .*/finalize' CLAUDE.md >/dev/null || fail "CLAUDE.md の story/ の行に /finalize がない"
grep -E '^\| `output/` .*/finalize' CLAUDE.md >/dev/null || fail "CLAUDE.md の output/ の行に /finalize がない"

grep -q '回収予定はシーン番号' story/threads.md || fail "story/threads.md に回収予定の書き方（シーン番号）の規則がない"
for skill in develop finalize; do
  grep -q '回収予定はシーン番号' ".claude/skills/$skill/SKILL.md" || fail "/$skill に回収予定の書き方（シーン番号）の規則がない"
done
grep -q 'シーン番号でない' .claude/agents/continuity-checker.md || fail "continuity-checker が回収予定の書き方の不備を検出しない"
grep -q '急かされても' .claude/skills/kickoff/SKILL.md || fail "/kickoff に、急かされても全文提示前に書かない規則がない"
grep -q '集計から除く' .claude/skills/status/SKILL.md || fail "/status が state.md・threads.md を集計から除いていない"
grep -q '付随して更新したファイル' .claude/skills/canonize/SKILL.md || fail "/canonize に、付随ファイルの status の扱いがない"
grep -q 'related にこのシーン' "$finalize" || fail "/finalize に、台帳と状態記録の related 更新がない"

for heading in "## 作品全体の決めごと" "## 文体の見本"; do
  grep -qx "$heading" output/novel/README.md 2>/dev/null || fail "output/novel/README.md に見出し「${heading}」がない"
done
for aspect in "文の長さ" "語尾" "段落の長さ" "描写の密度" "会話と地の文の比率"; do
  grep -q "$aspect" .claude/skills/draft/references/novel.md || fail "novel.md に文体の観点「${aspect}」がない"
done
grep -q 'output/<媒体>/README.md' .claude/skills/draft/SKILL.md || fail "/draft が媒体の README（決めごと・見本）を読んでいない"

for heading in "## 進捗" "## 未解決の問い" "## 次にやること"; do
  grep -qx "$heading" STATUS.md 2>/dev/null || fail "STATUS.md に見出し「${heading}」がない"
done

bash tests/hooks/guard-canon.test.sh >/dev/null || fail "フックのテストが失敗（bash tests/hooks/guard-canon.test.sh で詳細を確認）"
bash tests/revise/prose-stats.test.sh >/dev/null || fail "prose-stats のテストが失敗（bash tests/revise/prose-stats.test.sh で詳細を確認）"

[ "$failures" -eq 0 ] || { echo "検査失敗: $failures 件"; exit 1; }
echo "テンプレート検査: すべて成功"
