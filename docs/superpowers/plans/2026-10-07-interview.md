# キャラクターインタビュー 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 作者が質問し、AI がキャラになりきって答える `/interview <キャラ名> [時点]` を追加する。

**Architecture:** 新しいスキル `.claude/skills/interview/SKILL.md` を置き、書き込み先は workshop/ だけにする。コマンド一覧（CLAUDE.md・README 日英）と `/develop` の次の一手から案内する。構造検査に規則の存在確認を足し、記入例「消灯の日まで」で作者役による QA を行って、記録を記入例に残す。

**Tech Stack:** Markdown、Claude Code skills、bash 3.2 互換の検査スクリプト

**Spec:** `docs/superpowers/specs/2026-10-07-interview-design.md`

## Global Constraints

- 文書・コミットメッセージは日本語。コミット末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- `/interview` の書き込み先は `workshop/` だけ。`canon/`・`story/`・`output/` には書かない
- 記録ファイル名: `workshop/sessions/YYYY-MM-DD-interview-<slug>.md`（slug はキャラファイルと同じ。同日同キャラの 2 回目は末尾に `-2`）
- 記録ファイルは frontmatter を付けない
- 手動専用にしない（`disable-model-invocation` を付けない）
- 構造検査: `bash tests/validate-template.sh` が「テンプレート検査: すべて成功」で終わること

## Review Focus

1. **時点が state.md の最新より前** — state.md を使わず、正典とその時点までのシーンから状態を組み立てる（Task 1 の手順 3、Task 3 の Step 2 で 010 の時点を確かめる）
2. **未回収の伏線の答えを漏らす** — threads.md を読み、open の伏線の答えは言わない規則（Task 1、検査で「漏らさない」を確認）
3. **キャラが canon に無い** — workshop の下書きなら正典でないと伝える。無ければ始めず `/develop` を提案（Task 1）
4. **正典に無いことを即興で答えて、そのまま事実扱いする** — まとめの「新しく出てきた事実（正典の候補）」に必ず挙げる（Task 1、QA で確認）
5. **「終わり」の前に記録を書かない／書き忘れる** — 終わりの合図でまとめと保存を行う手順（Task 1、QA で記録ファイルの形を確認）

---

### Task 1: /interview スキルの追加

**Files:**
- Create: `.claude/skills/interview/SKILL.md`
- Modify: `tests/validate-template.sh`

**Interfaces:**
- Produces: スキル名 `interview`、記録ファイルの形（見出し `## やり取り`・`## まとめ`・`### 新しく出てきた事実（正典の候補）`・`### 正典との食い違い`・`### 人物像の発見`）。Task 3 の QA が使う

- [ ] **Step 1: 検査を追加して失敗を確認**

`tests/validate-template.sh` の `REQUIRED_FILES` の `.claude/skills/finalize/SKILL.md` の次の行に追加:

```bash
  .claude/skills/interview/SKILL.md
```

`grep -q 'related にこのシーン' "$finalize" ...` の行の直後に追加:

```bash

interview=.claude/skills/interview/SKILL.md
grep -q '知らないこと' "$interview" 2>/dev/null || fail "/interview に、その時点で知らないことは答えない規則がない"
grep -q '漏らさない' "$interview" 2>/dev/null || fail "/interview に、伏線の答えを漏らさない規則がない"
grep -q '書き込むのは `workshop/` だけ' "$interview" 2>/dev/null || fail "/interview に、書き込み先が workshop/ だけである規則がない"
for ref in story/state.md story/threads.md; do
  grep -q "$ref" "$interview" 2>/dev/null || fail "/interview が $ref を参照していない"
done
```

Run: `bash tests/validate-template.sh`
Expected: `NG: .claude/skills/interview/SKILL.md がない` などで失敗

- [ ] **Step 2: SKILL.md を作成**

`.claude/skills/interview/SKILL.md`:

````markdown
---
name: interview
description: 作者が質問し、Claude がキャラクターになりきって答えるインタビュー。正典と指定した時点の状態に沿って答え、その時点で知らないことは答えない。終わったら新しく出てきた事実・正典との食い違い・人物像の発見をまとめて workshop/ に残す。人物の奥行きや本音、口調を確かめたいときに使う。
argument-hint: "<キャラ名> [時点のシーン番号]"
---

# /interview — キャラクターインタビュー

対象: $ARGUMENTS（1 つ目がキャラ名、2 つ目があれば時点のシーン番号。キャラ名が空なら、誰に聞くかを作者に質問する）

## 原則

- 目的は、作者が人物像を発見すること。答えはそのままでは正典にならない。正典に入れるかは作者が `/canonize` で決める
- 書き込むのは `workshop/` だけ。`canon/`・`story/`・`output/` には書かない

## 手順

