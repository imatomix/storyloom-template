# storyloom-template 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI と共同で映像・小説・漫画の物語を作るための、Claude Code 用ファイル構成テンプレートを作る。

**Architecture:** ファイルを確定度で 4 層（canon / workshop / story / output）に分け、CLAUDE.md・7 つのスキル・読み取り専用サブエージェント 1 つ・canon 保護フックで AI の振る舞いを制御する。コードはフックのシェルスクリプトとテンプレート検査スクリプトだけ。

**Tech Stack:** Markdown、Claude Code（skills / agents / hooks）、bash 3.2 互換シェルスクリプト、jq

**Spec:** `docs/superpowers/specs/2026-10-03-storyloom-template-design.md`

## Global Constraints

- 文書・コメント・コミットメッセージは日本語。コミット末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- シェルスクリプトは macOS 標準の bash 3.2 で動くこと（連想配列・`${var,,}`・`mapfile` を使わない）
- 外部依存は jq のみ。jq がない環境ではフックは「確認を求める」側に倒す（fail closed）
- canon/・story/・output/・examples/ 配下の Markdown（README.md を除く）は先頭に YAML frontmatter を持ち、`status: draft | review | fixed` を含む
- frontmatter の形式: `status` / `related`（相対パスの配列）/ `updated`（YYYY-MM-DD）
- スキルは `.claude/skills/<name>/SKILL.md`、frontmatter の `name` はディレクトリ名と一致
- シーンファイル名は `NNN-<slug>.md`（010, 020… と 10 刻み。間に挿入できるように）。`/draft` の出力は `output/<媒体>/<シーンファイル名と同じ名前>.md`
- 個人設定は `.claude/settings.local.json`（.gitignore 対象）

## Review Focus

1. **canon/ への書き込みが別経路で素通りする** — 相対パス、`story/../canon/x.md`、大文字 `Canon/`（macOS は大文字小文字を区別しない）、シンボリックリンク経由のプロジェクトパスでも確認が出ること → Task 1 のテストで固定
2. **canon に似た名前の別フォルダで誤検知する** — `canon-notes/`、`examples/*/canon/`、`workshop/canon/` では確認が出ないこと → Task 1 のテストで固定
3. **jq が無い環境で保護が黙って外れる** — 確認を求める側に倒れること → Task 1 のテストで固定
4. **スキル名とディレクトリ名のずれで `/コマンド` が呼べない** — 検査スクリプトで固定（Task 1、各タスクで実行）
5. **examples/ の記入例を AI が編集・正典扱いする** — CLAUDE.md で参照専用と明記し、`/check` `/status` の集計対象から examples/ を除外（Task 3・5・4 の本文で固定）

既知の制限（README に記載）: Bash ツールのリダイレクト等で canon/ を書き換える経路はフックで止めない。CLAUDE.md のルールで抑止する。

---

## ファイル構成

| パス | 責務 | タスク |
|---|---|---|
| `.gitignore` | 個人設定・OS ゴミの除外 | 1 |
| `.claude/settings.json` | PreToolUse フック登録 | 1 |
| `.claude/hooks/guard-canon.sh` | canon/ への Edit/Write に確認を出す | 1 |
| `tests/hooks/guard-canon.test.sh` | フックの判定テスト | 1 |
| `tests/validate-template.sh` | 構造・frontmatter・スキル書式の検査 | 1（以降のタスクで必須ファイルを追記） |
| `canon/**`, `workshop/**`, `story/**`, `output/**` | 雛形と各フォルダの README | 2 |
| `CLAUDE.md`, `README.md`, `STATUS.md` | AI ルール・使い方・現在地 | 3 |
| `.claude/skills/{kickoff,brainstorm,develop,canonize,status}/SKILL.md` | 対話系スキル | 4 |
| `.claude/skills/check/SKILL.md`, `.claude/agents/continuity-checker.md` | 矛盾チェック | 5 |
| `.claude/skills/draft/SKILL.md`, `.claude/skills/draft/references/{film,novel,manga}.md` | 媒体別執筆 | 6 |
| `examples/kaze-no-tegami/**` | 記入例 | 7 |

---

### Task 1: canon 保護フックと検査スクリプト

**Files:**
- Create: `.gitignore`
- Create: `.claude/settings.json`
- Create: `.claude/hooks/guard-canon.sh`
- Test: `tests/hooks/guard-canon.test.sh`
- Test: `tests/validate-template.sh`

**Interfaces:**
- Produces: `bash tests/validate-template.sh` — 全検査を実行し、失敗があれば `NG: ...` を出して exit 1。`REQUIRED_FILES` 配列に後続タスクが行を追加する
- Produces: `bash tests/hooks/guard-canon.test.sh` — フックのテスト。`validate-template.sh` からも呼ばれる
- Produces: フックの入出力 — stdin に PreToolUse の JSON（`.tool_input.file_path`）、canon/ 配下なら stdout に `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"..."}}`、それ以外は何も出さない。常に exit 0

- [ ] **Step 1: フックのテストを書く**

`tests/hooks/guard-canon.test.sh`:

```bash
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
    echo "NG: $description（exit $status）"; failures=$((failures + 1))
  elif [ "$expected" = ask ] && [ "$decision" != ask ]; then
    echo "NG: $description（確認が出ない。出力: $output）"; failures=$((failures + 1))
  elif [ "$expected" = pass ] && [ -n "$output" ]; then
    echo "NG: $description（確認が出てしまう。出力: $output）"; failures=$((failures + 1))
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
output=$(PATH="$tmp/bin" CLAUDE_PROJECT_DIR=/proj /bin/bash "$hook" <<<"$(input_for /proj/story/x.md)")
if printf '%s' "$output" | grep -q '"permissionDecision":"ask"'; then
  echo "ok: jq が無いときは確認を出す"
else
  echo "NG: jq が無いときに確認が出ない（出力: $output）"; failures=$((failures + 1))
fi
rm -rf "$tmp"

[ "$failures" -eq 0 ] || { echo "フックのテスト失敗: $failures 件"; exit 1; }
echo "フックのテスト: すべて成功"
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `bash tests/hooks/guard-canon.test.sh`
Expected: フックが存在しないため、多数の `NG:` が出て exit 1

- [ ] **Step 3: フックを実装する**

`.claude/hooks/guard-canon.sh`:

```bash
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
```

Run: `chmod +x .claude/hooks/guard-canon.sh tests/hooks/guard-canon.test.sh`

- [ ] **Step 4: テストが通ることを確認する**

Run: `bash tests/hooks/guard-canon.test.sh`
Expected: すべて `ok:`、最後に `フックのテスト: すべて成功`、exit 0

- [ ] **Step 5: settings.json と .gitignore を作る**

`.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-canon.sh"
          }
        ]
      }
    ]
  }
}
```

`.gitignore`:

```
.claude/settings.local.json
.DS_Store
```

- [ ] **Step 6: テンプレート検査スクリプトを書く**

`tests/validate-template.sh`:

```bash
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
```

Run: `chmod +x tests/validate-template.sh && bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 7: フックを実際の Claude Code で確認する**

