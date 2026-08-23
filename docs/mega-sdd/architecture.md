# Mega-SDD Architecture Overview

This document is the durable architecture record. For implementation details, see `plugins/mega-sdd/` directly. For design rationale, see `docs/superpowers/specs/2026-05-13-mega-sdd-revamp-design.md`.

## The 3-layer model

**Intent → Unit → Bolt**

Each layer has a different audience, different anti-hallucination rails, and different artifacts. They compose into a single pipeline.

## Layer 1 — Intent

- **Audience:** Architects, product engineers
- **Input:** PRD, BRD, Figma, or free-text brief
- **Output:** 7-file vault + vault.json
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

## Anchor + hook

`SessionStart` hook detects SDD signals in CWD and injects `using-mega-sdd` anchor skill content. Anchor is scoped — only mandates skill invocation when SDD keywords or signals present.

## Pipeline diagram

(See `plugins/mega-sdd/README.md` for the rendered Mermaid diagram.)