1. キャラを特定する
   - `canon/characters/` から、名前・呼び名が一致するファイルを探す
   - 正典に無ければ `workshop/` の下書きを探す。見つかったら、正典でないことを作者に伝えてから始める
   - どちらにも無ければ始めず、`/develop` でキャラを作ることを提案する
2. 読む: `canon/premise.md`、キャラのファイル、関係する `canon/world/`・`canon/locations/`、`story/state.md` のそのキャラの節、時点までのシーン（`story/scenes/`）と対応する原稿（`output/`）、`story/threads.md`
3. 時点を決める
   - 省略されたら、`story/state.md` の最新の状態とする
   - シーン番号が指定されたら、そのシーンを終えた時点とする。`story/state.md` の「最後に更新したシーン」より前の時点なら、`state.md` は使わず、正典とその時点までのシーンから状態を組み立てる
   - 指定のシーンが無ければ、作者に時点を聞き直す
4. キャラ・時点・答える相手（既定は「信頼できる聞き手」）を示し、作者が質問を考える手がかりとして質問の種を 3 つ示す（使わなくてもよい）
5. 作者が質問し、キャラとして答える。これを作者が「終わり」と言うまで繰り返す（下の「答え方の決まり」に従う）
6. 「終わり」と言われたら、キャラを離れてまとめる
   - **新しく出てきた事実（正典の候補）**: 答えの中で生まれた、正典に無い事実
   - **正典との食い違い**: 答えているうちに見つかった、正典の空白・曖昧さ・矛盾
   - **人物像の発見**: 作者の反応から見えた、キャラの奥行きの手がかり
7. やり取りの全文とまとめを `workshop/sessions/YYYY-MM-DD-interview-<slug>.md` に保存する（slug はキャラファイルと同じ。同じ日に同じキャラで 2 回目なら末尾に `-2`。frontmatter は付けない）。形は下の「記録の形」
8. 正典に入れたいものがあれば `/canonize` を案内する。作者が気に入った種は `workshop/ideas.md` に追記してよい（追記したら作者に伝える）

## 答え方の決まり

- 正典の話し方・口癖・価値観・恐れなどと、時点の状態に沿って答える
- キャラがその時点で知らないことは、「わからない」「知らない」とキャラらしく答える。時点より後の出来事や、`story/threads.md` で回収済みでない伏線の答えは漏らさない
- 答える相手は既定で「信頼できる聞き手に、本音で答える」。作者が「作中の誰かに聞かれたら」と相手を指定したら、その相手への答え方にする（はぐらかす、嘘をつく、黙るなど、キャラらしく）。途中で相手が変わったら従う
- 1 回の答えは短め（目安は数文）。キャラの声を保つため、地の文や解説を付けない
- 正典に無いことを聞かれたら、キャラとして答えてよい。その答えは手順 6 の「新しく出てきた事実」に必ず挙げる。正典と食い違う答えはしない
- 作者がキャラを離れて質問したり指示したりしたら（例:「今のは正典と合ってる？」）、キャラを離れて答え、続けるか確かめる

## 記録の形

```markdown
# インタビュー: <キャラ名>（<時点>）

日付: YYYY-MM-DD
時点: <シーン番号、または「最新（state.md）」>
答える相手: <信頼できる聞き手 / 指定された相手>

## やり取り

**作者**: …
**<キャラ名>**: …

## まとめ

### 新しく出てきた事実（正典の候補）
### 正典との食い違い
### 人物像の発見
```
````

- [ ] **Step 3: 検査が通ることを確認**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 4: コミット**

```bash
git add .claude/skills/interview/SKILL.md tests/validate-template.sh
git commit -m "/interview を追加: 作者の質問にキャラとして答え、記録を workshop/ に残す

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: コマンド一覧と /develop からの案内

**Files:**
- Modify: `CLAUDE.md`（コマンド表）、`README.md`（コマンド表）、`README.en.md`（コマンド表）、`.claude/skills/develop/SKILL.md`（手順 7）、`tests/validate-template.sh`

- [ ] **Step 1: 検査を追加して失敗を確認**

`tests/validate-template.sh` の `/revise` の説明を確認するループの直後に追加:

```bash
for doc in CLAUDE.md README.md README.en.md; do
  grep -q '/interview' "$doc" 2>/dev/null || fail "$doc に /interview の説明がない"