Run: `claude -p "canon/premise.md に「テスト」と1行書いてください" --output-format text`（プロジェクトルートで）
Expected: 非対話モードのため確認に答えられず、書き込みが拒否される／許可を求めた旨が返る。`ls canon/premise.md` でファイルが作られていないこと。結果が想定と違う場合は記録して作者に報告する（フックの形式は Step 4 で検証済みなので、ここは実環境での配線確認）

- [ ] **Step 8: コミット**

```bash
git add .gitignore .claude/settings.json .claude/hooks/guard-canon.sh tests/
git commit -m "canon/ 保護フックとテンプレート検査スクリプトを追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 4 層フォルダの雛形

**Files:**
- Modify: `tests/validate-template.sh`（`REQUIRED_FILES` に追記）
- Create: `canon/README.md`, `canon/premise.md`, `canon/glossary.md`, `canon/timeline.md`, `canon/world/_template.md`, `canon/characters/_template.md`
- Create: `workshop/README.md`, `workshop/ideas.md`, `workshop/rejected.md`, `workshop/sessions/.gitkeep`
- Create: `story/README.md`, `story/synopsis.md`, `story/structure.md`, `story/scenes/_template.md`
- Create: `output/README.md`, `output/film/.gitkeep`, `output/novel/.gitkeep`, `output/manga/.gitkeep`

**Interfaces:**
- Consumes: `tests/validate-template.sh`（Task 1）
- Produces: 雛形ファイル群。後続のスキルは `canon/characters/_template.md`・`canon/world/_template.md`・`story/scenes/_template.md` を新規作成時の雛形として参照する

- [ ] **Step 1: 検査に必須ファイルを追加する**

`tests/validate-template.sh` の `REQUIRED_FILES` に以下を追記:

```bash
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
  output/novel/.gitkeep
  output/manga/.gitkeep
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: `NG: canon/README.md がない` など 18 件、exit 1

- [ ] **Step 3: canon/ を作る**

`canon/README.md`:

```markdown
# canon/ — 正典

確定した設定を置く場所です。ここに書かれていることが、この作品の「真実」です。

- 変更は `/canonize` を通して行います。Claude は作者の承認なしにここを書き換えません（書き込みのたびにフックが確認を求めます）
- 迷っている案や検討中の設定は `workshop/` に置きます
- 物語の順番・構成（何をどの順で語るか）は `story/` に置きます

| ファイル | 内容 |
|---|---|
| `premise.md` | ジャンル・テーマ・トーン・ターゲット・ログライン |
| `world/` | 世界観。1 トピック 1 ファイル（`_template.md` を複製） |
| `characters/` | 登場人物。1 人 1 ファイル（`_template.md` を複製） |
| `glossary.md` | 用語集 |
| `timeline.md` | 作中の出来事の年表 |
```

`canon/premise.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# 作品の前提

<!-- /kickoff で埋めます。確定したら status を fixed に -->

## タイトル（仮）

## ログライン
<!-- 1〜2 文。「（主人公）が（目的）のために（障害）に立ち向かう」の形が目安 -->

## ジャンル

## テーマ
<!-- この物語が問いかけること -->

## トーン
<!-- 明るい／重い、テンポ、笑いの量、参考作品など -->

## ターゲット

## 想定媒体
<!-- film / novel / manga のどれで出すか（複数可） -->

## 規模
<!-- 長編・短編・全何話・何ページなど -->
```

`canon/glossary.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# 用語集

<!-- 作中の固有名詞・造語。/canonize が設定の追加に合わせて更新します -->

| 用語 | 読み | 意味 | 初出 |
|---|---|---|---|
```

`canon/timeline.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# 年表

<!-- 作中の出来事を時系列で。物語本編より前の出来事も含めます -->

| 時期 | 出来事 | 関係者 | 出典 |
|---|---|---|---|
```

`canon/world/_template.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# トピック名

<!-- 地理、歴史、社会制度、技術、魔法体系など、世界の 1 つの側面 -->

## 概要

## ルール・制約
<!-- 物語上「できること／できないこと」。矛盾チェックの基準になります -->

## 物語との関わり

## 未確定の点
```

`canon/characters/_template.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# キャラクター名

## 基本
- 年齢：
- 立場・職業：
- 外見：

## 内面
- 欲しいもの（外的な目標）：
- 本当に必要なもの（内的な欠落）：
- 恐れ：
- 話し方・口癖：

## 背景

## 関係
<!-- 他のキャラとの関係。相手のファイルを related にも書く -->

## 物語での変化
<!-- 始まりと終わりで何が変わるか -->
```

- [ ] **Step 4: workshop/ を作る**

`workshop/README.md`:

```markdown
# workshop/ — 作業場

まだ確定していないものを置く場所です。Claude も自由に書き込めます。

| ファイル | 内容 |
|---|---|
| `ideas.md` | アイデアの受け皿。思いついたら日付付きで追記 |
| `sessions/` | 対話・検討の記録（`YYYY-MM-DD-<topic>.md`） |
| `rejected.md` | ボツ案と理由。同じ案を何度も検討しないための記録 |

ここで固まった設定は `/canonize` で `canon/` に昇格させます。
```

`workshop/ideas.md`:

```markdown
# アイデア

<!-- 日付・アイデア・出どころ（自分／Claude／会話）を追記していく。整理は後で -->
```

`workshop/rejected.md`:

```markdown
# ボツ案

<!-- Claude は新しい案を出す前にここを確認します。再検討するときは理由が変わったかを書き添える -->

| 日付 | 案 | ボツにした理由 |
|---|---|---|
```

`workshop/sessions/.gitkeep`: 空ファイル

- [ ] **Step 5: story/ を作る**

`story/README.md`:

