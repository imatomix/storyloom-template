# 文体の調整 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 小説の文体を作者が決め・見本で示し・数値を見ながら推敲できるようにする（文体の観点、文体の見本、`/revise`、計測スクリプト）。

**Architecture:** 決めごとと見本を `output/novel/README.md` に集約し、`/draft` と `/revise` が必ず読む。数値は Python 標準ライブラリだけの `prose-stats.py` が出し、無い環境では計測なしで動く。

**Tech Stack:** Markdown、Claude Code skills、Python 3（標準ライブラリのみ）、bash 3.2 互換の検査スクリプト

**Spec:** `docs/superpowers/specs/2026-10-03-prose-style-design.md`

## Global Constraints

- 文書・コミットメッセージは日本語。コミット末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Python は標準ライブラリのみ。終了コード: 正常 0、引数・ファイルの誤り 2
- bash 3.2 互換。`$変数` の直後に全角文字を続けない
- `/revise` は出来事・事実・台詞の内容を変えない。確定済み原稿の status を変えない

## Review Focus

1. **frontmatter の無い原稿・空の原稿でスクリプトが落ちる** — 0 除算を避け、0 として出力（Task 1 のテスト）
2. **地の文中の「」（引用）を会話として数える** — 行頭が「『のものだけを会話にする（Task 1 のテスト）
3. **場面転換の `◇` を段落・文として数える** — 除外する（Task 1 のテスト）
4. **python3 が無い環境で `/revise` が止まる** — 計測なしに切り替える手順を明記（Task 3）
5. **`/revise` が出来事まで書き換える** — SKILL.md の原則に明記し、変わった場合は `/finalize` を促す（Task 3）

---

### Task 1: 計測スクリプト

**Files:**
- Create: `.claude/skills/revise/scripts/prose-stats.py`
- Create: `tests/revise/prose-stats.test.sh`, `tests/revise/fixture.md`
- Modify: `tests/validate-template.sh`

**Interfaces:**
- Produces: `python3 .claude/skills/revise/scripts/prose-stats.py <原稿.md>` → 標準出力 4 行（下記の形式）。Task 3 の `/revise` が使う

- [ ] **Step 1: テストの入力を作る**

`tests/revise/fixture.md`:

```markdown
---
status: draft
---
港からの坂は、急だった。

風が吹く。草が揺れる。波が鳴る。

「こんばんは」

灯台の白い光。

◇

彼女は長い坂道を一歩ずつ踏みしめながら、夕暮れの海を見下ろす岬の上の灯台へとたどり着いた。
```

期待値の内訳: 地の文 6 文（11・4・5・4・6・44 字）、会話 1 行、段落 5（◇ は除外）、地の文の段落 4（1・3・1・1 文）。語尾は た・現在・現在・現在・その他・た。

- [ ] **Step 2: テストを書く**

`tests/revise/prose-stats.test.sh`:

```bash
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

empty=$(mktemp)
printf -- '---\nstatus: draft\n---\n' > "$empty"
python3 "$script" "$empty" >/dev/null 2>&1 && echo "ok: 本文が空でも落ちない" || { echo "NG: 本文が空で失敗"; failures=$((failures + 1)); }
rm -f "$empty"

python3 "$script" >/dev/null 2>&1; [ $? -eq 2 ] && echo "ok: 引数なしは終了コード 2" || { echo "NG: 引数なしの終了コード"; failures=$((failures + 1)); }
python3 "$script" /nonexistent.md >/dev/null 2>&1; [ $? -eq 2 ] && echo "ok: ファイルなしは終了コード 2" || { echo "NG: ファイルなしの終了コード"; failures=$((failures + 1)); }

[ "$failures" -eq 0 ] || { echo "prose-stats のテスト失敗: $failures 件"; exit 1; }
echo "prose-stats のテスト: すべて成功"
```

- [ ] **Step 3: 失敗を確認する**

Run: `bash tests/revise/prose-stats.test.sh`
Expected: スクリプトが無いため NG、exit 1

- [ ] **Step 4: スクリプトを書く**

`.claude/skills/revise/scripts/prose-stats.py`:

