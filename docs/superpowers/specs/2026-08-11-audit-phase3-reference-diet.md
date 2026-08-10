# Audit Phase 3 — reference diet (archaeology purge, context-enrichment split, mega-line reflow)

**Date:** 2026-08-11
**Status:** SHIPPED v6.5.0 (2026-08-11, 7d60c8c, CI green, suite 216/216 both trees; net −194 lines) — dual-blind round: 0 blockers / 1 major / 8 minors, ALL folded (§Round disclosure)
**Source:** audit recommendation #8 + the P2/P3 items (docs/superpowers/audits/2026-08-10-skills-audit.md). Third ship train of the audit roadmap (P1=6.2.0, 2a=6.3.0, 2b=6.4.0).
**Version:** 6.5.0 (minor — prose relocation/reformat only: NO rule, gate, grammar, halt, or loading-contract change).

**Iron rules for every edit in this release** (the accumulated round lessons, binding):
1. **Pin sweep BEFORE each file edit** — grep BOTH test trees for every phrase to be deleted/reworded; pins move WITH phrases in the same change; keep test-pinned phrases VERBATIM where they survive.
2. **Byte-preserving reflow** — the mega-line reflow changes FORMATTING only (split at existing em-dash/semicolon/bullet seams); wording identical; trigger tests re-run.
3. **Archaeology purge = runtime prose only** — specs/CHANGELOG/research keep everything; a purged sentence's OPERATIVE content (if any) stays, only the version/date/round narrative goes. The `deprecated (v3.0.0)` pin-bearing phrase in detect-drift report-format.md is EXEMPT (test-pinned). Anti-regression editor pins ("do not simplify back") convert to HTML comments, not deletion.
4. **context-enrichment split**: the amendment/measurement corpus (WITHDRAWN boxes, struck derivations, dual accounting tables, round narratives) moves to `docs/superpowers/specs/2026-08-11-context-enrichment-amendment-archive.md` (verbatim, with a provenance header); the ref KEEPS: operative tables (T1/T2, cascade, budget caps), absent-value/anti-halu rails, the Known-open table, every `reproduce-defect-as-written` annotation, and the builder contract. The moat-test pins on this file (tests/moat/test-dispatch-prompt-cascade.sh — incl. the recorded stale cap-pin note) must stay green; where a pin targets archived text, the pin moves per its own file's instruction.

## D1 — repo-wide version-archaeology purge (runtime prose)

~50 grep sites (audit dup-matrix row): `removed 5.29.0` / `since D2/v5.31.0` / `tranche 5b/5e` / `S3 DS-1` / `P0 v4.92.0` / `AUDIT L8` / `decision N` / `(v0.6, cond.)` template tags / `v0.11→v0.14` compat note / `pre-v1.x` blocks / research-file citations in rule text / PR#15/16 provenance / `adopted by 60k+ repos as of mid-2026`. Owners of history: CHANGELOG + specs. The Step-7.5 tombstone (3 verbatim copies) collapses to one line in generate-units SKILL only.

## D2 — context-enrichment.md split (per rule 4) — reopens deferred R6 WITH the audit's new evidence (~40-50% measured history; consulted on every builder-spec amendment).

## D3 — mega-line reflow (byte-preserving, worst offenders only)

`routing-rules.md` Mode D row (~2.4k chars) → a §Mode D subsection with one bullet per rule (the TABLE row keeps a one-line summary + pointer); `bind-codebase/SKILL.md:47` (~2k) and `execute-bolts/SKILL.md` B1 paragraph (~2k) → sub-bullets at existing seams; `resolve-oq/SKILL.md:51/:55`; `generate-intent Step 3.7`. Re-run trigger tests after each.

## D4 — small measured items

- `emit-fsd` styling-config.yaml cut to the 4 consumed keys (+ "PDF look is github.css" line); re-baseline verified UNNECESSARY — the parity suite carries zero styling assertions and passes unchanged against the dieted seed (round finding).
- `graph` trigger test (tests/skill-triggering/graph.test.md) — the one routed skill without one.
- `emit.md` maturity-ladder drift guard (structural test asserting the 4 hardcoded ladders match their doc-pack owners).
- diff-vault scope-aware fast pass (oq-only reads roll-up + OQ sections + targeted source sections only) — the ONE loading-contract change here, flagged as such.

## Deferred out (recorded)

halt-protocol family split (needs halt-path telemetry); vault-contract physical reorder (cross-skill SSOT blast radius — the 6.3.0 §-named reads already land the win); Wave-5 synthesis diet (needs an extraction run to verify against); os-detection/install-deps demoted-block deletion (keep-in-sync banner shipped in 6.4.0; delete only after a field run proves the script path sticks).

## Round disclosure (dual-blind, 2 reviewers, read-only)

Reviewer 1 (content-preservation; word-verified every reflow, byte-verified the 177 archived lines): 0 blockers / 1 major / 5 minors. Reviewer 2 (breakage; 213/213 CI-loop suites green pre-fold): 0 blockers / 0 majors / 3 minors. ALL folded (battery 31/31 post-fold): the diff-vault oq-only guard extended to Steps 2–3 (the major — a scope-conditioned Step 1 with unconditioned Steps 2–3 forces silent re-reads or unauthorized skips); the Mode D subsection re-scoped (DEMOTE policy + OQ counting note moved back out); the dangling `§D1` pointer dropped; the Step-3.7 bullet nesting restored; the ladder-parity guard hardened to owner-ladder set-comparison both directions (mutation-proved: renamed-to-existing-word now fails); the no-op re-baseline claim corrected in §D4; and ~11 same-class tag leftovers purged (`P4 v4.96.0` ×4, non-pinned `5.29.0` ×3, `(v0.11)`, `tranche-2b`, starterkit round narratives ×2 — the p2d-pinned `AMENDMENT 2026-07-31` anchor name deliberately kept). Implementation note: two builder agents initially halted on the parent session's context-warning hook echo (their own windows were fresh) — recon was reused, executors relaunched; a process quirk, not a content risk.

## Proof

Existing suites BOTH trees (the pins ARE the proof for relocation/reflow); new: `tests/skill-triggering/graph.test.md`, the emit.md ladder guard, re-baselined emission-parity. Round: dual-blind as always.
