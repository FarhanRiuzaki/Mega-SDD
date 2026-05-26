# Iter 56 Deep Audit — Dim B: Cross-Reference Integrity + Producer/Consumer Wiring

**Plugin version audited:** mega-sdd v3.38.0
**Audit scope:** Iter 54 (emit-fsd) + Iter 55 (install-deps) new surfaces, plus regression-class spot-checks on Iter 46/49/53 wiring contracts.
**Method:** field-name grep across `plugins/mega-sdd/skills/` + `plugins/mega-sdd/references/`; cross-check producer emit-site vs consumer read-site in actual SKILL.md procedure bodies (not just prose intent declarations).

---

## Summary

| Result | Count |
|---|---|
| P1 HIGH (declared consumer, no producer-side writer) | 1 |
| P2 MEDIUM (consumer wired weakly / contract not updated) | 3 |
| P3 LOW (wording drift / stale reference) | 2 |
| Confirmed clean (producer→consumer wired) | 8 |

**Net assessment:** Iter 54+55 shipped with two contract-side drifts (handoff-contract.md + predictive-checks.md not extended for install-deps; memory-schema.md not extended for install-outcomes.md). One serious P1 regression discovered on the Iter 46→53 `codebase_map_provenance` chain — the consumer logic exists in orchestrate-flow Step 3 but the producer's binding.md template body never actually emits the field (only the prose narration in Step 1 mentions assigning it). This is the same Iter 43/48/52/53 PARTIAL pattern: documented behavior that doesn't make it into the artifact body.

---

## Findings

### P1 HIGH

#### P1-1 — `binding_metadata.codebase_map_provenance` is never actually written to binding.md

**Severity:** P1 HIGH — completes the Iter 53 closure on paper but breaks it in practice. Consumer reads a field producer never emits.

**Producer claim:**
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md:41-43` (Step 1 prose) says: "record `binding_metadata.codebase_map_provenance = "snapshot-verified"` in binding.md header" (and `snapshot-stale` / `no-snapshot` variants).

**Producer reality:**
- The actual binding.md template emitted in `plugins/mega-sdd/skills/bind-codebase/SKILL.md:367-436` (Step 4 "Write `binding.md`") has YAML frontmatter only with `vault`, `codebase_map`, `bound_at`, `strict` — NO `binding_metadata.codebase_map_provenance` field anywhere in the template.
- `plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md` — `grep binding_metadata|codebase_map_provenance` returns **zero matches**. The contract template itself doesn't include the field.

**Consumer attempts to read it:**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md:151-154` — Step 3 chain optimization reads `binding_metadata.codebase_map_provenance` from binding.md header.
- Behavior path: since the field is never present, every binding.md falls through to "IF `no-snapshot` OR binding.md absent OR field unparseable → keep scan-codebase in chain" — the Iter 53 optimization is **silently dead code**.

**Fix-forward needed (next iter):**
1. Add `binding_metadata:` block to the binding.md template in `bind-codebase/SKILL.md` Step 4 (lines 369-376), including `codebase_map_provenance:` and the existing `constitution_hash` (line 305 prose).
2. Add same block to `binding-contract.md` canonical template.
3. Or alternatively: orchestrate-flow Step 3 must scan body, not just header — but bind-codebase still has to write the value somewhere first.

**Why this is the regression Iter 53 was supposed to close:** Iter 53 was the proactive fix-forward sweep that wired the consumer side in orchestrate-flow Step 3. It correctly identified `codebase_map_provenance` as a producer-only emission. It added the consumer logic. But it didn't verify the producer's binding.md template actually emits the field. Same pattern as Iter 43/48/52 — fixed the missing half but not the half that was missing on the producer template.

---

### P2 MEDIUM

#### P2-1 — `handoff-contract.md` not extended with emit-fsd / install-deps per-skill emission blocks

**Severity:** P2 MEDIUM — consumer-side contract drift; new metrics fields (sections_emitted, tools_audited, detected_os, etc.) are documented inside each new SKILL.md but not registered in the canonical handoff schema.