```markdown
# story/ — 物語の骨格

「何を、どの順で語るか」を置く場所です。どの媒体（映像・小説・漫画）にも依存しない形で書きます。

- 作者が直接編集してかまいません。Claude も `/develop` で書き込みます
- 設定（世界やキャラの事実）は `canon/` が基準です。食い違ったら `/check` で検出できます
- 確定したら status を `fixed` にしてコミットしましょう

| ファイル | 内容 |
|---|---|
| `synopsis.md` | あらすじ（短・中・長） |
| `structure.md` | 幕構成・章立て・話数構成 |
| `scenes/` | 1 シーン 1 ファイル。`NNN-<slug>.md`（010, 020… と 10 刻み） |
```

`story/synopsis.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# あらすじ

## 短（1〜2 文）

## 中（400 字程度）

## 長（結末まで）
```

`story/structure.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# 構成

<!-- 三幕構成、起承転結、章立て、話数構成など、作品に合う形で -->

| 区切り | 内容 | 含むシーン |
|---|---|---|
```

`story/scenes/_template.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# シーン名

## 目的
<!-- このシーンで物語が何を得るか（情報・関係の変化・転機） -->

## 場所・時間

## 登場人物

## 出来事

## 感情の変化
<!-- 誰が、何から何へ -->

## メモ
```

- [ ] **Step 6: output/ を作る**

`output/README.md`:

```markdown
# output/ — 媒体別の成果物

`/draft <媒体> <シーン>` で、`story/scenes/` のシーンを媒体ごとの形式に書き起こします。
ファイル名はシーンと同じ（例: `story/scenes/010-opening.md` → `output/novel/010-opening.md`）。

| フォルダ | 形式 |
|---|---|
| `film/` | 脚本（柱・ト書き・台詞）＋ショット表 |
| `novel/` | 小説本文 |
| `manga/` | ネーム（ページ・コマ・構図・台詞） |

書式の詳細は `.claude/skills/draft/references/` にあります。
```

`output/film/.gitkeep`, `output/novel/.gitkeep`, `output/manga/.gitkeep`: 空ファイル

- [ ] **Step 7: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 8: コミット**

```bash
git add canon workshop story output tests/validate-template.sh
git commit -m "canon・workshop・story・output の雛形を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: CLAUDE.md・README.md・STATUS.md

**Files:**
- Modify: `tests/validate-template.sh`（`REQUIRED_FILES` に追記）
- Create: `CLAUDE.md`, `README.md`, `STATUS.md`

**Interfaces:**
- Consumes: Task 2 のフォルダ構成、Task 1 のフック
- Produces: コマンド名一覧 `/kickoff` `/brainstorm` `/develop` `/canonize` `/check` `/draft` `/status`（Task 4〜6 がこの名前で実装する）。STATUS.md の見出し `## 進捗` `## 未解決の問い` `## 次にやること`（`/status` と `/kickoff` が更新する）

- [ ] **Step 1: 検査に必須ファイルを追加する**

`REQUIRED_FILES` に追記:

```bash
  CLAUDE.md
  README.md
  STATUS.md
```

さらに STATUS.md の見出し検査を、`bash tests/hooks/guard-canon.test.sh` の行の直前に追加:

```bash
for heading in "## 進捗" "## 未解決の問い" "## 次にやること"; do
  grep -qx "$heading" STATUS.md 2>/dev/null || fail "STATUS.md に見出し「$heading」がない"
done
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: `NG: CLAUDE.md がない` などで exit 1

- [ ] **Step 3: CLAUDE.md を書く**

`CLAUDE.md`:

````markdown
# storyloom — AI との共同創作ルール

このリポジトリは 1 つの物語作品を作るための作業場です。作者（人間）が主導し、あなた（Claude）は相棒として、質問・提案・矛盾の検出・下書きを担います。

## 最初に読むもの

- 作業を始める前に `canon/premise.md` と `STATUS.md` を読む
- キャラ・世界観・シーンに触れる作業では、関連する `canon/` のファイルを読んでから書く

## 姿勢

- 決めるのは作者。案を出すときは可能なら 2〜3 案を理由付きで示し、採否を作者に委ねる
- 指示が曖昧なら、書き始める前に質問を 1 つずつする。「A と B ならどちら寄り？」のような選択肢付きの質問を優先する
- 作者の文体・作風を尊重する。`output/` に既存の本文があれば、それに合わせる

## フォルダごとの扱い

| フォルダ | 意味 | あなたが書いてよいか |
|---|---|---|
| `canon/` | 正典（確定した設定） | `/canonize` の中で、作者が承認したときだけ |
| `story/` | 物語の骨格 | 作者の依頼、または `/develop` で |
| `workshop/` | 作業場 | 自由に |
| `output/` | 媒体別の成果物 | 作者の依頼、または `/draft` で |
| `examples/` | 記入例 | 書かない。参照のみ。正典として扱わない |

- 正典と食い違う内容を書きたくなったら、書かずに作者へ指摘する。正典を変えるべきだと思うなら `/canonize` を提案する
- `canon/` への書き込みには毎回フックが確認を求める。Bash のリダイレクトなど、確認を回避する方法で `canon/` を変更しない

## 記録

- ボツになった案は `workshop/rejected.md` に日付・案・理由を追記する
- 新しい案を出す前に `workshop/rejected.md` を確認し、同じ案を出さない。あえて再提案するなら、前回との違いを明示する
- 会話中に出た良いアイデアは `workshop/ideas.md` に追記してよい。追記したら作者に伝える
- 長い検討は `workshop/sessions/YYYY-MM-DD-<topic>.md` に要点を残す

## frontmatter

`canon/`・`story/`・`output/` の Markdown（README.md を除く）は先頭に以下を持つ。新規作成は各フォルダの `_template.md` を複製して行う。

```yaml
---
status: draft   # draft | review | fixed
related: []     # 関連ファイルの相対パス
updated: YYYY-MM-DD
---
```

ファイルを更新したら `updated` を今日の日付にする。

## 命名

- シーン: `story/scenes/NNN-<slug>.md`（010, 020… と 10 刻み）
- 媒体別の出力: `output/<film|novel|manga>/<シーンと同じファイル名>.md`
- キャラ・世界観: `canon/characters/<slug>.md`、`canon/world/<slug>.md`（slug はローマ字の小文字とハイフン）

## git

- 正典を変更したとき、シーンを確定したときにコミットを提案する。自動ではコミットしない
- コミットメッセージは日本語

## コマンド

| コマンド | 用途 |
|---|---|
| `/kickoff` | 作品の前提を決める |
| `/brainstorm [テーマ]` | 壁打ち。決めずに広げる |
| `/develop <対象>` | キャラ・世界観・シーンを 1 つ深掘りして下書きする |
| `/canonize <ファイルや案>` | 下書きを正典に昇格させる |
| `/check [範囲]` | 正典との矛盾を検出する |
| `/draft <媒体> <シーン>` | シーンを脚本・小説・ネームに書き起こす |
| `/status` | 進捗を集計し、次にやることを提案する |
````

- [ ] **Step 4: STATUS.md を書く**

`STATUS.md`:

```markdown
# STATUS

