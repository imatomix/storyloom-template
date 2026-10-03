---
name: status
description: canon/・story/・output/ の frontmatter の status を集計して STATUS.md を更新し、未解決の問いと次にやることを提案する。作品の現在地を知りたいときに使う。
---

# /status — 現在地を確認する

## 手順

1. 集計する。対象は `canon/`、`story/`、`output/film/`、`output/novel/`、`output/manga/` の `.md`。`README.md` と `_template.md` と `examples/` は除く
   - 各ファイルの frontmatter の `status:` を読み、領域ごとに draft / review / fixed を数える
   - frontmatter が無い・status が不正なファイルは、別に一覧にして作者に知らせる
2. 現在地を把握する
   - `canon/premise.md` が draft のまま → 前提が固まっていない
   - キャラ・世界観が少ない、シーンが少ない、シーンはあるが output が無い、など
   - `workshop/ideas.md` に溜まっている未処理のアイデア
   - 各ファイルの `## 未確定の点` と STATUS.md の既存の「未解決の問い」
   - `story/threads.md` の伏線: 状態 open の数と、回収予定のシーンが既に確定（status: fixed）しているのに open のままのもの
3. STATUS.md を更新する
   - `最終更新:` を今日に
   - `## 進捗` の表を集計結果で置き換える
   - `## 未解決の問い` を整理する（解決済みは消し、新しいものを足す）。回収予定を過ぎた伏線はここに ID 付きで挙げる
   - `## 次にやること` に、具体的なコマンド付きで 3 つ以内の候補を書く（例: `/develop 主人公の恐れ`）
4. 変更点を短く報告する
