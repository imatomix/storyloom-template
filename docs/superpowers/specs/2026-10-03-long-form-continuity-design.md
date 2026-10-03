# 長編の一貫性強化 設計書

日付: 2026-10-03
前提: `docs/superpowers/specs/2026-10-03-storyloom-template-design.md`（基本設計）

## 目的

長い作品でも設定・状態・伏線の一貫性を保てるようにする。Dramatron（google-deepmind/dramatron）と AI_NovelGenerator（YILING0013/AI_NovelGenerator）との比較から、次を取り入れる。

- AI_NovelGenerator の「定稿」: 作者が確定した原稿を起点に、要約とキャラの現在の状態を更新する
- AI_NovelGenerator の `plot_arcs` と章立ての項目（伏線操作・引き）: 伏線台帳とシーン設計欄
- AI_NovelGenerator の下書き時コンテキスト（直近の要約・前章末尾・次章情報）: `/draft` の読み込み範囲
- Dramatron の「場所」生成段階: 場所の正典化
- 取材資料、構成の型の参考資料、タスク別モデル指定

取り入れないもの: ベクトル検索（1 行あらすじと Grep で代替）、全自動生成パイプライン、数値閾値による制約。

## 基本方針

- 状態の更新は作者が確定した原稿を起点に行う（`/finalize`）。AI の下書きの時点では更新しない
- 物語の進行で変わる記録（状態・伏線）は `story/` に置く。正典（`canon/`）は変わらない設定のまま

## 追加ファイル

| パス | 内容 |
|---|---|
| `story/state.md` | キャラの現在の状態。キャラごとに「最後に更新したシーン・居場所・知っていること・持ち物・体の状態・関係の変化」 |
| `story/threads.md` | 伏線台帳。列: ID（T01…）／種類（伏線・問い）／内容／張ったシーン／回収予定／回収したシーン／状態（open・closed・dropped） |
| `canon/locations/_template.md` | 場所の雛形。見た目／音と匂い／光・時間帯による変化／間取りと動線／ここで起きたシーン |
| `workshop/research/.gitkeep` | 取材資料の置き場 |
| `.claude/skills/develop/references/structure.md` | 構成の型（三幕構成・起承転結・Save the Cat 15 ビート）の要点と使いどころ |
| `.claude/skills/finalize/SKILL.md` | 確定コマンド |

## シーン雛形の拡張

frontmatter に `summary: ""`（1 行あらすじ。`/finalize` が書く）を追加。本文に次の見出しを追加する。

- `## 伏線` — 張る／回収する（threads.md の ID で記述）
- `## 引き` — 次のシーンへ運ぶ問い
- `## 情報の差` — 読者だけが知ること／キャラだけが知ること
- `## 重要な小道具`
- `## 時間的な制約`
- `## このシーンの後で変わったこと` — `/finalize` が書く

## /finalize <シーン>

- 手動専用（`disable-model-invocation: true`）
- 手順:
  1. シーン骨格・確定対象の原稿・state.md・threads.md を読む。原稿が複数媒体にある場合は基準の媒体を作者に聞く
  2. 変更案を一括で提示する: シーンの `summary` と「後で変わったこと」、state.md の差分、threads.md の差分（新規の伏線を追加、回収したものを closed に）
  3. 正典に無い新事実は `/canonize` の候補として示すだけで、canon/ には書かない
  4. 作者の承認後に書き込み、原稿とシーンの status を `fixed` にする。コミットを提案する

## 既存要素の変更

| 対象 | 変更 |
|---|---|
| `/draft` | 追加で読む: state.md、open の伏線、確定済みシーンの `summary` 一覧（Grep）、同じ媒体の直前シーンの原稿末尾、次のシーンの「目的」。書き終えたら触れた伏線を報告する |
| `/develop` | シーン作成時に新しい欄も埋め、新しい伏線を threads.md に open で登録。対象に「場所」を追加（下書きは `workshop/drafts/locations/`）。構成作成時は structure.md を参照 |
| continuity-checker | state.md と threads.md も読む。検出項目を追加: 回収予定を過ぎた open の伏線／張っていない伏線の回収／シーン順に見た状態の矛盾。出力に「伏線」節を追加。frontmatter に `model: sonnet` |
| `/status` | open の伏線数と回収予定を過ぎた伏線を報告 |
| CLAUDE.md・README | コマンド表・フォルダ説明・命名（`canon/locations/<slug>.md`）・モデル指定の変え方 |
| `canon/README.md`・`story/README.md`・`workshop/README.md` | 新しいファイル・フォルダの行を追加 |

## 記入例

「風の手紙」に追加する。

- シーン 010 に新しい欄と `summary`
- `story/state.md`（紬・六郎の 010 終了時点の状態）
- `story/threads.md`（T01「紬が北の空を見上げた理由」問い・open、T02「六郎自身が待つ風便」伏線・open）
- `canon/locations/sakaue-yubinkyoku.md`（坂上郵便局）

## 検査

`tests/validate-template.sh` に以下を追加する。

- 新しい必須ファイル
- `story/scenes/_template.md` に `summary:` があること
- `story/threads.md` に台帳の見出し行があること

## 検証

- 構造検査が通ること
- 記入例を作品本体の位置にコピーし、回収予定を過ぎた open の伏線を仕込んで `/check` が検出すること
- 対話系の `/finalize` は作者の手動確認に委ねる
