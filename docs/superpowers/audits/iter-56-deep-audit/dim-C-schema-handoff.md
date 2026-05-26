# Iter 56 Deep Audit — Dimension C: Schema + Handoff Contract Consistency

**Plugin version:** v3.38.0
**Scope:** Cross-skill handoff schema validation gate (Iter 33 F3/F4) coverage for skills added in Iter 54 (emit-fsd) + Iter 55 (install-deps) plus surface touches in execute-bolts (Iter 53), generate-units, bind-codebase, orchestrate-flow.
**Auditor:** subagent (dim C)
**Date:** 2026-05-26

---

## Summary

The handoff-contract.md schema gate (`plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`) has **fallen out of sync with skill emissions**. Iter 54 (emit-fsd) and Iter 55 (install-deps) shipped with handoff YAML emission blocks declared *only* inside each skill's own SKILL.md — neither has any entry in handoff-contract.md `## Per-skill expected emissions` and neither has TYPE annotations for its new `metrics:` fields. Per Iter 33 F4 (the `handoff_type_mismatch` halt), fields without TYPE annotations bypass type-check (warn-only) — so the validation gate is silently disabled for every metric these two skills emit.

Two adjacent producer-only consumer-only drifts compound this:

1. **`metrics.acceptance_test_concerns: []`** (Iter 53, execute-bolts → orchestrate-flow Step 7) is declared in execute-bolts SKILL.md line 971 and consumed in orchestrate-flow SKILL.md line 375, but is **not declared in handoff-contract.md** anywhere — so the field that the audit explicitly added to surface Iter 47 under-validation concerns evades schema validation.

2. **`binding_metadata.codebase_map_provenance`** (Iter 46/48 producer; Iter 53 consumer in orchestrate-flow Step 3 line 151-152) lives in `binding.md` header (not in handoff YAML at all) — outside this audit's strict scope, but worth flagging as a parallel producer-only-then-consumer-attached pattern that bypassed handoff-contract.

The halt enum in `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md:569` and the `source_skill` enum at line 576 **are correctly updated** for both Iter 54 + Iter 55 — `emit-fsd` and `install-deps` both appear in source_skill, and `install_failed` + `pkg_mgr_not_found` both appear in the halt enum.

Iter 47 `_authored_by` provenance has **7 declared values** in adversarial-test-prompt.md table (line 84-93), but execute-bolts NOTE-injection logic (`bolt-dispatch-prompt.md` line 64) only branches on 2 of them (`same-pass`, `adversarial-review-failed`) — which IS correct per spec (NOTE is omitted for strong-provenance units), BUT pre-Iter-47 absent-field handling (treated as `same-pass`) is documented in only one place (adversarial-test-prompt.md line 94; bolt-dispatch-prompt.md line 82) and never appears as an enum branch in code — relies on string equality + fallback default.

**Severity rollup:** 1 × P1 HIGH, 4 × P2 MEDIUM, 2 × P3 LOW.

---

## Findings

### Finding C-001 — `emit-fsd` has NO entry in handoff-contract.md `## Per-skill expected emissions` (P1 HIGH)

**File:** `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`
**Lines:** 244-502 (the `## Per-skill expected emissions` section)
**Evidence:** `grep -n "emit-fsd" handoff-contract.md` returns ZERO matches. The section enumerates `extract-intelligence` / `generate-intent` / `scan-codebase` / `bind-codebase` / `generate-units` / `execute-bolts` / `diff-vault` / `emit-agents-md` / `resolve-oq` / `detect-drift`. emit-fsd is missing entirely.

**Symptom:** Iter 33 F4 type-check enforcement (handoff-contract.md line 227 "fields with explicit `TYPE:` annotations above are validated at Step 6.b.i. Fields without a `TYPE:` annotation bypass type check"). With emit-fsd absent from the contract, ALL its fields (sections_emitted, citations_count, drift_callouts_count, mode, pdf_emitted, fallback_format) bypass type check — `handoff_type_mismatch` halt cannot fire even if a future skill version emits sections_emitted as a string instead of int.

**Why P1:** This is the exact failure mode Iter 33 F4 was built to prevent. The contract documents the gate ("Fields without a `TYPE:` annotation bypass type check — warn-only log") and emit-fsd silently sits in the bypass zone. Schema drift could go undetected for an arbitrarily long time. Also: emit-fsd SKILL.md line 25 + line 153 explicitly point users at handoff-contract.md as authoritative — but the authoritative doc has no contract for this skill, so the reference is circular.