```python
#!/usr/bin/env python3
"""小説原稿の文体を計測する。使い方: prose-stats.py <原稿.md>"""
import re
import sys

SENTENCE_END = re.compile(r"(?<=[。！？])")
DIALOGUE_OPENERS = ("「", "『")
SCENE_BREAK = "◇"
PRESENT_ENDINGS = set("うくすつぬふむゆるぐずづぶぷいだ")
SHORT_MAX = 15
MEDIUM_MAX = 35


def strip_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[end + 5:]
    return text


def split_paragraphs(body):
    blocks = [b.strip() for b in re.split(r"\n\s*\n", body)]
    return [b for b in blocks if b and b != SCENE_BREAK]


def split_sentences(paragraph):
    return [s.strip() for s in SENTENCE_END.split(paragraph) if s.strip()]


def ending_of(sentence):
    core = sentence.rstrip("。！？")
    if core.endswith("た"):
        return "past"
    if core and core[-1] in PRESENT_ENDINGS:
        return "present"
    return "other"


def ratio(part, whole):
    return part / whole if whole else 0.0


def longest_run(items):
    best = run = 0
    previous = None
    for item in items:
        run = run + 1 if item == previous else 1
        best = max(best, run)
        previous = item
    return best


def measure(text):
    paragraphs = split_paragraphs(strip_frontmatter(text))
    dialogue = [p for p in paragraphs if p.startswith(DIALOGUE_OPENERS)]
    narrative = [split_sentences(p) for p in paragraphs if not p.startswith(DIALOGUE_OPENERS)]
    sentences = [s for paragraph in narrative for s in paragraph]
    lengths = [len(s.rstrip("。！？")) for s in sentences]
    endings = [ending_of(s) for s in sentences]
    count = len(sentences)

    return "\n".join([
        f"地の文: {count} 文 / 会話: {len(dialogue)} 行（会話の比率 {ratio(len(dialogue), len(dialogue) + count):.0%}）",
        f"文の長さ: 平均 {ratio(sum(lengths), count):.1f} 字 / 最長 {max(lengths, default=0)} 字"
        f" / 短 {ratio(sum(1 for n in lengths if n <= SHORT_MAX), count):.0%}"
        f" / 中 {ratio(sum(1 for n in lengths if SHORT_MAX < n <= MEDIUM_MAX), count):.0%}"
        f" / 長 {ratio(sum(1 for n in lengths if n > MEDIUM_MAX), count):.0%}",
        f"語尾: た {ratio(endings.count('past'), count):.0%}"
        f" / 現在形 {ratio(endings.count('present'), count):.0%}"
        f" / 体言止め・その他 {ratio(endings.count('other'), count):.0%}"
        f" / 同じ語尾の最大連続 {longest_run(endings)}",
        f"段落: {len(paragraphs)} / 地の文の段落あたり {ratio(count, len(narrative)):.1f} 文"
        f" / 1 文だけの段落 {ratio(sum(1 for p in narrative if len(p) == 1), len(narrative)):.0%}",
    ])


def main(argv):
    if len(argv) != 2:
        print("使い方: prose-stats.py <原稿.md>", file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as f:
            text = f.read()
    except OSError as error:
        print(f"ファイルを読めません: {error}", file=sys.stderr)
        return 2
    print(measure(text))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Run: `chmod +x .claude/skills/revise/scripts/prose-stats.py tests/revise/prose-stats.test.sh`

- [ ] **Step 5: テストが通ることを確認する**

Run: `bash tests/revise/prose-stats.test.sh`
Expected: すべて ok、exit 0。期待値と違えば、Step 1 の内訳と実際の値を突き合わせて原因（文字数の数え方・区切り）を特定し、スクリプトを直す（テストの期待値は内訳から計算し直したときだけ直す）

- [ ] **Step 6: 構造検査から呼ぶ**

`tests/validate-template.sh` の `REQUIRED_FILES` に追記:

```bash
  .claude/skills/revise/scripts/prose-stats.py
  tests/revise/prose-stats.test.sh
  tests/revise/fixture.md
```

フックのテストを呼ぶ行の次に追加:

```bash
bash tests/revise/prose-stats.test.sh >/dev/null || fail "prose-stats のテストが失敗（bash tests/revise/prose-stats.test.sh で詳細を確認）"
```

Run: `bash tests/validate-template.sh` → `テンプレート検査: すべて成功`

- [ ] **Step 7: コミット**

```bash
git add .claude/skills/revise/scripts tests
git commit -m "文体の計測スクリプト prose-stats.py とテストを追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 文体の観点・見本の雛形・/draft の対応

