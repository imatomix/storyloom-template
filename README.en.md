# storyloom-template

[日本語](README.md)

A template for writing stories — films, novels, and manga — together with AI ([Claude Code](https://docs.claude.com/en/docs/claude-code/overview)).
The author leads; Claude asks questions, proposes options, catches contradictions, and drafts. There is no code: just Markdown files plus Claude Code skills and a hook.

> The commands, templates, and examples are written in Japanese, and Claude will converse in Japanese by default. You can ask Claude to translate `CLAUDE.md` and the skills if you want to work in another language.

## Features

- **The author decides.** Claude offers two or three options and digs in with questions. Settled facts (the *canon*) are only changed when the author approves, and a hook enforces this mechanically.
- **One outline, three media.** Medium-independent scene outlines can be turned into a screenplay (with a shot list), novel prose, or a manga name (storyboard script).
- **Holds together over long works.** Each time the author finalizes a manuscript, the template updates each character's current state, a foreshadowing ledger, and one-line scene summaries. `/check` finds contradictions and unresolved setups.
- **Readable examples.** `examples/` includes the novel version of an in-progress short story, "Until the Lights Go Out" (消灯の日まで). This story was created by AI (Claude) during the template's QA process; no human wrote any part of it, including the author's side of the conversation.

## Getting started

1. Create your own repository with **Use this template** on GitHub, or clone it:
   ```bash
   git clone https://github.com/imatomix/storyloom-template.git my-story && cd my-story
   rm -rf .git docs/superpowers && git init   # drop the template's history and development docs if you don't need them
   ```
2. Start Claude Code and run `/kickoff`.
3. See `examples/` for reference (delete it whenever you like):
   - `kaze-no-tegami/` — a short piece showing how to fill in each file
   - `shoutou-no-hi/` — a work in progress showing how state, foreshadowing, and finalizing work over several scenes

Requirements: Claude Code and jq (used by the canon guard hook; bundled with macOS 15 and later. Without jq, every write asks for confirmation).

## How files are organized

Files are separated by how settled they are.

| Folder | Meaning | Does Claude write here? |
|---|---|---|
| `canon/` | Canon: settled facts | Only through `/canonize`, with the author's approval |
| `story/` | Story outline (medium-independent) | When asked, and via `/develop` and `/finalize` |
| `workshop/` | Workspace: ideas, discussions, rejected ideas, research | Freely |
| `output/` | Manuscripts per medium | Via `/draft`; `/finalize` only changes their status |
| `examples/` | Examples | Never (reference only) |

## Commands

| Command | Purpose |
|---|---|
| `/kickoff` | Decide the premise (genre, theme, logline, …) |
| `/brainstorm [topic]` | Widen ideas through questions and options |
| `/develop <target>` | Dig into one character, world topic, location, scene, or structure and draft it |
| `/canonize <file or idea>` | Promote a draft to canon (review the diff and approve) |
| `/check [scope]` | List contradictions with canon and unresolved foreshadowing |
| `/draft <film\|novel\|manga> <scene>` | Write a scene as a screenplay, prose, or manga name |
| `/finalize <scene>` | Finalize an edited manuscript and update the scene summary, character state, and foreshadowing ledger |
| `/revise <scene>` | Measure prose style (sentence length, endings, paragraphs) and revise it against the work's style rules and sample |
| `/status` | Summarize progress in STATUS.md and suggest next steps |

`/kickoff`, `/canonize`, and `/finalize` run only when the author invokes them.

Typical flow (order is not fixed):

```
/kickoff → /brainstorm → /develop → /canonize → (build story/) → /draft → (author edits) → /finalize → /check → /status
```

## Adjusting prose style

Novel style is set in `output/novel/README.md`: style rules (point of view, tense, sentence length, sentence endings, paragraph length, descriptive density, dialogue ratio) and a style sample. `/draft` and `/revise` follow the sample over the rules. `/revise` measures the manuscript with Python 3 (falls back to reading without numbers), proposes before/after edits, and applies only the ones you approve.

## Canon guard

Whenever Claude edits or writes a file under `canon/`, a hook (`.claude/hooks/guard-canon.sh`) asks for confirmation, even in auto-accept modes.
Known limitation: writes through Bash commands are not covered by the hook (CLAUDE.md tells Claude not to do this).

## Testing the template

```bash
bash tests/validate-template.sh
```

## About the examples

Both works in `examples/` were created by AI (Claude); there is no human author.

- `kaze-no-tegami/` — written by Claude as a reference while building the template
- `shoutou-no-hi/` — created during QA: Claude played the author and answered the questions, and a separate Claude Code session ran the commands in response

## Repository layout

| Path | Contents |
|---|---|
| `CLAUDE.md` | Rules for Claude's behavior |
| `.claude/skills/` | Commands (skills) |
| `.claude/agents/` | Subagent for continuity checks |
| `.claude/hooks/` | Canon guard hook |
| `canon/`, `story/`, `workshop/`, `output/` | Your work's files (templates) |
| `examples/` | Examples |
| `tests/` | Structure checks and hook tests |
| `docs/superpowers/` | Design docs and implementation plans for the template itself (development record). Not needed for writing; delete freely |

## License

[MIT](LICENSE) (including the examples)
