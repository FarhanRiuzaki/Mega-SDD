# Audit Phase 4 — platform hygiene (emit-agents-md honest labeling, AUDIT.md lifecycle, teacher↔template parity harness)

**Date:** 2026-08-11
**Status:** DRAFT
**Source:** `docs/superpowers/audits/2026-08-10-skills-audit.md` Phase-4 roadmap — "emit-agents-md engine migration or honest non-moat labeling" (honest labeling chosen; engine migration NOT taken — see Non-goals), "AUDIT.md lifecycle decision (refresh … or archive to docs/superpowers/audits/)" (archive chosen), and "standing schema↔template parity harness … as the permanent answer to the teacher/template class". Fourth ship train of the audit roadmap (P1=6.2.0, 2a=6.3.0, 2b=6.4.0, P3=6.5.0). **Companion:** `docs/superpowers/proposals/2026-08-11-morning-proposals.md` — the decision doc for the Phase-4 items that need the user's cost/value call (build-dispatch-prompt extraction, free-text delta lane, moat-takeout candidates with numbers, halt-protocol split, deferred roster); nothing in that doc is implemented here.
**Version:** 6.6.0 (minor — honest-labeling prose + dead-field deletion + file relocation + a new CI harness; NO rule, gate, grammar, halt-envelope, or loading-contract change).

**Iron rules for every edit in this release** (the accumulated round lessons, binding):
1. **Pin sweep BEFORE each file edit** — grep BOTH test trees (`tests/` + `plugins/mega-sdd/tests/`) for every phrase to be deleted/reworded; pins move WITH phrases in the same change; keep test-pinned phrases VERBATIM where they survive.
2. **Relocate-then-delete** — a file leaving a runtime namespace (AUDIT.md) has every inbound pointer repointed in the SAME change; records are archived verbatim + banner, never retro-edited.
3. **Verify-before-delete** — a "rotted field" is deleted only after a grep proves no script/skill/hook writes its source key; a "never-taken lock" claim is verified by reading the skill.

## E1 — emit-agents-md honest labeling (audit rework-driver (c): "the only emission with no deterministic verification — prose-asserted idempotency it cannot deliver")

The lane has NO builder script and NO validator — every guarantee it states is model-rendered prose. The fix is honesty, not machinery:

- **SKILL.md Step 6** — "Idempotent — same vault → same output" becomes "Best-effort flatten — model-rendered, NOT byte-idempotent; the vault remains the sole source of truth and AGENTS.md is never a cited record." The Step-2/schema *marker-based safe-regeneration* contract (deterministic substring detection) is a different, honest claim and stays.
- **SKILL.md Step 5** — "Cite vault file:section for every claim" gains "(best-effort — no deterministic verifier backs this lane, unlike the four doc-packs)".
- **Rotted header fields DELETED** — `properties_validated` / `replay_snapshot_count` / `convergence_cycle_count` from the schema header block + §Conditional header field presence table (incl. the two value-0 rows + the convergence soft-caution rail) + the SKILL Step-5 variable list. **Verified:** no script/hook/skill writes the source keys `properties_summary` / `replay_state` / `convergence_state` into vault.json (repo grep — only the emit-agents-md pair mentions them). The handoff-contract `pbt: properties_validated` field is a DIFFERENT surface (per-phase PBT handoff metrics, orchestrate-flow-owned) and is untouched.
- **`memory_in_use` dropped from the handoff halt-status enum** — the skill only READS `memory/conventions.md` (Step 3) and never invokes `derive-vault-json.sh` or any lock-taking writer; a halt status it can never emit is a fabricated enum member. §Halt conditions (3 real halts) unchanged.
- **The 50-line disclaimed skeleton DELETED** — replaced by 3 lines (output shape summary + "the authoritative template is `references/agents-md-schema.md` — render from it"). The skeleton's own text ("ILLUSTRATIVE … Render from the schema, never from this skeleton") already conceded it teaches nothing the schema doesn't own; it omitted 5 header fields + 1 section and was itself a drift seam of the exact teacher/template class E3 pins.
- **Schema ToC fixed** — the duplicated double-entry list (each section listed twice) becomes the real heading list; "Idempotent regeneration" heading renamed "Marker-based regeneration" to match the honest label (pin sweep: no test pins the old heading; trigger-test prose updated — AM3 renamed "Safe regeneration (marker-based)", pass-criteria "idempotent" claim dropped). Frontmatter description "idempotent write-out" → "marker-guarded write-out" (trigger keywords untouched).
- **Skill version bump** 1.6.4 → 1.7.0 (minor).

Kept pins verified in place: `@AGENTS.md` / `does NOT read AGENTS.md natively` / `Never edit CLAUDE.md without explicit yes` (roadmap §), `https://aaif.io` (platform), the announce trace tag (p9), `safe default per the Hard rails` + `DESTRUKTIF` (keterangan).

## E2 — AUDIT.md lifecycle: ARCHIVE (audit #10 + Phase-4)

`git mv plugins/mega-sdd/AUDIT.md docs/superpowers/audits/2026-06-05-audit-md-rounds-1-3-ARCHIVED.md` + a 5-line prepended banner: archived 2026-08-11; status lines STALE (Round-3 "not yet fixed" was fixed in v4.39.0 per CHANGELOG); superseded by `docs/superpowers/audits/2026-08-10-skills-audit.md`; the method (verify-before-record, severity buckets, adversarial dismissal) remains the house standard.

