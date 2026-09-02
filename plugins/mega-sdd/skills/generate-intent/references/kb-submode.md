# generate-intent — Mode B KB sub-mode (`--kb=<path>`)

## Contents
- What the KB sub-mode is
- Grammar detection (PRD-kontrak vs legacy numbered tree)
- KB freshness preflight
- Consumption — PRD-kontrak grammar
- Consumption — legacy numbered-tree grammar
- Tier-aware routing per claim
- ERD freedom
- KB Q&A loop
- KB auto-detection

## What the KB sub-mode is

Invocation: `generate-intent --kb=.mega-sdd/knowledge-base/`. Consumes a
`mega-sdd:extract-intelligence` output as the legacy-rebuild brief.

The KB is treated as **ANALYSIS INPUT, not a 1:1 spec.** Vault output
emphasizes REENGINEERING goals + business intent; legacy detail surfaces only
when the `[LOCKED]` tier requires preservation. Per the governing directive:
"code dan ERD bisa berubah, tapi goals reengineering nya terpenuhi, jika tidak
ada ketentuan erd harus 1:1" (code and ERD may change as long as the
reengineering goals are met; ERD need not be 1:1 unless a rule requires it).

The KB sub-mode shares the SAME vault contract
(`generate-intent/references/vault-contract.md`) as Mode A and Mode B
free-text; only input parsing differs.

## Grammar detection (PRD-kontrak vs legacy numbered tree)

Two KB grammars exist on disk; detect ONCE, deterministically:

- `<kb>/census.json` present (or `<kb>/modules/*.prd.md` exists) →
  **PRD-kontrak grammar** (extract-intelligence v2 — census-contracted,
  one PRD per module).
- Otherwise → **legacy numbered-tree grammar** (`00-overview/` …
  `99-rebuild-architecture/`). Pre-existing KBs keep working unchanged.

## KB freshness preflight (advisory, OPT-IN)

- **PRD-kontrak:** `census.json` carries per-file `sha256` for every legacy
  source file. Recompute against the legacy codebase when reachable
  (`legacy_root` in the census): all match → log confirmed; some drifted →
  warn "KB may be stale: N of M source files changed since extraction —
  consider re-running extract-intelligence". **DO NOT halt.** Legacy root
  unreachable → advisory "legacy source not reachable; freshness unchecked".
- **Legacy tree:** check `<kb>/.shared-snapshots/extracted-kb.snapshot.json`
  `source_files_sha256_map` the same way; absent → "no freshness snapshot;
  treating as fresh".

KB consumption correctness is unchanged whether the check confirms/warns/skips.

## Consumption — PRD-kontrak grammar

1. **Read `README.md` first** — extract the `Reengineering Opportunities`
   section + the `Mutability Tier Distribution` table + the module
   quick-reference (recommended rebuild ORDER — module is the phasing unit).
2. **Read `<kb>/data-mutation-policy.md`** (KB root) when present — drives ERD
   freedom. Absent = no `[LOCKED]` entities were found → all-`[INTENT]`
   default.
3. **Read every `modules/*.prd.md`** — frontmatter (classification,
   criticality, `depends_on`, counts) + body claims. Confidence is
   default-verified: an UNMARKED cited claim routes as `[VERIFIED]`; only
   `[INFERRED]`/`[OPEN]` are tagged. Mutability tags as written; an untagged
   claim defaults to `[INTENT]`.
4. **`stages:` blocks** in a module PRD's §3 Flow are copied VERBATIM into the
   matching `flows.md` flow with the back-reference
   `_kb_source: [modules/<domain>.prd.md]` (followed by
   `validate-vault-flow-staging.sh` to prove staging was not dropped), and the
   matching Mermaid `stateDiagram` is emitted — never re-flatten.
5. **Multi-module scoping:** there is no `--phase` lane in this grammar —
   module IS the phasing unit. Consuming ALL modules is the default; to scope
   a vault to a subset, generate per the README's recommended order and record
   out-of-scope modules as explicit constraints/OQs, or point Mode A at a
   single module PRD. A `--phase=N` flag against a PRD-kontrak KB → log
   "PRD-kontrak KB has no phase lane (module = phasing unit); flag ignored"
   and proceed (never halt).
6. **README `## ERD` / `## System Flow`** (multi-module) seed
   `02-architecture.md` boundaries + `flows.md` skeletons — the rebuild shape,
   with legacy shape as reference only.
7. **`<kb>/decisions/ADR-*.md` with `Status: accepted`** (7.14.0, architecture
   advisor — `plugins/mega-sdd/references/architecture-advisor.md`): a recorded
   human decision is a legitimate input document (same source class as a PRD) —
   its `## Claims` block flows into the vault with the ADR as the citation, and
   its topology seeds the target-architecture side of `02-architecture.md`.
   `Status: proposed` is NEVER consumed as a decision — surface it as an OQ
   ("arsitektur target belum diputuskan — ADR-NNN masih proposed"). No
   `decisions/` dir = nothing to do (the advisor is optional).

