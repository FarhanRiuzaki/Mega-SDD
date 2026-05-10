# Flow Orchestrator — v0.14 Agentic Upgrade Design

**Date**: 2026-05-10
**Plugin version target**: v0.14.0
**New skill**: `flow` (lifecycle orchestrator)
**Goal**: Make the plugin agentic (multi-skill orchestration with plan-then-execute UX) without compromising the anti-hallucination invariants that define the project.

---

## Why this design

The plugin today is 4 separate skills + 1 maintenance command. Users have to:

1. Remember which skill to invoke for which lifecycle event (PRD revision → vault-diff; stakeholder meeting → resolve-oq; before sprint review → drift-detect).
2. Sit through ~15 prompts across a full lifecycle round (5 from grand-design-spec, several from each subsequent skill).
3. Manually chain skills in the right order.

The orchestrator collapses that into one slash invocation that inspects state, proposes a plan, executes it.

**Constraints (non-negotiable):**

- **Anti-halu rails preserved.** Every gap → OQ. No auto-answers. No auto-conflict-resolution. Stakeholder authority is absolute.
- **Inspectability before execution.** User sees the proposed chain before any sub-skill runs. No silent multi-skill execution.
- **Stateless.** No `.gds-state.json`. Each `flow` invocation re-inspects CWD; resumption is just re-running.
- **No content invention.** Orchestrator only routes; it never produces vault content directly.

These constraints exist because they're what makes the plugin valuable — losing them produces a faster but less trustworthy tool, which is a worse product.

---

## Skill identity

- **Slash command**: `/grand-design-spec:flow`
- **Skill file**: `plugins/grand-design-spec/skills/flow/SKILL.md`
- **Frontmatter description**: *"Multi-skill lifecycle orchestrator. Inspects CWD, proposes a chain of grand-design-spec sub-skills (generate / resolve-oq / vault-diff / drift-detect), confirms with user once, then executes the chain in --auto mode. Triggers — 'run the flow', 'orchestrate vault lifecycle', 'auto vault', 'do the next thing', or paraphrases."*
- **Arguments**: `[optional: vault-path or PRD-path or 'auto']`
  - `flow` (no args) — auto-detect from CWD.
  - `flow ./timeoff-spec/` — operate on this vault explicitly.
  - `flow PRD-v2.pdf` — bias toward "vault-diff this PRD against the closest vault in CWD."
- **Companion command file**: `plugins/grand-design-spec/commands/flow.md` (slash autocomplete surface)

---

## CWD inspection + decision matrix

The orchestrator's first phase is deterministic state reading — no LLM judgment, just rules.

### Inspection signals

| Signal | How detected | What it tells us |
|--------|--------------|------------------|
| Vault present? | Directory in CWD (or arg) containing all 7 files (`00-index.md` through `06-constraints.md`) | Generate vs evolve |
| `vault.json` present? | File next to the 7 .md files | Pre- or post-v0.11 vault |
| Vault metadata | Parse `00-index.md` Vault Lock Status: `Implementation mode`, `PRD source` filename + version, last `Vault version` | Lifecycle position |
| PRD/source files | PDF/DOCX/MD files in CWD or args. Compare filename/version to vault's `PRD source` | New PRD revision? |
| Codebase signals | `composer.json` / `package.json` / `Gemfile` / `pom.xml` / `Cargo.toml` / etc. in CWD or vault parent | Is `mode=existing` actionable? |
| Unresolved P1 count | `vault.json.open_questions_summary.by_priority.P1` (or grep `[ ] **OQ-...** [P1]` in markdown if vault.json missing) | Resolve-oq needed? |
| Mode migration trigger | `mode_migrate_after` field in vault.json or 00-index | mode=new vault about to flip? |
| Git state | `git log --oneline -1` in CWD; `git status` for dirty | Safety nudges |

### Decision matrix (applied in order)

```
IF no vault AND PRD detected:
    → propose: grand-design-spec (generate)
    → optional chain: resolve-oq (opt-in via plan confirmation, since user may not have stakeholder answers yet)

IF vault exists AND new PRD detected (filename or version differs from vault's PRD source):
    → propose: vault-diff
    → conditional chain: resolve-oq if vault-diff introduces ≥1 new P1 OQ

IF vault exists AND vault.json missing:
    → propose: grand-design-spec re-run with vault's existing flags (regenerates manifest)

IF vault exists AND P1 count > 0 AND no new PRD:
    → propose: resolve-oq (scope=p1-only)

IF vault exists AND mode=existing AND codebase detected:
    → propose: drift-detect
    → conditional chain: resolve-oq if drift findings produce vault-side actions

IF vault exists AND mode=new AND mode_migrate_after trigger has fired
    (heuristic: only "first commit on main" is auto-detectable — check `git log --reverse | head -1`;
     "first prod deploy" and "sprint-1 demo" require human knowledge → ask):
    → propose: vault-diff with mode flip prompt OR manual edit instruction

IF nothing detected (empty CWD, no vault, no PRD):
    → STOP, surface "no vault or PRD found — point me at one"
```

