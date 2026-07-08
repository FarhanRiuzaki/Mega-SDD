# Mega-SDD v4 — Lean Core (design + execution spec)

**Date:** 2026-06-04
**Branch:** `v4-lean-core`
**Source analysis:** `research/2026-06-04-architecture-modernization-audit.md`
**Decision:** Full v4 (4 phases), strangler refactor — preserve the moat, ruthlessly delete the rest.
**Owner:** Claude (technical execution). Farhan gates business decisions only.

---

## Goal

Bring Mega-SDD in line with current Anthropic Skill guidance and superpowers' "gates > rules > hooks" discipline, **without losing** the spec↔code grounding moat. Cut hand-maintained surface ~50–65% and move fragility off the hot path.

## Non-negotiable invariants (the moat — preserve byte-for-byte in behavior)

1. Binding produces CONFIRMED / CONFLICT / OQ verdicts with codebase anchors + Implementation State Map.
2. `bind-codebase` CONFLICT **hard-gate** blocks downstream units/bolts (the one legitimate PreToolUse block).
3. sha256 citation discipline in `emit-fsd` (`.citation-map.json`, `[Pending — X]` not fabrication).
4. Halt taxonomy C1/C2/C3 and mutability tiers `[LOCKED]/[INTENT]/[ARTIFACT]` remain the domain vocabulary.
5. Anti-hallucination rule: no fabricated grounding; cite or mark OPEN/Pending.

Everything not on this list is a candidate for deletion or consolidation.

## Acceptance targets (measurable)

| Metric | Now | v4 target |
|---|---|---|
| SKILL.md body total | 8,758 | ≤ 3,800 |
| Any single SKILL.md | up to 1,285 | ≤ 500 (hot ≤ 200) |
| Description version/Iter strings | many | 0 |
| Hook shell lines / files | 2,404 / 4 | < 400 / 1 |
| Validators (lines, placement) | 8,302, hot-path | < 2,500, behind `/analyze` |
| Hook-enforced invariants | ~14 PreToolUse branches | 1–3 |
| Commands | 25 | ~5 |
| `agents/` | 0 | 4 |
| Version source of truth | 2 (mismatch) | 1 (v4.0.0) |

---

## Canonical patterns (apply uniformly)

### Pattern A — Skill slim (progressive disclosure)
SKILL.md becomes a **router**: frontmatter + when-to-use + the decision/step skeleton + explicit one-level links to `references/*.md` for heavy detail. Move to `references/` anything that is: a long procedure for one branch, a schema/contract, examples, or recovery content. Skill body keeps only what *every* invocation needs (HOT tier). No `@`-links. References one level deep, each with a table-of-contents if >100 lines.

### Pattern B — Description rewrite
Third person, present tense, ≤ ~350 chars. State **what + when**. **Delete every** `vN+`, `Iter N`, changelog fragment. **Preserve** all trigger keywords including Indonesian variants (they are load-bearing for ID/EN routing). Form:
`<what it does in one clause>. Use when <trigger conditions, incl. ID keywords>.`

### Pattern C — Gate over hook
If a constraint can be a self-checked blocking gate in skill prose ("STOP — do not proceed unless X"), it stays prose. Only promote to a hook when it is both critical AND un-promptable. Default bias: prose gate.

### Pattern D — Consolidated verify surface
All advisory/consistency checks run inside one `/mega-sdd:analyze` command (read-only, user/chain-invoked), emitting one `CONSISTENCY-REPORT.md`. Reactive PostToolUse validation is removed except where it feeds invariant #2.

---

## Phase 1 — Slim skills + progressive disclosure  (lowest risk, = economics work)

Per-skill target (descending priority by overage):