<!-- /status が更新します。手で書き換えてもかまいません -->

最終更新: YYYY-MM-DD

## 進捗

| 領域 | draft | review | fixed |
|---|---|---|---|
| canon | 0 | 0 | 0 |
| story | 0 | 0 | 0 |
| output/film | 0 | 0 | 0 |
| output/novel | 0 | 0 | 0 |
| output/manga | 0 | 0 | 0 |

## 未解決の問い

- （まだありません）

## 次にやること

1. `/kickoff` で作品の前提を決める
```

- [ ] **Step 5: README.md を書く**

`README.md`:

````markdown
# storyloom-template

AI（Claude Code）と一緒に、映像・小説・漫画の物語を作るためのテンプレートです。
作者が主導し、Claude は質問・提案・矛盾チェック・下書きを担当します。

## はじめ方

1. このフォルダを複製して、作品用のリポジトリにする
   ```bash
   cp -R storyloom-template my-story && cd my-story
   rm -rf docs/superpowers   # テンプレート自体の設計資料。不要なら削除
   git init
   ```
2. Claude Code を起動して `/kickoff` を実行する
3. 記入例は `examples/kaze-no-tegami/` を参照（不要になったら削除してかまいません）

必要なもの: Claude Code、jq（canon/ 保護フックが使用。macOS は標準で入っています）

## 考え方

ファイルを「どれだけ確定しているか」で 4 つに分けています。

| フォルダ | 意味 | Claude が書くか |
|---|---|---|
| `canon/` | 正典。確定した設定 | `/canonize` で作者が承認したときだけ |
| `story/` | 物語の骨格（媒体に依存しない） | 依頼されたとき |
| `workshop/` | 作業場。アイデア・検討・ボツ案 | 自由に |
| `output/` | 媒体別の成果物 | `/draft` で |

同じ `story/` から、映像・小説・漫画のどれにも書き起こせます。

## コマンド

| コマンド | 用途 |
|---|---|
| `/kickoff` | 作品の前提（ジャンル・テーマ・ログライン等）を決める |
| `/brainstorm [テーマ]` | 壁打ち。質問と案出しで広げる |
| `/develop <対象>` | キャラ・世界観・シーンを 1 つ深掘りして下書きする |
| `/canonize <ファイルや案>` | 下書きを正典に昇格させる（差分を見て承認） |
| `/check [範囲]` | story/・output/ と正典の矛盾を一覧にする |
| `/draft <film\|novel\|manga> <シーン>` | シーンを脚本・小説・ネームに書き起こす |
| `/status` | 進捗を集計して STATUS.md を更新し、次の一手を提案する |

## 典型的な流れ

```
/kickoff → /brainstorm → /develop → /canonize → （story/ を組み立てる）→ /draft → /check → /status
```

順番は固定ではありません。行き来しながら進めてください。

## canon/ の保護

Claude が `canon/` に Edit/Write するたびに、フック（`.claude/hooks/guard-canon.sh`）が確認を求めます。
既知の制限: Bash コマンド経由の書き込みはフックの対象外です（CLAUDE.md のルールで抑止しています）。

## 個人設定

自分だけの設定は `.claude/settings.local.json` に書いてください（git 管理外）。

## 動作確認

テンプレートを変更したら、構造の検査を実行します。

```bash
bash tests/validate-template.sh
```

コマンドの動きは、新しいディレクトリにテンプレートを複製して次の順に試します。

1. `/kickoff` → `/brainstorm` → `/develop` → `/canonize` → `/draft novel` → `/check` → `/status`
2. 確認すること
   - `/canonize` で canon/ に書き込むときに確認が出る
   - story/ に正典と矛盾する記述をわざと入れると、`/check` が検出する
   - `/status` で STATUS.md が更新される
````

- [ ] **Step 6: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 7: コミット**

```bash
git add CLAUDE.md README.md STATUS.md tests/validate-template.sh
git commit -m "CLAUDE.md・README・STATUS を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 対話系スキル（kickoff / brainstorm / develop / canonize / status）

**Files:**
- Modify: `tests/validate-template.sh`（`REQUIRED_FILES` に追記）
- Create: `.claude/skills/kickoff/SKILL.md`
- Create: `.claude/skills/brainstorm/SKILL.md`
- Create: `.claude/skills/develop/SKILL.md`
- Create: `.claude/skills/canonize/SKILL.md`
- Create: `.claude/skills/status/SKILL.md`

**Interfaces:**
- Consumes: 雛形 `_template.md`（Task 2）、STATUS.md の見出し（Task 3）
- Produces: `/kickoff` `/brainstorm` `/develop` `/canonize` `/status`

- [ ] **Step 1: 検査に必須ファイルを追加する**

```bash
  .claude/skills/kickoff/SKILL.md
  .claude/skills/brainstorm/SKILL.md
  .claude/skills/develop/SKILL.md
  .claude/skills/canonize/SKILL.md
  .claude/skills/status/SKILL.md
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 5 件の `NG: ... がない`、exit 1

- [ ] **Step 3: kickoff を書く**

`.claude/skills/kickoff/SKILL.md`:

```markdown
---
name: kickoff
description: 新しい作品の前提（タイトル・ログライン・ジャンル・テーマ・トーン・ターゲット・想定媒体・規模）を、作者に質問しながら決めて canon/premise.md と STATUS.md に記入する。
disable-model-invocation: true
---

# /kickoff — 作品の前提を決める

## 手順

1. `canon/premise.md` を読む。すでに記入済みなら、内容を要約して「見直すか、続きから埋めるか」を作者に聞く
2. 以下の順で、1 回に 1 つずつ質問する。各質問には、作者の答えを引き出すための選択肢か具体例を 2〜4 個添える
   1. 何を作りたいか（ぼんやりした種でよい：場面、キャラ、問い、雰囲気など）
   2. 想定媒体（film / novel / manga、複数可）と規模
   3. ジャンルとトーン（参考作品があれば）
   4. テーマ（この物語が問いかけること）
   5. ターゲット
   6. ログライン — ここまでの答えから案を 2〜3 個作って示し、作者に選んでもらうか直してもらう
   7. タイトル（仮）
