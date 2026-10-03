# storyloom-template

AI（Claude Code）と一緒に、映像・小説・漫画の物語を作るためのテンプレートです。
作者が主導し、Claude は質問・提案・矛盾チェック・下書きを担当します。

## はじめ方

1. このフォルダを複製して、作品用のリポジトリにする
   ```bash
   cp -R storyloom-template my-story && cd my-story
   rm -rf .git docs/superpowers   # テンプレート自体の履歴と設計資料。不要なら削除
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
