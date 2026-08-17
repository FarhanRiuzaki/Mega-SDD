# Halt-registry family split — P2a of the token-lard cuts (v6.14.0)

**Status:** SHIPPED v6.14.0 (2026-08-17, dfe1cef, CI green, both-tree suite 274/274). Round: 1 BLOCKER (subtype-taxonomy dismemberment — restored canonically) + 6 MAJOR folded; the round-hardened mirror guard immediately caught the pre-existing `pbt_property_violated` registry gap. Companion verdict: P2b (hot-SKILL diet) EVALUATED → REJECTED, `research/2026-08-17-p2b-skill-diet-verdict.md`.
**Evidence:** telemetry 2026-08-17 — `halt-protocol.md` loaded **165× across 27 sessions** (~6/session; 46,346 B ≈ 11.6k tok upper bound per full load, ~1.22M cumulative). The 2026-08-11 proposals doc (d) gated this split on exactly that measurement ("instrument → ukur → baru potong") — the bar is now met. P1 (v6.13.0) added read-range telemetry, so the win is verifiable after shipping.
**Depends on:** spec `2026-08-17-token-lard-cuts-p1.md` (SHIPPED v6.13.0).

## Design

`references/halt-protocol.md` (46.3KB) is one file serving two very different reads:
- **Envelope reads** (the majority — 11 of 15 anchored citations target `§halt-protocol`): schema, `next_action` shape, field rules, subtype enums. Needed by EVERY emitter and consumer.
- **Per-type guidance reads**: 83 entries averaging ~350B, each relevant only to the ONE phase that emits it. §Type-specific guidance alone is 29.3KB (63% of the file) — every envelope read pays for all 83 types.

**Split:** the registry keeps everything anchored/enum-bearing and gains a slim per-type INDEX; the long guidance prose moves to per-emitter family files:

```
references/halt-protocol.md          # CANONICAL — kept sections + NEW index
references/halt-families/intent-and-vault.md   # generate-intent, diff-vault, resolve-oq
references/halt-families/extract.md            # extract-intelligence (wave quality gates)
references/halt-families/scan.md               # scan-codebase (deep-scan, engine)
references/halt-families/bind.md               # bind-codebase (packs, constitution, OQ-verdict)
references/halt-families/units.md              # generate-units (dedup, hard-rule, squads, interfaces)
references/halt-families/bolts.md              # execute-bolts (B1-B4, review, verify_unit, ledger)
references/halt-families/flow.md               # orchestrate-flow / front door / sync (detect-drift) / memory / install-deps
references/halt-families/emit.md               # emit-* (citation, signoff, execution_fabricated, pdf)
```

**Round amendments (B1 + M-series, on the record):** the first implementation dismembered the `quality_gate_failed` subtype taxonomy (its 9 subtype bullets were promoted to standalone index rows under an over-claiming "every type is canonical-enum" preamble). Folded: the canonical `#### quality_gate_failed subtypes` section is RESTORED in the registry (enum + the "Consumer dispatch logic MUST branch on `details.subtype`" rule + family pointers), the 9 index rows carry an explicit *(subtype of `quality_gate_failed`)* marker, and the preamble scopes its enum claim. Index truncation that dropped the C1/soft stop class on 6 rows is repaired (class markers restored — the index is a recognition router; a truncated row must never read as ALWAYS-STOP). Twin entries (`diff_conflict`, `drift_framework_mismatch` — prose + absorbed one-liner) merged into single family sections. The toothed mirror guard immediately caught a REAL pre-existing gap: `pbt_property_violated` (emitted by the PBT post-flight, bridged by convergence loops) had never been registered — now indexed (bolts) with a sourced guidance body.