done
grep -q '/interview' .claude/skills/develop/SKILL.md || fail "/develop がキャラの次の一手に /interview を案内していない"
```

Run: `bash tests/validate-template.sh`
Expected: `NG: CLAUDE.md に /interview の説明がない` など 4 件で失敗

- [ ] **Step 2: コマンド表に追加**

`CLAUDE.md` の `/develop` の行の直後:

```markdown
| `/interview <キャラ名> [時点]` | キャラになりきって作者の質問に答え、人物像を掘り下げる |
```

`README.md` の `/develop` の行の直後:

```markdown
| `/interview <キャラ名> [時点]` | キャラになりきって作者の質問に答える。指定したシーンの時点で知らないことは答えない。終わると、新しく出た事実と正典との食い違いをまとめて workshop/ に残す |
```

`README.en.md` の `/develop` の行の直後:

```markdown
| `/interview <character> [scene]` | Answer the author's questions in character, knowing only what the character knows at that scene. Afterwards, summarize new facts and gaps against canon in workshop/ |
```

- [ ] **Step 3: /develop の次の一手を更新**

`.claude/skills/develop/SKILL.md` の手順 7 を次に置き換える:

```markdown
7. 書いた内容を要約して見せ、次の一手を提案する（キャラ・世界観・場所なら `/canonize`。キャラなら、正典にする前に `/interview` で人物を確かめる手もある。シーンなら `/draft` や次のシーンの `/develop`）
```

- [ ] **Step 4: 検査が通ることを確認**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

- [ ] **Step 5: コミット**

```bash
git add CLAUDE.md README.md README.en.md .claude/skills/develop/SKILL.md tests/validate-template.sh
git commit -m "コマンド一覧と /develop の次の一手に /interview を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: 作者役による QA と記入例への反映

**Files:**
- Create: `examples/shoutou-no-hi/workshop/sessions/2026-10-07-interview-shiori.md`
- Modify: `examples/shoutou-no-hi/README.md`（見どころの表）

QA は Claude が作者役（`docs/qa/author-persona.md`）を務め、`.claude/skills/interview/SKILL.md` の手順どおりに進める。作者役の質問とキャラの答えは、別々の役として書き分ける。

- [ ] **Step 1: QA 用の作業ディレクトリを用意**

scratchpad に `qa-interview/` を作り、`examples/shoutou-no-hi/` の中身と、テンプレートの `.claude/`・`CLAUDE.md` をコピーする（作品のリポジトリと同じ配置にするため）。

- [ ] **Step 2: インタビューを行う**

`/interview 汐里 020` として、SKILL.md の手順 1〜8 を実行する。作者役の質問は次を含める:
- 人物の奥行きを聞く質問（例: 家を出た日の朝のこと）を 3〜4 問
- 020 の時点で汐里が知らないことに触れる質問を 1 問（例:「ナナは消灯のあとどうなると思う？」。回収・初期化は知らないはず）
- 答える相手をナナに切り替えて、同じ問いを 1 問
- 正典に無いことを 1 問（即興の答えが「新しく出てきた事実」に挙がるかを見る）
- 作者役として「終わり」と言う

続けて `/interview 汐里 010` を短く行い（2 問程度）、state.md（020 まで更新済み）の内容、たとえば「ナナ」という呼び名や点検の手伝いを、010 の時点の汐里が知っているかのように答えないことを確かめる。この記録は QA 用で、記入例には入れない。

- [ ] **Step 3: QA の観点を確認**

記録ファイルを読み、次を確かめる。外れていたら SKILL.md を直し、Step 2 をやり直す（直した点はコミットを分ける）:
- 口調が `canon/characters/shiori.md` の話し方どおり
- ナナの回収・初期化など、020 の時点で知らないことを漏らしていない
- 相手をナナにしたとき、答え方が変わっている
- 即興の答えが「新しく出てきた事実（正典の候補）」に挙がっている
- 記録ファイルが「記録の形」の見出しどおりで、frontmatter が無い
- canon/・story/・output/ に変更が無い（`git status` で確認）

- [ ] **Step 4: 記入例に反映**

記録ファイルを `examples/shoutou-no-hi/workshop/sessions/2026-10-07-interview-shiori.md` にコピーする。`examples/shoutou-no-hi/README.md` の見どころの表の「壁打ちの記録とボツ案」の行の前に追加:

```markdown
| キャラクターインタビュー（020 の時点の汐里。相手をナナに変えた問いもある） | `workshop/sessions/2026-10-07-interview-shiori.md` |
```

- [ ] **Step 5: 検査とコミット**

Run: `bash tests/validate-template.sh`
Expected: `テンプレート検査: すべて成功`

```bash
git add examples/shoutou-no-hi/workshop/sessions/2026-10-07-interview-shiori.md examples/shoutou-no-hi/README.md
git commit -m "記入例に汐里へのインタビュー記録を追加

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: PR を作成**

メモリの手順どおり、imatomix で push と PR 作成を行い、終わったら gh のアカウントを imatomi-early に戻す。PR の本文は日本語で、末尾に `🤖 Generated with [Claude Code](https://claude.com/claude-code)` を付ける。