**Fix:** Add `### emit-fsd` section to handoff-contract.md after the `detect-drift` block (after line 504), modeled on the `emit-agents-md` template (lines 422-446). Include TYPE annotations for ALL Iter 54 metrics:
- `sections_emitted` TYPE: int
- `sections_excluded` TYPE: int
- `citations_count` TYPE: int
- `drift_callouts_count` TYPE: int
- `mode` TYPE: enum (`pre-dev` | `post-dev`)
- `pdf_emitted` TYPE: bool
- `fallback_format` TYPE: enum (null | `html` | `markdown`)

Status enum should be `completed | halted` (no `paused` per SKILL.md line 159). Halt sources: `dep_missing | quality_gate_failed`.

---

### Finding C-002 — `install-deps` has NO entry in handoff-contract.md `## Per-skill expected emissions` (P1 HIGH)

**File:** `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`
**Lines:** 244-502 (Per-skill expected emissions section)
**Evidence:** `grep -n "install-deps" handoff-contract.md` returns ZERO matches.

**Symptom:** Same as C-001 — all install-deps metric fields (`tools_audited`, `tools_already_present`, `tools_installed`, `tools_failed`, `tools_sudo_pending`, `detected_os`, `detected_pkg_mgr`) bypass type check. `detected_os` and `detected_pkg_mgr` are particularly schema-sensitive because they have enum constraints declared in install-deps SKILL.md line 208-209 — without TYPE annotations in the contract those constraints are unenforceable.

**Why P1:** Same as C-001. install-deps SKILL.md line 26 + line 188 point users at handoff-contract.md as the schema authority; the authority has nothing for this skill.

**Fix:** Add `### install-deps` section after the emit-fsd entry (per C-001 above). TYPE annotations needed:
- `tools_audited` TYPE: int
- `tools_already_present` TYPE: int
- `tools_installed` TYPE: int
- `tools_failed` TYPE: int
- `tools_sudo_pending` TYPE: int
- `detected_os` TYPE: enum (`macos` | `linux` | `wsl` | `windows-bash` | `unknown`)
- `detected_pkg_mgr` TYPE: enum (`brew` | `apt` | `dnf` | `pacman` | `apk` | `winget` | `scoop` | `cargo-fallback` | `none`)

Status enum: `completed | halted`. Halt sources: `install_failed | pkg_mgr_not_found | memory_in_use`.

**Note:** Group C-001 + C-002 fix in one commit — both are the same omission class introduced when Iter 54 + 55 added new skills without updating the contract section.

---

### Finding C-003 — `metrics.acceptance_test_concerns: []` (Iter 53) not in handoff-contract.md execute-bolts entry (P2 MEDIUM)

**File:** `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`
**Lines:** 362-390 (execute-bolts entry)
**Evidence:** The execute-bolts handoff template in handoff-contract.md (line 363-388) lists `items_processed`, `items_blocked`, `bolts_used_starterkit_slice`, `slice_avg_size_kb` but NOT `acceptance_test_concerns`. Producer emits it (`execute-bolts/SKILL.md:971-975`). Consumer reads it (`orchestrate-flow/SKILL.md:375`).

**Symptom:** The new field is a producer-emitted, consumer-read schema element but lacks TYPE annotation. By the bypass rule, type-check is warn-only. Per memory/MEMORY.md note "[Propagation within iter] producer-only ships hide debt", Iter 53 was meant to close this exact pattern but the field that Iter 53 ADDED to surface acceptance-test concerns itself bypasses the gate it was supposed to traverse.

**Why P2:** Functional in practice (orchestrate-flow consumes it correctly), but evades schema validation. If a future skill update changes the field shape (e.g., emits objects vs strings under the `unit:` / `concern:` keys), `handoff_type_mismatch` will not fire.

**Fix:** Add to handoff-contract.md execute-bolts entry:
```yaml
metrics:
  acceptance_test_concerns:                            # v3.4.0+, Iter 53
    TYPE: array<object>                                # each item: { unit: string, concern: string }
    REQUIRED: yes (empty array when no concerns flagged)
```

---

### Finding C-004 — Halt enum line 569 is correctly updated for Iter 54/55, but `quality_gate_failed` subtypes are documented in SKILL.md only (P2 MEDIUM)

