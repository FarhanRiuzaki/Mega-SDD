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
| Upgrading from older mega-sdd | (not a scenario) See `plugins/mega-sdd/references/upgrade-from-old-version.md` | — |

## Before you start — install check

All scenarios assume mega-sdd is installed:

```bash
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended companion (TDD discipline)
```

For higher precision (recommended):

```bash
brew install tree-sitter ast-grep ripgrep jd
# OR
cargo install tree-sitter-cli ast-grep ripgrep
```

Full install matrix: see [`plugins/mega-sdd/references/tooling-install.md`](../../plugins/mega-sdd/references/tooling-install.md).

Mega-sdd works WITHOUT these tools (graceful fallbacks). Install for better precision + faster iteration.

## Verification — is mega-sdd ready?

In your Claude Code session, type:

```
/mega-sdd:
```

You should see autocomplete with `/mega-sdd:auto` as primary command + other phase commands. If you see "command not found", restart Claude Code session OR run `/plugin marketplace update`.

## The ONE command (most users)

```bash
/mega-sdd:auto ./your-prd.md
```

Replace `./your-prd.md` with your input. Mega-sdd detects:
- **PRD file** (`.md`, `.pdf`, `.docx`) → vault generation
- **Legacy code directory** → extract-intelligence first, then vault
- **Existing vault directory** → skip ahead to binding/units/bolts
- **Quoted brief** (`"build a clinic system"`) → free-text Mode B
- **Empty input** → inspects CWD, proposes chain

Single upfront confirmation; then runs end-to-end. Halts on real issues (conflicts, missing OQs); auto-continues otherwise.

## What about all the other commands?

Most users never type them. They're auto-invoked by `/mega-sdd:auto`. Available for advanced/manual use:

- Phase commands: `generate-intent`, `scan-codebase`, `bind-codebase`, `generate-units`, `execute-bolts`
- Event-driven: `resolve-oq`, `diff-vault`, `detect-drift`
- Diagnostic (auto-invoked): `lint-units`, `analyze-parallelism`, `list-modules`, `emit-agents-md`
- Maintenance: `memory`, `migrate-rules`, `migrate-paths`

Full reference: [`../../README.md`](../../README.md) Advanced commands section.

## If something goes wrong

1. **Pipeline halts mid-chain** → mega-sdd surfaces a YAML blocker with `next_action` field telling you exactly what to run. Resolve, then `/mega-sdd:auto --resume`.
2. **Confused about state** → run `/mega-sdd:list-modules` to see per-module status.
3. **Bolt fails** → check `<vault>/bolts/U-XXX/bolt-report.md` for details. Often acceptance test needs adjustment.
4. **Want to undo** → bolts produce atomic git commits; `git revert <commit>` rolls back a unit.

For recovery scenarios, see [Scenario 6](scenario-6-recovery-from-halt.md).

## Feedback + questions

Scenarios assume mega-sdd v3.8.0+. If steps don't match your behavior:
1. Check version: `cat plugins/mega-sdd/.claude-plugin/plugin.json | grep version`
2. Update plugin: `/mega-sdd:update-plugin`
3. Report mismatches with concrete steps reproduced

These scenarios are tested against the sample PRD at [`sample-prd-clinic.md`](sample-prd-clinic.md). Use that for first-run to match expected outputs exactly.
