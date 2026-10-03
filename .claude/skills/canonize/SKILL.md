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
5. 書き込む。frontmatter の `status` は作者の指示どおり（指定がなければ `fixed`）、`updated` は今日。付随して更新したファイル（glossary.md・timeline.md・関係するキャラなど）の status も、主ファイルに揃えるかを作者に確認する
6. 昇格元の下書き（`workshop/drafts/...`）は削除してよいか作者に確認する
7. 影響を受ける story/・output/ がある場合は `/check` を提案する
8. コミットを提案する。メッセージ例: `正典: <対象> を追加`