| Skill | Now (body+refs) | Target body | Action |
|---|---|---|---|
| generate-intent | 1,285 + 2,585 | ≤ 450 | split Mode A/B, classifier, phase, starterkit-binding into refs |
| execute-bolts | 1,189 + 1,049 | ≤ 450 | split T2 injection, hard-rule pre/post-flight, dispatch into refs/agents |
| generate-units | 903 + 1,301 | ≤ 400 | split unit-schema emission, dep-graph, hard-rule grammar into refs |
| orchestrate-flow | 771 + 1,360 | ≤ 350 | split routing-rules, predictive-checks, handoff into refs |
| scan-codebase | 723 + 554 | ≤ 350 | split queries, framework-pack resolution into refs |
| detect-drift | 669 + 0 | ≤ 300 | **extract inline procedure → references/** (exemplar split) |
| bind-codebase | 591 + 237 | ≤ 350 | careful — preserve gate; split state-map + tech-OQ detail |
| resolve-oq | 561 + 262 | ≤ 250 | split walk procedure into refs |
| diff-vault | 522 + 0 | ≤ 250 | extract procedure; evaluate merge with detect-drift (defer) |
| using-mega-sdd | 179 | ≤ 150 | anchor — description cleanup + tighten (do first) |
| others (analyze, emit-*, memory, install-deps, extract-intelligence) | ≤ 500 already | hold / minor | description cleanup only |

**Wave order:** (1) all 16 descriptions; (2) `using-mega-sdd` anchor; (3) one full exemplar body-split (`detect-drift`); (4) the 8 remaining large bodies; (5) verify triggers against `tests/skill-triggering/*`.

**Acceptance:** every SKILL.md ≤ 500; triggers preserved (grep keyword parity); no behavior change to the moat skills' contracts.

## Phase 2 — Consolidate enforcement

1. Build `/mega-sdd:analyze` (already named in `fork-a-recovery-map.md`): run consistency passes, emit one report. Absorb the bulk of `scripts/validate-*.sh` as internal functions/passes.
2. Keep hook-enforced ONLY: binding-conflict gate (+ at most SessionStart anchor inject, Stop telemetry if proven). Demote all other PreToolUse branches to `/analyze` or prose gates.
3. Collapse `hooks/{session-start,pre-tool-use,post-tool-use,stop}` → one `hooks/dispatch` with a tiny fast PreToolUse path (read one state file, decide).
4. Delete validators absorbed into `/analyze` once parity is shown on TF-Import fixtures.

**Acceptance:** hot path does one cheap check; `/analyze` reproduces prior validator coverage on `tests/fixtures/code-delivery/**`.

## Phase 3 — Subagents + command cull

1. Create `agents/implementer.md`, `agents/spec-reviewer.md`, `agents/code-quality-reviewer.md`, `agents/domain-extractor.md` (move vendored/inline prompts here; set cheap model per mechanical role).
2. `execute-bolts` and `extract-intelligence` dispatch these instead of carrying inline prompt blocks.
3. Reduce commands to ~5: `auto`, `analyze`, plus the pipeline verbs that need manual entry. Remove the rest; rely on skill auto-trigger.

**Acceptance:** subagent dispatch works on a real unit; command surface ≤ 5.

## Phase 4 — Narrative reset + v4.0.0

1. Rewrite `CLAUDE.md` to contracts + invariants + the 5 non-negotiables; move history to one collapsed appendix or drop (git holds it).
2. Truncate `CHANGELOG.md` to recent; archive the 588 KB history out of tree.
3. Purge `Iter N` / `vN+` strings from all runtime prose (skills, refs, descriptions).
4. Single version source of truth; reconcile `plugin.json` (3.72.0) vs `marketplace.json` (1.3.0); tag **v4.0.0**.

**Acceptance:** clean `CLAUDE.md` < 120 lines; zero runtime Iter strings; one version.

---

## Method discipline (per superpowers, which Farhan endorses)

- TDD-for-skills: before keeping a slimmed skill, confirm it still triggers + behaves on its `tests/skill-triggering/*.test.md` fixture.
- Strangler, not rewrite: each phase ships independently on `v4-lean-core`; moat behavior verified against TF-Import artifacts each phase.
- Reversible: all work on the branch; nothing merged until a phase passes its acceptance.


> **Amendment (2026-07-06, token-efficiency B2/M-07):** the execute-bolts PreToolUse gate aggregator emits the remediation of EVERY failing gate in the single deny (joined, capped ~2500 chars with a /mega-sdd:analyze pointer), instead of fails[0] only — each additional failing gate previously cost a full deny→fix→re-invoke cycle. Identical block semantics; strictly more information per block.

> **Amendment (2026-07-07, token-efficiency B3/M-11):** the execute-bolts review-panel lens dispatch (`skills/execute-bolts/references/review-panel.md`) sizes the unit-body payload per lens. The **spec lens** gets the full unit body verbatim (it verifies Implementation-steps fidelity, Hard-rule honoring, and `target_files` coverage — the moat checks — and must see everything). The **other lenses (security, standards, quality, design)** get frontmatter + requirements + Hard rules + Anchors/Anti-patterns + Migration notes but NOT the Implementation-steps NARRATIVE — they judge the landed diff (security judges the actual authz/validation in the code, not the step prose), so the step narrative is dead weight sent 4× per full-tier bolt attempt (~40–50% of a typical body). **Migration notes is retained in every lens** (review-round correction): its `extend`-unit KEEP sub-list is the authoritative "code to preserve" for pre-existing controls that predate the unit and are therefore absent from its `binding_refs`/§B slice — the security lens's architectural-drift/bypass check is blind without it, and the list is only a few short lines. The blind-dispatch rail is untouched (this changes unit-body SIZING, not cross-lens sharing). The `superpowers-bridge.md` review-flow diagram is kept in sync with this sized-per-lens contract (the LLM controller reads both; a stale "full body to every lens" instruction would silently make the savings inert). Agent-body de-dup lands with it: `agents/design-reviewer.md` single-sources the ceiling-move list in §Floor vs ceiling (check #0 points at it instead of re-enumerating); `agents/bolt-implementer.md` self-review references the Iron Rules (esp. #4) instead of re-listing them.

> **Amendment (2026-07-07, token-efficiency B3/M-13a):** the `using-mega-sdd` anchor ROUTING CORE (injected on every SessionStart) drops the verbatim keyword bullets in favor of a one-line pointer at the always-loaded skill descriptions, and collapses the lanes list to one routing sentence — because the harness loads every skill's frontmatter description on startup AND on compaction, so a trigger phrase living in a description is reachable on a cold start without paying for it in the core. INVARIANT (enforced by `tests/anchor-diet/test-lean-anchor.sh`): every load-bearing trigger must survive on the UNION of the core + all skill descriptions; the collapse first UNION'd the phrases that were ONLY in the core into the owning descriptions (bound-vault / legacy intelligence / source of truth dari legacy → using-mega-sdd's own description; check consistency / consistency report → analyze's). The Hard rule + Output language sections stay in the core byte-identical in substance (they are the only pieces NOT reconstructable from a description). Core shrank ~3886→~3212 chars.