Inbound pointers repointed (full-repo grep; history docs/specs/CHANGELOG keep their references — records stand):
- `plugins/mega-sdd/references/telemetry-schema.md:40` ("see AUDIT.md Round-2 L1")
- `plugins/mega-sdd/hooks/post-tool-use` comment blocks (×2: "AUDIT.md Round-2 L1", "AUDIT.md L1")
- `tests/token-efficiency/test-2a2d-chain-parallel.sh` exclusion-rationale comment (the sweep itself only greps skills/commands/references and is unaffected)
- `README.md` audit-trail link
- NOT dangling (verified): `references/fork-a-recovery-map.md` carries no AUDIT.md reference (the audit's "e.g." was stale); the moat-test "AUDIT Round-2 L3/L5/L6" mentions are round names, not paths; `batch-and-fanout.md` "(AUDIT L1)" likewise.

## E3 — standing teacher↔template parity harness (audit Phase-4: "the permanent answer to the teacher/template drift class")

New `tests/surface/test-p12-teacher-template-parity.sh` — pins the KNOWN teacher↔template pairs so re-drift fails CI (the 6.1.1 lesson made structural: the contract must hold at BOTH the schema that teaches and the template that stamps):

- **(a)** generate-units `unit-schema.md` required-frontmatter keys (`task_type`, `grounding_confidence`, `module`) each appear in `templates/unit.md` (the A8 fix, pinned).
- **(b)** the 6.1.1 `expects` contract at both teachers: `templates/unit.md` expects line contains `substring the runner LITERALLY prints` AND `unit-schema.md` contains `SUBSTRING MATCHER`.
- **(c)** staging-drop severity (the A3 fix, pinned): `generate-intent/references/templates/04-flows.md` says `advisory` for `vault_flow_staging_drop` AND `vault-contract.md` says **advisory** — plus negative pins that NEITHER file's `vault_flow_staging_drop` lines say halt/block.
- **(d)** the UAT step-row owner (the 2b S5 relocation, pinned): `uat-sections.md §Section 2` carries the 7-cell row shape (header row + `| 1 | <Aksi> | <Expected Result> |` literal + `Pending — flow` literal) while SKILL + uat-template carry pointers (`OWNED by … §Section 2` / `adds no rules of its own`) — with NEGATIVE pins that neither re-grows the killed row-literal enumeration.
- **(e)** the binding marker pair (the 2b S5 parity-pin decision, standing): `binding-md-template.md` + `resolve-oq/references/binding-mode.md` BOTH carry `### ✅ CONFLICT-` and `**Resolution**: ✅ RESOLVED (`.

Overlap with `test-p11-owner-parity.sh` S5a/S6a is deliberate: p11 pins the 2b *release outcome*; p12 is the *standing class harness* new pairs get added to. Mutation-proved on scratch copies (P12_ROOT override): ≥2 pins demonstrated to FAIL when the template half drifts.

## Round disclosure (dual-blind, 2 reviewers, read-only)

Reviewer 1 (fidelity+moat; verified every E1 claim against the tree, incl. zero-writer greps for the 3 deleted fields and the never-taken-lock read of the skill): 0 blockers / 1 major / 2 minors, 8 CLEAN lines. The major: `handoff-contract.md` §Skill-status index still enumerated `memory_in_use` in emit-agents-md's halted set after the SKILL-local enum dropped it — the exact enum-drift class iron-rule 1 exists for; FOLDED (the one row edited; the diff-vault/resolve-oq/detect-drift rows keep theirs — those skills DO take the write lock). Minor 1: the new SKILL output-shape summary claimed every section renders "only when its vault source exists" while the schema marks two sections "Always"; FOLDED (now "rendered per the schema's conditional-presence tables"). Minor 2 (disclosure): R1 did not independently re-run the p12 mutation proofs or re-trace the proposals doc's ~230k figure; CLOSED post-round — 3 fresh mutation arms on scratch copies (expects-contract strip → arm b FAIL; row-literal regrowth → arm d3 FAIL; severity fork to halt → arms c1+c3 FAIL) and the ~230k figure traced to audit §1/§6/§13 verbatim.

Reviewer 2 (breakage; ship-readiness): static pass found ZERO findings (independently confirmed the schema ToC fix dropped only fenced template content, not real headings). Its full CI loop reached 103/214 suites, 0 failures, then stalled when the parent session compacted (same parent-echo process quirk as P3, now on the wait path); superseded — the post-fold both-tree suite run below is the authoritative breakage gate and covers a strict superset (the folds landed after R2's snapshot).

## Proof

New: `tests/surface/test-p12-teacher-template-parity.sh` green + ≥2 mutation proofs on scratch copies. Re-run: `tests/surface/test-p9-audit-phase1.sh`, `test-p10-when-triggered-refs.sh`, `test-p11-owner-parity.sh`, `tests/roadmap/test-roadmap-pins.sh`, `tests/platform/test-platform-pins.sh`, `tests/fmea/test-fmea-pins.sh`, `tests/interaction-keterangan/test-oq-prompt-keterangan.sh`, `tests/token-efficiency/test-2a2d-chain-parallel.sh`, `plugins/mega-sdd/tests/moat/test-no-depth2-dispatch.sh` + every suite the pin sweeps flag. Trigger-test prose (`tests/skill-triggering/emit-agents-md.test.md`) aligned with the honest labels.

## Non-goals

- **emit-agents-md engine migration** (a deterministic builder script + verifier) — the audit's alternative fork; honest labeling is the cheap correct half, the engine is a proposals-doc candidate only if the lane earns it (it is a terminal convenience emission, not a cited record).
- Everything in the companion proposals doc — build-dispatch-prompt.sh `_lib` extraction, free-text delta lane, T2/advisor/B1 moat-takeout calls, halt-protocol family split, the deferred roster. Decision-first; zero implementation here.
- CHANGELOG/plugin.json stamps — ship-time (parent session).