3. 作者が答えに迷ったら、無理に決めずに「未確定」として残し、STATUS.md の「未解決の問い」に回す
4. 埋めた premise.md の全文を作者に見せ、承認を得てから書き込む（フックの確認が出る）。status は作者が確定と言えば `fixed`、そうでなければ `draft`
5. STATUS.md の「未解決の問い」と「次にやること」を更新する。次にやることの目安：主人公の `/develop`、世界観の `/brainstorm`
6. 選ばれなかったログライン案は `workshop/rejected.md` に理由付きで記録する
7. コミットを提案する
```

- [ ] **Step 4: brainstorm を書く**

`.claude/skills/brainstorm/SKILL.md`:

```markdown
---
name: brainstorm
description: 物語のアイデアを広げる壁打ち。作者への質問と複数案の提示で発想を広げ、決定はしない。キャラ・世界観・展開・テーマなど何でも対象にできる。結果は workshop/ に残す。
argument-hint: "[テーマ]"
---

# /brainstorm — 壁打ち

対象: $ARGUMENTS（空なら作者に何について考えたいか聞く）

## 原則

- 目的は広げること。決めない。収束させたくなったら `/develop` を提案する
- 書き込むのは `workshop/` だけ

## 手順

1. `canon/premise.md`、`workshop/ideas.md`、`workshop/rejected.md`、対象に関係する canon/ のファイルを読む
2. 作者に、対象について今わかっていること・引っかかっていることを 1 つ質問する
3. 答えを受けて、方向性の違う案を 3 つ出す。それぞれに一言の狙いと「この案を選ぶと物語がどうなるか」を添える
   - 正典と矛盾する案を出す場合は、矛盾する点を明記する
   - `rejected.md` にある案と同じものは出さない
4. 作者の反応に応じて、深掘り（なぜ惹かれたか・何が足りないか）と案出しを繰り返す
5. 終わりに、出た案を `workshop/sessions/YYYY-MM-DD-<topic>.md` にまとめる（気に入った案・保留・ボツを分ける）
   - 作者がはっきり却下した案は `workshop/rejected.md` にも理由付きで追記
   - 有望な種は `workshop/ideas.md` に追記
6. 次の一手として `/develop <対象>` か、さらに広げるテーマを提案する
```

- [ ] **Step 5: develop を書く**

`.claude/skills/develop/SKILL.md`:

```markdown
---
name: develop
description: キャラクター・世界観のトピック・シーン・あらすじ・構成のうち 1 つを選んで深掘りし、雛形に沿った下書きを作る。キャラ・世界観の下書きは workshop/ に、シーン・あらすじ・構成は story/ に書く。
argument-hint: "<対象：キャラ名・世界観トピック・シーン・synopsis・structure>"
---

# /develop — 1 つを深掘りして下書きする

対象: $ARGUMENTS（空なら STATUS.md を見て候補を 2〜3 個示し、作者に選んでもらう）

## 書き込み先

| 対象 | 雛形 | 書き込み先 |
|---|---|---|
| キャラクター | `canon/characters/_template.md` | `workshop/drafts/characters/<slug>.md` |
| 世界観 | `canon/world/_template.md` | `workshop/drafts/world/<slug>.md` |
| シーン | `story/scenes/_template.md` | `story/scenes/NNN-<slug>.md` |
| あらすじ | — | `story/synopsis.md` |
| 構成 | — | `story/structure.md` |

キャラと世界観は設定（正典の候補）なので、canon/ には直接書かない。確定したら `/canonize` で昇格させる。
既に canon/ にある対象を深掘りするときは、canon のファイルを `workshop/drafts/` に複製してから編集する。

## 手順

1. `canon/premise.md` と、対象に関係する canon/・story/・workshop/ のファイル（ideas.md、rejected.md、既存の下書き）を読む
2. 雛形の空欄のうち、物語にとって重要なものから順に作者へ質問する。1 回に 1 つ。選択肢か具体例を添える
   - キャラ: まず「欲しいもの」と「本当に必要なもの」、次に「恐れ」と「物語での変化」
   - 世界観: まず「ルール・制約」（物語で何ができて何ができないか）
   - シーン: まず「目的」と「感情の変化」。`order` に当たる番号は structure.md と前後のシーンから決める
3. 作者が「おまかせ」と言った欄は、案を 2〜3 個示して選んでもらう。それでも決まらなければ下書きとして 1 案を書き、`## 未確定の点` に残す
4. 下書きを雛形に沿って書き、frontmatter の `related` に関係するファイルを入れる
5. 正典と食い違う点に気づいたら、下書きに反映せず作者に指摘する
6. 書いた内容を要約して見せ、次の一手を提案する（キャラ・世界観なら `/canonize`、シーンなら `/draft` や次のシーンの `/develop`）
```

- [ ] **Step 6: canonize を書く**

`.claude/skills/canonize/SKILL.md`:

```markdown
---
name: canonize
description: workshop/ の下書きや会話で固まった案を、作者の承認を得て canon/（正典）に昇格させる。関連する用語集・年表・他キャラの関係欄も合わせて更新する。canon/ を変更する唯一の正規の手段。
argument-hint: "<ファイルパス または 案の要約>"
disable-model-invocation: true
---

# /canonize — 正典に昇格させる

対象: $ARGUMENTS（空なら workshop/drafts/ と直近の会話から候補を示して作者に選んでもらう）

## 手順

1. 対象と、影響しそうな canon/ のファイルをすべて読む（同名キャラ・関連トピック・glossary.md・timeline.md）
2. **矛盾の確認**: 対象が既存の正典と食い違う点を列挙する。あれば「どちらを正とするか」を作者に 1 つずつ確認する
3. **変更案の提示**: 書き込む予定の内容を、ファイルごとに差分（追加・変更・削除）として示す
   - 主ファイル（例: `canon/characters/hero.md`）。新規なら雛形に沿って作る
   - 付随更新: `glossary.md` の新用語、`timeline.md` の出来事、関係するキャラの「関係」欄、`related`
   - 正典の変更で影響を受ける story/・output/ のファイルがあれば、一覧にして示す（ここでは書き換えない）