**Kept in `halt-protocol.md` (all currently-cited anchors survive):**
- `§halt-escalation-discipline` (C1/C2/C3) — cited.
- `§halt-protocol` envelope + Schema + Canonical `next_action` shape + Field rules + Multiple blockers + Backward compatibility — the 11-citation anchor.
- `§Type-specific schemas` (the YAML field blocks + subtype enums — `citation_unresolvable`, `mode_migrate` fields, etc.) — test-pinned enums stay greppable in the canonical file.
- **NEW `§Registry index`**: one row per halt type — `type` — emitter — stop class — distinguishing token(s) — `→ halt-families/<file>.md`. The row keeps each type's most-pinned token (e.g. `execution_fabricated` row names `ANNEX_FORGED`) so registry-existence greps in the test suite keep hitting the canonical file.

**Moved:** the ~83 guidance bodies, verbatim, each under a `### <type>` heading in its family file (headings make family files §-addressable; P1's range telemetry can then prove §-reads).

## Invariants

1. **Byte conservation** — every guidance entry's text appears verbatim in exactly one family file (mechanical split, zero rewording; the split script asserts this).
2. **Anchor survival** — `§halt-protocol`, `§halt-escalation-discipline`, `§Consumer`, the subtype enums, and every existing grep-pin (ANNEX_FORGED, execution_fabricated, citation_unresolvable, the PageRank tombstone pair, delta-lane 6a trio) still resolve against the files their tests read; where a pin's text moves, the INDEX row carries the pinned token — tests are amended ONLY where they asserted location, never existence.
3. **Routing** — family files are routed from the canonical registry (the index IS the router); skills citing `halt-protocol.md §<type>` semantics get the index row + pointer. One-level-deep rule: family files are reachable from halt-protocol.md which is a plugin-root reference (not a skill ref) — the SKILL-router rule does not apply to plugin-root references, matching the existing `references/*.md` topology.
4. **No behavior change** — halt semantics, stop classes, envelope fields all byte-identical; this is a storage split.
5. **Size targets (amended twice, on the record)** — halt-protocol.md ≤ **30KB** (final 29,846 from 46,346, −36%; the round's B1 fold added back the spec-mandated canonical subtype section + stop-class markers — correctness beat the first 28KB number); family files ≤ **12.5KB** (bolts 9,728 / flow 11,972 — `flow` deliberately kept ONE file rather than an artificial orchestrate-vs-maintenance subdivision; index one-liners capped at 90 chars because the index doubles as a recognition router that often avoids loading any family at all). A registry-only load (the common case) drops ~11.6k → ~7.5k tok; registry + median family ≈ ~8k; worst (flow) ≈ ~10.5k.

## Mechanics

A one-shot split script (scratchpad, not shipped) parses §Type-specific guidance, maps each entry to its family via the "emitted by `<skill>`" / `<skill>:` marker in its own text (hand-written fallback map for entries that name no emitter), writes the family files + index, rewrites halt-protocol.md, and ASSERTS byte-conservation before writing anything.

## Tests

NEW `tests/halt-registry/test-family-split.sh` (16 arms):
- every type named in the index has a `### <type>` section in its named family file, and vice-versa (no orphan guidance);
- halt-protocol.md ≤ 30,000 B; each family ≤ 12,800 B (the amended targets — see invariant 5);
- pinned tokens present: ANNEX_FORGED + execution_fabricated (index), citation_unresolvable, halt-displayer contract;
- the taxonomy mirror ASSERTS (round M5 — the first version computed and never asserted): every snake_case type the mirror names must exist in the registry; this immediately caught the pre-existing `pbt_property_violated` gap;
- subtype section restored + dispatch rule canonical + all 9 subtype rows marked (round B1);
- ALWAYS-STOP floor across family files ≥55 (semantic-flip tripwire, round minor);
- envelope anchors still head their sections; edit-here banners; split-actually-happened probe.

Existing suite: the 9 halt-protocol-reading tests run unmodified except where they pinned LOCATION of moved prose (each amendment named in the CHANGELOG).

## Non-goals
P2b (hot-SKILL diets) is its own release. No new halt types, no stop-class changes, no keterangan changes.
