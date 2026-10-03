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
