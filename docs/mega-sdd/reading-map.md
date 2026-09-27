# Reading Map — Where to Look at Each Stage

> **Companion to `paths.md`** (`plugins/mega-sdd/references/paths.md`): paths.md tells skills WHERE to write; this doc tells users WHERE to read.
>
> **Convention**: ⭐ marks the primary entry-point per stage. Read that first.

## Contents

- Reading order (9.0)
- Pre-pipeline (your inputs)
- Stage 1 — The router
- Stage 2 — Direct / assisted lanes
- Stage 3 — After `plan` (guarded)
- Stage 4 — After `execute-bolts` (guarded)
- Stage 5 — After `/mega-sdd:sync`
- Stage 6 — Docs lanes (KB, team documents, interop)
- Legacy rebuild, module by module
- Pre-9.0 vaults (layout-2)
- E2E one-liner
- See also

## Reading order (9.0)

1. **Router** — which lane `/mega-sdd` picked, and why (Stage 1).
2. **Direct / assisted** — most tasks end here; the chat report is the result (Stage 2).
3. **`plan`** — guarded only: the vault + units (Stage 3).
4. **`execute-bolts`** — guarded only: per-unit binding, bolts, the delivery check (Stage 4).
5. **`/mega-sdd:sync`** — after the code moved on under an existing vault (Stage 5).
6. **Docs lanes** — KB, PRD / FSD / SIT / UAT, HTML, AGENTS.md; opt-in, any time (Stage 6).

Every lane ends with the same **result contract**, in chat: an acceptance-criterion → test table, `scripts/delivery-check.sh` `VERDICT: PASS` on the final commit, and the list of assumptions and decisions made. Whichever lane ran, read that first.

## Pre-pipeline (your inputs)

| What | Where | Read when |
|---|---|---|
| Project requirements | `<project>/prd.md` (your file) or a quoted free-text brief | Before any mega-sdd run |
| Legacy codebase | `<project>/legacy-code/` OR `old-reference/_source/` | Before extract-intelligence |

## Stage 1 — The router

`/mega-sdd <prd|brief>` runs `scripts/route-lane.sh` first. It is read-only and writes nothing, not even `.mega-sdd/`.

| What | Where | Read when |
|---|---|---|
| ⭐ Lane line | chat — direct/assisted open with one lane line naming the fired signals, e.g. `lane: direct (signals: none) · naik ke pipeline: /mega-sdd <input> --guarded`; guarded opens with the proposed chain and ONE confirmation | Every PRD/brief run |
| Router verdict | `route-lane.sh` stdout — one JSON line `{lane, signals_fired, evidence, override}` | Why this lane was picked |
| Signals | `plugins/mega-sdd/scripts/route-lane.sh` header — `vault_present` → guarded; `existing_code` / `spec_open_items` / `security_surface` / `multi_flow` → assisted; none → direct | Checking what fires a lane |

Force a lane with `--direct` / `--assisted` / `--guarded`; `--lite` implies `--guarded`.

## Stage 2 — Direct / assisted lanes

Path root: none — these lanes write nothing under `.mega-sdd/`.

| What | Where | Read when |
|---|---|---|
| ⭐ Result report | chat — criterion → status → covering test table, the delivery-check `VERDICT:` line, assumptions and decisions, commits | End of the run |
| Code + tests | the commits the report names (`git log`) | Review |
| Delivery check | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/delivery-check.sh" --cwd=<root>` (fresh checkout of HEAD; re-run any time) | Before merging |
| Blind review (assisted only) | chat — findings as `severity \| file:line \| issue`; Critical/Important fixed, Minor reported | Assisted runs |
| Procedure | `plugins/mega-sdd/references/direct-lane.md` | What the lanes do, what they never do, when they escalate to guarded |

## Stage 3 — After `plan` (guarded)

Path root: `<project>/.mega-sdd/vaults/<slug>/`

| What | Where | Read when |
|---|---|---|
| ⭐ Vault entrypoint (layout-3) | `context.md` — sections Overview · Flows (`### F-*`, Mermaid + DoD) · Data model (DBML) · Constraints (NFR) · Decisions · Open Questions · AI Technical Decisions | Start here every session |
| Project rules | `constitution.md` | Security/compliance/anti-patterns (§A–§F) |
| Open questions | `context.md ## Open Questions` (the one OQ home); machine index `vault.json` `open_questions[]` + `open_questions_summary` | What needs answering |
| Phase manifest | `vault.json` `phase` + `phase_total` | Which phase this vault covers (legacy numbered-tree KB only; otherwise 1/1) |
| AI consumer protocol | `_meta/ai-consumer-guide.md` | Before an AI tool writes code against the vault |
| ⭐ Unit roll-up | `units/_index.md` | All units + their dependencies |
| Atomic work unit | `units/U-XXX.md` (per unit — `prd_source` + `context_source` citations, `## Claims` on brownfield) | Specific task before bolt execution |

