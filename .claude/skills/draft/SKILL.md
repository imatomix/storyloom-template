---
name: draft
description: story/scenes/ のシーンを、映像（脚本＋ショット表）・小説（本文）・漫画（ネーム）の形式で output/ に書き起こす。媒体ごとの書式ガイドに従う。
argument-hint: "<film|novel|manga> <シーン番号またはファイル名>"
---

# /draft — シーンを媒体の形式で書く

引数: $ARGUMENTS（1 つ目が媒体、2 つ目がシーン。足りなければ作者に聞く）

## 手順

1. 媒体の書式ガイドを読む: `references/film.md`、`references/novel.md`、`references/manga.md` のうち該当するもの
2. 読む:
   - 対象シーンのファイル、その `related` にある canon/ のファイル、`canon/premise.md` のトーン
   - 前後のシーン（番号が隣のもの）。次のシーンの「目的」を踏まえて、このシーンの引きを作る
   - `story/state.md`（登場キャラの現在の状態）と `story/threads.md`（状態が open の伏線）
   - 確定済みシーンの 1 行あらすじ一覧（`story/scenes/` の frontmatter の `summary:` を Grep で集める）
   - 同じ媒体の直前のシーンの原稿があれば、その末尾（文体と流れをつなぐため）
3. `output/<媒体>/README.md`（作品全体の決めごと・文体の見本）があれば読み、従う。同じ媒体の `output/` に既存の原稿があれば読み、文体・書式を合わせる
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
7. このシーンで触れた伏線（張った・回収した・進めた）を `story/threads.md` の ID で報告する。台帳の更新は作者が原稿を直し終えた後の `/finalize` で行う
8. 書き終えたら、迷った箇所を 1〜3 個挙げて作者の判断を仰ぐ
