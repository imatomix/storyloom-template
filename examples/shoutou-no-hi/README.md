# 消灯の日まで（制作途中の記入例）

廃止が決まった離島の灯台に家出してきた 14 歳の汐里と、停止命令が出ても「灯を絶やすな」の命令が優先されて止まれない旧式の灯台守ロボット LK-7（ナナ）の話。媒体は読み切り漫画と短編映画。

このテンプレートのコマンドを一通り使って作った、**制作途中の状態**の見本です。`風の手紙` が「各ファイルの埋め方」の見本なのに対し、こちらは長い作品の運用（状態記録・伏線台帳・確定）の見本です。

## 読む順番

1. `STATUS.md` — 作品の現在地。どこまで決まり、何が残っているか
2. `canon/premise.md` → `canon/characters/` → `canon/locations/todai.md` — 正典
3. `story/scenes/010-shinobikomi.md` → `output/manga/010-shinobikomi.md` — 骨格と、それを書き起こしたネーム
4. `story/state.md`・`story/threads.md` — 010・020 を確定した後のキャラの状態と伏線台帳

## 見どころ

| 見たいもの | ファイル |
|---|---|
| 確定（`/finalize`）後のシーン：`summary` と「このシーンの後で変わったこと」 | `story/scenes/010-shinobikomi.md`、`020-nana.md` |
| シーンをまたいで更新された状態 | `story/state.md`（最後に更新したシーン：020） |
| 伏線台帳（ID・回収予定は「未定」） | `story/threads.md`、各シーンの `## 伏線` |
| 基準の媒体だけを確定する | 漫画 010・020 は fixed、映画 010 は draft |
| 右綴じのめくりを意識したネーム（13 ページ） | `output/manga/010-shinobikomi.md` |
| 作者の手直しを正典に戻す流れ | 漫画 010 の「未読 12 件」の場面 → `canon/characters/shiori.md` の「恐れ」 |
| 壁打ちの記録とボツ案 | `workshop/sessions/`、`workshop/rejected.md` |

## 意図的に残しているもの

制作途中の見本なので、次は未完成のままにしています。

- `story/scenes/030-haikou.md` は骨格だけの draft。「未確定の点」と、正典に無い新事実（旧分校など）が残っている
- `story/synopsis.md`・`story/structure.md` は未記入。そのため伏線の回収予定はすべて「未定」
- 結末（ナナの最後の選択、日誌の最後のページ、未読 12 件の中身）は未決。`STATUS.md` の「未解決の問い」を参照

## 作り方について

テンプレートの動作確認（QA）で、作者役の回答に対して Claude Code が各コマンドを実行して作りました。作者役の回答は「おまかせ」が多いため、正典の細部には Claude の案が多く含まれています。
