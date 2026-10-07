#!/bin/bash
# テンプレートの構造・frontmatter・スキル書式を検査する。
set -u
cd "$(dirname "$0")/.."
failures=0
fail() { echo "NG: $1"; failures=$((failures + 1)); }

REQUIRED_FILES=(
  .gitignore
  .claude/skills/revise/SKILL.md
  .claude/skills/revise/scripts/prose-stats.py
  tests/revise/prose-stats.test.sh
  tests/revise/fixture.md
  tests/revise/fixture-edge.md
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
  .claude/skills/interview/SKILL.md
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
jq -e '.permissions.allow | index("Bash(python3 .claude/skills/revise/scripts/prose-stats.py:*)")' .claude/settings.json >/dev/null 2>&1 \
  || fail ".claude/settings.json で prose-stats.py の実行が許可されていない"

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
for doc in CLAUDE.md README.md README.en.md; do
  grep -q '/revise' "$doc" 2>/dev/null || fail "$doc に /revise の説明がない"
done
for doc in CLAUDE.md README.md README.en.md; do
  grep -q '/interview' "$doc" 2>/dev/null || fail "$doc に /interview の説明がない"
done
grep -q '/interview' .claude/skills/develop/SKILL.md || fail "/develop がキャラの次の一手に /interview を案内していない"

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

interview=.claude/skills/interview/SKILL.md
grep -q '知らないこと' "$interview" 2>/dev/null || fail "/interview に、その時点で知らないことは答えない規則がない"
grep -q '漏らさない' "$interview" 2>/dev/null || fail "/interview に、伏線の答えを漏らさない規則がない"
grep -q '書き込むのは `workshop/` だけ' "$interview" 2>/dev/null || fail "/interview に、書き込み先が workshop/ だけである規則がない"
grep -q '回収したシーンが時点より後' "$interview" 2>/dev/null || fail "/interview の漏洩防止が、時点までに回収されたかを基準にしていない"
grep -q '最後に更新したシーン」より後' "$interview" 2>/dev/null || fail "/interview に、state.md より後の時点の扱いがない"
grep -q '時点を決めてから読む' "$interview" 2>/dev/null || fail "/interview が、時点を決める前に状態記録を読んでしまう"
for ref in story/state.md story/threads.md; do
  grep -q "$ref" "$interview" 2>/dev/null || fail "/interview が $ref を参照していない"
done

for heading in "## 作品全体の決めごと" "## 文体の見本"; do
  grep -qx "$heading" output/novel/README.md 2>/dev/null || fail "output/novel/README.md に見出し「${heading}」がない"
done
for aspect in "文の長さ" "語尾" "段落の長さ" "描写の密度" "会話と地の文の比率"; do
  grep -q "$aspect" .claude/skills/draft/references/novel.md || fail "novel.md に文体の観点「${aspect}」がない"
done
grep -q 'output/<媒体>/README.md' .claude/skills/draft/SKILL.md || fail "/draft が媒体の README（決めごと・見本）を読んでいない"

for heading in "## シーン設計" "### 全体" "### 場面" "### 媒体ごとの分量と狙い"; do
  grep -qx "$heading" story/scenes/_template.md || fail "story/scenes/_template.md に「${heading}」がない"
done

grep -q '## シーン設計' .claude/skills/draft/SKILL.md || fail "/draft がシーン設計を扱っていない"
grep -q '書き終えた後の確認' .claude/skills/draft/SKILL.md || fail "/draft が書き終えた後の確認を行っていない"
grep -q 'シーン設計' .claude/skills/develop/SKILL.md || fail "/develop がシーン設計に触れていない"

for guide in film manga novel; do
  grep -q '^## 書き終えた後の確認' ".claude/skills/draft/references/$guide.md" || fail "$guide.md に「書き終えた後の確認」がない"
done
grep -q 'ショット表' .claude/skills/draft/references/film.md && fail "film.md にショット表が残っている"
grep -q '^## 描写の技法' .claude/skills/draft/references/novel.md || fail "novel.md に「描写の技法」がない"
grep -q '大きさ・位置' .claude/skills/draft/references/manga.md || fail "manga.md にコマの項目（大きさ・位置）がない"

leftover=$(grep -rln 'ネーム\|ショット表' CLAUDE.md README.md README.en.md .claude output canon story workshop 2>/dev/null)
[ -z "$leftover" ] || fail "旧い用語（ネーム・ショット表）が残っている: $(echo $leftover)"
grep -q '^## 使い方のコツ' README.md || fail "README.md に「使い方のコツ」がない"
grep -q '^## Tips' README.en.md || fail "README.en.md に「Tips」がない"

grep -q '3〜4 秒' .claude/skills/draft/references/film.md || fail "film.md に、ト書き中心の場面の尺の見積もり方がない"

grep -q '場所か時間が変わる場面の変わり目' .claude/skills/draft/references/film.md || fail "film.md の柱の確認が、場所か時間が変わる場面に限定されていない"
grep -q '項目が未記入' .claude/skills/draft/SKILL.md || fail "/draft に、設計が空かどうかの判断基準がない"
grep -q '想定媒体に無い' .claude/skills/draft/SKILL.md || fail "/draft に、想定媒体に無い媒体の扱いがない"
for doc in CLAUDE.md README.md; do
  grep -E '^\| `story/` .*/draft' "$doc" >/dev/null || fail "$doc の story/ の行に /draft（シーン設計）がない"
done
grep -E '^\| `story/` .*/draft' README.en.md >/dev/null || fail "README.en.md の story/ の行に /draft がない"

for heading in "## 進捗" "## 未解決の問い" "## 次にやること"; do
  grep -qx "$heading" STATUS.md 2>/dev/null || fail "STATUS.md に見出し「${heading}」がない"
done

bash tests/hooks/guard-canon.test.sh >/dev/null || fail "フックのテストが失敗（bash tests/hooks/guard-canon.test.sh で詳細を確認）"
bash tests/revise/prose-stats.test.sh >/dev/null || fail "prose-stats のテストが失敗（bash tests/revise/prose-stats.test.sh で詳細を確認）"

[ "$failures" -eq 0 ] || { echo "検査失敗: $failures 件"; exit 1; }
echo "テンプレート検査: すべて成功"