**Producer claim:**
- `plugins/mega-sdd/skills/emit-fsd/SKILL.md:170-177` — declares 7 new metrics fields (sections_emitted, sections_excluded, citations_count, drift_callouts_count, mode, pdf_emitted, fallback_format).
- `plugins/mega-sdd/skills/install-deps/SKILL.md:202-209` — declares 7 new metrics fields (tools_audited, tools_already_present, tools_installed, tools_failed, tools_sudo_pending, detected_os, detected_pkg_mgr).

**Consumer reality:**
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` lists §Per-skill expected emissions for: extract-intelligence (line 246), generate-intent (266), scan-codebase (288), bind-codebase (311), generate-units (333), execute-bolts (362), diff-vault (392), emit-agents-md (422), resolve-oq (448), detect-drift (477).
- **NO section for `emit-fsd` or `install-deps`.** New skills land without contract registration.
- Iter 33 F4 type-check enforceability gate (line 227) — fields without TYPE annotation bypass type-check. New skills' metrics are warn-only by default. Acceptable degradation but the canonical contract should still register them.

**Per Iter 38 audit D3-002 (artifact_missing) — line 111:** the contract validates artifact existence at orchestrator boundary. emit-fsd's handoff says `FSD.pdf` as artifact but when fallback to HTML happens, the listed path is `FSD.html`. The contract's existence check would fire halt `artifact_missing` on FSD.pdf when pandoc skipped — emit-fsd's handoff emission needs conditional artifact path logic; this isn't documented in handoff-contract.md as a known per-skill variant.

#### P2-2 — `install-deps` missing from `predictive-checks.md` catalog

**Severity:** P2 MEDIUM — install-deps declares its own pre-flight (SKILL.md:38-40) but doesn't register them in the orchestrate-flow predictive-checks catalog. Orchestrator Step 3.5 only runs catalog checks; bypasses install-deps preflight entirely when invoked under `--auto`.

**Producer claim:**
- `plugins/mega-sdd/skills/install-deps/SKILL.md:38-40` — preflight checks: `pkg_mgr_detected`, `memory_writable`.

**Consumer reality:**
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` has sections for: scan-codebase (36), bind-codebase (52), execute-bolts (68), generate-intent (84), detect-drift (93), diff-vault (116), resolve-oq (139), extract-intelligence (162), emit-agents-md (185), emit-fsd (201), memory (224).
- **NO `## install-deps preflight checks` section.** When install-deps runs under `--auto`, orchestrate-flow Step 3.5 finds no catalog entry → silently skips preflight. install-deps' own Step 1 still runs its checks, but the orchestrator-level pre-chain validation gate doesn't see them.

