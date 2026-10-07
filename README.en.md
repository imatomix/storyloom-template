# storyloom-template

[日本語](README.md)

**Not a template for making AI write your story. A workspace that keeps AI from breaking the story you write with it.**

A template for writing films, novels, and manga with [Claude Code](https://docs.claude.com/en/docs/claude-code/overview). There is no code: just Markdown files plus Claude Code skills and a hook.

> The commands, templates, and examples are written in Japanese, and Claude will converse in Japanese by default. You can ask Claude to translate `CLAUDE.md` and the skills if you want to work in another language.

## Why

When you work on a long story with AI:

- It forgets settings you decided earlier
- Settings quietly change
- Scenes contradict each other (a character holds an item they lost two scenes ago)
- It decides things the author should decide

## How it prevents that

- **Files are separated by how settled they are.** Settled facts go in `canon/`, the story outline in `story/`, ideas under consideration in `workshop/`, manuscripts in `output/`.
- **Only the author can settle things.** The canon changes only when the author approves it through `/canonize`. A hook asks for confirmation every time Claude tries to write there.
- **State and foreshadowing are tracked, and contradictions are found.** Each time a manuscript is finalized (`/finalize`), character state and the foreshadowing ledger are updated. `/check` lists contradictions in settings and timeline, and unresolved setups.
- **The author decides.** Claude asks questions and offers two or three options. The author chooses.
- **Your work is a Git repository.** You can trace when and how the canon changed.

## What else it does

- **Scene design, then three media.** Decide with the author how each part of a scene is shown, then write it as a screenplay, novel prose, or a manga text storyboard.
- **Prose style tuning.** Measure novel prose and revise it toward the author's style rules and sample (`/revise`).
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

Requirements: Claude Code and jq (used by the canon guard hook; bundled with macOS 15 and later. Without jq, every write asks for confirmation). With Python 3, `/revise` measures prose style numerically (optional).

## How files are organized

Files are separated by how settled they are.

| Folder | Meaning | Does Claude write here? |
|---|---|---|
| `canon/` | Canon: settled facts | Only through `/canonize`, with the author's approval |
| `story/` | Story outline (medium-independent) | When asked, and via `/develop`, `/finalize`, and `/draft` (scene design only) |
| `workshop/` | Workspace: ideas, discussions, rejected ideas, research | Freely |
| `output/` | Manuscripts per medium | Via `/draft`; `/finalize` only changes their status |
| `examples/` | Examples | Never (reference only) |

## Commands

| Command | Purpose |
|---|---|
| `/kickoff` | Decide the premise (genre, theme, logline, …) |
| `/brainstorm [topic]` | Widen ideas through questions and options |
| `/develop <target>` | Dig into one character, world topic, location, scene, or structure and draft it |
| `/interview <character> [scene]` | Answer the author's questions in character, knowing only what the character knows at that scene. Afterwards, summarize new facts and gaps against canon in workshop/ |
| `/canonize <file or idea>` | Promote a draft to canon (review the diff and approve) |
| `/check [scope]` | List contradictions with canon and unresolved foreshadowing |
| `/draft <film\|novel\|manga> <scene>` | Design the scene, then write it as a screenplay, prose, or a manga text storyboard |
| `/finalize <scene>` | Finalize an edited manuscript and update the scene summary, character state, and foreshadowing ledger |
| `/revise <scene>` | Measure prose style (sentence length, endings, paragraphs) and revise it against the work's style rules and sample |
| `/status` | Summarize progress in STATUS.md and suggest next steps |

`/kickoff`, `/canonize`, and `/finalize` run only when the author invokes them.

Typical flow (order is not fixed):

```
/kickoff → /brainstorm → /develop → /canonize → (build story/) → /draft → (author edits) → /finalize → /check → /status
```

## Tips

Output depth depends on what you give Claude.

- **Avoid "up to you."** Pick from the options or answer concretely, even in a few words.
- **Write the style sample yourself** in `output/novel/README.md`.
- **Decide the scene's showpiece, emotional peak, and one unforgettable detail yourself** in the scene design.
- **Set length targets before drafting** (characters, minutes, pages).

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