Codebase context (GROUND, guarded only), path root `<project>/.mega-sdd/`:

| What | Where | Read when |
|---|---|---|
| Symbol index | `codebase/symbol-index.json` (`build-symbol-index.sh`; derived, recomputable) | What `plan` task-typed against and the JIT bind verdicts from |
| Routing digest | `state.json` (`derive-state.sh` / `ground.sh`) | What the status view (`/mega-sdd`, no arg) rendered |
| Legacy scan outputs | `codebase/codebase-map.md`, `codebase/starterkit-context.yaml` — no 9.0 writer; read when present | Pre-9.0 projects only |

## Stage 4 — After `execute-bolts` (guarded)

Path root: `<project>/.mega-sdd/vaults/<slug>/bolts/`

| What | Where | Read when |
|---|---|---|
| ⭐ Batch roll-up | `_summary.md` + the chat report (the result contract, incl. the delivery-check verdict) | Overall outcome |
| Per-unit binding | `U-XXX/binding.json` (`summary` verdict counts + `claims[]`, each with its verdict, anchor and any `resolution`; written by the JIT bind at dispatch — the gate itself reads `.mega-sdd/.validation-blockers.json`) | Why THIS unit was blocked/cleared |
| Per-unit outcome | `U-XXX/bolt-report.md` | Specific bolt's tests + commits + drift |
| Acceptance evidence | `U-XXX/acceptance.json` (criterion → test → verdict) | Which test covers which criterion |
| Dispatch context (debugging) | `U-XXX/dispatch-prompt.md` | What the AI executor saw |
| Pre/post snapshots | `U-XXX/preflight.json` + `postflight.json` | Hard-rule / drift detection input |
| Quarantine | `U-XXX/quarantine.json` | A unit parked on a deferred decision |

## Stage 5 — After `/mega-sdd:sync`

| What | Where | Read when |
|---|---|---|
| ⭐ Sync run report | `<vault>/SYNC-REPORT.md` | What the last sync applied vs queued + the closing staleness verification |
| 🔄 Pending sync decisions | `<vault>/PENDING-SYNC.md` | Human-only decisions an autonomous sync deferred (CONFLICTs, drift direction calls, vault patch drafts) |
| Drift report (after detect-drift) | `<vault>/DRIFT-REPORT.md` | Code-vs-vault divergence |
| Re-bound units | `<vault>/bolts/U-XXX/binding.json` (refreshed by `rebind-units.sh`; `--full-bind` = every unit) | Is the code still in line with the spec? |
| Vault diff (after diff-vault) | `<vault>/VAULT-DIFF.md` | Cross-revision vault changes (a PRD revision → `plan --regenerate`) |
| Dirty-paths journal (ambient) | `.mega-sdd/codebase/.dirty-paths.jsonl` | Which files changed in-session since the last sync (consumed by sync; not for manual editing) |

## Stage 6 — Docs lanes (KB, team documents, interop)

Opt-in, outside the build path.

### Legacy extraction (extract-intelligence)

Path root: `<project>/.mega-sdd/knowledge-base/`

| What | Where | Read when |
|---|---|---|
| ⭐ Roll-up + critical findings + **module quick-reference (recommended rebuild order)** | `README.md` | Start here |
| Extraction census: code files + sha256 + stacks + entry points + module claims | `census.json` | Verifying coverage / freshness |
| Per-module PRD-kontrak (6 sections: Purpose · Business Rules · Flow (Mermaid) · Data In/Out · Edge Cases & Gotchas · Open Questions) | `modules/<domain>.prd.md` | Understanding what legacy did |
| What's locked vs free to redesign | `data-mutation-policy.md` (present only when ≥1 `[LOCKED]` claim exists) | ERD freedom decisions |

Reading order: `README.md` → the module you'll rebuild first (`modules/<domain>.prd.md`) → `data-mutation-policy.md` if present. Citations are inline `path:line`; a cited claim with **no** marker is verified — only `[INFERRED]` / `[OPEN]` are tagged explicitly, and mutability tiers `[LOCKED]/[INTENT]/[ARTIFACT]` ride inline. The KB feeds `plan --kb=<KB>` (see Legacy rebuild below).

> **Pre-existing KBs** on the numbered tree (`00-overview/ … 99-rebuild-architecture/`) stay readable everywhere: start at `README.md`, domains under `10-domains/`, phasing under `99-rebuild-architecture/suggested-phasing.md`.

### Team documents + interop

