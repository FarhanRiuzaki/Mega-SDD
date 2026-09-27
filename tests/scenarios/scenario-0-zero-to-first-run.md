# Scenario 0 — Zero to First Run

**Time**: ~20 minutes
**Goal**: Go from "I've never installed Claude Code" to your first successful mega-sdd run.

This scenario assumes **nothing**. If you've never opened Claude Code — or never used an AI coding tool at all — start here. If Claude Code is already installed and working, skip to [Scenario 1](scenario-1-greenfield-from-idea.md).

Your first run takes the **direct lane**: `/mega-sdd` routes a clear task to plain Claude Code behaviour (no spec vault, no subagents) and ends with a delivery check. The spec pipeline is opt-in (`--guarded`) — Scenario 1 shows both.

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
/plugin marketplace add FarhanRiuzaki/Mega-SDD
/plugin install mega-sdd
/plugin install superpowers@claude-plugins-official
```

(`superpowers` is an optional companion plugin that adds TDD discipline to code execution — recommended, not required. It lives in the official Anthropic marketplace, which Claude Code already knows, so no extra `marketplace add` is needed.)

Then restart the session so the new commands register: exit (`Ctrl+C` twice), run `claude` again — or just type `/reload-plugins` if your version supports it.

## Step 4 — Verify the install

In the Claude Code session, type:

```
/mega-sdd:
```

You should see `/mega-sdd:sync`, `/mega-sdd:emit`, and the three one-timers. The bare `/mega-sdd` front door is installed by the SessionStart hook on your first session — before that, use `/mega-sdd:mega-sdd`. If nothing appears, restart Claude Code once more, then run `/plugin marketplace update mega-sdd`.

Optional (recommended later, skippable now): `/mega-sdd:install-deps` installs native helper tools (`ast-grep`, `pandoc`, …). Mega-sdd works fine without them — every tool has a graceful fallback.

## Step 5 — Your first run

Still inside the Claude Code session, in your empty practice folder:

```
/mega-sdd "build a small task-list API — create a task, list tasks, mark a task complete"
```

What you'll see, in order:

1. **One lane line, no confirmation prompt.** Mega-sdd first runs a router script over your request and the folder. Nothing here needs a human decision, so it picks the direct lane:
   ```
   lane: direct (signals: none) · naik ke pipeline: /mega-sdd "build a small task-list API …" --guarded `mega-sdd-trace:direct`
   ```
   (The trailing `mega-sdd-trace:direct` is a fixed tag for the gateway log; ignore it.)
2. **Claude builds it in this session**, like plain Claude Code would. Your sentence doesn't name a language or framework, so Claude picks the simplest option that is easy to change later, and lists that choice as an assumption at the end.
3. **Code + tests + commits.** Every requirement gets at least one automated test, run through the project's standard test command.
4. **The delivery check.** After the last commit, `scripts/delivery-check.sh` runs on a fresh copy of that commit: test script present, tests pass under two time zones, build passes with no local `.env`. Claude fixes any `FAIL` and re-runs it until it prints `VERDICT: PASS`. (It checks Node projects; on another stack it prints `SKIP` and Claude runs that stack's own test and build commands.)
5. **A short report — the result contract.** Every mega-sdd lane ends with the same three things:
   ```
   | Criterion                         | Status | Test                              |
   |-----------------------------------|--------|-----------------------------------|
   | create a task                     | ✓      | test/tasks.test.js › creates…     |
   | list tasks                        | ✓      | test/tasks.test.js › lists…       |
   | mark a task complete              | ✓      | test/tasks.test.js › completes…   |

   delivery-check: VERDICT: PASS
   Assumptions & decisions: Node + Express (brief names no stack); in-memory store (no persistence asked for) …
   Commits: 2
   ```
   (Illustrative — your file names and choices will differ.)

Nothing is written under `.mega-sdd/` on this lane. If the router had seen open items (an "Open questions" list, `TBD`, `??` …), a security surface (login, payments, roles…) or several user flows, it would have picked **assisted**: the same flow plus ONE batched question round before coding and ONE blind review after. The lane line names the signals that fired.

## What just happened — the vocabulary

| Term | Plain meaning |
|---|---|
| **PRD** | A requirements document — "what we want built". Mega-sdd accepts one, or just a sentence. |
| **Lane** | How much process a request gets: **direct** (plain Claude Code), **assisted** (+ one question round + one blind review), **guarded** (the spec pipeline). The router picks; `--direct` / `--assisted` / `--guarded` override it. |
| **Delivery check** | `scripts/delivery-check.sh` — the reviewer's-eye check on a fresh copy of your last commit. A run is done only at `VERDICT: PASS`. |
| **Result contract** | What every lane hands back: acceptance criterion → test table, the delivery-check verdict, the assumptions and decisions made. |
| **Vault** | *(guarded lane)* The structured spec written from your PRD/idea, every claim cited to its source. |
| **Open Question (OQ)** | Anything the spec can't prove becomes a question for you — never a silent guess. |
| **Unit** | *(guarded)* One small, well-defined task — about one pull request of work. |
| **Binding** | *(guarded)* Just before a unit runs, its claims about your *existing* code are checked against the code. A contradiction (CONFLICT) stops that unit until a human decides. |
| **Bolt** | *(guarded)* An executed unit: code + passing tests, committed to git. |
| **Halt** | *(guarded)* A deliberate pause when something genuinely needs a human. Resume with `/mega-sdd --resume`. |

## Where to go next

- **[Scenario 1 — Greenfield from idea](scenario-1-greenfield-from-idea.md)** (15–30 min) — the same flow on a realistic example, then the same idea on the guarded spec pipeline.
- **[Scenario 2 — PRD-driven feature](scenario-2-prd-driven-feature.md)** (30 min) — when you have an actual PRD and an existing codebase (assisted lane).
- The full chooser table: [scenarios README](README.md).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `claude: command not found` in terminal | Open a new terminal window (PATH refresh). Re-run the installer if it persists. |
| `/plugin` or `/mega-sdd:` not recognized in the session | You may be typing into your shell instead of the Claude Code chat — check for the Claude Code prompt. If you're in the session, restart it. |
| `/mega-sdd:` shows no autocomplete after install | Restart Claude Code, then `/plugin marketplace update mega-sdd`. |
| Login loop / auth errors | `claude logout` then `claude` again; check you're using the intended account. |
| Windows issues | Prefer WSL. See the platform table in [`tooling-install.md`](../../plugins/mega-sdd/references/tooling-install.md). |