**Files:**
- Modify: `tests/validate-template.sh`
- Modify: `.claude/skills/draft/references/novel.md`, `.claude/skills/draft/SKILL.md`
- Create: `output/novel/README.md`

**Interfaces:**
- Produces: `output/novel/README.md` の見出し `## 作品全体の決めごと` `## 文体の見本`（Task 3 の `/revise` が読む）

- [ ] **Step 1: 検査を追加する**

`REQUIRED_FILES` に `  output/novel/README.md` を追記。STATUS.md 見出し検査の直前に追加:

```bash
for heading in "## 作品全体の決めごと" "## 文体の見本"; do
  grep -qx "$heading" output/novel/README.md 2>/dev/null || fail "output/novel/README.md に見出し「${heading}」がない"
done
for aspect in "文の長さ" "語尾" "段落の長さ" "描写の密度" "会話と地の文の比率"; do
  grep -q "$aspect" .claude/skills/draft/references/novel.md || fail "novel.md に文体の観点「${aspect}」がない"
done
grep -q 'output/<媒体>/README.md' .claude/skills/draft/SKILL.md || fail "/draft が媒体の README（決めごと・見本）を読んでいない"
```

- [ ] **Step 2: 失敗を確認する**

Run: `bash tests/validate-template.sh`
Expected: README がない・見出し 2 件・観点（語尾・段落の長さ・描写の密度・会話と地の文の比率）・/draft の不参照で exit 1

- [ ] **Step 3: novel.md を書き換える**

`.claude/skills/draft/references/novel.md` の「## 決めること（シーンごとではなく作品全体で）」節を次に置き換える:

```markdown
## 決めること（シーンごとではなく作品全体で）

最初の `/draft novel` の前に `output/novel/README.md` を読む。決めごとが空なら作者に確認し、決まったことを `## 作品全体の決めごと` に書く。以後はその決定に従う。

- 視点: 一人称／三人称一元／三人称多元
- 時制: 過去形中心／現在形中心
- 表記: 数字（漢数字／算用数字）、ルビの書き方（`|漢字《かんじ》`）
- 心の声: 括弧で書くか、地の文に溶かすか

文体は次の 5 観点で決める。「短め」「柔らかめ」のような一語の指定だけにせず、緩急のつけ方まで決める。

| 観点 | 決める内容の例 |
|---|---|
| 文の長さ | 基調と、緩急をつける場面（例: 基調は短め、情景と感情の山場では長く） |
| 語尾 | 「た」の比率の目安と、混ぜるもの（現在形・体言止めなど） |
| 段落の長さ | 1 文だけの段落を使う頻度 |
| 描写の密度 | 感覚描写・比喩の量 |
| 会話と地の文の比率 | 会話中心か、地の文中心か |

`## 文体の見本` に作者の文章（数段落）や目指す文体の特徴があれば、決めごとの言葉よりも見本の実際の文章に合わせる。

## 書き終えた後の確認

`python3 .claude/skills/revise/scripts/prose-stats.py <原稿>` で計測し、決めごとと比べて外れている点（同じ語尾の連続、文の長さの偏りなど）を作者に報告する。python3 が無ければ、読んで気づいた点を報告する。直すかどうかは作者が決め、直すなら `/revise` を使う。
```

- [ ] **Step 4: 雛形を作る**

`output/novel/README.md`:

```markdown
# output/novel/ — 小説本文

`/draft novel` と `/revise` は、書く前にこのファイルを読みます。

## 作品全体の決めごと

<!-- 最初の /draft novel で作者と決めます。書式ガイド: .claude/skills/draft/references/novel.md -->

- 視点：
- 時制：
- 表記：
- 心の声：
- 文の長さ：
- 語尾：
- 段落の長さ：
- 描写の密度：
- 会話と地の文の比率：

## 文体の見本

<!-- 作者が書いた数段落を貼るか、目指す文体の特徴を書きます。言葉の説明より、見本の文章のほうが文体は正確に伝わります -->
```

`output/novel/.gitkeep` は削除する（README があるため不要）。

- [ ] **Step 5: /draft を書き換える**

`.claude/skills/draft/SKILL.md` の手順 3 を次に置き換える:

```markdown
3. `output/<媒体>/README.md`（作品全体の決めごと・文体の見本）があれば読み、従う。同じ媒体の `output/` に既存の原稿があれば読み、文体・書式を合わせる
```

- [ ] **Step 6: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh` → `テンプレート検査: すべて成功`

