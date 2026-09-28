# Mega-SDD Architecture Overview

This document is the durable architecture record. For implementation details, see `plugins/mega-sdd/` directly. For design rationale, see `docs/superpowers/specs/2026-05-13-mega-sdd-revamp-design.md`; for the current (9.0) shape and why it is this small, see `docs/superpowers/specs/2026-09-27-v9-simplification-design.md`.

## The router in front

`/mega-sdd <prd|brief>` runs `scripts/route-lane.sh` first (deterministic, read-only, zero model tokens) and picks one lane from observable signals:

- **direct** — a clear task. The main session builds it like plain Claude Code: no vault, no units, no subagents, no `.mega-sdd/` writes.
- **assisted** — open business items, a security surface, a multi-flow product, or an existing app. Direct + ONE batched ask before coding + ONE blind review.
- **guarded** — an existing vault, or `--guarded` (`--lite` implies it). The spec pipeline below.

Procedure for the first two: `plugins/mega-sdd/references/direct-lane.md`. Every lane ends with the same **result contract**: an acceptance-criterion → test table, `scripts/delivery-check.sh` `VERDICT: PASS` on the final commit, and the list of assumptions and decisions made.

Measured, not claimed: the routed lanes are on par with vanilla Claude Code on greenfield (`research/2026-09-27-lane-router-results.md`); the guarded pipeline surfaced the same seeded spec traps as vanilla at ~6× the cost (`research/2026-09-27-brownfield-results.md`). The pipeline's value is traceability and audit artefacts, not code quality.

## The 4-layer model (guarded lane)

**Intent → Bind → Unit → Bolt** — ONE pipeline, `plan` → `execute-bolts` → `delivery-check.sh`. `plan` writes Intent and Unit in one phase; Bind runs just-in-time per unit inside the Bolt phase. (The classic chain `generate-intent → scan-codebase → bind-codebase → generate-units` and the scan-first classic spine were removed in 9.0.)

Each layer has a different audience, different anti-hallucination rails, and different artifacts. They compose into a single pipeline.

## Layer 1 — Intent

- **Audience:** Architects, product engineers
- **Input:** PRD, BRD, Figma; a seed PRD the front door writes from a brief under `--guarded`; or an `extract-intelligence` knowledge base (`plan --kb=<kb>`)
- **Output:** layout-3 vault written by `plan`: `context.md` + `constitution.md` + `vault.json`. Pre-9.0 layout-2 vaults (`vault.md` / `model.md` / `flows.md` / `constraints.md`) and legacy 7-file vaults are read-only; building on one takes `migrate-paths --vault-layout=3` first
- **Repo access:** Not required (brownfield: the GROUND symbol index, read-only)
- **Rails:** Open Question promotion, source citation, halt-on-ambiguity, the plan-coverage rail (`validate-plan-coverage.sh` — a PRD heading with no unit, no open OQ carrying `[covers: …]` and no `## Coverage exclusions` line halts)

## Layer 2 — Bind (just-in-time, per unit)

- **Audience:** Dev / AI with repo read-only access
- **Input:** the unit's `target_files` / `## Anchors` / `## Claims` + the GROUND symbol index (`.mega-sdd/codebase/symbol-index.json`)
- **Output:** `bolts/U-XXX/binding.json`, written at `execute-bolts` pre-flight 3.9 (`derive-unit-claims.sh` → `write-unit-binding.sh`, the sole writer → `validate-handoff-binding-units.sh`). Whole-vault audit: `/mega-sdd:sync --full-bind` (`rebind-units.sh --units=all`)
- **Repo access:** Read-only
- **Rails:** BLOCKING on conflicts (a CONFLICT closes that unit's gate at dispatch), no auto-resolution, human-in-the-loop (`resolve-oq --binding`); verdicts are script-written, never hand-written

## Layer 3 — Unit

- **Audience:** Dev / AI building the dispatch list for code execution
- **Input:** the source (PRD / KB) + `context.md`, in the same `plan` phase
- **Output:** units/U-*.md with dependency graph, each citing `prd_source` + `context_source`
- **Repo access:** Read-only
- **Rails:** target_files whitelist, mandatory acceptance test, atomicity (1 unit = 1 PR-sized commit), claims are contracts, never verdicts

## Layer 4 — Bolt

- **Audience:** AI agent with write access
- **Input:** unit spec
- **Output:** code commits + bolt-report.md; after the last unit, `delivery-check.sh` on a fresh checkout of HEAD
- **Repo access:** Write
- **Rails:** TDD (superpowers optional), target_files enforcement, halt-on-failure after max retries, the result contract

## Superpowers integration

Bolt phase runs inline in one context and closes with one blind review of the whole range (`skills/execute-bolts/references/inline-run.md`; the per-unit agents were removed in P3). [superpowers](https://github.com/obra/superpowers) TDD skills are an optional technique when installed (`skills/execute-bolts/references/superpowers-bridge.md`).

The pipeline is self-contained: the first-class agents in `plugins/mega-sdd/agents/` encode the execution discipline, so no superpowers install (and, since v7.4.0, no vendored copy) is required.

## Anchor + hooks

The `SessionStart` hook detects SDD signals in CWD and injects `using-mega-sdd` anchor skill content, weighted S/M/L (slim anchor for small contexts). The anchor is scoped — it only mandates skill invocation when SDD keywords or signals are present.

Six hook events total, each dispatched DIRECTLY from `hooks/hooks.json` (`bash "${CLAUDE_PLUGIN_ROOT}/hooks/<name>"` — the run-hook.sh dispatcher was deleted in v7.5.0): `SessionStart` (anchor + state notice, plus the `mega-sdd-note:` session line on gateway-routed sessions), `PreToolUse` (the gate aggregator — CONFLICT gate, anti-self-bypass, bolt evidence gates; matcher `Skill|Bash|Edit|Write`), `PostToolUse` (dirty-paths journal + advisory notices; matcher `Write|Edit`), `Stop` (bolt-artifact detection + analyze aggregate + gateway publisher), `UserPromptExpansion` (front-door routing), `UserPromptSubmit` (the `mega-sdd-trace:turn` gateway tag + completion-census sync offer). Everything observability-shaped beyond the gateway tag and session line was removed in v7.3.0; the memory/phase-advisor/slice lanes died in v7.3.0–v7.4.0.

## Pipeline diagram

(See `plugins/mega-sdd/README.md` for the rendered Mermaid diagram.)
