---
name: develop
description: キャラクター・世界観のトピック・場所・シーン・あらすじ・構成のうち 1 つを選んで深掘りし、雛形に沿った下書きを作る。キャラ・世界観・場所の下書きは workshop/ に、シーン・あらすじ・構成は story/ に書く。
argument-hint: "<対象：キャラ名・世界観トピック・場所・シーン・synopsis・structure>"
---

# /develop — 1 つを深掘りして下書きする

対象: $ARGUMENTS（空なら STATUS.md を見て候補を 2〜3 個示し、作者に選んでもらう）

## 書き込み先

| 対象 | 雛形 | 書き込み先 |
|---|---|---|
| キャラクター | `canon/characters/_template.md` | `workshop/drafts/characters/<slug>.md` |
| 世界観 | `canon/world/_template.md` | `workshop/drafts/world/<slug>.md` |
| 場所 | `canon/locations/_template.md` | `workshop/drafts/locations/<slug>.md` |
| シーン | `story/scenes/_template.md` | `story/scenes/NNN-<slug>.md` |
| あらすじ | — | `story/synopsis.md` |
| 構成 | — | `story/structure.md` |

キャラ・世界観・場所は設定（正典の候補）なので、canon/ には直接書かない。確定したら `/canonize` で昇格させる。
既に canon/ にある対象を深掘りするときは、canon のファイルを `workshop/drafts/` に複製してから編集する。

## 手順

1. `canon/premise.md` と、対象に関係する canon/・story/・workshop/ のファイル（ideas.md、rejected.md、既存の下書き）を読む
2. 雛形の空欄のうち、物語にとって重要なものから順に作者へ質問する。1 回に 1 つ。選択肢か具体例を添える
   - キャラ: まず「欲しいもの」と「本当に必要なもの」、次に「恐れ」と「物語での変化」
   - 世界観: まず「ルール・制約」（物語で何ができて何ができないか）
   - 場所: まず「間取りと動線」と「光・時間帯による変化」（映像・漫画の画面設計に効く）
   - シーン: まず「目的」と「感情の変化」、次に「伏線」「引き」「情報の差」。ファイル名の番号は structure.md と前後のシーンから決める。「このシーンの後で変わったこと」と `summary` は空のまま（`/finalize` が書く）。作者が望めば「シーン設計」まで作ってよい（作らなければ `/draft` の最初に作る）
   - 構成: `references/structure.md` の型を 2〜3 個示して選んでもらい、既存のシーンを当てはめて空いている段を示す
3. 作者が「おまかせ」と言った欄は、案を 2〜3 個示して選んでもらう。それでも決まらなければ下書きとして 1 案を書き、`## 未確定の点` に残す
4. 下書きを雛形に沿って書き、frontmatter の `related` に関係するファイルを入れる
5. シーンで新しい伏線・問いを張る場合は、`story/threads.md` に登録する（ID は台帳の最大 ID + 1、状態 open、張ったシーンと回収予定を記入）。回収予定はシーン番号（例: 040）で書き、決まっていなければ「未定」とする。構成上の位置しか決まっていなければ、structure.md から候補のシーン番号を作者に示して選んでもらう。シーンの `## 伏線` にはその ID を書く
6. 正典と食い違う点に気づいたら、下書きに反映せず作者に指摘する
7. 書いた内容を要約して見せ、次の一手を提案する（キャラ・世界観・場所なら `/canonize`、シーンなら `/draft` や次のシーンの `/develop`）
