# Mega-SDD User Scenarios

Step-by-step walkthroughs for common mega-sdd use cases. Use these if you're **new to mega-sdd** and want a guided first experience.

Since 9.0, `/mega-sdd <prd|brief>` runs `scripts/route-lane.sh` first and picks a lane:

- **direct** — a clear task: the main session builds it like plain Claude Code (no vault, no units, no subagents). Procedure: [`direct-lane.md`](../../plugins/mega-sdd/references/direct-lane.md).
- **assisted** — open business items, a security surface, several flows, or an existing app: direct + ONE batched ask before coding + ONE blind review.
- **guarded** — an existing vault, or `--guarded` (`--lite` implies it): the one spec pipeline, `plan` (PRD, a seed PRD from a brief, or `plan --kb=<kb>` after `extract-intelligence`) → `execute-bolts` (inline: JIT bind up front + per task, CONFLICT quarantine at run start, one blind review).

Walkthroughs that show a vault, units and bolts are guarded-lane runs. The classic chain (`generate-intent` → `scan-codebase` → `bind-codebase` → `generate-units`) was removed in 9.0: where an older walkthrough names one of those skills, read `plan` (spec + units) or the per-unit bind inside `execute-bolts`.

Every lane ends with the same result: an acceptance-criterion → test table, `scripts/delivery-check.sh` `VERDICT: PASS` on the final commit, and the list of assumptions and decisions made. Measured on greenfield PRDs, the routed lanes are on par with plain Claude Code; on a brownfield PRD the guarded pipeline surfaced the same seeded spec traps as plain Claude Code at ~6× the cost. Its value is traceability and audit artefacts, not better code (commits `d447a6d2`, `5d880e8b`).

Each scenario:
- Takes 5–60 minutes wall-clock (legacy rebuilds vary with the census)
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
| Legacy codebase → modern rebuild (one tranche) | [Scenario 4 — Legacy rebuild](scenario-4-legacy-rebuild.md) · concept guide: [Revamp Journey](../../docs/mega-sdd/revamp-journey.md) | varies (census-scaled) |
| Multi-team coordination (a vault that already carries `_meta/squads.yaml` — `plan` does not author one) | [Scenario 5 — Multi-squad parallel](scenario-5-multi-squad-parallel.md) | 45 min |
| Something halted; need to recover | [Scenario 6 — Recovery from halt](scenario-6-recovery-from-halt.md) | 15 min |
| Multi-architect (BE/FE/MW shared PRD) | [Scenario 7 — Multi-architect](scenario-7-multi-architect.md) | 60 min |
| Starterkit-aware generation (auto-detected stack) | [Scenario 8 — Starterkit-aware generation](scenario-8-starterkit-aware-generation.md) | 30 min |
| **Legacy rebuild landed module-by-module (phased)** | **[Scenario 10 — Phased rebuild walkthrough](scenario-10-phased-rebuild-walkthrough.md)** | **varies (census-scaled)** |
| **Model tier override (cost/quality control)** | **[Scenario 11 — Model tier override](scenario-11-model-tier-override.md)** | **~5 min** |
| **Code changed after "done" — continuous sync** | **[Scenario 12 — Continuous sync](scenario-12-continuous-sync.md)** | **~10 min** |
| Upgrading from older mega-sdd | (not a scenario) See `docs/mega-sdd/upgrade-from-old-version.md` | — |

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

You should see autocomplete with `/mega-sdd:sync`, `/mega-sdd:emit`, and the three maintenance one-timers (`install-deps`, `update-plugin`, `migrate-paths`) — the surface is exactly these plus the bare `/mega-sdd` front door (the SessionStart hook installs its wrapper on your first session; before that, `/mega-sdd:mega-sdd` works). If NOTHING autocompletes, restart the Claude Code session OR run `/plugin marketplace update`.

## The ONE command (most users)

```bash
/mega-sdd ./your-prd.md
```

Replace `./your-prd.md` with your input. Mega-sdd detects:
- **PRD file** (`.md`, `.pdf`, `.docx`) or **quoted brief** (`"build a clinic system"`) → `route-lane.sh` picks the lane; direct/assisted build it straight away (no vault); guarded (`--guarded`) runs `plan` → `execute-bolts` (a brief is first written to a seed PRD)
- **Legacy code directory** → `extract-intelligence` → `plan --kb=<kb>` → `execute-bolts` (needs `--out=<path>`)
- **Knowledge-base directory** (an `extract-intelligence` output) → `plan --kb` → `execute-bolts`
- **Existing vault directory** → a layout-3 vault with units goes to `execute-bolts` (JIT bind per unit); a pre-9.0 layout-2 vault is still read, and to build or sync on it the front door proposes `/mega-sdd:migrate-paths --vault-layout=3` first (then the mandatory re-bind)
- **Empty input** → inspects CWD, proposes chain

Direct/assisted announce the lane in one line and start — no confirmation prompt. Guarded asks ONE upfront confirmation, then runs end-to-end; it halts on real issues (conflicts, open P1 business OQs) and auto-continues otherwise. `--classic` and `lane: standard` are retired: the front door says so in one line and ignores them.

## What about all the other stages?

Most users never invoke them directly. They're auto-invoked by the `/mega-sdd` chain, and since 6.0.0 the per-stage typed commands no longer register — ask by phrase instead (a typed legacy form still arrives as plain text and routes to the same skill):

- Phase skills (guarded chain): `plan` (vault + units), `execute-bolts` (JIT bind per unit + bolts); `extract-intelligence` upstream for a legacy rebuild
- Event-driven: "resolve OQ", "PRD revisi" (diff-vault), "cek drift"
- Diagnostics (on demand; auto-run inside a guarded chain only with `--full`): "lint units", "cek parallelism", "status module", "generate AGENTS.md"
- Maintenance verbs (still typed): `/mega-sdd:migrate-paths`, `/mega-sdd:install-deps`, `/mega-sdd:update-plugin` — plus "migrate hard rules" by phrase

Full migration map: [plugin README §Commands](../../plugins/mega-sdd/README.md#commands-youll-actually-use).

## If something goes wrong

1. **Guarded pipeline halts mid-chain** → mega-sdd surfaces a YAML blocker with `next_action` field telling you exactly what to run. Resolve, then `/mega-sdd --resume`.
2. **Confused about state** → say "status module" (the list-modules rollup) or just run `/mega-sdd` with no args for the state view.
3. **Bolt fails** (guarded) → check `<vault>/bolts/U-XXX/bolt-report.md` for details. Often acceptance test needs adjustment.
4. **`delivery-check.sh` prints `FAIL`** (any lane) → the run is not done: fix the finding, commit, and re-run until `VERDICT: PASS`.
5. **Want to undo** → bolts produce atomic git commits; `git revert <commit>` rolls back a unit.

For recovery scenarios, see [Scenario 6](scenario-6-recovery-from-halt.md).

## Feedback + questions

Scenario walkthroughs written before 6.0.0 may show `/mega-sdd:<stage>` typed forms — those still route as plain text, but the registered commands are only the 3 verbs + 3 one-timers. If steps don't match your behavior:
1. Check your installed version: type `/plugin` in Claude Code (works in any project)
2. Update plugin: `/mega-sdd:update-plugin`
3. Report mismatches with concrete steps reproduced

These scenarios are tested against the sample PRD at [`sample-prd-clinic.md`](sample-prd-clinic.md). Use that for first-run to match expected outputs exactly.
