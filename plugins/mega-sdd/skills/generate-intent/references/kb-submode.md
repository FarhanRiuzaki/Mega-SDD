# generate-intent — Mode B KB sub-mode (`--kb=<path>`)

## Contents
- What the KB sub-mode is
- KB freshness preflight
- KB consumption behavior
- `--phase=N` parsing + phasing
- Tier-aware routing per claim
- ERD freedom
- KB Q&A loop
- KB auto-detection

## What the KB sub-mode is

Invocation: `generate-intent --kb=.mega-sdd/knowledge-base/`. Consumes a `mega-sdd:extract-intelligence` knowledge base as the legacy-rebuild brief.

The KB is treated as **ANALYSIS INPUT, not a 1:1 spec.** Vault output emphasizes REENGINEERING goals + business intent; legacy detail surfaces only when the `[LOCKED]` tier requires preservation. Per the governing directive: "code dan ERD bisa berubah, tapi goals reengineering nya terpenuhi, jika tidak ada ketentuan erd harus 1:1" (code and ERD may change as long as the reengineering goals are met; ERD need not be 1:1 unless a rule requires it).

The KB sub-mode shares the SAME vault contract (`generate-intent/references/vault-contract.md`) as Mode A and Mode B free-text; only input parsing differs.

## KB freshness preflight (advisory, OPT-IN)

Before reading KB content, check whether `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` exists per `plugins/mega-sdd/references/shared-snapshot-schema.md §extract-intelligence (extracted-kb snapshot)`:

1. If the snapshot exists, read `source_files_sha256_map`.
2. For each `<repo-relative-path>` in the map, compute the current sha256 of that file in the legacy source codebase.
3. If ALL files match → log `"KB freshness: confirmed (<N> source files unchanged since extraction at <generated_at>)"`. Proceed.
4. If SOME files drifted → log a warning: `"KB may be stale: <drifted-count> of <total> source files changed since extraction (<generated_at>). Consider \`extract-intelligence --force\` to refresh KB before generating vault."`. **DO NOT halt** — the user retains agency to proceed (legacy stale-KB warnings should not block reengineering work).
5. If the snapshot is absent (older KBs OR snapshot write failed) → log advisory `"KB has no freshness snapshot; treating as fresh."`. Proceed.

KB consumption correctness is unchanged whether the check confirms / warns / skips.

## KB consumption behavior

1. **Read the KB README first** — extract the `Reengineering Opportunities` section + the `Mutability Tier Distribution` table. If the KB has no tier markers (older KB), treat all claims as `[INTENT]` (safe middle-ground).
2. **Read `99-rebuild-architecture/data-mutation-policy.md`** — this drives ERD freedom. Without this file, fall back to "all `[INTENT]`" default.
3. **Read the `10-domains` files** + extract claims with both confidence + mutability markers.

## `--phase=N` parsing + phasing

Default: `--phase=1` (when the flag is absent).

When `--kb` AND `--phase=N`:
a. Read `<KB>/99-rebuild-architecture/suggested-phasing.md`. Count `## Phase` heading occurrences → `phase_total`.
b. Validate `N` ≤ `phase_total`. If out of range → error message: "Phase <N> requested but suggested-phasing.md has only <phase_total> phases. Available: 1..<phase_total>." Halt the invocation (no halt-protocol envelope needed — invocation-time validation).
c. Read the `## Phase <N>` section content (scope + deliverables + acceptance criteria).
d. Scope vault generation to this phase's deliverables — extract claims from the KB filtered by Phase N's scope. Out-of-phase domains may still be cited but are not woven into Phase N's vault.
e. Persist: write `phase: N`, `phase_total: <phase_total>` to `vault.json` (the vault.json write step).

Defensive fallback: if `suggested-phasing.md` is absent OR has zero `## Phase` headers → log "no phasing detected in KB; treating as single-phase (phase: 1, phase_total: 1)" + proceed.

- When `--phase` is absent AND `--kb` is set → assume `--phase=1` AND set `phase_total` from `suggested-phasing.md` (or 1 if absent).
- When `--kb` is not set (Mode A / Mode B free-text) → always `phase: 1, phase_total: 1`.

