# Mega-SDD Architecture Overview

This document is the durable architecture record. For implementation details, see `plugins/mega-sdd/` directly. For design rationale, see `docs/superpowers/specs/2026-05-13-mega-sdd-revamp-design.md`.

## The 4-layer model

**Intent → Bind → Unit → Bolt** (Bind is brownfield-only)

Each layer has a different audience, different anti-hallucination rails, and different artifacts. They compose into a single pipeline.

## Layer 1 — Intent

- **Audience:** Architects, product engineers
- **Input:** PRD, BRD, Figma, or free-text brief
- **Output:** 4-file layout-2 vault (`vault.md` / `model.md` / `flows.md` / `constraints.md`) + `vault.json` (legacy 7-file vaults are still read)
- **Repo access:** Not required
- **Rails:** Open Question promotion, source citation, halt-on-ambiguity

## Layer 2 — Bind (brownfield only)

- **Audience:** Dev / AI with repo read-only access
- **Input:** vault + codebase-map.md
- **Output:** bound-vault + binding.md
- **Repo access:** Read-only
- **Rails:** BLOCKING on conflicts, no auto-resolution, human-in-the-loop

## Layer 3 — Unit

- **Audience:** Dev / AI building the dispatch list for code execution
- **Input:** bound-vault (brownfield) or vault (greenfield)
- **Output:** units/U-*.md with dependency graph
- **Repo access:** Read-only
- **Rails:** target_files whitelist, mandatory acceptance test, atomicity (1 unit = 1 PR-sized commit)

## Layer 4 — Bolt

- **Audience:** AI agent with write access
- **Input:** unit spec
- **Output:** code commits + bolt-report.md
- **Repo access:** Write
- **Rails:** TDD via superpowers, target_files enforcement, halt-on-failure after max retries

## Superpowers integration

Bolt phase routes through [superpowers](https://github.com/obra/superpowers) skills:
- `executing-plans` — implementation step runner
- `subagent-driven-development` — parallel unit execution
- `test-driven-development` — acceptance test discipline
- `using-git-worktrees` — isolation per parallel bolt

The pipeline is self-contained: the first-class agents in `plugins/mega-sdd/agents/` encode the execution discipline, so no superpowers install (and, since v7.4.0, no vendored copy) is required.

## Anchor + hooks

The `SessionStart` hook detects SDD signals in CWD and injects `using-mega-sdd` anchor skill content, weighted S/M/L (slim anchor for small contexts). The anchor is scoped — it only mandates skill invocation when SDD keywords or signals are present.

Six hook events total, each dispatched DIRECTLY from `hooks/hooks.json` (`bash "${CLAUDE_PLUGIN_ROOT}/hooks/<name>"` — the run-hook.sh dispatcher was deleted in v7.5.0): `SessionStart` (anchor + state notice), `PreToolUse` (the gate aggregator — CONFLICT gate, anti-self-bypass, bolt evidence gates; matcher `Skill|Bash|Edit|Write`), `PostToolUse` (dirty-paths journal + advisory notices; matcher `Write|Edit`), `Stop` (bolt-artifact detection + analyze aggregate + gateway publisher), `UserPromptExpansion` (front-door routing), `UserPromptSubmit` (the `mega-sdd-trace:turn` gateway tag + completion-census sync offer). Everything observability-shaped beyond the gateway tag was removed in v7.3.0; the memory/advisor/slice lanes died in v7.3.0–v7.4.0.

## Pipeline diagram

(See `plugins/mega-sdd/README.md` for the rendered Mermaid diagram.)
