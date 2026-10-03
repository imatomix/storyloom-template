# storyloom-template 設計書

日付: 2026-10-03

## 目的

AI（Claude Code）とともに、映像作品・小説・漫画などのストーリーを作り上げていくためのテンプレートリポジトリを作る。

- 形態: コードを持たない、Markdown のファイル構成 + Claude Code の仕組み（CLAUDE.md・スキル・サブエージェント・フック）
- 利用者: まずは作者本人。将来、他者への配布や複数人での共同制作に広げる可能性がある
- 1 リポジトリ = 1 作品（シリーズものも 1 作品として扱う）
- 執筆言語: 日本語

## 基本方針

1. **人間が主導、AI は相棒。** 決定は作者が行う。AI は質問・提案・矛盾検出・下書きを担う。
2. **確定度でファイルを分ける。** 正典（canon）・作業場（workshop）・骨格（story）・成果物（output）を分け、AI が書いてよい範囲をフォルダ構成で明示する。
3. **共通の土台 + 媒体別の出力。** 世界観・キャラ・プロットは全媒体で共通とし、最終出力だけを媒体（film / novel / manga）ごとに分ける。1 つの物語を複数媒体に展開できる。
4. **配布・共同制作への備え（作り込みはしない）。**
   - 個人依存の設定は `.claude/settings.local.json` に置き、テンプレート本体に含めない
   - 各フォルダに短い README を置く
   - 正典の変更は git の差分で追えるようにする

## フォルダ構成

```
storyloom-template/
├── CLAUDE.md              # AI の振る舞いルール
├── README.md              # 使い方（はじめ方・コマンド一覧・作業の流れ・動作確認）
├── STATUS.md              # 現在地：工程ごとの進捗／未解決の問い／次にやること
│
├── canon/                 # 正典（確定した設定）。AI は /canonize 経由でのみ変更
│   ├── README.md
│   ├── premise.md         # ジャンル・テーマ・トーン・ターゲット・ログライン
│   ├── world/             # 世界観（1 トピック 1 ファイル）
│   │   └── _template.md
│   ├── characters/        # キャラ 1 人 1 ファイル
│   │   └── _template.md
│   ├── glossary.md        # 用語集
│   └── timeline.md        # 作中年表
│
├── workshop/              # 作業場。AI が自由に書いてよい
│   ├── README.md
│   ├── ideas.md           # アイデアの受け皿（日付付き追記）
│   ├── sessions/          # 対話ログ・検討メモ（YYYY-MM-DD-topic.md）
│   └── rejected.md        # ボツ案とその理由
│
├── story/                 # 物語の骨格（媒体非依存）。人間が直接編集してよい
│   ├── README.md
│   ├── synopsis.md        # あらすじ（短・中・長）
│   ├── structure.md       # 幕構成・章立て・話数構成
│   └── scenes/            # 1 シーン 1 ファイル
│       └── _template.md
│
├── output/                # 媒体別の成果物
│   ├── README.md
│   ├── film/              # 脚本、絵コンテ用ショット表
│   ├── novel/             # 本文（章ごと）
│   └── manga/             # ネーム（ページ・コマ・台詞・構図メモ）
│
├── examples/              # 小さなサンプル作品の記入例（不要なら削除可）
│
└── .claude/
    ├── settings.json      # canon/ 保護フック
    ├── skills/            # スラッシュコマンド（後述）
    └── agents/            # サブエージェント（後述）
```

### canon と story の区別

- canon: 「何が真実か」（設定）。変更は `/canonize` 経由で、作者の承認が必須。
- story: 「何をどの順で語るか」（構成）。書き直しが多いため、人間が直接編集してよい。AI も `/develop` で書き込める。確定時にはコミットを促す。

### メタ情報（frontmatter）

canon/、story/、output/ の各ファイルは YAML frontmatter を持つ。

```yaml
---
status: draft        # draft | review | fixed
related:             # 関連ファイルへの相対パス
  - canon/characters/hero.md
updated: 2026-10-03
---
```

`/check` と `/status` がこれを利用する。

## スキル（`.claude/skills/<name>/SKILL.md`）