**File:** `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md:569` (halt enum) + line 630-631 (install-deps halt descriptions) + emit-fsd SKILL.md:115,147,195 + install-deps SKILL.md:150
**Evidence:**
- `install_failed` and `pkg_mgr_not_found` appear in the enum (line 569) ✓
- `source_skill` enum (line 576) lists `emit-fsd | install-deps` ✓
- BUT: emit-fsd emits subtyped halts `quality_gate_failed:pdf_render_failed` (SKILL.md:115) and `quality_gate_failed:template_slot_unfilled` (SKILL.md:147,195) — the enum has `quality_gate_failed` (line 569) but the subtype taxonomy is NOT in vault-contract.md
- install-deps emits subtyped halts `install_failed:install_command_failed` and `install_failed:verify_after_install_failed` (SKILL.md:150,183) — install-deps SKILL.md line 183 declares the subtypes, vault-contract.md line 630 declares them in the `details` object spec, but they are not in a canonical subtype enum

**Symptom:** Consumers of the blocker envelope must guess at subtype values. If the orchestrator (or `gsd-list-phase-assumptions`-style aggregator) wants to enumerate distinct subtypes, there's no single source of truth.

**Why P2:** This is a "wording inconsistency / missing enum" gap — not a runtime failure. Existing subtype consumers work fine via string-match against the documented values. But the schema doesn't declare them as an enum, so any future subtype addition will be undiscoverable.

**Fix:** Add a `### subtype enums` block to vault-contract.md after line 631:
```yaml
quality_gate_failed.subtype: pdf_render_failed | template_slot_unfilled | starterkit_metrics_inconsistent  # extract from each producer skill
install_failed.subtype: install_command_failed | verify_after_install_failed
```

(starterkit_metrics_inconsistent reference per generate-units/SKILL.md:797.)

---

### Finding C-005 — `_authored_by:` enum has 7 declared values; pre-Iter-47 fallback is documentation-only, not in code (P2 MEDIUM)

**File:** `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md:84-93`
**Evidence:** Table at line 84-93 declares 7 values: `same-pass | adversarial-reviewed | adversarial-reviewed (no gaps) | adversarial-reviewed (+N gaps merged) | adversarial-review-failed | independent-llm | human`. Line 94 says "Pre-Iter-47 units (no field present) → treat as `same-pass`". Bolt-dispatch-prompt.md:82 mirrors this: "Pre-Iter-47 units (no `_authored_by:` field) are treated as `same-pass`".

execute-bolts NOTE-injection logic per `bolt-dispatch-prompt.md:64` reads ONLY 2 values (`same-pass` OR `adversarial-review-failed`). For the 7-value enum:
- `same-pass` → NOTE injected ✓
- `adversarial-review-failed` → NOTE injected ✓
- `adversarial-reviewed` → NOTE omitted (line 78-79: strong) ✓
- `adversarial-reviewed (no gaps)` → NOTE omitted ✓
- `adversarial-reviewed (+N gaps merged)` → NOTE omitted ✓
- `independent-llm` → NOTE omitted ✓
- `human` → NOTE omitted ✓
- *field absent* (pre-Iter-47) → NOTE injected via "treat as same-pass" rule ✓

**Symptom:** Behaviorally correct, BUT the audit-explicit check (does execute-bolts NOTE injection logic read ALL 7 values?) reveals that the code does NOT enumerate all 7 — it branches on TWO + a documented default. Anyone reading bolt-dispatch-prompt.md:64 in isolation might think the other 5 values are unhandled. The mapping is correct but the enum is not exhaustively enumerated in the consumer.

**Why P2:** No runtime defect — string equality + default branch handles all 7 cases. But the enum coverage is implicit, not explicit. A future addition (e.g., a `human-validated` 8th value) would silently fall into the NOTE-omitted bucket by default, possibly incorrectly.

**Fix:** Annotate bolt-dispatch-prompt.md:64 with an explicit enum coverage map:
```
NOTE-INJECT trigger values: same-pass | adversarial-review-failed | (absent → treat as same-pass)
NOTE-OMIT values (strong provenance): adversarial-reviewed | adversarial-reviewed (no gaps) | adversarial-reviewed (+N gaps merged) | independent-llm | human
```

Add cross-reference: "If `_authored_by:` takes a new value not in either list above → default to NOTE-INJECT (safer; treats unknown as potential weak provenance)."

---

### Finding C-006 — `codebase_map_provenance` (Iter 46/48/53) lives in `binding.md` header, NOT in handoff YAML (P3 LOW)

**File:** `plugins/mega-sdd/skills/bind-codebase/SKILL.md:41-44`
**Evidence:** bind-codebase records `binding_metadata.codebase_map_provenance = "snapshot-verified" | "snapshot-stale" | "no-snapshot"` in `binding.md` header (SKILL.md:41-43). orchestrate-flow Step 3 (SKILL.md:151-152) reads this directly from binding.md to optimize the chain — not from a handoff YAML field.

