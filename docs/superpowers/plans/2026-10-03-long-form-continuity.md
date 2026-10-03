# 長編の一貫性強化 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 確定コマンド `/finalize`・伏線台帳・キャラの状態記録・場所の正典化を storyloom-template に追加し、長い作品でも一貫性を保てるようにする。

**Architecture:** 物語の進行で変わる記録を `story/state.md` と `story/threads.md` に置き、作者が確定した原稿を起点に `/finalize` が更新する。`/draft`・`/develop`・`/status`・continuity-checker はこれらを読み書きするよう拡張する。

**Tech Stack:** Markdown、Claude Code（skills / agents）、bash 3.2 互換の検査スクリプト

**Spec:** `docs/superpowers/specs/2026-10-03-long-form-continuity-design.md`

## Global Constraints

- 文書・コミットメッセージは日本語。コミット末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- bash 3.2 互換。`$変数` の直後に全角文字を続けない（`${変数}` を使う）
- canon/・story/・output/・examples/ 配下の Markdown（README.md を除く）は frontmatter に `status: draft | review | fixed`
- 伏線 ID は `T` + 2 桁連番（T01, T02…）。状態は `open | closed | dropped`
- 場所: `canon/locations/<slug>.md`。下書きは `workshop/drafts/locations/<slug>.md`
- `/finalize` は `disable-model-invocation: true`。canon/ には書かない

## Review Focus

1. **`/finalize` が作者の承認前に書き込む** — SKILL.md で「承認後に書き込む」を手順上明示し、書き込み対象を列挙（Task 2）
2. **`/finalize` が canon/ を書き換える** — 新事実は `/canonize` 候補の提示のみ（Task 2）。フックも canon/ を保護している
3. **複数媒体の原稿で状態が食い違う** — 基準媒体を作者に聞く（Task 2）
4. **伏線 ID の重複・採番ずれ** — `/develop` と `/finalize` は threads.md の最大 ID + 1 で採番（Task 2・3）
5. **examples/ の伏線台帳を作品の台帳と取り違える** — continuity-checker と `/status` は examples/ を除外（既存ルールを維持、Task 3・4）

---

### Task 1: 雛形と台帳の追加

**Files:**
- Modify: `tests/validate-template.sh`
- Modify: `story/scenes/_template.md`
- Create: `story/state.md`, `story/threads.md`, `canon/locations/_template.md`, `workshop/research/.gitkeep`
- Modify: `canon/README.md`, `story/README.md`, `workshop/README.md`

**Interfaces:**
- Produces: threads.md の表の見出し行 `| ID | 種類 | 内容 | 張ったシーン | 回収予定 | 回収したシーン | 状態 |`
- Produces: シーン雛形の見出し `## 伏線` `## 引き` `## 情報の差` `## 重要な小道具` `## 時間的な制約` `## このシーンの後で変わったこと` と frontmatter `summary:`
- Produces: state.md のキャラ項目 `最後に更新したシーン／居場所／知っていること／持ち物／体の状態／関係の変化`

- [ ] **Step 1: 検査を追加する**

`REQUIRED_FILES` の `output/manga/.gitkeep` の次に追記:

```bash
  story/state.md
  story/threads.md
  canon/locations/_template.md
  workshop/research/.gitkeep
```

STATUS.md の見出し検査ループの直前に追記:

```bash
grep -q '^summary:' story/scenes/_template.md 2>/dev/null \
  || fail "story/scenes/_template.md の frontmatter に summary がない"
grep -qx '| ID | 種類 | 内容 | 張ったシーン | 回収予定 | 回収したシーン | 状態 |' story/threads.md 2>/dev/null \
  || fail "story/threads.md に台帳の見出し行がない"
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 4 件の「がない」と summary・台帳の 2 件、計 6 件で exit 1

- [ ] **Step 3: シーン雛形を書き換える**

`story/scenes/_template.md`:

```markdown
---
status: draft
related: []
summary: ""   # 1 行あらすじ。/finalize が書く
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

