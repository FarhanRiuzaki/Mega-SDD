# Scenario 0 — Zero to First Run

**Time**: ~20 minutes
**Goal**: Go from "I've never installed Claude Code" to your first successful mega-sdd run.

This scenario assumes **nothing**. If you've never opened Claude Code — or never used an AI coding tool at all — start here. If Claude Code is already installed and working, skip to [Scenario 1](scenario-1-greenfield-from-idea.md).

## What you'll need

- A computer running **macOS, Linux, or Windows** (on Windows, WSL is the smoothest path — see the [platform support table](../../plugins/mega-sdd/references/tooling-install.md)).
- A **terminal** (macOS: Terminal.app or iTerm; Windows: WSL/Ubuntu terminal; Linux: any).
- A **Claude account** — either a [Claude Pro/Max subscription](https://claude.com) or a [Claude Console](https://console.anthropic.com) account with API billing. Claude Code will walk you through login on first launch.

No prior AI-tool experience required.

## Step 1 — Install Claude Code

Claude Code is a command-line tool — you install it once, then run it inside any project folder. Follow the official guide if anything below looks different from your setup: **<https://code.claude.com/docs/en/quickstart>**.

macOS / Linux / WSL:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Or, if you already have Node.js 18+:

```bash
npm install -g @anthropic-ai/claude-code
```

Verify it installed:

```bash
claude --version
```

If the command prints a version number, you're good. If you get "command not found", open a new terminal window and try again (the installer updates your PATH, which only takes effect in new shells).

## Step 2 — Start Claude Code and log in

Create a practice folder and launch Claude Code inside it:

```bash
mkdir -p ~/playground/first-run
cd ~/playground/first-run
git init
claude
```

On first launch, Claude Code opens a browser window asking you to log in with your Claude account. Approve it, return to the terminal, and you'll land in an interactive chat session.

**Orientation — the 30-second version:**

- Claude Code is a **chat inside your terminal**. Type plain English ("explain this repo", "fix the failing test") and it works in your project.
- Anything starting with `/` is a **slash command** — a predefined action. Type `/` alone to see the list. `/help` shows the basics.
- Press **Esc** to interrupt Claude mid-task. `Ctrl+C` twice exits the session.

## Step 3 — Install the mega-sdd plugin

> ⚠️ **The most common newcomer mistake**: the commands below are typed **inside the Claude Code chat session** (at the `>` prompt), NOT in your shell. If you type them into bash/zsh, you'll get "command not found".

In your running Claude Code session, type:

```
/plugin marketplace add https://scm.bankmegadev.com/ai-rnd/mega-sdd.git
/plugin install mega-sdd
/plugin install superpowers
```

(`superpowers` is an optional companion plugin that adds TDD discipline to code execution — recommended, not required.)

Then restart the session so the new commands register: exit (`Ctrl+C` twice), run `claude` again — or just type `/reload-plugins` if your version supports it.

## Step 4 — Verify the install

In the Claude Code session, type:

```
/mega-sdd:
```

You should see an autocomplete list with `/mega-sdd` at the top plus its companion verbs (`/mega-sdd:sync`, `/mega-sdd:emit`). If nothing appears, restart Claude Code once more, then run `/plugin marketplace update mega-sdd`.

Optional (recommended later, skippable now): `/mega-sdd:install-deps` installs native helper tools (`tree-sitter`, `ast-grep`, `ripgrep`, …) for higher precision. Mega-sdd works fine without them — every tool has a graceful fallback.

## Step 5 — Your first run

Still inside the Claude Code session, in your empty practice folder:

```
/mega-sdd "build a simple todo API — create a task, list tasks, mark a task complete"
```

What you'll see, in order:

1. **A chain proposal** — mega-sdd detects your input is a free-text idea on an empty project and proposes its plan (generate spec → break into tasks → write code). It asks you to confirm **once**, then runs.
2. **A spec being built** — mega-sdd first writes your idea into a structured spec (the *vault*) instead of jumping straight to code. Anything it isn't sure about becomes an **Open Question** it asks you — it never guesses.
3. **Work units** — the spec gets broken into small, reviewable tasks (each about the size of one pull request).
4. **Code + tests + commits** — each unit is implemented with tests and committed to git automatically.

If it pauses mid-run, that's a **halt** — a deliberate safety stop, not a crash. It tells you exactly what it needs (usually an answer from you) and how to continue (`/mega-sdd --resume`).

## What just happened — the vocabulary

| Term | Plain meaning |
|---|---|
| **PRD** | A requirements document — "what we want built". Mega-sdd accepts one, or just a sentence. |
| **Vault** | The structured spec mega-sdd writes from your PRD/idea, with every claim cited to its source. |
| **Open Question (OQ)** | Anything the spec can't prove becomes a question for you — never a silent guess. |
| **Binding** | (Brownfield only) Checking the spec against your *real* code before generating tasks. |
| **Unit** | One small, well-defined task — about one pull request of work. |
| **Bolt** | An executed unit: code + passing tests, committed to git. |
| **Halt** | A deliberate pause when something genuinely needs a human. Resume with `--resume`. |

## Where to go next

- **[Scenario 1 — Greenfield from idea](scenario-1-greenfield-from-idea.md)** (15 min) — the same flow on a realistic example, with expected outputs at every phase.
- **[Scenario 2 — PRD-driven feature](scenario-2-prd-driven-feature.md)** (30 min) — when you have an actual PRD and an existing codebase.
- The full chooser table: [scenarios README](README.md).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `claude: command not found` in terminal | Open a new terminal window (PATH refresh). Re-run the installer if it persists. |
| `/plugin` or `/mega-sdd:` not recognized in the session | You may be typing into your shell instead of the Claude Code chat — check for the Claude Code prompt. If you're in the session, restart it. |
| `/mega-sdd:` shows no autocomplete after install | Restart Claude Code, then `/plugin marketplace update mega-sdd`. |
| Login loop / auth errors | `claude logout` then `claude` again; check you're using the intended account. |
| Windows issues | Prefer WSL. See the platform table in [`tooling-install.md`](../../plugins/mega-sdd/references/tooling-install.md). |