### Chain rules

- **Hard cap**: max 3 skills per chain. Beyond that → surface and ask for explicit confirmation.
- **Conditional chains** only fire when the prior step's output makes the next step meaningful (e.g., `vault-diff` → `resolve-oq` only if new P1 OQs were introduced).
- **Lifecycle order is fixed**: generate → diff → resolve → drift. Never out of order.

---

## Plan format + confirmation UX

### Plan output template

```
grand-design-spec:flow — proposed chain

Detected state:
  • Vault: ./timeoff-spec/ (v1.1, mode=new, output_mode=compact, prd_status=draft)
  • PRD source on file: PRD-v1.pdf (vault was generated from this)
  • New PRD candidate: PRD-v2.pdf (different filename → new revision)
  • vault.json: present (in sync)
  • Unresolved P1 OQs: 12
  • Codebase: not detected (mode=new, no codebase signals in CWD)

Plan (3 steps):
  [1] vault-diff PRD-v2.pdf → ./timeoff-spec/
        Why: new PRD detected, vault is at v1.1
        --auto mode: yes (vault metadata supplies output_mode + project_shape)
        Conflicts requiring stakeholder input will halt; everything else applies.

  [2] resolve-oq ./timeoff-spec/ (scope: p1-only)
        Why: vault-diff likely introduces new P1 OQs
        --auto mode: NO. resolve-oq always interactive — captures stakeholder answers.

  [3] drift-detect — SKIPPED
        Why: mode=new, no codebase to reconcile against

Proceed? [y / edit / cancel]
```

### Confirmation

Single `AskUserQuestion` with three options:

- **Run as proposed** (default) — execute the chain.
- **Edit plan** (v0.14 MVP: `skip step N` and `stop after step N` only; reordering and arg-editing deferred to v0.15+).
- **Cancel** — exit.

### Mid-chain behavior

The orchestrator does **not** re-prompt between steps in a confirmed chain. Sub-skills run with their `--auto` flag (where applicable). Two exceptions:

- **`resolve-oq` step**: always interactive on per-OQ choices. Orchestrator hands off; resolve-oq prompts as normal; control returns after the resolution round.
- **Sub-skill emits a `blocker` artifact** in `--auto`: orchestrator catches it, surfaces the structured YAML in chat, pauses chain. User resolves (manually or via resolve-oq next round) and re-invokes `flow`.

### Final summary (always emitted)

```
flow <complete | paused | failed>

Steps executed:
  ✓ [1] vault-diff: 4 added, 3 changed, 1 removed (annotated). 6 new OQs (3 P1).
  ⏸ [2] resolve-oq: 5/8 OQs resolved (paused — user exited).
  – [3] drift-detect: skipped (mode=new)

Vault state: ./timeoff-spec/ (v1.2)
Unpushed commits: 5
Pending blockers: 3 P1 OQs unresolved · 1 DIFF_CONFLICT in 05-decisions
Next suggested step: re-run /grand-design-spec:flow after resolving blockers,
                     OR run /grand-design-spec:resolve-oq to finish the round you started.
```

The "Next suggested step" line is heuristic-only — never auto-executed.

---

## `--auto` semantics (the anti-halu lever)

Universal rule across all sub-skills:

> **Skip logistical prompts. Never skip substance prompts. Never auto-fill content.**