## Consumption — legacy numbered-tree grammar

1. Read the KB README (`Reengineering Opportunities` + `Mutability Tier
   Distribution`); no tier markers at all (pre-v1.4 KB) → treat all claims as
   `[INTENT]`.
2. Read `99-rebuild-architecture/data-mutation-policy.md` (ERD freedom;
   absent → all-`[INTENT]`).
3. Read the `10-domains` files; extract claims with confidence + mutability
   markers (this grammar writes explicit `[VERIFIED]` tags).
4. `--phase=N`: read `99-rebuild-architecture/suggested-phasing.md`, count
   `## Phase` headings → `phase_total`; out-of-range N → invocation-time
   error; absent/zero headings → single-phase fallback. Persist
   `phase`/`phase_total` to vault.json.
5. `99-rebuild-architecture/suggested-system-flow.md` seeds architecture +
   flow skeletons; `module-dependency-graph.md` recorded as the vault.md
   frontmatter pointer `kb_module_graph: <path>` (read by generate-units);
   `50-integrations/` — every contract becomes a `[LOCKED]` constraint or a
   templated OQ. Never silently dropped: an extraction that found integrations
   MUST surface every one of them as constraint or OQ.

## Tier-aware routing per claim

| Marker pair | Vault treatment | Vault location |
|---|---|---|
| `[VERIFIED][LOCKED]` (PRD-kontrak: unmarked-cited + `[LOCKED]`) | Verbatim — exact legacy field name, type, constraint preserved | `02-architecture.md` + Hard Rule emission for execute-bolts; tagged `mutability_source: kb_locked` |
| `[VERIFIED][INTENT]` (unmarked-cited + `[INTENT]`/untagged) | Outcome goal — state transition + business rule preserved; implementation references rebuild proposal | `vault.md ## Architecture` (rebuild shape) + `flows.md` (outcome); tagged `mutability_source: kb_intent` |
| `[VERIFIED][ARTIFACT]` | Vault `## Open Questions` — default "discard unless preserve required" | `constraints.md ## Open Questions`; tagged `mutability_source: kb_artifact`, default resolution: discard |
| `[INFERRED][LOCKED]` | Single confirmation question (high stakes); default "keep as LOCKED" pending user veto | OQ until confirmed, then promoted per the `[VERIFIED][LOCKED]` rule |
| `[INFERRED][INTENT]` | Vault body with note "INFERRED — confirm in dev"; outcome already captured | `flows.md` with `[INFERRED]` annotation |
| `[INFERRED][ARTIFACT]` | Skip the vault entry entirely; log to `_diagnostics/kb-skipped-artifacts.md` | Diagnostic only |
| `[OPEN][?]` | Vault `Open Question` — answering resolves both axes | `constraints.md ## Open Questions` |
| §6 entry already `[x]`-resolved (KB-stage resolution via resolve-oq KB mode, 7.21.0) | Vault OQ born PRE-RESOLVED — the tag, the stakeholder answer, and its `Resolved (stakeholder, <date>)` provenance carried verbatim; the deriver maps `[x]` → `resolved` automatically | `constraints.md ## Open Questions` as `[x]`; a §6 `[~]` carries over as out-of-scope |

## ERD freedom

- **PRD-kontrak:** the README `## ERD` (multi-module) or the module PRD's §4
  entities (single-module) propose the rebuild shape. `[LOCKED]`
  entities/fields from `<kb>/data-mutation-policy.md` retain the legacy shape
  verbatim (name, type, constraints, validation rules).
- **Legacy tree:** `99-rebuild-architecture/suggested-erd.md` is the proposed
  new shape — NOT the legacy `30-data-model/conceptual-erd.md`; same
  `[LOCKED]` exception via `data-mutation-policy.md`.

## KB Q&A loop

Shorter than free-text Mode B because the KB covers most gaps. Aim ≤5
questions. Primary targets:

- `[INFERRED][LOCKED]` items (highest stakes — confirm the preservation requirement).
- `[ARTIFACT]` items flagged for discard (confirm with the user before discarding).
- Reengineering Opportunities (confirm the rebuild team accepts the proposal).

## KB auto-detection

Priority order, first hit wins: `.mega-sdd/knowledge-base/README.md`
(canonical default) → `docs/knowledge-base/README.md` (legacy) →
`docs/mega-sdd/knowledge-base/README.md` →
`old-reference/knowledge-base/README.md`. If detected AND no `--from-prompt`
/ positional PRD argument → set `--kb=<detected-path>` implicitly. Confirm
with the user before proceeding.