- [ ] **Step 7: コミット**

```bash
git add -A .claude/skills/draft output/novel tests/validate-template.sh
git commit -m "小説の書式ガイドに文体の観点を追加し、決めごと・文体の見本の雛形を用意

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: /revise スキルと文書の更新

**Files:**
- Modify: `tests/validate-template.sh`
- Create: `.claude/skills/revise/SKILL.md`
- Modify: `CLAUDE.md`, `README.md`, `README.en.md`

**Interfaces:**
- Consumes: Task 1 のスクリプト、Task 2 の `output/novel/README.md`
- Produces: `/revise <シーン>`

- [ ] **Step 1: 検査を追加する**

`REQUIRED_FILES` に `  .claude/skills/revise/SKILL.md` を追記。`/finalize` の説明の検査ループの後に追加:

```bash
for doc in CLAUDE.md README.md README.en.md; do
  grep -q '/revise' "$doc" 2>/dev/null || fail "$doc に /revise の説明がない"
done
```

- [ ] **Step 2: 失敗を確認する**

Run: `bash tests/validate-template.sh` → SKILL.md がない、3 文書に説明がない、で exit 1

- [ ] **Step 3: スキルを書く**

`.claude/skills/revise/SKILL.md`:

```markdown
---
name: revise
description: 小説の原稿（output/novel/）の文体を推敲する。文の長さ・語尾・段落などを計測して作品の決めごとや文体の見本と比べ、直す箇所の案を「直す前 → 直した後」で示し、作者が承認した箇所だけを書き換える。出来事や台詞の内容は変えない。
argument-hint: "<シーン番号またはファイル名> [観点や範囲]"
---

# /revise — 文体を推敲する

対象: $ARGUMENTS（空なら output/novel/ の原稿を示して作者に選んでもらう）

## 原則

- 直すのは文体だけ。出来事・事実・台詞の内容は変えない
- **作者が承認した箇所だけを書き換える**
- 文体の基準は `output/novel/README.md`。文体の見本があれば、決めごとの言葉より見本の文章を優先する

## 手順

1. 読む: 対象の原稿（`output/novel/NNN-*.md`）、`output/novel/README.md`（作品全体の決めごと・文体の見本）
   - 決めごとの文体の項目（文の長さ・語尾・段落の長さ・描写の密度・会話と地の文の比率）が空なら、先に作者と決めて README に書く（`.claude/skills/draft/references/novel.md` の観点を使う）
2. 計測する: `python3 .claude/skills/revise/scripts/prose-stats.py <原稿>`
   - python3 が無い、またはスクリプトが失敗したら、その旨を伝え、計測なしで読んで進める
3. 診断を示す: 計測値と決めごと・見本との差を、箇条書きで 3〜5 点にまとめる（例: 「た」で終わる文が 85%、同じ語尾が 9 文続く箇所がある）
4. 案を示す: 直す箇所を 3〜5 つ選び、それぞれ「直す前 → 直した後」と、ねらい（緩急・語尾の変化・描写の追加など）を示す
   - 作者が原稿全体の推敲を求めたら、段落のまとまりごとに案を示し、承認を得ながら先へ進む
   - 作者が観点や範囲を指定したら（例: 「語尾だけ」「冒頭の 3 段落」）、それに絞る
5. 作者の承認を待つ。承認された箇所だけを書き換え、`updated` を今日にする。status は変えない
6. 書き換えた後にもう一度計測し、前後の数値を並べて示す
7. 推敲の途中で出来事や事実が変わった場合は、そのことを伝え、確定済みのシーンなら `/finalize` のやり直しを提案する
8. 作者の好みがはっきりした点（「体言止めは多めでいい」など）は、`output/novel/README.md` の決めごとに追記するか作者に確認する
```

- [ ] **Step 4: 文書を更新する**

- `CLAUDE.md` のコマンド表、`/finalize` の行の次に:
  `| \`/revise <シーン>\` | 小説の文体を計測して推敲する |`
- `CLAUDE.md` の「## フォルダごとの扱い」表の `output/` の行を次に:
  `| \`output/\` | 媒体別の成果物 | 作者の依頼、または \`/draft\`・\`/revise\` で。\`/finalize\` は status だけを変える |`
- `README.md` のコマンド表、`/finalize` の行の次に:
  `| \`/revise <シーン>\` | 小説の文体を計測し（文の長さ・語尾・段落）、作品の決めごとや文体の見本と比べて推敲する |`