| Skill | What gets auto-defaulted | What stays interactive | Halt behavior |
|-------|--------------------------|------------------------|---------------|
| **grand-design-spec** | Output folder (`./<slug>-spec/`); IMPLEMENTATION_MODE (codebase signals → `existing`, else `new`); `mode_migrate_after` (default `"first commit on main"` for `mode=new`); PRD_STATUS (default `draft`); OUTPUT_MODE (default `compact`); PROJECT_SHAPE (auto-confirm inference); gap-count push-back (skip — dump to OQs) | Figma fetching if MCP not loaded (still asks once); destructive overwrite confirmations (folder exists & non-empty) | Emits `blocker` (type=`oq_blocker`) when generation produces P1s that would block |
| **resolve-oq** | Vault path (if exactly 1 detected); resume-detection (default "continue from current state"); resolution scope (default `p1-only`); lock-state ack (defaults to "proceed if DRAFT") | **All** per-OQ Resolve/OOS/Defer prompts. Per-resolution doc-classification override prompts. Cross-cutting multi-doc landing prompts. | n/a — fully interactive on substance |
| **vault-diff** | Vault path; diff scope (default `full`); old-source path prompt (skip, vault-state-only); apply-changes Y/N for non-conflict categories (default Y); vault version bump type (default patch unless conflicts merit minor) | **All** Resolved-OQ conflicts. **All** Decision conflicts. Major-scope-shift refusal still triggers. | New `blocker` (type=`diff_conflict`) per conflict; chain pauses |
| **drift-detect** | Codebase path (only if CWD obviously a code repo — has `composer.json`/`package.json`/etc.; otherwise REQUIRE explicit arg, don't guess); scope-dirs auto-confirm after framework detection; drift scope (default `full`); skip Step 5 interactive walkthrough — write `DRIFT-REPORT.md`, surface top findings in chat | Major framework mismatch warning (still asks) | `blocker` (type=`drift_framework_mismatch`) only on framework mismatch; otherwise read-only — just reports |

### Unified halt envelope (extending v0.11 OQ_BLOCKER)

Add to `references/vault-contract.md` as new section §halt-protocol:

```yaml
blocker:
  type: oq_blocker | diff_conflict | drift_framework_mismatch
  tag: <OQ-AR-1 | D-007 | etc.>          # stable identifier
  priority: P1 | P2 | P3 | n/a
  context: "Implementing F-U-001 backend"  # what's blocked
  resolver_owner: "Mike Patel"             # who should answer
  resolver_route: "ask in #timeoff-team"   # where to find them
  vault_version: "1.1"
  source_skill: vault-diff | grand-design-spec | drift-detect
  # type-specific fields:
  conflict_old: "<vault state>"            # diff_conflict only
  conflict_new: "<new PRD state>"          # diff_conflict only
  options: ["supersede", "keep_vault", "capture_both"]  # diff_conflict only
```

**Backward compatibility**: vaults generated under v0.13 still produce the old `oq_blocker:` YAML. Vaults regenerated under v0.14 produce the new `blocker: type: oq_blocker` form. AI consumers should accept both shapes during transition (~1 release cycle).

### What `--auto` does NOT do (anti-halu rails)

Explicitly out of scope. These are **non-negotiable**:

- ❌ Auto-resolve OQs (resolve-oq stays fully interactive on per-OQ choice).
- ❌ Auto-pick a side on conflicts (vault-diff stays interactive on Resolved-OQ / Decision conflicts).
- ❌ Skip the Figma "do you have screenshots?" question if Figma was referenced but no MCP — must not invent UI structure.
- ❌ Auto-confirm "overwrite existing folder" — destructive, always asks.
- ❌ Generate `DRIFT-ACTIONS.md` from drift-detect (action list is a deliberate human decision; --auto only writes `DRIFT-REPORT.md`).

---

## Failure handling

Five failure modes. None retry automatically. All surface to chat.

| Mode | Orchestrator response |
|------|-----------------------|
| Sub-skill returns `BLOCKED` | Stop chain. Surface error in chat. |
| Sub-skill emits `blocker` artifact (substance halt) | Pause chain. Surface YAML. Note: *"Resume by re-invoking flow after resolving."* |
| Sub-skill crashes (uncaught error, file write failure, git failure) | Capture stderr/last-output. Surface in chat. |
| Sub-skill succeeds but signals abnormal (e.g., 0 entities extracted) | Continue chain. Surface as ⚠️ in final summary. |
| User cancels mid-chain | Stop. Whatever was committed stays. Final summary shows completed vs skipped. |

### Resumption

Stateless. Re-invoke `/grand-design-spec:flow` after fixing the blocker. Orchestrator re-inspects CWD on each call and picks up from current state.

---

## Implementation footprint

### New files (2)

| File | Purpose |
|------|---------|
| `plugins/grand-design-spec/skills/flow/SKILL.md` | Orchestrator skill |
| `plugins/grand-design-spec/commands/flow.md` | Slash command wrapper |

### Modified files (12)

| File | Change |
|------|--------|
| `skills/grand-design-spec/SKILL.md` | Add `--auto` flag handling at Steps 0–0.7; version 0.9.0 → 0.10.0 |
| `skills/resolve-oq/SKILL.md` | Add `--auto` for logistical prompts only; version 0.3.0 → 0.4.0 |
| `skills/vault-diff/SKILL.md` | Add `--auto` flag; introduce `blocker` (type=`diff_conflict`); version 0.2.0 → 0.3.0 |
| `skills/drift-detect/SKILL.md` | Add `--auto` flag; skip Step 5 walkthrough; version 0.2.0 → 0.3.0 |
| `skills/grand-design-spec/references/vault-contract.md` | Add §halt-protocol with unified `blocker` envelope; document the `OQ_BLOCKER` → `blocker.type=oq_blocker` migration |
| `skills/grand-design-spec/references/templates/00-index.md` | Update "Halt protocol for autonomous runs" sub-section to use unified `blocker` envelope |
| `.claude-plugin/marketplace.json` | Plugin version 0.13.0 → 0.14.0 |
| `plugins/grand-design-spec/.claude-plugin/plugin.json` | Plugin version 0.13.0 → 0.14.0 |
| `CHANGELOG.md` | v0.14.0 entry enumerating all skill version moves |
| `README.md` | Add `/grand-design-spec:flow` row to commands table; mention orchestrator in Quick Start; update repo structure |
| `plugins/grand-design-spec/README.md` | Add flow row to skills table |
| `CONTRIBUTING.md` | Note `--auto` flag convention as required for any future skill |

### Skill version moves (per CONTRIBUTING.md rule)

- `flow`: new at **0.1.0**
- `grand-design-spec`: 0.9.0 → **0.10.0** (added `--auto`)
- `resolve-oq`: 0.3.0 → **0.4.0** (added `--auto` for logistics)
- `vault-diff`: 0.2.0 → **0.3.0** (added `--auto`, `blocker.type=diff_conflict`)
- `drift-detect`: 0.2.0 → **0.3.0** (added `--auto`)
- Plugin: 0.13.0 → **0.14.0**

### Estimated commit chain (~10 atomic commits)

1. Update `references/vault-contract.md` with §halt-protocol unified envelope
2. Update `00-index.md` template Halt protocol section
3. `grand-design-spec` skill: --auto flag (0.9 → 0.10)
4. `resolve-oq` skill: --auto flag (0.3 → 0.4)
5. `vault-diff` skill: --auto flag + diff_conflict blocker (0.2 → 0.3)
6. `drift-detect` skill: --auto flag (0.2 → 0.3)
7. Add new `flow` skill (0.1.0)
8. Add `commands/flow.md`
9. Update READMEs + CONTRIBUTING.md
10. Bump plugin to 0.14.0 + CHANGELOG entry

---

## Out of scope (deferred to v0.15+)

- **State file** (`.gds-state.json` lifecycle position tracking). Approach 2 from brainstorming. Reconsider if v0.14 reveals user struggles with "did I forget drift-detect?" even with the orchestrator.
- **Plan editing beyond skip/stop**: reordering steps, arg-editing per step. Add when plan-rejection rate suggests need.
- **Scheduled mode** (cron-via-`schedule`-skill drift-detect). Holds for v0.16+; depends on user pull.
- **Self-critiquing loops** (Approach 4 from brainstorming). Different problem; not in agentic-orchestration scope.
- **Stakeholder simulation** (Approach 5). Crosses anti-halu rail; permanent no without explicit redesign.

---

## Open Questions

- **OQ-FLOW-1** [P2]: Should `flow` write its plan to a `FLOW-PLAN.md` artifact like vault-diff/drift-detect do? Useful for offline review but adds another file. Default: don't, keep stateless. Revisit if users ask.
- **OQ-FLOW-2** [P3]: Should the unified `blocker` envelope be prefixed differently (`gds-blocker:` vs `blocker:`) to avoid YAML key collisions in user-managed configs? Probably yes — namespace it. Decide during implementation.
- **OQ-FLOW-3** [P3]: For the `vault-diff` `--auto` apply-changes default (Y for non-conflicts), should there be a max-changes cap (e.g., refuse to auto-apply if >50 changes detected — too risky to land without per-change confirmation)? Lean yes; default cap=50.

---

## Sources

- Brainstorming session 2026-05-10: user picked "Multi-skill orchestrator" + "Plan-then-execute" + constraint "powerful but on the line".
- Audit at `docs/superpowers/specs/2026-05-09-plugin-audit-design.md` — informs which skills exist + their current behavior.
- Per-skill SKILL.md files (v0.13 state).
- v0.13 contract `plugins/grand-design-spec/skills/grand-design-spec/references/vault-contract.md`.