**Note:** install-deps is currently not part of the auto-diagnostic chain (orchestrate-flow Step 6 table at lines 354-361 doesn't list it). If it's never invoked under `--auto` by orchestrate-flow itself, the catalog gap may be tolerable. But install-deps DOES declare a `--auto` flag (line 26) + handoff emission (line 186), implying it expects to be orchestratable. Pick one: either remove `--auto`/handoff support OR register preflight in the catalog.

#### P2-3 — `install-outcomes.md` not registered in `memory-schema.md` PROJECT scope file table

**Severity:** P2 MEDIUM — install-deps writes a new memory file that the memory subsystem's canonical schema doesn't know about. Memory operations (`/mega-sdd:memory list / show / search / review / prune / promote / diff / export / import / clear`) would miss this file.

**Producer claim:**
- `plugins/mega-sdd/skills/install-deps/SKILL.md:31` — output artifact: `<project>/.mega-sdd/memory/install-outcomes.md`.
- `install-deps/SKILL.md:154-158` (Step 7) — acquires `install-outcomes.md.lock`, appends run record.
- `install-deps/SKILL.md:61-67` (Step 2) — reads memory file for 30-day cache.

**Consumer reality:**
- `plugins/mega-sdd/skills/memory/references/memory-schema.md` §3 PROJECT scope (lines 48-53) lists: `decisions.md`, `conventions.md`, `outcomes.md`, `routing-outcomes.md`. **NO `install-outcomes.md` row.**
- `grep install-outcomes plugins/mega-sdd/skills/memory/` returns **zero matches** — memory subsystem has no awareness of this file.

**Impact:** `/mega-sdd:memory list --scope=project` will not enumerate install-outcomes.md. `memory prune` won't garbage-collect it. `memory export` won't include it. Schema-version stamping (memory-schema.md §1) won't validate it on a future migration.

**Fix-forward:** add row to memory-schema.md §3 PROJECT scope table: `install-outcomes.md | Native dep install run records | Markdown chronological log | Gitignored (per-machine; PATH-dependent)` — plus add §4 per-file schema block with the row format spec written in install-deps SKILL.md spec §9.

---

### P3 LOW

#### P3-1 — `tooling-install.md` and `tool-matrix.yaml` document overlapping content with no cross-link

**Severity:** P3 LOW — wording drift; two install reference files coexist without acknowledgment.

**Status:**
- `plugins/mega-sdd/references/tooling-install.md` — user-facing manual install reference, still actively cited by scan-codebase:182, diff-vault:474+514, commands/lint-units.md:163.
- `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml` — new (Iter 55) machine-readable install matrix consumed by install-deps SKILL.md:59.
- Neither file references the other. `tooling-install.md` does not point readers to "run `/mega-sdd:install-deps` for auto-install"; `tool-matrix.yaml` does not document fallback to manual instructions.

**Fix-forward:** add cross-reference notes at top of each file ("for auto-install see tool-matrix.yaml" / "for manual install steps see tooling-install.md").

#### P3-2 — Orphan reference file: `bind-codebase/references/conflict-resolution.md`

**Severity:** P3 LOW — declared reference file with no consumer.

**Status:**
- `plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md` exists.
- `grep -rl conflict-resolution plugins/mega-sdd/` returns ONLY the file itself — no SKILL.md or other reference imports it.

**Possible cause:** likely a pre-resolve-oq-skill era artifact. Conflict resolution was lifted out of bind-codebase into the resolve-oq skill in earlier iter. This reference file appears to be a leftover.

**Fix-forward:** either delete the file, OR add `## See also` link from `bind-codebase/SKILL.md` or `references/binding-contract.md`.

---

## Confirmed clean (producer→consumer wirings verified)

These wirings were spot-checked and found to have both producer emit + consumer read paths in actual procedure bodies (not just prose narration):

| Field / Artifact | Producer | Consumer | Verdict |
|---|---|---|---|
| `acceptance_test_concern` (bolt self-assess) | bolt-dispatch-prompt.md:73 (instruction) + bolt subagent emits in bolt-report.md | execute-bolts SKILL.md:588-594 (post-flight scan) → handoff metrics → orchestrate-flow:375 (Step 7 summary surface) + emit-fsd section-mapping.md:150,162 | OK — Iter 53 producer-consumer chain fully wired |
| `_authored_by` (acceptance_test provenance) | generate-units SKILL.md:456-458 + adversarial-test-prompt.md:78-82 | execute-bolts SKILL.md:163 (dispatch-prompt NOTE injection); generate-units --regenerate preserves `human` (SKILL.md:471) | OK |
| `Last_Scanned_Sha256` (per-file source hash) | scan-codebase codebase-map-schema.md:31 + SKILL.md:137-139 (writer) | scan-codebase SKILL.md:137-139 (shallow-scan reader); emit-fsd section-mapping.md:130,134 (citation footer) | OK |
| `vault.json.lock` (concurrency lock) | vault-contract.md §Concurrency contract (canonical) | generate-intent SKILL.md:544; bind-codebase SKILL.md:470; diff-vault SKILL.md:361; resolve-oq SKILL.md:217 — all 4 writers wired | OK — Iter 49 propagated everywhere |
| `codebase-map.snapshot.json` (scan→bind hop) | scan-codebase SKILL.md:431-454 (Step 10.6 write) | bind-codebase SKILL.md:38-44 (Step 1 read) | OK — Iter 46 hop functional |
| `extracted-kb.snapshot.json` (extract→intent hop) | extract-intelligence SKILL.md:213,220 (Step 5.5 write) | generate-intent SKILL.md:44 (--kb preflight read) | OK |
| `vault_present_for_fsd` predictive check | emit-fsd SKILL.md:39 (own preflight) | orchestrate-flow predictive-checks.md:203-208 (registered in catalog) | OK |
| emit-fsd integration with orchestrate-flow Step 6 | emit-fsd SKILL.md handoff emission | orchestrate-flow SKILL.md:360 (auto-integrated diagnostics table) | OK |

---

## Producer-Consumer Matrix (Iter 54+55+regression-class)

| Field/Artifact | Iter | Producer (file:line) | Consumer (file:line) | Status |
|---|---|---|---|---|
| `acceptance_test_concern:` | 47/53 | bolt-dispatch-prompt.md:73 | execute-bolts:588-594 → orchestrate-flow:375 | WIRED |
| `_authored_by:` | 47 | generate-units:456-458 | execute-bolts:163 (dispatch NOTE) | WIRED |
| `Last_Scanned_Sha256` | 46 | scan-codebase:137-139 | scan-codebase:138 (shallow); emit-fsd:130 | WIRED |
| vault.json lock | 49 | vault-contract.md §Concurrency | gen-intent:544 / bind:470 / diff:361 / resolve:217 | WIRED |
| `codebase-map.snapshot.json` | 46 | scan-codebase:431 | bind-codebase:39 | WIRED |
| `extracted-kb.snapshot.json` | 46 | extract-intelligence:213 | generate-intent:44 | WIRED |
| `binding_metadata.codebase_map_provenance` | 46/53 | bind-codebase:41-43 (PROSE ONLY) **NOT IN TEMPLATE** | orchestrate-flow:151-154 (reads non-existent field) | **P1 BROKEN** |
| emit-fsd handoff metrics block | 54 | emit-fsd:170-177 | handoff-contract.md (per-skill block MISSING) | **P2 DRIFT** |
| install-deps handoff metrics block | 55 | install-deps:202-209 | handoff-contract.md (per-skill block MISSING) | **P2 DRIFT** |
| install-deps preflight | 55 | install-deps:38-40 | predictive-checks.md (no catalog entry) | **P2 DRIFT** |
| `install-outcomes.md` memory file | 55 | install-deps:31,154 (writer) + 61 (reader) | memory-schema.md §3 PROJECT scope (file NOT LISTED) | **P2 DRIFT** |
| `conflict-resolution.md` reference | pre-Iter-49 | bind-codebase/references/ | (no consumer) | **P3 ORPHAN** |
| `tooling-install.md` vs `tool-matrix.yaml` | 55 | both exist, no cross-link | scan/diff cite tooling-install only | **P3 OVERLAP** |

---

## Recommended next-iter actions (prioritized)

1. **P1-1 closure (highest)**: amend `bind-codebase/SKILL.md` Step 4 binding.md template to actually emit `binding_metadata:` block including `codebase_map_provenance`. Same for `references/binding-contract.md` template. Without this, Iter 53 chain optimization is dead code that always falls through to no-op.
2. **P2-1**: add `emit-fsd` and `install-deps` per-skill emission blocks to `handoff-contract.md §Per-skill expected emissions` (between emit-agents-md and resolve-oq makes sense for emit-fsd; install-deps at end as bootstrap).
3. **P2-2**: add `## install-deps preflight checks` section to `predictive-checks.md` with `pkg_mgr_detected` + `memory_writable` checks, mirroring install-deps SKILL.md:38-40.
4. **P2-3**: add `install-outcomes.md` row to `memory-schema.md` §3 PROJECT scope file table; add §4 per-file schema spec block.
5. **P3-1**: cross-link `tooling-install.md` ↔ `tool-matrix.yaml`.
6. **P3-2**: delete `bind-codebase/references/conflict-resolution.md` or re-attach as cited reference.

All 6 actions are tight-scope text edits; estimated 1 iter to ship all.