| What | Where | Read when |
|---|---|---|
| ⭐ Corporate FSD (`/mega-sdd:emit fsd`) | `<vault>/fsd/FSD.pdf` + `FSD.md` | Confluence-format FSD for stakeholder sign-off; upload PDF manually to Confluence |
| PRD / SIT / UAT (`/mega-sdd:emit prd\|sit\|uat`) | `<vault>/prd/PRD.md` · `<vault>/sit/SIT.md` · `<vault>/uat/UAT.md` (+ xlsx) | Stakeholder review, SIT/UAT execution |
| Doc citation trace | `<vault>/<doc>/.citation-map.json` | Audit which vault/units/bolts source each section was grounded on. Writer: `scripts/build-citation-map.sh`; sanctioned reader: `scripts/build-citation-map.sh (--check-drift mode)` (the model consumes its drift lines, never the file) |
| Executive summary (`/mega-sdd:emit summary`) | `<target>/summary/SUMMARY.md` + its HTML | Presentations |
| Offline HTML (`/mega-sdd:emit html <file\|dir>`) | `<parent>/html/<stem>.html` | Sharing with people who don't run Claude |
| Tool-agnostic AI context (emit-agents-md) | `<repo-root>/AGENTS.md` | Other AI tools (Continue, Cursor, Aider) consume this |

## Legacy rebuild, module by module

`extract-intelligence` → KB → `plan --kb=<KB>` → `execute-bolts --all --lite`.

For PRD-kontrak KBs the **module is the phasing unit**. `plan --kb=<KB>` consumes ALL modules by default — one `context.md`, units written module by module in the README's recommended rebuild order. To scope a vault to a subset, declare each heading of an out-of-scope module in `context.md ## Coverage exclusions` (`- <module>.prd.md#"<heading>" — later tranche`) or raise an open OQ per heading carrying `[covers: <kb>/modules/<module>.prd.md#<slug>]` — a constraint row alone fails the plan-coverage rail, `plan_coverage_gap` — or point `plan` at a single module PRD (positional). `plan` detects the grammar (census.json present → PRD-kontrak lane).

Legacy numbered-tree KBs keep the `--phase` lane:

1. Read `<KB>/99-rebuild-architecture/suggested-phasing.md` §Phase 2
2. Run `plan --kb=<KB> --phase=2` into its own vault (`--vault=<dir>`; `plan` refuses to overwrite an existing `context.md` without `--regenerate`)
3. `execute-bolts --all --lite` for the Phase 2 scope
4. Repeat for Phase 3+

`vault.json.phase` tells you which phase the current vault represents.

## Pre-9.0 vaults (layout-2)

A classic-born vault (`vault.md` / `model.md` / `flows.md` / `constraints.md`, legacy `00-index.md … 06-constraints.md`, whole-vault `binding.md` + `bound/`) is still READ — the status view and `emit-*` work on it. To build or sync on it, `/mega-sdd` proposes `/mega-sdd:migrate-paths --vault-layout=3` (a legacy 7-file vault takes the `--vault-layout` rung to layout-2 first; then the mandatory full JIT re-bind); the old files are archived verbatim under `<vault>/_meta/archive/layout2/`, and each unit's prior verdicts land in `bolts/U-XXX/binding-migrated.json`. `_meta/squads.yaml` / `interfaces/` exist only on pre-9.0 multi-squad vaults (`plan` does not write them). Steps: `upgrade-from-old-version.md` §Upgrading to 9.0.

## E2E one-liner

`PRD/brief → route-lane.sh → direct | assisted (main session → commits → delivery-check PASS) | guarded (plan → .mega-sdd/vaults/<slug>/ context.md + units → execute-bolts: JIT bind + bolts → delivery-check PASS) → /mega-sdd:sync when code moves → emit prd|fsd|sit|uat|html|summary + AGENTS.md (repo root) on demand`

Legacy rebuild: `legacy-code/ → KB (.mega-sdd/knowledge-base/) → plan --kb → vault (.mega-sdd/vaults/<slug>/) → execute-bolts inside that vault`

## See also

- `plugins/mega-sdd/references/paths.md` — implementer-facing per-skill write paths (this doc's inverse)
- `plugins/mega-sdd/references/direct-lane.md` — the direct/assisted procedure + the result contract
- `plugins/mega-sdd/skills/plan/SKILL.md` — the one spec phase (PRD / seed PRD / `--kb`)
- `plugins/mega-sdd/skills/extract-intelligence/references/prd-kontrak-template.md` — KB grammar authority (PRD-kontrak module template + master stack idiom table + per-module gate)
- `plugins/mega-sdd/references/vault-core.md` — vault structure spec (§schema/§OQ/§constitution/§id-stability); the multi-scope overlay is in `plugins/mega-sdd/skills/plan/references/scope-flow.md`
- `docs/mega-sdd/upgrade-from-old-version.md` — what 9.0 removed and how to move an older project
