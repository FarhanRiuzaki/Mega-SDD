# Reading Map — Where to Look at Each Pipeline Stage

> **Companion to `paths.md`**: paths.md tells skills WHERE to write; this doc tells users WHERE to read.
>
> **Convention**: ⭐ marks the primary entry-point per stage. Read that first.

## Contents

- Pre-pipeline (your inputs)
- Stage 1 — After extract-intelligence (legacy-rebuild only)
- Stage 2 — After generate-intent
- Stage 3 — After scan-codebase
- Stage 4 — After bind-codebase
- Stage 5 — After generate-units
- Stage 6 — After execute-bolts
- Stage 7 — Cross-cutting + interop
- Phase 2+ workflow (after Phase 1 completes)
- E2E one-liner
- See also

## Pre-pipeline (your inputs)

| What | Where | Read when |
|---|---|---|
| Project requirements | `<project>/prd.md` (your file) | Before any mega-sdd run |
| Legacy codebase | `<project>/legacy-code/` OR `old-reference/_source/` | Before extract-intelligence |

## Stage 1 — After extract-intelligence (legacy-rebuild only)

Path root: `<project>/.mega-sdd/knowledge-base/`

| What | Where | Read when |
|---|---|---|
| ⭐ Roll-up + critical findings | `README.md` | Start here |
| Per-domain extraction (11-section template) | `10-domains/<domain>.md` | Understanding what legacy did |
| Cross-domain flows | `20-workflows/<workflow>.md` | Tracing user journeys |
| Legacy data model | `30-data-model/conceptual-erd.md` | As-is data shape |
| Business rules | `40-business-rules/<rule>.md` | Per-rule detail |
| Integrations | `50-integrations/<integration>.md` | External system contracts |
| ⭐ **Phased rebuild plan (Phase 1/2/3+)** | `99-rebuild-architecture/suggested-phasing.md` | Planning Phase 2+ work |
| Proposed new ERD | `99-rebuild-architecture/suggested-erd.md` | Target data shape |
| What's locked vs free to redesign | `99-rebuild-architecture/data-mutation-policy.md` | ERD freedom decisions |
| Module dependency graph | `99-rebuild-architecture/module-dependency-graph.md` | Build ordering |

## Stage 2 — After generate-intent

Path root: `<project>/.mega-sdd/vaults/<slug>/`

| What | Where | Read when |
|---|---|---|
| ⭐ Vault entrypoint + Phase context | `vault.md` (legacy vaults: `00-index.md`) | Start here every session |
| Feature scope (Phase N) | `vault.md ## Overview` | What you're building NOW |
| Components + APIs | `vault.md ## Architecture` | Component contracts |
| Data shape | `model.md` | Per-entity fields + relations |
| User flows | `flows.md` | Happy paths + edge cases |
| Decisions log | `vault.md ## Decisions` | Why decisions were made |
| Constraints | `constraints.md` | NFRs + compliance + technical |
| Project rules | `constitution.md` (v1.8+, if present) | Security/compliance/anti-patterns |
| Open questions | `vault.json` `oqs[]` | What needs answering |
| Phase manifest | `vault.json` `phase` + `phase_total` | Which phase this vault covers (v3.26+) |

## Stage 3 — After scan-codebase (on-demand / classic spine — the express default binds without this stage)

Path root: `<project>/.mega-sdd/codebase/`

| What | Where | Read when |
|---|---|---|
| ⭐ Codebase map | `codebase-map.md` | Understanding existing code |
| Starterkit context (v3.23+) | `starterkit-context.yaml` | Your stack's auth/RBAC/UI patterns |

## Stage 4 — After bind-codebase

Path root: `<project>/.mega-sdd/vaults/<slug>/`

| What | Where | Read when |
|---|---|---|
| ⭐ Implementation State Map | `binding.md` §Implementation State Map | What's IMPLEMENTED / NEW / PARTIAL |
| Per-claim binding evidence | `binding.md` body | Why each claim was classified |

## Stage 5 — After generate-units

Path root: `<project>/.mega-sdd/vaults/<slug>/units/`

| What | Where | Read when |
|---|---|---|
| ⭐ Unit roll-up | `_index.md` | All units + their dependencies |
| Atomic work unit | `U-XXX.md` (per unit) | Specific task before bolt execution |
| Squad partition | `_meta/squads.yaml` (multi-squad) | Team coordination |

## Stage 6 — After execute-bolts

Path root: `<project>/.mega-sdd/vaults/<slug>/bolts/`

| What | Where | Read when |
|---|---|---|
| ⭐ Batch roll-up | `_summary.md` | Overall outcome |
| Per-unit outcome | `U-XXX/bolt-report.md` | Specific bolt's tests + commits + drift |
| Dispatch context (debugging) | `U-XXX/dispatch-prompt.md` | What the AI executor saw |
| Pre/post snapshots | `U-XXX/preflight.json` + `postflight.json` | Drift detection input |

## Stage 7 — Cross-cutting + interop

| What | Where | Read when |
|---|---|---|
| ⭐ Tool-agnostic AI context | `<repo-root>/AGENTS.md` | Other AI tools (Continue, Cursor, Aider) consume this |
| Drift report (after detect-drift) | `<vault>/DRIFT-REPORT.md` | Code-vs-vault divergence |
| Vault diff (after diff-vault) | `<vault>/VAULT-DIFF.md` | Cross-revision vault changes |
| 🔄 Sync run report (after /mega-sdd:sync) | `<vault>/SYNC-REPORT.md` | What the last sync applied vs queued + the closing staleness verification |
| 🔄 Pending sync decisions | `<vault>/PENDING-SYNC.md` | Human-only decisions an autonomous sync deferred (CONFLICTs, drift direction calls, vault patch drafts) |
| Dirty-paths journal (ambient) | `.mega-sdd/codebase/.dirty-paths.jsonl` | Which files changed in-session since the last scan (consumed by sync; not for manual editing) |
| ⭐ Corporate FSD (after emit-fsd) | `<vault>/fsd/FSD.pdf` + `FSD.md` | Confluence-format FSD for stakeholder sign-off; upload PDF manually to Confluence |
| FSD citation trace (after emit-fsd) | `<vault>/fsd/.citation-map.json` | Audit which vault/units/bolts source each FSD section was grounded on. Writer: `scripts/build-citation-map.sh`; sanctioned reader: `scripts/build-citation-map.sh (--check-drift mode)` (the model consumes its drift lines, never the file) |

## Phase 2+ workflow (after Phase 1 completes)

When Phase 1 vault's bolts complete:

1. Read `<KB>/99-rebuild-architecture/suggested-phasing.md` §Phase 2
2. Run `generate-intent --kb=<KB> --phase=2` to bootstrap Phase 2 vault (v3.26+)
3. Pipeline proceeds: bind-codebase → generate-units → execute-bolts (for Phase 2 scope)
4. Repeat for Phase 3+

`vault.json.phase` tells you which phase the current vault represents. The vault.md §Phase context surfaces this at the top of the vault for at-a-glance discovery.

## E2E one-liner

`legacy-code/ → KB (.mega-sdd/knowledge-base/) → vault per phase (.mega-sdd/vaults/<slug-phase-N>/) → bind+units+bolts inside that vault → AGENTS.md (repo root) for interop`

## See also

- `paths.md` — implementer-facing per-skill write paths (this doc's inverse)
- `plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md` — KB structure spec
- `plugins/mega-sdd/skills/generate-intent/references/vault-core.md` — vault structure spec (§schema/§OQ/§constitution/§id-stability); conditional overlays (§Starterkit-binding/§Multi-scope) in `vault-contract.md`