## 伏線
<!-- 張る：T03 〜／回収する：T01。ID は story/threads.md の台帳 -->

## 引き
<!-- 次のシーンへ読者を運ぶ問い -->

## 情報の差
<!-- 読者だけが知っていること／キャラだけが知っていること -->

## 重要な小道具

## 時間的な制約

## このシーンの後で変わったこと
<!-- /finalize が書きます -->

## メモ
```

- [ ] **Step 4: 台帳と状態記録を作る**

`story/state.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# キャラの現在の状態

<!-- 物語の進行で変わる状態の記録。/finalize が確定したシーンをもとに更新します。キャラごとに見出しを 1 つ。変わらない設定は canon/characters/ に -->

## キャラクター名
- 最後に更新したシーン：
- 居場所：
- 知っていること：
- 持ち物：
- 体の状態：
- 関係の変化：
```

`story/threads.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# 伏線台帳

<!-- 張った伏線と、まだ答えていない問い。/develop が登録し、/finalize が更新し、/check が回収漏れを検出します
ID: T + 2 桁連番。新規は最大 ID + 1
状態: open（未回収）／closed（回収済み）／dropped（取りやめ。理由を内容欄に） -->

| ID | 種類 | 内容 | 張ったシーン | 回収予定 | 回収したシーン | 状態 |
|---|---|---|---|---|---|---|
```

`canon/locations/_template.md`:

```markdown
---
status: draft
related: []
updated: YYYY-MM-DD
---
# 場所名

## 概要
<!-- どこにあり、物語でどんな役割を持つ場所か -->

## 見た目

## 音と匂い

## 光・時間帯による変化

## 間取りと動線
<!-- 人物がどこから入り、どこに立ち、どこへ抜けるか。映像・漫画の画面設計の基準になります -->

## ここで起きたシーン

## 未確定の点
```

`workshop/research/.gitkeep`: 空ファイル

- [ ] **Step 5: 各 README に行を足す**

`canon/README.md` の表、`world/` の行の次に:

```markdown
| `locations/` | 場所。1 か所 1 ファイル（`_template.md` を複製） |
```

`story/README.md` の表、`scenes/` の行の次に:

```markdown
| `state.md` | キャラの現在の状態（居場所・知っていること・持ち物など）。`/finalize` が更新 |
| `threads.md` | 伏線台帳。張った伏線と未回収の問い |
```

`workshop/README.md` の表、`drafts/` の行の次に:

```markdown
| `research/` | 取材資料・時代考証・専門知識のメモ。Claude が参照します |
```

- [ ] **Step 6: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 7: コミット**

```bash
git add tests/validate-template.sh story canon workshop
git commit -m "伏線台帳・状態記録・場所の雛形を追加し、シーン雛形を拡張

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: /finalize スキル

**Files:**
- Modify: `tests/validate-template.sh`
- Create: `.claude/skills/finalize/SKILL.md`

**Interfaces:**
- Consumes: Task 1 の state.md・threads.md・シーン雛形の見出し
- Produces: `/finalize <シーン>`

- [ ] **Step 1: 検査を追加する**

`REQUIRED_FILES` の `.claude/skills/draft/references/manga.md` の次に `  .claude/skills/finalize/SKILL.md` を追記

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: `NG: .claude/skills/finalize/SKILL.md がない`、exit 1

- [ ] **Step 3: スキルを書く**

`.claude/skills/finalize/SKILL.md`:

