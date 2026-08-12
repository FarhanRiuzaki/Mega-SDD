# Mega-SDD User Scenarios

Step-by-step walkthroughs for common mega-sdd use cases. Use these if you're **new to mega-sdd** and want a guided first experience.

Each scenario:
- Takes 5-30 minutes wall-clock
- Includes sample inputs you can copy-paste
- Shows expected outputs at each phase
- Covers common pitfalls + recovery paths

## Quick chooser — which scenario fits you?

| Your situation | Scenario | Time |
|---|---|---|
| **Never installed Claude Code at all** | [Scenario 0 — Zero to first run](scenario-0-zero-to-first-run.md) | 20 min |
| First time trying mega-sdd; want minimum viable run | [Scenario 1 — Greenfield from idea](scenario-1-greenfield-from-idea.md) | 15 min |
| Have a PRD; existing project | [Scenario 2 — PRD-driven feature](scenario-2-prd-driven-feature.md) | 30 min |
| Field-level gap (PRD says X, code has Y) | [Scenario 3 — Field-level extension](scenario-3-field-extension.md) | 20 min |
| Legacy codebase → modern rebuild (single phase) | [Scenario 4 — Legacy rebuild](scenario-4-legacy-rebuild.md) | 4 hr |
| Multi-team coordination | [Scenario 5 — Multi-squad parallel](scenario-5-multi-squad-parallel.md) | 45 min |
| Something halted; need to recover | [Scenario 6 — Recovery from halt](scenario-6-recovery-from-halt.md) | 15 min |
| Multi-architect (BE/FE/MW shared PRD) | [Scenario 7 — Multi-architect](scenario-7-multi-architect.md) | 60 min |
| Starterkit-aware generation (auto-detected stack) | [Scenario 8 — Starterkit-aware generation](scenario-8-starterkit-aware-generation.md) | 30 min |
| End-to-end intelligence layer test | [Scenario 9 — Flawless seamless intelligence](scenario-9-flawless-seamless-intelligence.md) | 30-40 min |
| **Legacy rebuild with phased plan (multi-phase)** | **[Scenario 10 — Phased rebuild walkthrough](scenario-10-phased-rebuild-walkthrough.md)** | **~3 hr** |
| **Model tier override (cost/quality control)** | **[Scenario 11 — Model tier override](scenario-11-model-tier-override.md)** | **~5 min** |
| **Code changed after "done" — continuous sync** | **[Scenario 12 — Continuous sync](scenario-12-continuous-sync.md)** | **~10 min** |
| Upgrading from older mega-sdd | (not a scenario) See `plugins/mega-sdd/references/upgrade-from-old-version.md` | — |

## Before you start — install check

**Step 0 — never used Claude Code itself?** Mega-sdd runs inside [Claude Code](https://claude.com/claude-code), Anthropic's terminal AI coding agent. If you haven't installed or tried it, follow [Scenario 0 — Zero to first run](scenario-0-zero-to-first-run.md) first — it covers installing Claude Code, logging in, and your first mega-sdd run with nothing assumed.

> **Note**: every command starting with `/` (like `/plugin …` or `/mega-sdd:…`) is typed **inside the Claude Code chat session**, not in your shell. Commands shown in `bash` blocks without a leading `/` run in your normal terminal.

All scenarios assume mega-sdd is installed — canonical install steps: [root README — Quick start](../../README.md#quick-start-5-minutes).

For higher precision (recommended, optional), run `/mega-sdd:install-deps` inside Claude Code — it detects your OS + package manager and installs the native tools with safety rails. Manual per-platform one-liners: [`tooling-install.md`](../../plugins/mega-sdd/references/tooling-install.md). Mega-sdd works WITHOUT these tools (graceful fallbacks).

## Verification — is mega-sdd ready?

In your Claude Code session, type:

```
/mega-sdd:
```

You should see autocomplete with `/mega-sdd:sync`, `/mega-sdd:emit`, `/mega-sdd:slice` (6.8.0+), and the four maintenance one-timers (`install-deps`, `update-plugin`, `memory`, `migrate-paths`) — the surface is exactly these plus the bare `/mega-sdd` front door (the SessionStart hook installs its wrapper on your first session; before that, `/mega-sdd:mega-sdd` works). If NOTHING autocompletes, restart the Claude Code session OR run `/plugin marketplace update`.

## The ONE command (most users)

```bash
/mega-sdd ./your-prd.md
```

Replace `./your-prd.md` with your input. Mega-sdd detects:
- **PRD file** (`.md`, `.pdf`, `.docx`) → vault generation
- **Legacy code directory** → extract-intelligence first, then vault
- **Existing vault directory** → skip ahead to binding/units/bolts
- **Quoted brief** (`"build a clinic system"`) → free-text Mode B
- **Empty input** → inspects CWD, proposes chain

Single upfront confirmation; then runs end-to-end. Halts on real issues (conflicts, missing OQs); auto-continues otherwise.

## What about all the other stages?

Most users never invoke them directly. They're auto-invoked by the `/mega-sdd` chain, and since 6.0.0 the per-stage typed commands no longer register — ask by phrase instead (a typed legacy form still arrives as plain text and routes to the same skill):

- Phase skills (chain-run): `generate-intent`, `scan-codebase` (on-demand), `bind-codebase`, `generate-units`, `execute-bolts`
- Event-driven: "resolve OQ", "PRD revisi" (diff-vault), "cek drift"
- Diagnostics (auto-run on classic; on-demand otherwise): "lint units", "cek parallelism", "status module", "generate AGENTS.md"
- Maintenance verbs (still typed): `/mega-sdd:memory`, `/mega-sdd:migrate-paths` — plus "migrate hard rules" by phrase

Full migration map: [plugin README §Commands](../../plugins/mega-sdd/README.md#commands-youll-actually-use).

## If something goes wrong

1. **Pipeline halts mid-chain** → mega-sdd surfaces a YAML blocker with `next_action` field telling you exactly what to run. Resolve, then `/mega-sdd --resume`.
2. **Confused about state** → say "status module" (the list-modules rollup) or just run `/mega-sdd` with no args for the state view.
3. **Bolt fails** → check `<vault>/bolts/U-XXX/bolt-report.md` for details. Often acceptance test needs adjustment.
4. **Want to undo** → bolts produce atomic git commits; `git revert <commit>` rolls back a unit.

For recovery scenarios, see [Scenario 6](scenario-6-recovery-from-halt.md).

## Feedback + questions

Scenario walkthroughs written before 6.0.0 may show `/mega-sdd:<stage>` typed forms — those still route as plain text, but the registered commands are only the 4 verbs + 4 one-timers. If steps don't match your behavior:
1. Check your installed version: type `/plugin` in Claude Code (works in any project)
2. Update plugin: `/mega-sdd:update-plugin`
3. Report mismatches with concrete steps reproduced

These scenarios are tested against the sample PRD at [`sample-prd-clinic.md`](sample-prd-clinic.md). Use that for first-run to match expected outputs exactly.