The `00-index.md` §Phase context block that consumes these values is specified in the generation guide (routed from the SKILL router).

## Tier-aware routing per claim

| KB marker pair | Vault treatment | Vault location |
|---|---|---|
| `[VERIFIED][LOCKED]` | Verbatim — exact legacy field name, type, constraint preserved | `02-architecture.md` + Hard Rule emission for execute-bolts; tagged `mutability_source: kb_locked` |
| `[VERIFIED][INTENT]` | Outcome goal — state transition + business rule preserved; implementation references rebuild proposal | `02-architecture.md` (rebuild shape) + `04-flows.md` (outcome); tagged `mutability_source: kb_intent` |
| `[VERIFIED][ARTIFACT]` | Vault `## Open Questions` — default "discard unless preserve required" | `00-index.md` OQ section; tagged `mutability_source: kb_artifact`, default resolution: discard |
| `[INFERRED][LOCKED]` | Single confirmation question (high stakes); default "keep as LOCKED" pending user veto | OQ until confirmed, then promoted per the `[VERIFIED][LOCKED]` rule |
| `[INFERRED][INTENT]` | Vault body with note "INFERRED — confirm in dev"; outcome already captured | `04-flows.md` with `[INFERRED]` annotation |
| `[INFERRED][ARTIFACT]` | Skip the vault entry entirely; log to `_diagnostics/kb-skipped-artifacts.md` | Diagnostic only |
| `[OPEN][?]` | Vault `Open Question` — answering resolves both axes | `00-index.md` OQ section |

## ERD freedom

Vault `02-architecture.md` uses `99-rebuild-architecture/suggested-erd.md` as the proposed new shape — NOT the legacy `30-data-model/conceptual-erd.md`. **Exception:** `[LOCKED]` entities/fields from `data-mutation-policy.md` retain the legacy shape verbatim (name, type, constraints, validation rules).

## Rebuild-architecture + integrations consumption (every extraction output lands somewhere)

The remaining `99-rebuild-architecture/` synthesis files and the integrations domain are consumed here — no extraction wave's output is write-only:

| KB source | Vault treatment | Vault location |
|---|---|---|
| `99-rebuild-architecture/suggested-system-flow.md` | Proposed component/flow shape — the peer of suggested-erd for behavior: seed `02-architecture.md` component boundaries + `04-flows.md` system-flow skeletons from it (legacy flow shape is reference, not the target) | `02-architecture.md` + `04-flows.md` |
| `99-rebuild-architecture/module-dependency-graph.md` | Carried as a vault pointer for unit decomposition — record the KB path under `00-index.md` §Implementation Notes (`kb_module_graph: <path>`); `generate-units` reads it as a module-grouping + dependency seed | `00-index.md` §Implementation Notes (pointer) |
| `50-integrations/` | Each external contract becomes EITHER a `06-constraints.md` integration constraint (when `[LOCKED]` — wire format/SLA preserved verbatim) OR a templated OQ ("preserve legacy contract `<name>` in the rebuild? — evidence: `50-integrations/<file>`") when `[INTENT]`/`[ARTIFACT]`. Never silently dropped: an extraction wave that found integrations MUST surface every one of them as constraint or OQ | `06-constraints.md` + `00-index.md` OQ section |

## KB Q&A loop

Shorter than free-text Mode B because the KB covers most gaps. Aim ≤5 questions. Primary targets:

- `[INFERRED][LOCKED]` items (highest stakes — confirm the preservation requirement).
- `[ARTIFACT]` items flagged for discard (confirm with the user before discarding).
- Reengineering Opportunities (confirm the rebuild team accepts the proposal).

## KB auto-detection

Priority order, first hit wins: `.mega-sdd/knowledge-base/README.md` (canonical default) → `docs/knowledge-base/README.md` (legacy) → `docs/mega-sdd/knowledge-base/README.md` → `old-reference/knowledge-base/README.md`. If detected AND no `--from-prompt` / positional PRD argument → set `--kb=<detected-path>` implicitly. Confirm with the user before proceeding.