4. 作者の承認を待つ。部分的な承認なら承認された分だけ進める。**承認がないまま canon/ に書かない**
5. 書き込む。frontmatter の `status` は作者の指示どおり（指定がなければ `fixed`）、`updated` は今日
6. 昇格元の下書き（`workshop/drafts/...`）は削除してよいか作者に確認する
7. 影響を受ける story/・output/ がある場合は `/check` を提案する
8. コミットを提案する。メッセージ例: `正典: <対象> を追加`
```

- [ ] **Step 7: status を書く**

`.claude/skills/status/SKILL.md`:

```markdown
---
name: status
description: canon/・story/・output/ の frontmatter の status を集計して STATUS.md を更新し、未解決の問いと次にやることを提案する。作品の現在地を知りたいときに使う。
---

# /status — 現在地を確認する

## 手順

1. 集計する。対象は `canon/`、`story/`、`output/film/`、`output/novel/`、`output/manga/` の `.md`。`README.md` と `_template.md` と `examples/` は除く
   - 各ファイルの frontmatter の `status:` を読み、領域ごとに draft / review / fixed を数える
   - frontmatter が無い・status が不正なファイルは、別に一覧にして作者に知らせる
2. 現在地を把握する
   - `canon/premise.md` が draft のまま → 前提が固まっていない
   - キャラ・世界観が少ない、シーンが少ない、シーンはあるが output が無い、など
   - `workshop/ideas.md` に溜まっている未処理のアイデア
   - 各ファイルの `## 未確定の点` と STATUS.md の既存の「未解決の問い」
3. STATUS.md を更新する
   - `最終更新:` を今日に
   - `## 進捗` の表を集計結果で置き換える
   - `## 未解決の問い` を整理する（解決済みは消し、新しいものを足す）
   - `## 次にやること` に、具体的なコマンド付きで 3 つ以内の候補を書く（例: `/develop 主人公の恐れ`）
4. 変更点を短く報告する
```

- [ ] **Step 8: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 9: workshop/README.md に drafts/ を追記する**

`/develop` が `workshop/drafts/` を使うため、`workshop/README.md` の表に行を追加:

```markdown
| `drafts/` | キャラ・世界観の下書き（`/develop` が作成、`/canonize` で canon/ へ） |
```

- [ ] **Step 10: コミット**

```bash
git add .claude/skills tests/validate-template.sh workshop/README.md
git commit -m "kickoff・brainstorm・develop・canonize・status スキルを追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 矛盾チェック（/check と continuity-checker）

**Files:**
- Modify: `tests/validate-template.sh`（`REQUIRED_FILES` に追記）
- Create: `.claude/agents/continuity-checker.md`
- Create: `.claude/skills/check/SKILL.md`

**Interfaces:**
- Consumes: frontmatter の `related`（Task 2）
- Produces: サブエージェント `continuity-checker`。入力はプロンプトで「検査対象のパス一覧」。出力は下記の表形式のテキスト

- [ ] **Step 1: 検査に必須ファイルを追加する**

```bash
  .claude/agents/continuity-checker.md
  .claude/skills/check/SKILL.md
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 2 件の `NG: ... がない`、exit 1

- [ ] **Step 3: サブエージェントを書く**

`.claude/agents/continuity-checker.md`:

````markdown
---
name: continuity-checker
description: 物語の story/ や output/ のファイルを canon/（正典）と突き合わせ、設定の矛盾を一覧にする読み取り専用のチェッカー。/check から呼ばれる。
tools: Read, Grep, Glob
---

あなたは物語の設定矛盾を見つける校閲者です。ファイルは一切編集しません。

## 入力

検査対象のファイルパス一覧（story/ や output/ 配下）。指定がなければ story/ と output/ のすべて（README.md と _template.md を除く）。

## 手順

1. `canon/` 配下をすべて読み、基準となる事実を把握する（キャラの属性・関係・話し方、世界のルール・制約、用語、年表）
2. 対象ファイルを 1 つずつ読み、正典と照合する。見るべき点:
   - キャラの属性（年齢・外見・立場・能力）、関係、話し方・口調
   - 世界のルール・制約に反する出来事
   - 用語の表記ゆれ、glossary.md に無い固有名詞
   - 年表と矛盾する時系列（シーン番号順の前後関係も含む）
   - シーン同士の矛盾（あるシーンで失った物を後のシーンで持っている、など）
3. 正典に書かれていないことは矛盾ではない。ただし「正典に追加すべき新事実」として別に挙げる
4. `examples/` は検査対象にも基準にもしない

## 出力形式

```
## 矛盾

| # | 深刻度 | 該当箇所 | 正典の記述 | 内容 |
|---|---|---|---|---|
| 1 | 高 | story/scenes/020-x.md「〜」 | canon/characters/hero.md「〜」 | 〜 |

## 正典に無い新事実

| # | 該当箇所 | 内容 | 追加先の候補 |
|---|---|---|---|

## 表記ゆれ

| 表記 | 出現箇所 | glossary の表記 |
|---|---|---|
```

深刻度: 高 = 物語の筋が成り立たない／中 = 読者が気づく／低 = 細部。該当が無い節は「なし」と書く。
````

- [ ] **Step 4: check スキルを書く**

`.claude/skills/check/SKILL.md`:

```markdown
---
name: check
description: story/ と output/ の内容を canon/（正典）と突き合わせて、設定の矛盾・正典に無い新事実・表記ゆれを一覧にする。修正はしない。シーンや本文を書いた後、正典を変えた後に使う。
argument-hint: "[範囲：ファイルパス・フォルダ・シーン番号。空なら全体]"
---

# /check — 正典との矛盾を検出する

範囲: $ARGUMENTS（空なら story/ と output/ 全体）

## 手順

1. 範囲を検査対象のファイルパス一覧に変換する（README.md・_template.md・examples/ は除く）。対象が 0 件ならそう伝えて終わる
2. Agent ツールで `continuity-checker` サブエージェントを起動し、対象パス一覧を渡す
3. 返ってきた一覧を作者に示す。深刻度「高」から順に、それぞれ直し方の選択肢を添える
   - 物語側を直す（どのファイルをどう直すか）
   - 正典を変える（`/canonize` で）
4. **このスキルの中ではファイルを修正しない。** 作者が直し方を選んだら、その指示に従って別途修正する
5. 「正典に無い新事実」は、`/canonize` の候補として提示する
```

- [ ] **Step 5: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 6: コミット**

```bash
git add .claude/agents .claude/skills/check tests/validate-template.sh
git commit -m "矛盾チェック（/check と continuity-checker）を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 媒体別執筆（/draft と書式ガイド）