```markdown
---
name: finalize
description: 作者が直し終えた output/ の原稿を確定させ、シーンの 1 行あらすじと「後で変わったこと」、story/state.md（キャラの現在の状態）、story/threads.md（伏線台帳）を更新する。作者の承認を得てから書き込む。
argument-hint: "<シーン番号またはファイル名>"
disable-model-invocation: true
---

# /finalize — シーンを確定し、記録を更新する

対象: $ARGUMENTS（空なら status が draft の原稿があるシーンを示して作者に選んでもらう）

## 原則

- 記録の元にするのは、作者が直し終えた原稿だけ。原稿に書かれていないことを状態に書かない
- **作者の承認を得るまで、どのファイルにも書き込まない**
- canon/ には書かない。正典に無い新事実は `/canonize` の候補として示すだけにする

## 手順

1. 読む: 対象シーン（`story/scenes/NNN-*.md`）、`output/*/` の同名の原稿、`story/state.md`、`story/threads.md`、シーンの `related` にある canon/ のファイル
   - 原稿が無ければ、先に `/draft` するよう伝えて終わる
   - 原稿が複数の媒体にあれば、どれを基準にするか作者に聞く。媒体間で出来事が食い違っていたら、その点も伝える
2. 変更案を作り、まとめて作者に示す
   - **シーン**: frontmatter の `summary`（1 行、40 字程度）と `## このシーンの後で変わったこと`（箇条書き）
   - **state.md**: 登場したキャラごとに、居場所・知っていること・持ち物・体の状態・関係の変化の差分。「最後に更新したシーン」をこのシーンにする。初登場のキャラは見出しを追加
   - **threads.md**: このシーンで張った伏線・生まれた問いを追加（ID は台帳の最大 ID + 1、状態 open、張ったシーンにこのシーン）。回収したものは「回収したシーン」を埋めて closed に
   - **正典の候補**: 原稿で初めて出た固有名詞・過去の出来事・設定。`/canonize` で入れるかどうかを作者に聞く
3. 作者の承認を待つ。修正の指示があれば反映して再提示する
4. 承認された分を書き込む。基準の原稿とシーンの status を `fixed` にし、書き換えた全ファイルの `updated` を今日にする
5. 回収予定を過ぎても open の伏線があれば知らせる
6. コミットを提案する。メッセージ例: `確定: 010-arrival`
```

- [ ] **Step 4: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 5: コミット**

```bash
git add .claude/skills/finalize tests/validate-template.sh
git commit -m "確定コマンド /finalize を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: /draft・/develop・/status の拡張と構成の参考資料

**Files:**
- Modify: `tests/validate-template.sh`
- Create: `.claude/skills/develop/references/structure.md`
- Modify: `.claude/skills/draft/SKILL.md`, `.claude/skills/develop/SKILL.md`, `.claude/skills/status/SKILL.md`

**Interfaces:**
- Consumes: Task 1 の台帳・状態・雛形、Task 2 の `/finalize`

- [ ] **Step 1: 検査を追加する**

`REQUIRED_FILES` に `  .claude/skills/develop/references/structure.md` を追記。さらに、スキル本文が新しい記録を参照していることの検査を STATUS.md 見出し検査の直前に追加:

```bash
for skill in draft develop status finalize; do
  grep -q 'story/threads.md' ".claude/skills/$skill/SKILL.md" 2>/dev/null \
    || fail ".claude/skills/$skill/SKILL.md が story/threads.md を参照していない"
done
for skill in draft finalize; do
  grep -q 'story/state.md' ".claude/skills/$skill/SKILL.md" 2>/dev/null \
    || fail ".claude/skills/$skill/SKILL.md が story/state.md を参照していない"
done
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: structure.md がない、draft・develop・status の threads.md 不参照、draft の state.md 不参照の計 5 件で exit 1

- [ ] **Step 3: 構成の参考資料を書く**

`.claude/skills/develop/references/structure.md`:

```markdown
# 構成の型

`/develop structure` で構成を考えるときの参考。型は道具であり、作品に合わなければ崩してよい。作者に 2〜3 の型を示し、選んでもらう。

## 三幕構成

| 幕 | 割合 | 役割 |
|---|---|---|
| 第一幕：設定 | 約 25% | 日常と主人公を示し、きっかけの事件で物語を動かす。幕の終わりで主人公が後戻りできない選択をする |
| 第二幕：対立 | 約 50% | 目標に向かうほど障害が強まる。中盤（ミッドポイント）で状況や目標の意味が反転する。終盤で最大の危機 |
| 第三幕：解決 | 約 25% | クライマックスで主題に答えを出し、変化した主人公の新しい日常を示す |

向いている: 映画、長編小説。一本の大きな目標がある物語

## 起承転結

| 段 | 役割 |
|---|---|
| 起 | 状況と人物の提示 |
| 承 | 状況の展開・深まり |
| 転 | 予想を覆す出来事。見え方が変わる |
| 結 | 転を受けた着地 |

向いている: 短編、4 コマ・短編漫画、連載の 1 話単位。対立より「見え方の変化」が中心の物語

## Save the Cat（15 ビート）

オープニング・イメージ／テーマの提示／セットアップ／きっかけ／悩みの時／第一ターニングポイント／B ストーリー／お楽しみ／ミッドポイント／迫り来る悪い奴ら／すべてを失って／心の暗闇／第二ターニングポイント／フィナーレ／ファイナル・イメージ

向いている: 娯楽映画、テンポを重視する長編。三幕構成を細かく割ったものとして使う

## 使い方

- 型の各段に、既存のシーン（`story/scenes/`）を当てはめ、空いている段を見つける
- 空いている段は、`/develop` でシーンを作る候補として作者に示す
- 伏線（`story/threads.md`）の回収予定は、第三幕・結・フィナーレに集まりすぎていないか確認する
```

- [ ] **Step 4: /draft を書き換える**

`.claude/skills/draft/SKILL.md` の「## 手順」の 2 と 6 を次に置き換え、7 を 8 にずらして新しい 7 を入れる:

```markdown
2. 読む:
   - 対象シーンのファイル、その `related` にある canon/ のファイル、`canon/premise.md` のトーン
   - 前後のシーン（番号が隣のもの）。次のシーンの「目的」を踏まえて、このシーンの引きを作る
   - `story/state.md`（登場キャラの現在の状態）と `story/threads.md`（状態が open の伏線）
   - 確定済みシーンの 1 行あらすじ一覧（`story/scenes/` の frontmatter の `summary:` を Grep で集める）
   - 同じ媒体の直前のシーンの原稿があれば、その末尾（文体と流れをつなぐため）
```

```markdown
6. 正典に無い新しい事実（新しい固有名詞・過去の出来事など）を書いた場合は、書き終えた後に一覧で作者に伝え、`/canonize` の候補にする
7. このシーンで触れた伏線（張った・回収した・進めた）を `story/threads.md` の ID で報告する。台帳の更新は作者が原稿を直し終えた後の `/finalize` で行う
```

- [ ] **Step 5: /develop を書き換える**

`.claude/skills/develop/SKILL.md`:
- frontmatter の description を次に置き換える:
  `description: キャラクター・世界観のトピック・場所・シーン・あらすじ・構成のうち 1 つを選んで深掘りし、雛形に沿った下書きを作る。キャラ・世界観・場所の下書きは workshop/ に、シーン・あらすじ・構成は story/ に書く。`
- argument-hint を `"<対象：キャラ名・世界観トピック・場所・シーン・synopsis・structure>"` に
- 「## 書き込み先」の表の世界観の行の次に追加:
  `| 場所 | \`canon/locations/_template.md\` | \`workshop/drafts/locations/<slug>.md\` |`
- 表の直後の文「キャラと世界観は設定（正典の候補）なので」を「キャラ・世界観・場所は設定（正典の候補）なので」に
- 手順 2 の箇条に追加:
  ```markdown
     - 場所: まず「間取りと動線」と「光・時間帯による変化」（映像・漫画の画面設計に効く）
     - 構成: `references/structure.md` の型を 2〜3 個示して選んでもらい、既存のシーンを当てはめて空いている段を示す
  ```
- 手順 2 のシーンの箇条を次に置き換え:
  ```markdown
     - シーン: まず「目的」と「感情の変化」、次に「伏線」「引き」「情報の差」。ファイル名の番号は structure.md と前後のシーンから決める。「このシーンの後で変わったこと」と `summary` は空のまま（`/finalize` が書く）
  ```
- 手順 4 の次に追加し、以降の番号をずらす:
  ```markdown
  5. シーンで新しい伏線・問いを張る場合は、`story/threads.md` に登録する（ID は台帳の最大 ID + 1、状態 open、張ったシーンと回収予定を記入）。シーンの `## 伏線` にはその ID を書く
  ```

- [ ] **Step 6: /status を書き換える**

`.claude/skills/status/SKILL.md` の手順 2 の箇条に追加:

```markdown
   - `story/threads.md` の伏線: 状態 open の数と、回収予定のシーンが既に確定（status: fixed）しているのに open のままのもの
```

手順 3 の `## 未解決の問い` の行を次に置き換え:

```markdown
   - `## 未解決の問い` を整理する（解決済みは消し、新しいものを足す）。回収予定を過ぎた伏線はここに ID 付きで挙げる
```

- [ ] **Step 7: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 8: コミット**

```bash
git add .claude/skills tests/validate-template.sh
git commit -m "/draft・/develop・/status を伏線台帳と状態記録に対応させ、構成の参考資料を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: continuity-checker の拡張

**Files:**
- Modify: `tests/validate-template.sh`
- Modify: `.claude/agents/continuity-checker.md`

**Interfaces:**
- Consumes: Task 1 の threads.md 台帳形式
- Produces: 出力の節 `## 伏線`（`/check` はこれをそのまま作者に示す）

- [ ] **Step 1: 検査を追加する**

Task 3 で追加したループの後に:

```bash
grep -q '^## 伏線' .claude/agents/continuity-checker.md 2>/dev/null \
  || fail "continuity-checker の出力形式に「伏線」節がない"
grep -qx 'model: sonnet' .claude/agents/continuity-checker.md 2>/dev/null \
  || fail "continuity-checker に model: sonnet がない"
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 2 件で exit 1

- [ ] **Step 3: エージェントを書き換える**

`.claude/agents/continuity-checker.md` 全体を次に置き換える:

````markdown
---
name: continuity-checker
description: 物語の story/ や output/ のファイルを canon/（正典）・キャラの状態記録・伏線台帳と突き合わせ、設定や時系列の矛盾と伏線の回収漏れを一覧にする読み取り専用のチェッカー。/check から呼ばれる。
tools: Read, Grep, Glob
model: sonnet
---

あなたは物語の設定矛盾を見つける校閲者です。ファイルは一切編集しません。

## 入力

検査対象のファイルパス一覧（story/ や output/ 配下）。指定がなければ story/ と output/ のすべて（README.md と _template.md を除く）。

## 手順

1. `canon/` 配下をすべて読み、基準となる事実を把握する（キャラの属性・関係・話し方、世界のルール・制約、場所、用語、年表）
2. `story/state.md` と `story/threads.md` を読む
3. 対象ファイルを 1 つずつ読み、正典と照合する。見るべき点:
   - キャラの属性（年齢・外見・立場・能力）、関係、話し方・口調
   - 世界のルール・制約に反する出来事、場所の描写の食い違い
   - 用語の表記ゆれ、glossary.md に無い固有名詞
   - 年表と矛盾する時系列（シーン番号順の前後関係も含む）
4. シーンを番号順に見て、状態の流れを確かめる。各シーンの「このシーンの後で変わったこと」と state.md を手がかりに、失った物を後で持っている、知らないはずのことを知っている、怪我が説明なく治っている、などを探す
5. 伏線台帳を確かめる
   - 回収予定のシーンが存在し status が fixed なのに、状態が open のままの伏線
   - 台帳に無い ID がシーンの `## 伏線` に書かれている、または張ったシーンより前で回収されている
   - 台帳で closed なのに、回収したシーンの本文に回収に当たる出来事が見当たらない
6. 正典に書かれていないことは矛盾ではない。ただし「正典に追加すべき新事実」として別に挙げる
7. `examples/` は検査対象にも基準にもしない

## 出力形式

```
## 矛盾

| # | 深刻度 | 該当箇所 | 基準（正典・状態記録）の記述 | 内容 |
|---|---|---|---|---|
| 1 | 高 | story/scenes/020-x.md「〜」 | canon/characters/hero.md「〜」 | 〜 |

## 伏線

| ID | 問題 | 該当箇所 | 内容 |
|---|---|---|---|
| T01 | 回収予定を過ぎて open | story/threads.md、story/scenes/040-x.md | 〜 |

## 正典に無い新事実

| # | 該当箇所 | 内容 | 追加先の候補 |
|---|---|---|---|

## 表記ゆれ

| 表記 | 出現箇所 | glossary の表記 |
|---|---|---|
```

深刻度: 高 = 物語の筋が成り立たない／中 = 読者が気づく／低 = 細部。該当が無い節は「なし」と書く。
````

- [ ] **Step 4: /check の説明を合わせる**

`.claude/skills/check/SKILL.md` の description を次に置き換える:
`description: story/ と output/ の内容を canon/（正典）・キャラの状態記録・伏線台帳と突き合わせて、設定や時系列の矛盾・伏線の回収漏れ・正典に無い新事実・表記ゆれを一覧にする。修正はしない。シーンや本文を書いた後、正典を変えた後に使う。`

手順 3 の後に追加し、以降の番号をずらす:

```markdown
4. 「伏線」の節があれば、それぞれ「回収するシーンを作る／回収予定を変える／dropped にする」の選択肢を添えて示す
```

- [ ] **Step 5: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 6: コミット**

```bash
git add .claude/agents .claude/skills/check tests/validate-template.sh
git commit -m "continuity-checker に状態の流れと伏線の回収漏れの検出を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: CLAUDE.md と README の更新

**Files:**
- Modify: `tests/validate-template.sh`
- Modify: `CLAUDE.md`, `README.md`

- [ ] **Step 1: 検査を追加する**

Task 4 で追加した検査の後に:

```bash
for doc in CLAUDE.md README.md; do
  grep -q '/finalize' "$doc" 2>/dev/null || fail "$doc に /finalize の説明がない"
done
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 2 件で exit 1

- [ ] **Step 3: CLAUDE.md を更新する**

- 「## 記録」の末尾に追加:
  ```markdown
  - 物語の進行で変わる状態は `story/state.md`、伏線と未回収の問いは `story/threads.md` に記録する。どちらも原稿の確定時に `/finalize` で更新する。新しい伏線をシーンに張るときは `/develop` で台帳に登録する
  - 取材資料は `workshop/research/` にある。時代考証や専門的な描写の前に確認する
  ```
- 「## 命名」の「キャラ・世界観」の行を次に置き換える:
  ```markdown
  - キャラ・世界観・場所: `canon/characters/<slug>.md`、`canon/world/<slug>.md`、`canon/locations/<slug>.md`（slug はローマ字の小文字とハイフン）
  - 伏線: `T` + 2 桁連番（T01, T02…）。新規は台帳の最大 ID + 1
  ```
- 「## コマンド」の表、`/draft` の行の次に:
  ```markdown
  | `/finalize <シーン>` | 直し終えた原稿を確定し、状態記録と伏線台帳を更新する |
  ```

- [ ] **Step 4: README.md を更新する**

- 「## コマンド」の表、`/draft` の行の次に:
  ```markdown
  | `/finalize <シーン>` | 直し終えた原稿を確定し、1 行あらすじ・キャラの状態・伏線台帳を更新する |
  ```
- 「## 典型的な流れ」のコードブロックを次に置き換える:
  ```
  /kickoff → /brainstorm → /develop → /canonize → （story/ を組み立てる）→ /draft → （作者が直す）→ /finalize → /check → /status
  ```
- 「## 典型的な流れ」の段落の後に新しい節を追加:
  ```markdown
  ## 長い作品の一貫性

  - `story/state.md` — キャラの現在の状態（居場所・知っていること・持ち物など）
  - `story/threads.md` — 伏線台帳。張った伏線と未回収の問い
  - シーンの `summary` — 1 行あらすじ。`/draft` は全シーンを読まずに、これで流れをつかむ

  いずれも作者が原稿を直し終えた後の `/finalize` で更新します。`/check` は回収予定を過ぎた伏線や、シーン順に見た状態の矛盾も検出します。
  ```
- 「## 個人設定」の後に新しい節を追加:
  ```markdown
  ## モデルの指定

  矛盾チェック（`.claude/agents/continuity-checker.md`）は読むファイルが多いため、`model: sonnet` を指定しています。細かな矛盾の見落としが気になる場合は `model: inherit`（会話と同じモデル）に変えてください。
  ```

- [ ] **Step 5: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 6: コミット**

```bash
git add CLAUDE.md README.md tests/validate-template.sh
git commit -m "CLAUDE.md と README に /finalize と長編の一貫性の仕組みを追記

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 記入例の更新

**Files:**
- Modify: `tests/validate-template.sh`
- Modify: `examples/kaze-no-tegami/story/scenes/010-arrival.md`, `examples/kaze-no-tegami/output/novel/010-arrival.md`（status のみ）, `examples/README.md`
- Create: `examples/kaze-no-tegami/story/state.md`, `examples/kaze-no-tegami/story/threads.md`, `examples/kaze-no-tegami/canon/locations/sakaue-yubinkyoku.md`

- [ ] **Step 1: 検査を追加する**

examples の条件付きブロック `REQUIRED_FILES+=(` の中に追記:

```bash
    examples/kaze-no-tegami/story/state.md
    examples/kaze-no-tegami/story/threads.md
    examples/kaze-no-tegami/canon/locations/sakaue-yubinkyoku.md
```

- [ ] **Step 2: 検査が失敗することを確認する**

Run: `bash tests/validate-template.sh`
Expected: 3 件の「がない」で exit 1

- [ ] **Step 3: シーン 010 を新しい雛形に合わせる**

`examples/kaze-no-tegami/story/scenes/010-arrival.md` の frontmatter に `related` の後で `summary: 紬が坂上郵便局に着任し、六郎から風便の存在を聞かされる` を追加し、`related` に `canon/locations/sakaue-yubinkyoku.md` と `story/threads.md` を足す。`## 感情の変化` と `## メモ` の間に次を挿入:

```markdown
## 伏線

張る：T01、T02

## 引き

風便は本当に届くのか。紬はなぜ北の空を見上げたのか

## 情報の差

読者は、紬が北の空を見上げたことに意味がありそうだと感じている。紬自身はまだ理由を自覚していない

## 重要な小道具

空の木箱（風便を入れる箱）

## 時間的な制約

秋の最初の北風の日（風便が届く日）が近い

## このシーンの後で変わったこと

- 紬は風便の存在を聞かされ、半信半疑ながら気にかけはじめた
- 紬にとって六郎は「つかみどころのない上司」になった
```

- [ ] **Step 4: 状態記録・台帳・場所を書く**

`examples/kaze-no-tegami/story/state.md`:

```markdown
---
status: fixed
related:
  - story/scenes/010-arrival.md
updated: 2026-10-03
---
# キャラの現在の状態

## 紬
- 最後に更新したシーン：010-arrival
- 居場所：港町。坂上郵便局に勤務しはじめた
- 知っていること：風便の存在（半信半疑）
- 持ち物：特になし
- 体の状態：坂道で少し疲れている
- 関係の変化：六郎を、何を考えているかわからない上司だと感じている

## 六郎
- 最後に更新したシーン：010-arrival
- 居場所：坂上郵便局
- 知っていること：風便の季節が近いこと
- 持ち物：老眼鏡（額に上げたまま）
- 体の状態：変化なし
- 関係の変化：紬を迎えたが、多くを語っていない
```

`examples/kaze-no-tegami/story/threads.md`:

```markdown
---
status: fixed
related:
  - story/scenes/010-arrival.md
updated: 2026-10-03
---
# 伏線台帳

| ID | 種類 | 内容 | 張ったシーン | 回収予定 | 回収したシーン | 状態 |
|---|---|---|---|---|---|---|
| T01 | 問い | 紬が北の空を見上げた理由（祖母に別れを言えなかった後悔） | 010-arrival | 040 | | open |
| T02 | 伏線 | 六郎自身も、誰かからの風便を待っている（木箱の埃を払う仕草、「まあ、届くさ」） | 010-arrival | 050 | | open |
```

`examples/kaze-no-tegami/canon/locations/sakaue-yubinkyoku.md`:

```markdown
---
status: fixed
related:
  - canon/glossary.md
  - story/scenes/010-arrival.md
updated: 2026-10-03
---
# 坂上郵便局

## 概要

港町の坂のいちばん上にある小さな郵便局。風便を扱う唯一の局で、局員は六郎と紬の二人

## 見た目

木造の平屋。木の引き戸と、色の褪せた赤いポスト。窓口の奥に、天井まで届く棚のある部屋

## 音と匂い

坂の下から波の音とカモメの声。古い紙と木の匂い

## 光・時間帯による変化

夕方は西日が窓口まで差し込む。夜は町の灯を見下ろせる

## 間取りと動線

引き戸を入るとすぐ窓口。窓口の脇の通路から奥の部屋へ。奥の部屋の棚に、風便を入れる木箱が並ぶ

## ここで起きたシーン

- 010-arrival：紬の着任

## 未確定の点

- 局の裏手の様子
```

`examples/kaze-no-tegami/output/novel/010-arrival.md` の frontmatter の `status: draft` を `status: fixed` に（`/finalize` の基準にした原稿という見本）。

`examples/README.md` の `kaze-no-tegami/` の行を次に置き換える:

```markdown
- `kaze-no-tegami/` — 短編「風の手紙」。前提・キャラ 2 人・場所・用語集・シーン 1 つとその 3 媒体版、`/finalize` 後の状態記録と伏線台帳
```

- [ ] **Step 5: 検査が通ることを確認する**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 6: 記入例の整合を読み直す**

state.md・threads.md・シーン 010・場所・既存のキャラと用語集が食い違っていないことを確認する

- [ ] **Step 7: コミット**

```bash
git add examples tests/validate-template.sh
git commit -m "記入例に状態記録・伏線台帳・場所を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 通しの動作確認

- [ ] **Step 1: 構造検査**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 2: 新しいスキルが認識されることを確認する**

scratchpad に `git archive HEAD` で複製し、`claude -p "このプロジェクトで使えるスラッシュコマンド（プロジェクトのスキル）の名前だけを列挙してください"`
Expected: finalize を含む 8 つ

- [ ] **Step 3: /check が回収予定を過ぎた伏線を検出することを確認する**

同じ複製先で:

```bash
cp -R examples/kaze-no-tegami/canon/. canon/
cp -R examples/kaze-no-tegami/story/. story/
cat > story/scenes/040-letter.md <<'EOF'
---
status: fixed
related: []
summary: 紬が初めての風便を配達する
updated: 2026-10-03
---
# 初配達

## 目的
紬が初めて風便を配達する

## 出来事
紬は宛先の家に風便を届け、受け取った老婦人と話す
EOF
claude -p "/check" --output-format text
```

Expected: 「伏線」節に T01（回収予定 040 が fixed なのに open）が挙がる。ファイルは変更されない

- [ ] **Step 4: 対話の確認を作者に依頼する**

`/finalize` は対話が必要なため、README「動作確認」の手順に加えて作者に試してもらう

- [ ] **Step 5: 不具合があれば修正してコミット**