**Symptom:** Outside this audit's strict handoff-contract scope, but parallel to C-003 — a producer-only-then-consumer-attached field added across multiple iters. The orchestrator reads binding.md OUT-OF-BAND of the handoff envelope, bypassing the schema gate.

**Why P3:** Working as designed (bind-codebase handoff doesn't need to redundantly emit this — binding.md is the authoritative artifact). But a `binding.md` header schema validator does not exist; orchestrate-flow Step 3 parses with string-match logic at line 152. If bind-codebase changes the header format, the consumer breaks silently.

**Fix (optional):** Add a `metadata.codebase_map_provenance` field to bind-codebase's handoff YAML template (handoff-contract.md:312-329) with TYPE: enum (`snapshot-verified` | `snapshot-stale` | `no-snapshot`). Status: CONDITIONAL (when codebase-map.md present). This brings the field into Iter 33 F4 type-check scope.

---

### Finding C-007 — install-deps preflight checks NOT in predictive-checks.md (P3 LOW)

**File:** `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
**Evidence:** `grep -n "install-deps preflight" predictive-checks.md` returns ZERO matches. emit-fsd preflight checks exist at line 201-222 (Iter 54), but install-deps (Iter 55) has none.

install-deps SKILL.md:36-41 declares 2 preflight checks (`pkg_mgr_detected`, `memory_writable`) but they are documented only in the skill, not in the central predictive-checks.md registry.

**Symptom:** Per orchestrate-flow Step 3.5 (predictive-checks.md:249 "Read protocol"), the orchestrator scans this file for each skill in the proposed chain. install-deps preflights will be silently skipped when install-deps is part of an auto-chain.

**Why P3:** install-deps is rarely chained automatically (no skill emits `next_action.suggested_skill: mega-sdd:install-deps`). Predictive-checks coverage is informational, not a hard gate. Skill-internal Step 1 still runs the checks at invocation time.

**Fix:** Add `## install-deps preflight checks (v3.5.0+, Iter 55)` section to predictive-checks.md after the emit-fsd block (after line 222):
- `pkg_mgr_detected` — `command -v brew || command -v apt || ...` — fatal: yes — predicts_halt: `pkg_mgr_not_found`
- `memory_writable` — `mkdir -p <project>/.mega-sdd/memory && rmdir ...` — fatal: yes — predicts_halt: `memory_in_use`

---

## Coverage Matrix

| Skill | In handoff-contract `## Per-skill expected emissions`? | TYPE annotations on new metrics? | In source_skill enum (vault-contract:576)? | Halts in enum (vault-contract:569)? | In predictive-checks.md? |
|---|---|---|---|---|---|
| extract-intelligence | YES (line 246-262) | partial | YES | YES (`quality_gate_failed`) | n/a (no preflight) |
| generate-intent | YES (line 267-286) | partial | YES | YES | YES |
| scan-codebase | YES (line 290-309) | partial | YES | YES | YES |
| bind-codebase | YES (line 312-329) | partial — `codebase_map_provenance` absent (C-006) | YES | YES | YES |
| generate-units | YES (line 333-358) | partial | YES | YES | YES |
| execute-bolts | YES (line 362-390) | partial — `acceptance_test_concerns` absent (C-003) | YES | YES | YES |
| diff-vault | YES (line 392-420) | partial | YES | YES | YES |
| emit-agents-md | YES (line 422-446) | partial | YES | YES | YES |
| resolve-oq | YES (line 448-475) | partial | YES | YES | (no preflight needed) |
| detect-drift | YES (line 477-504) | partial | YES | YES | YES |
| **emit-fsd** | **NO (C-001)** | **NO (C-001)** | YES (line 576) | YES (`quality_gate_failed` + `dep_missing`) | YES (line 201-222) |
| **install-deps** | **NO (C-002)** | **NO (C-002)** | YES (line 576) | YES (`install_failed`, `pkg_mgr_not_found`) | **NO (C-007)** |
| extract-intelligence | YES | partial | YES | YES | n/a |
| memory | n/a (no orchestrated handoff) | n/a | YES (line 576) | YES (`memory_in_use`, `memory_schema_mismatch`) | YES |
| orchestrate-flow (self) | n/a (the orchestrator itself) | n/a | YES | YES (`predictive_check_failed`, `invalid_handoff`, `handoff_type_mismatch`, `model_tier_unknown`, `handoff_missing`, `artifact_missing`, `routing_outcome_corrupt`) | n/a |

### Halt enum verification (vault-contract.md:569)

ALL halt types appearing in any skill's `## Halt protocol` section verified present in the enum. Confirmed via:
- `emit-fsd` → `dep_missing` ✓, `quality_gate_failed` ✓
- `install-deps` → `install_failed` ✓ (line 630), `pkg_mgr_not_found` ✓ (line 631), `memory_in_use` ✓
- `execute-bolts` → all halt types covered
- No orphan halts in enum (every halt has at least one producer skill in SKILL.md)

### `_authored_by:` provenance value coverage (Iter 47)

| Value | adversarial-test-prompt.md declared? | execute-bolts NOTE-injection handles? |
|---|---|---|
| `same-pass` | YES (line 86) | YES — inject |
| `adversarial-reviewed` | YES (line 87) | YES — omit (strong) |
| `adversarial-reviewed (no gaps)` | YES (line 88) | YES — omit |
| `adversarial-reviewed (+N gaps merged)` | YES (line 89) | YES — omit |
| `adversarial-review-failed` | YES (line 90) | YES — inject |
| `independent-llm` | YES (line 91) | YES — omit |
| `human` | YES (line 92) | YES — omit |
| *field absent* (pre-Iter-47) | line 94 fallback rule | YES — treated as `same-pass` per bolt-dispatch-prompt.md:82 |

All 7 declared values + the absent-field fallback are behaviorally handled. C-005 flags this as P2 because the enum coverage in the consumer (bolt-dispatch-prompt.md:64) is implicit (branch-on-2 + default-omit), not exhaustively enumerated.

---

## Iter 33 TYPE annotation depth audit

handoff-contract.md:227 declares: "Iter 33 covers all top-level fields + 1 level of nesting (e.g., `mutability.tier_distribution.LOCKED`). Deeper nesting deferred to Iter 34+."

Spot-checked fields added post-Iter-38:
- `metrics.bolts_used_starterkit_slice` (Iter 32) — TYPE: int annotation NOT in contract; per-skill handoff template shows usage but contract Per-skill emissions block lists `(OPTIONAL)` only at top level (handoff-contract.md:149). Bypass per bypass-rule.
- `starterkit_context.libs_count` (Iter 32) — TYPE: int declared in contract line 220 ✓
- `acceptance_test_concerns` (Iter 53) — missing per C-003
- `codebase_map_provenance` (Iter 46) — not in handoff per C-006
- `tools_audited / tools_installed / detected_os / detected_pkg_mgr` (Iter 55) — missing per C-002
- `sections_emitted / citations_count / drift_callouts_count / mode / pdf_emitted / fallback_format` (Iter 54) — missing per C-001

**Recommendation:** Run a sweep iter to add TYPE annotations for ALL `metrics.*` field-by-field across the Per-skill expected emissions section. Currently the contract documents the metric NAMES but rarely the TYPES at field level — most TYPE annotations are at object-level (`metrics:` TYPE: object — line 151). One-level-nested TYPE on individual metric fields would close the bypass.

---

## Compliance assessment vs Iter 33 F3/F4 contract

**F3 (machine-readable constraints):** Partial. Top-level handoff fields (lines 95-225 of handoff-contract.md) have REQUIRED/CONDITIONAL/OPTIONAL severity + TYPE annotations. Per-skill metric fields (lines 244-504) do NOT have TYPE annotations at field-level — they declare names only.

**F4 (handoff_type_mismatch enforcement):** Effective only for fields with explicit TYPE annotations (handoff-contract.md:227). Per the bypass rule, every metric field added in Iter 32+ that lacks a TYPE annotation evades enforcement. The handoff validation gate is therefore much LESS strict in practice than the Iter 33 narrative suggests.

**Recommendation:** Either (a) close the bypass loophole by making TYPE annotations REQUIRED for the gate to consider a field at all (so missing annotations = `invalid_handoff` halt against the skill author, not the user), OR (b) add a sweep iter that fills in TYPE annotations across the entire Per-skill emissions section.

---

## File reference index (absolute paths)

- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — primary audit target
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — preflight coverage
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 7 consumer
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — halt enum + source_skill enum
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-fsd/SKILL.md` — Iter 54 producer
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/install-deps/SKILL.md` — Iter 55 producer
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml` — tool matrix
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/execute-bolts/SKILL.md` — Iter 53 producer
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — Iter 47 NOTE injection
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-units/SKILL.md` — Iter 53 starterkit_metrics_inconsistent consumer
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` — `_authored_by` enum
- `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/bind-codebase/SKILL.md` — Iter 46/48 codebase_map_provenance