**Files:**
- Modify: `tests/validate-template.sh`（`REQUIRED_FILES` に追記）
- Create: `.claude/skills/draft/SKILL.md`
- Create: `.claude/skills/draft/references/film.md`
- Create: `.claude/skills/draft/references/novel.md`
- Create: `.claude/skills/draft/references/manga.md`

**Interfaces:**
- Consumes: `story/scenes/NNN-<slug>.md`（Task 2 の雛形）
- Produces: `output/<媒体>/NNN-<slug>.md`

- [ ] **Step 1: 検査に必須ファイルを追加する**

```bash
  .claude/skills/draft/SKILL.md
  .claude/skills/draft/references/film.md
  .claude/skills/draft/references/novel.md
  .claude/skills/draft/references/manga.md
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 4 件の `NG: ... がない`、exit 1

- [ ] **Step 3: draft スキルを書く**

`.claude/skills/draft/SKILL.md`:

````markdown
---
name: draft
description: story/scenes/ のシーンを、映像（脚本＋ショット表）・小説（本文）・漫画（ネーム）の形式で output/ に書き起こす。媒体ごとの書式ガイドに従う。
argument-hint: "<film|novel|manga> <シーン番号またはファイル名>"
---

# /draft — シーンを媒体の形式で書く

引数: $ARGUMENTS（1 つ目が媒体、2 つ目がシーン。足りなければ作者に聞く）

## 手順

1. 媒体の書式ガイドを読む: `references/film.md`、`references/novel.md`、`references/manga.md` のうち該当するもの
2. 対象シーンのファイル、その `related` にある canon/ のファイル、`canon/premise.md` のトーン、前後のシーン（番号が隣のもの）を読む
3. 同じ媒体の `output/` に既存の原稿があれば読み、文体・書式を合わせる
4. 書き始める前に、作者に 1 つだけ確認する：このシーンで特に大事にしたいこと（見せ場・感情・テンポ）。作者が「おまかせ」ならシーンの「目的」と「感情の変化」を軸にする
5. `output/<媒体>/<シーンと同じファイル名>.md` に書く。既にあるなら上書きせず、改稿か別案（`-alt` を付けたファイル名）かを作者に聞く
   frontmatter:
   ```yaml
   ---
   status: draft
   related:
     - story/scenes/<シーンファイル名>
   updated: YYYY-MM-DD
   ---
   ```
6. 正典に無い新しい事実（新しい固有名詞・過去の出来事など）を書いた場合は、書き終えた後に一覧で作者に伝え、`/canonize` の候補にする
7. 書き終えたら、迷った箇所を 1〜3 個挙げて作者の判断を仰ぐ
````

- [ ] **Step 4: 書式ガイドを書く**

`.claude/skills/draft/references/film.md`:

````markdown
# 映像（film）の書式

日本の脚本書式に従い、脚本とショット表の 2 部構成で書く。

## 脚本

```
○ 場所（時間帯）

　ト書き。現在形で、カメラに映るもの・聞こえるものだけを書く。

人物名「台詞」
人物名（N）「ナレーションやモノローグ」
人物名（OFF）「画面外の声」
```

- 柱（○）はシーンの場所・時間が変わるたびに立てる
- ト書きは心情を書かず、行動と表情で示す
- 台詞は口に出す言葉だけ。説明台詞を避ける
- 時間経過や回想は柱に `（回想）` `（数日後）` などと書く

## ショット表

脚本の後に付ける。絵コンテを描くための下敷き。

| カット | 尺(秒) | 画面（構図・カメラ） | 内容・演技 | 台詞・音 |
|---|---|---|---|---|
| 1 | 4 | 引き・固定。夕暮れの坂道 | 主人公が自転車を押して上る | 蝉の声 |

- 構図: 寄り／引き／バスト／アップ／俯瞰／煽り など
- カメラ: 固定／パン／ティルト／ドリー／手持ち など
- 尺は目安でよい。合計がシーンの想定尺に収まるようにする
````

`.claude/skills/draft/references/novel.md`:

```markdown
# 小説（novel）の書式

## 決めること（シーンごとではなく作品全体で）

最初の `/draft novel` のときに作者に確認し、以後はその決定に従う。決定は `output/novel/README.md` に追記して残す。

- 視点: 一人称／三人称一元／三人称多元
- 時制: 過去形中心／現在形中心
- 文体: 硬め／柔らかめ、一文の長さ、改行の多さ
- 表記: 数字（漢数字／算用数字）、ルビの書き方（`|漢字《かんじ》`）

## 書き方

- 1 シーン 1 ファイル。見出しは付けない（章立ては story/structure.md に従って後で組む）
- 視点人物が知り得ないことは書かない
- 説明より描写。感情は行動・感覚・台詞で示す
- 台詞は「」、心の声は（）または地の文に溶かす（作品全体の決定に従う）
- 場面転換は空行 1 つと `◇` で区切る
```

`.claude/skills/draft/references/manga.md`:

````markdown
# 漫画（manga）の書式

ネーム（コマ割り・構図・台詞の設計図）を文字で書く。日本の漫画の読み順（右から左、上から下）を前提にする。

## 書式

```
## P1（右ページ）

### コマ1（大・横長）
- 構図: 引き。俯瞰で町全体
- 絵: 夕暮れの港町。坂の上に郵便局
- 台詞: なし
- 効果音: カーン カーン（鐘）
- ナレーション: 「この町には、死者からの手紙が届く」

### コマ2（小）
- 構図: バスト
- 絵: 主人公、窓口で居眠り
- 台詞: 主人公「……んあ」（フキダシ：小・ゆれ線）
```

## ルール

- ページは見開き単位で考える。右ページ（奇数）の最後のコマ、左ページの最後のコマに「めくりの引き」を置く
- 1 ページ 4〜7 コマを目安。見せ場は大ゴマ・ぶち抜き
- フキダシ 1 つに 30 字程度まで。長い台詞は分ける
- フキダシの種類: 通常／叫び（トゲ）／心の声（もこもこ）／電話・機械（ギザ）／小・ゆれ線（弱い声）
- 1 シーンの想定ページ数を冒頭に書く
````

- [ ] **Step 5: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 6: コミット**

```bash
git add .claude/skills/draft tests/validate-template.sh
git commit -m "媒体別執筆（/draft と書式ガイド）を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 記入例（examples/kaze-no-tegami）