| コマンド | 役割 | 書き込み先 |
|---|---|---|
| `/kickoff` | 新作品の初期設定。質問しながら premise.md と STATUS.md を埋める | canon/premise.md（対話内で承認を取る）、STATUS.md |
| `/brainstorm [テーマ]` | 壁打ち。質問で掘り下げ、案を 3 つ程度出す。決定はしない | workshop/ |
| `/develop <対象>` | キャラ・世界観・シーン等を 1 つ深掘りし下書きを作る | workshop/、story/ |
| `/canonize <ファイル or 案>` | 下書きを正典に昇格。差分を提示し承認後に書き込む。用語集・年表など関連ファイルも更新 | canon/ |
| `/check [範囲]` | story/ と output/ を canon/ と突き合わせ、矛盾をリスト化する。修正はしない | なし（報告のみ） |
| `/draft <媒体> <シーン>` | シーンを媒体別の形式で書く | output/<媒体>/ |
| `/status` | メタ情報を集計して STATUS.md を更新し、次にやることを提案 | STATUS.md |

`/draft` は媒体別の書式ガイドを参照ファイルとして持つ。

- `.claude/skills/draft/references/film.md` — 脚本書式（柱・ト書き・台詞）、ショット表の列定義
- `.claude/skills/draft/references/novel.md` — 本文の書式（視点・章ファイルの分け方）
- `.claude/skills/draft/references/manga.md` — ネーム書式（ページ / コマ / 構図 / 台詞 / 効果音）

## サブエージェント（`.claude/agents/`）

- **continuity-checker**: `/check` の実体。読み取り専用（Read / Grep / Glob のみ）。canon を基準に対象ファイルを読み、矛盾を「該当箇所・正典の記述・矛盾の内容・深刻度」のリストで返す。別コンテキストで動くため、メインの会話に大量のファイルを読み込まない。

媒体別の執筆エージェントは作らない（対話しながら書けるほうが有用なため、`/draft` スキルで扱う）。

## 正典の保護

1. CLAUDE.md に「canon/ は `/canonize` の中で、作者の承認を得た場合のみ編集する」と明記する。
2. 保険として `.claude/settings.json` に PreToolUse フックを設定する。`canon/` 配下への Edit / Write に対して `permissionDecision: "ask"` を返し、毎回作者に確認を求める。

## CLAUDE.md の内容

**姿勢**
- 決めるのは作者。案は可能なら 2〜3 案を理由付きで出し、採否は作者に委ねる
- 曖昧な指示には、書き始める前に質問を 1 つずつする。選択肢付きの質問を優先する
- 作者の文体・作風を尊重する。output/ に既存の本文があれば合わせる

**ファイルの扱い**
- canon/ は `/canonize` 経由でのみ変更する。正典と食い違う内容を書きたくなったら、書かずに作者に指摘する
- 作業前に canon/premise.md と関連する canon ファイルを読む
- ボツになった案は workshop/rejected.md に理由付きで記録する。新しい案を出す前に rejected.md を確認し、同じ案を出さない
- 会話中に出た良いアイデアは workshop/ideas.md に追記してよい（追記したことは作者に伝える）
- frontmatter の書式を守る

**git**
- 正典の変更やシーンの確定のたびにコミットを提案する（自動ではコミットしない）。コミットメッセージは日本語

## 初期状態

- 全ファイルは空の雛形。各ファイルには「何を書く場所か」を短いコメントで示す
- `_template.md` は `/develop` や `/canonize` が新規ファイルを作るときの雛形
- `examples/` に小さなサンプル作品 1 本分の記入例を置く（premise・キャラ 1〜2 人・シーン 1〜2 個・各媒体の draft 例）

## 検証方法

コードがないため、自動テストの代わりに手動のシナリオで確認する。README の「動作確認」として残す。

1. テンプレートをコピーした新しいディレクトリで Claude Code を起動する
2. `/kickoff` → `/brainstorm` → `/develop` → `/canonize` → `/draft novel` → `/check` → `/status` を順に実行する
3. 次を確認する
   - canon/ への書き込み時にフックによる確認が出る
   - 意図的に仕込んだ矛盾を `/check` が検出する
   - STATUS.md が更新される

加えて、フックのスクリプトは canon/ 内外のパスを入力に与えて、期待どおりの判定を返すことをシェルで確認する。

## スコープ外

- Web UI やアプリ
- 画像生成・動画生成との連携
- 複数作品の管理
- 共同制作向けのレビューフロー（担当割り当て等）