- `README.md` の「## 長い作品の一貫性」節の後に新しい節:

  ```markdown
  ## 文体の調整

  小説の文体は `output/novel/README.md` で決めます。
  - **作品全体の決めごと**：視点・時制・表記に加え、文の長さ・語尾・段落の長さ・描写の密度・会話と地の文の比率
  - **文体の見本**：自分で書いた数段落を貼っておくと、`/draft` と `/revise` はそれに合わせます

  `/revise` は原稿を計測して（Python 3 を使用。無い環境では計測なしで読んで指摘）、直す箇所の案を出し、承認した箇所だけを書き換えます。
  ```
- `README.en.md` のコマンド表、`/finalize` の行の次に:
  `| \`/revise <scene>\` | Measure prose style (sentence length, endings, paragraphs) and revise it against the work's style rules and sample |`
- `README.en.md` の「## Canon guard」の前に新しい節:

  ```markdown
  ## Adjusting prose style

  Novel style is set in `output/novel/README.md`: style rules (point of view, tense, sentence length, sentence endings, paragraph length, descriptive density, dialogue ratio) and a style sample. `/draft` and `/revise` follow the sample over the rules. `/revise` measures the manuscript with Python 3 (falls back to reading without numbers), proposes before/after edits, and applies only the ones you approve.
  ```

- [ ] **Step 5: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh` → `テンプレート検査: すべて成功`

- [ ] **Step 6: コミット**

```bash
git add .claude/skills/revise CLAUDE.md README.md README.en.md tests/validate-template.sh
git commit -m "推敲コマンド /revise を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 記入例の書き直し

**Files:**
- Modify: `examples/shoutou-no-hi/output/novel/README.md`, `010-shinobikomi.md`, `020-nana.md`, `examples/shoutou-no-hi/README.md`

- [ ] **Step 1: 推敲前の数値を記録する**

Run: `python3 .claude/skills/revise/scripts/prose-stats.py examples/shoutou-no-hi/output/novel/010-shinobikomi.md`（020 も）。出力を控える

- [ ] **Step 2: QA 用の作品に新しいテンプレートを反映する**

scratchpad の QA 作業ディレクトリに `.claude/`・`CLAUDE.md` をコピーしてコミット

- [ ] **Step 3: 決めごとと見本を書き換える**

QA 作業ディレクトリの `output/novel/README.md` を新しい雛形の形に揃え、文体の項目を次のように決める（既存の視点・時制・表記・心の声・ルビは維持）:

- 文の長さ：基調は短め。情景と感情が動く場面では、読点でつないだ長い文を混ぜて緩急をつける
- 語尾：「た」は全体の六割程度まで。現在形と体言止めを混ぜ、同じ語尾を四文以上続けない
- 段落の長さ：一文だけの段落は、間（ま）を作りたい箇所に絞る
- 描写の密度：音・匂い・光などの感覚描写を多めに。比喩は控えめ
- 会話と地の文の比率：地の文中心。会話は短く

`## 文体の見本` には、作品と同じ文体の目標を示す 2〜3 段落の見本（作品外の場面。夜の港など）を書く。

- [ ] **Step 4: /revise で 010 と 020 を推敲する**

`claude -p "/revise 010 原稿全体を推敲してください"` を実行し、案をすべて承認する（`--continue` で「すべて承認します」）。020 も同様。出来事・台詞が変わっていないことを `git diff` で確認する

- [ ] **Step 5: 推敲後の数値を計測し、記入例に反映する**

推敲後の 010・020 と `output/novel/README.md` を `examples/shoutou-no-hi/output/novel/` にコピー。`examples/shoutou-no-hi/README.md` の見どころの表に行を追加:

`| 文体の決めごと・見本と推敲 | \`output/novel/README.md\`。010・020 は \`/revise\` で推敲した（下の表） |`

末尾の「## 作り方について」の前に、推敲前後の計測値を並べた表（地の文の平均文長、長い文の割合、「た」の割合、同じ語尾の最大連続）を追加する

- [ ] **Step 6: 検査とコミット**

Run: `bash tests/validate-template.sh` → `テンプレート検査: すべて成功`

```bash
git add examples
git commit -m "記入例「消灯の日まで」の小説版を /revise で推敲し、文体の決めごと・見本を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
