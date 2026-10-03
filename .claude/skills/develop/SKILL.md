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
   - シーン: まず「目的」と「感情の変化」。ファイル名の番号は structure.md と前後のシーンから決める
3. 作者が「おまかせ」と言った欄は、案を 2〜3 個示して選んでもらう。それでも決まらなければ下書きとして 1 案を書き、`## 未確定の点` に残す
4. 下書きを雛形に沿って書き、frontmatter の `related` に関係するファイルを入れる
5. 正典と食い違う点に気づいたら、下書きに反映せず作者に指摘する
6. 書いた内容を要約して見せ、次の一手を提案する（キャラ・世界観なら `/canonize`、シーンなら `/draft` や次のシーンの `/develop`）