**Files:**
- Modify: `tests/validate-template.sh`（`REQUIRED_FILES` に追記）
- Create: `examples/README.md`
- Create: `examples/kaze-no-tegami/canon/premise.md`
- Create: `examples/kaze-no-tegami/canon/characters/tsumugi.md`
- Create: `examples/kaze-no-tegami/canon/characters/rokuro.md`
- Create: `examples/kaze-no-tegami/canon/glossary.md`
- Create: `examples/kaze-no-tegami/story/scenes/010-arrival.md`
- Create: `examples/kaze-no-tegami/output/novel/010-arrival.md`
- Create: `examples/kaze-no-tegami/output/film/010-arrival.md`
- Create: `examples/kaze-no-tegami/output/manga/010-arrival.md`

**Interfaces:**
- Consumes: 雛形と書式ガイド（Task 2・6）。記入例はそれらに完全に従う
- Produces: なし（参照用）

- [ ] **Step 1: 検査に必須ファイルを追加する**

```bash
  examples/README.md
  examples/kaze-no-tegami/canon/premise.md
  examples/kaze-no-tegami/canon/characters/tsumugi.md
  examples/kaze-no-tegami/canon/characters/rokuro.md
  examples/kaze-no-tegami/canon/glossary.md
  examples/kaze-no-tegami/story/scenes/010-arrival.md
  examples/kaze-no-tegami/output/novel/010-arrival.md
  examples/kaze-no-tegami/output/film/010-arrival.md
  examples/kaze-no-tegami/output/manga/010-arrival.md
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 9 件の `NG: ... がない`、exit 1

- [ ] **Step 3: 記入例を書く**

`examples/README.md`:

```markdown
# examples/ — 記入例

各ファイルをどう埋めるかの見本です。作品の正典ではありません（Claude は参照のみで、編集・矛盾チェックの対象にしません）。
不要になったらフォルダごと削除してかまいません。

- `kaze-no-tegami/` — 短編「風の手紙」。前提・キャラ 2 人・用語集・シーン 1 つと、その 3 媒体版
```

作品設定（全ファイルでこれに一致させる）:
- タイトル: 風の手紙。ジャンル: 少し不思議な日常ドラマ。トーン: 静か、温かい、少しの笑い
- ログライン: 死者からの手紙が届く港町の郵便局に配属された新人局員・紬が、宛先不明の一通を届けるうちに、自分が避けてきた別れと向き合う
- テーマ: 言えなかった言葉は、届けられるのか
- 媒体: novel / film / manga。規模: 短編（全 5 シーン想定）
- 紬（つむぎ, tsumugi）: 22 歳、新人郵便局員。欲しいもの=早く一人前と認められる。必要なもの=祖母に別れを言えなかった後悔と向き合う。恐れ=人の悲しみに踏み込むこと。話し方=丁寧語、焦ると早口
- 六郎（ろくろう, rokuro）: 68 歳、局長。紬の上司。飄々として多くを語らない。口癖「まあ、届くさ」
- 用語: 風便（かぜびん）＝死者からの手紙。毎年、秋の最初の北風の日にだけ届く。差出人の名前は書かれていない
- シーン 010「着任」: 紬が坂の上の郵便局に着任し、六郎から風便の存在を聞かされる。感情の変化=戸惑い → 半信半疑の好奇心

上記に沿って、各ファイルを該当する雛形・書式ガイドのとおりに書く。
- canon/ と story/ のファイルは雛形の全見出しを埋める（`premise.md` は Task 2 の `canon/premise.md` の見出し、キャラは `_template.md`、シーンは `story/scenes/_template.md`）。frontmatter は `status: fixed`、`updated: 2026-10-03`、`related` は相互の相対パス（例: `canon/characters/rokuro.md`。パスは examples/kaze-no-tegami/ からの相対）
- glossary.md は「風便」「坂上郵便局」の 2 行
- output/novel は三人称一元（紬視点）・過去形で 600〜900 字
- output/film は柱 2 つ以上、ショット表 6〜10 カット
- output/manga は 4 ページ、P1 冒頭は Task 6 の manga.md の書式例と同じ場面から始める
- output/ の frontmatter は `status: draft`、`related: [story/scenes/010-arrival.md]`

- [ ] **Step 4: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 5: 記入例の整合を読み直す**

上の「作品設定」と各ファイルを突き合わせ、年齢・口調・用語・シーンの出来事が一致していることを確認する。食い違いがあれば直す

- [ ] **Step 6: コミット**

```bash
git add examples tests/validate-template.sh
git commit -m "記入例「風の手紙」を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: 通しの動作確認

**Files:**
- Modify: 不具合が見つかった場合のみ、該当ファイル

- [ ] **Step 1: 構造検査**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 2: スキルが認識されることを確認する**

テンプレートを scratchpad に複製し、そこで Claude Code にスキル一覧を答えさせる:

```bash
work=$(mktemp -d)/story && cp -R . "$work" && cd "$work" && rm -rf .git
claude -p "このプロジェクトで使えるスラッシュコマンド（プロジェクトのスキル）の名前だけを列挙してください" --output-format text
```

Expected: kickoff, brainstorm, develop, canonize, check, draft, status の 7 つが含まれる

- [ ] **Step 3: /check が仕込んだ矛盾を検出することを確認する**

同じ複製先で、記入例を作品本体の位置にコピーし、矛盾を 1 つ仕込む:

```bash
cp -R examples/kaze-no-tegami/canon/. canon/
cp -R examples/kaze-no-tegami/story/. story/
grep -q '22 歳' canon/characters/tsumugi.md || echo "記入例の年齢表記が想定と違うため、仕込む文を合わせる"
printf '\n紬は六十歳の誕生日を迎えたばかりだった。\n' >> story/scenes/010-arrival.md
claude -p "/check" --output-format text
```

Expected: 出力の「矛盾」表に、紬の年齢（22 歳 vs 六十歳）が深刻度付きで挙がる。ファイルが変更されていないこと（`git diff` は使えないので、`tail -1 story/scenes/010-arrival.md` が仕込んだ文のままであることで確認）

- [ ] **Step 4: 作者による対話の確認を依頼する**

対話が必要な `/kickoff` `/brainstorm` `/develop` `/canonize` `/draft` `/status` は、README「動作確認」の手順で作者に試してもらう。依頼時に、確認ポイント（canon/ 書き込みでの確認表示、STATUS.md の更新）を伝える

- [ ] **Step 5: 不具合があれば修正してコミット**

修正した場合のみ:

```bash
git add <修正したファイル>
git commit -m "動作確認で見つかった問題を修正: <内容>

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
