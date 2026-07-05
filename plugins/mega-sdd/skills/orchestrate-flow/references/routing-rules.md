# Orchestrate-Flow Routing Rules

`orchestrate-flow` inspects CWD and proposes a chain of skills based on detected state. This document specifies the decision matrix.

## Contents

- [CWD inspection (deterministic, in order)](#cwd-inspection-deterministic-in-order)
- [Decision matrix](#decision-matrix)
- [Multi-squad detection](#multi-squad-detection-v11)
- [Chain depth limit](#chain-depth-limit)
- [Deep-chain decision matrix](#deep-chain-decision-matrix-scan-first-for-brownfield)
- [Resume + skip](#resume--skip)
- [Single confirmation](#single-confirmation)
- [Halt-pause behavior](#halt-pause-behavior)
- [Greenfield vs brownfield detection](#greenfield-vs-brownfield-detection)
- [First-run dependency check](#first-run-dependency-check)

## CWD inspection (deterministic, in order)

1. **PRD/seed detection.** Does CWD contain `prd.md`, `seed-PRD.md`, or `*.md` PRD candidates?
2. **Vault detection.** Probe in priority order — `.mega-sdd/vaults/*/vault.json` (canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy) → `vaults/*/vault.json` (oldest legacy). First hit wins.
3. **Bound-vault detection.** Same dirs but with `-bound` suffix?
4. **Units detection.** Any `units/U-*.md` files?
5. **Bolts detection.** Any `bolts/U-*/bolt-report.md`?
6. **Repo detection.** Is CWD inside a git repo? Any package manifests?
7. **Codebase-map detection.** Probe in priority order — `.mega-sdd/codebase/codebase-map.md` (canonical) → `<repo-root>/codebase-map.md` (legacy). First hit wins.
8. **Knowledge-base detection.** Probe in priority order — `.mega-sdd/knowledge-base/README.md` (default), `docs/knowledge-base/README.md` (legacy), `docs/mega-sdd/knowledge-base/README.md`, `old-reference/knowledge-base/README.md`. First hit wins; report as `knowledge_base: present (path: <hit>)` or `absent`.
9. **Open Questions count.** Aggregate P0/P1 OQ count across vault files.
10. **Drift signals.** Has detect-drift been run recently?

## Decision matrix

### Starterkit-first ordering

Per user directive "scan code base harusnya di atur di depan ... starterkit itu wajib ada. jika tidak ada baru greenfield" — starterkit detection runs FIRST. When detected, scan-codebase precedes generate-intent so vault is pack-aware from the start.

| State (from inspection) | Proposed chain |
|---|---|
| **Starterkit detected** + no vault + no codebase-map + PRD or brief present | `scan-codebase` (load pack into context) → `generate-intent --scan=<codebase-map> [<prd>\|--from-prompt]` (pack-aware vault) → `bind-codebase` → `generate-units` |
| **Starterkit detected** + Legacy codebase + rebuild intent + no vault | `extract-intelligence <legacy>` (KB) → `scan-codebase` (TARGET scaffold) → `generate-intent --kb=<kb> --scan=<codebase-map>` (KB + pack aware) → `bind-codebase` → `generate-units` |
| **Starterkit ABSENT** + `--greenfield` flag set | `generate-intent --greenfield [<prd>\|--from-prompt]` (stack-agnostic vault) → `generate-units` (no scan/bind until user scaffolds) |
| **Starterkit ABSENT** + no `--greenfield` flag | HALT `no_starterkit_detected` with options (scaffold first / opt in greenfield / cancel) |

### Pre-existing flows (legacy starterkit-absent path; preserved for back-compat)

| State (from inspection) | Proposed chain |
|---|---|
| Legacy codebase + no PRD + no vault + rebuild intent (user mentioned "rebuild di stack baru" / "reverse engineer" / "extract intelligence") | `extract-intelligence <legacy>` → `generate-intent --kb=<kb>` |
| `knowledge_base: present` + no vault | `generate-intent --kb=<kb>` (skip extract-intelligence — already done) |
| Brief only (no vault, no PRD, no KB) + starterkit absent + `--greenfield` | `generate-intent --from-prompt --greenfield` (Q&A first) |
| PRD exists, no vault, starterkit absent + `--greenfield` | `generate-intent <prd> --greenfield` |
| Vault exists, mode=greenfield, no units | `generate-units` |
| Vault exists, mode=existing, no codebase-map | `scan-codebase` → `bind-codebase` → `generate-units` |
| Vault exists, codebase-map exists, no bound-vault, BUT `binding.md` has NO ACTIVE (unresolved) conflict block AND every resolution action is KEEP_VAULT or DEFER (ZERO KEEP_CODE/SPLIT — those edited the vault and still need a re-bind) — a KEEP_VAULT/DEFER-only resolution leaves `bound/` absent by design | `generate-units` (the resolution-marked binding.md needs no re-bind; routing to `bind-codebase` would re-derive the unchanged vault-vs-code contradiction, re-raise the SAME CONFLICT and infinite-loop — per `resolve-oq/references/binding-mode.md` Step 5 + `convergence-loops.md`). NOTE: a MIXED / KEEP_CODE / SPLIT resolution ALSO leaves `bound/` absent but the vault WAS edited — it falls through to the `bind-codebase` row below (re-bind), matching the resolve-oq handoff + convergence surfaces |
| Vault exists, codebase-map exists, no bound-vault | `bind-codebase` (alone if blocking; chain if clean) |
| Bound-vault exists, no units | `generate-units` |
| Units exist, some not in bolts | `execute-bolts --all` |
| Vault has `squad_count: ≥2`, units exist, some not in bolts | `execute-bolts --per-squad` |
| Vault has `squad_count: ≥2`, units exist, user invokes from a single-squad context (e.g., on a dev's laptop with a specific role) | Ask: "Run for which squad?" then propose `execute-bolts --squad=<answer>` |
| Vault has `squad_count: ≥2` but `interfaces_count: 0` and ≥1 unit has cross-squad coupling hint in vault_source | `generate-units` (re-run, will surface `interface_ref_missing` halts as needed) |
| All units executed, no recent drift check | `detect-drift` |
| **Mode D — maintenance/sync** (map + binding exist AND change signal present: `.mega-sdd/codebase/.dirty-paths.jsonl` non-empty OR git HEAD ≠ the map's `last_scanned_commit`) | `scan-codebase --changed-only` → `detect-drift` (scoped to changed paths) → [`resolve-oq` if drift walked] → `bind-codebase --paths=@<changed-paths>` → `generate-units --reconcile` → `execute-bolts` (stale/new units only; `superseded` skipped). The never-ending-development lane per spec `2026-06-10-living-vault-continuous-sync-design.md`; `--sync` forces this row regardless of other inference. |
| Vault has unresolved P0/P1 OQs with status != deferred | `resolve-oq` first (intent gate, before any other chain) |
| Vault has only deferred P0/P1 OQs + brownfield context | `scan-codebase` → `bind-codebase` (which auto-resolves deferred OQs) |
| New PRD revision detected (file newer than vault) | `diff-vault <new-prd>` first |

**Mode D autonomous policy (`--sync --auto`):** one upfront confirmation covers the whole chain; mid-chain decisions are DEFERRED, never asked — drift direction calls + write-back drafts + re-bind CONFLICTs queue into `<vault>/PENDING-SYNC.md` (mode note: `DRIFT-ACTIONS.md` is the INTERACTIVE walkthrough's artifact and is correctly absent under `--auto` — PENDING-SYNC.md is its autonomous counterpart, not a missing file); the chain executes everything the gates allow and ends by writing `<vault>/SYNC-REPORT.md` (applied vs queued, conflicts, reconcile outcomes, closing staleness verification via `scripts/compute-unit-staleness.sh`). A queued CONFLICT yields handoff `status: paused` with the digest path in `next_action` — never `completed`-with-silence.

- **Cache-warm the graph (non-blocking).** After `SYNC-REPORT.md` is written,
  `Run: scripts/build-graph.sh --root <project>` to refresh `.mega-sdd/graph.json`.
  This is cache-warming only — a failure here NEVER blocks sync and emits no halt
  YAML (the graph is rebuilt lazily on next `/mega-sdd:graph` query regardless).

**Mode D change-signal inspection (cheap, two probes):** `grep -c . .mega-sdd/codebase/.dirty-paths.jsonl` and compare `git rev-parse HEAD` to the map frontmatter's `last_scanned_commit`. Either positive → Mode D candidate. Mode D NEVER fires on a repo without an existing map+binding (that's a normal brownfield first-run, rows above). Precedence: the P0/P1 OQ intent gate still runs first; a new PRD revision (diff-vault row) outranks sync.

**OQ counting note:** When inspecting vault for P0/P1 OQ counts, distinguish:
- `pending_p0_p1_count`: OQs with `status: pending` (or status field absent) at P0/P1 priority. These gate the chain via the intent rule above.
- `deferred_p0_p1_count`: OQs with `status: deferred`. These do NOT gate; they propagate to binding phase.

## Multi-squad detection

When CWD inspection finds `<vault>/_meta/squads.yaml` with ≥2 squads:

- Set `squad_count` in state snapshot to the count
- Read declared squad IDs to validate any `--squad=<id>` user input
- Adjust execute-bolts proposal:
  - Default to `--per-squad` (main-thread squad loop; concurrent depth-1 bolt-agent dispatch — see `execute-bolts/references/squad-subagent.md`)
  - If user is running in a context that suggests single-squad focus
    (e.g., explicit `--squad=<id>` arg passed to orchestrate-flow, or
    a hint like "I'm on the FE team"), use `--squad=<id>` instead

If the count is exactly 1 (or file absent): treat as single-squad mode,
do NOT propose `--per-squad` (it would halt). Use `--all` or unit-by-unit.

If interface files exist (`<vault>/interfaces/*.md`):
- Report `interfaces_count` in state snapshot
- Don't read content (cheap inspection); just count files
- Trust execute-bolts pre-flight to validate interface lock states at run time

## Chain depth limit

Hard cap: **3 sub-skills per chain** (default mode).

`--deep` flag LIFTS the cap. Chain extends to pipeline-end with auto-continue via the handoff YAML protocol (the handoff-contract reference is indexed in SKILL.md §Specialist references). Cap-lift is opt-in; default mode unchanged for backward compatibility.

## Deep-chain decision matrix (scan-first for brownfield)

When `--deep` flag is set, the cap-3 rule is replaced with pipeline-end chains.

**Brownfield reorder**: for brownfield paths, `scan-codebase` now runs **BEFORE** `generate-intent` so vault generation has codebase context (conventions, existing entities, framework signals). Per user feedback — vault was previously gen'd without code awareness, leading to fabricated entities + late PARTIAL_FIELDS_MISSING discovery + cold-start OQ classifier.

| State (from inspection) | `--deep` proposed chain |
|---|---|
| Legacy + no PRD + no vault + rebuild intent | `extract-intelligence` → `scan-codebase` (target codebase, if any scaffold exists) → `generate-intent --kb` (scan-aware) → `bind-codebase` → `generate-units` → `execute-bolts` (6 phases) |
| PRD exists, no vault, brownfield (existing code present) | **`scan-codebase`** → `generate-intent <prd>` (scan-aware) → `bind-codebase` → `generate-units` → `execute-bolts` (5 phases) — **REORDERED** |
| PRD exists, no vault, greenfield (empty repo) | `generate-intent <prd>` → `generate-units` → `execute-bolts` (3 phases — no scan needed) |
| `knowledge_base: present` + no vault + brownfield | `scan-codebase` → `generate-intent --kb` (scan-aware) → `bind-codebase` → `generate-units` → `execute-bolts` (5 phases) |
| Brief only (no vault, no PRD, no KB) + greenfield | `generate-intent --from-prompt` → `generate-units` → `execute-bolts` (3 phases) |
| Brief only + brownfield | `scan-codebase` → `generate-intent --from-prompt` (scan-aware) → `bind-codebase` → `generate-units` → `execute-bolts` (5 phases) |
| Vault exists, mode=existing, no codebase-map | `scan-codebase` → `bind-codebase` → `generate-units` → `execute-bolts` (4 phases — vault already written; can't retro-scan-aware it without `--refresh`) |
| Vault exists, codebase-map exists, no bound-vault | `bind-codebase` → `generate-units` → `execute-bolts` (3 phases) |
| Bound-vault exists, no units | `generate-units` → `execute-bolts` (2 phases) |
| Units exist, some not in bolts | `execute-bolts --all` (1 phase) |

### Greenfield vs brownfield detection

When `--deep` chain plans, orchestrator probes:

- `.git` present + existing code files (`.{php,js,ts,py,rs,go,rb}` etc.) → **brownfield** (run scan-codebase first)
- `.git` present + only scaffolding files (e.g., bare Laravel boilerplate, no business logic) → **brownfield-light** (run scan-codebase --quick first)
- No `.git` OR fresh `composer create-project`/`npx create-*` with no manual edits → **greenfield** (skip scan-codebase upfront)

Override via `--brownfield` / `--greenfield` flag on `auto`/`orchestrate-flow`.

**Halt behavior unchanged**: any blocker (CONFLICT, business OQ, hard_rule_violated, dedup_ambiguous, etc.) pauses the deep chain identically to current cap-3 behavior. User resolves, then runs `orchestrate-flow --deep --resume`.

**Confirmation behavior in `--deep`**: ONE upfront confirmation listing ALL phases. User picks Run / Edit / Cancel. A single upfront confirmation covers the entire chain INCLUDING destructive phases (`execute-bolts`); bolts have their own existing safety (target_files whitelist, Hard rules).

### `--from=<phase>` and `--to=<phase>` interaction with `--deep`

- `--from=<phase>` skips earlier phases regardless of CWD state. Useful for forcing re-execution of a specific later phase.
- `--to=<phase>` stops at that phase. Useful for staging (run extract + intent, review, then run bind + units + bolts separately).
- `--from` + `--to` + `--deep` combine cleanly. Example: `/mega-sdd:orchestrate-flow --deep --from=bind-codebase --to=generate-units` runs only the 2-phase window.

### `--resume` mechanics

`--resume` does NOT read a persisted state file. It:
1. Skips upfront confirmation (chain was approved before)
2. Re-runs CWD inspection (same as a fresh invocation)
3. Builds chain per routing-rules
4. Automatically skips phases whose artifacts already exist (e.g., if `vault.json` exists, skip `generate-intent`)
5. Resumes execution from the first phase whose artifacts are absent
6. If the resumed phase still has its blocker unresolved → halt re-fires (correct safety behavior)

User MUST resolve halt-blockers manually BEFORE re-running `--resume`.

## Resume + skip

User options on chain proposal:
- **Run** — execute all proposed steps
- **Edit** — `skip step N` or `stop after step N` only
- **Cancel** — abort

## Single confirmation

User confirms ONCE before chain starts. Sub-skills run with `--auto`. Substance prompts (per-OQ choices, conflict resolutions) ALWAYS surface to human regardless of `--auto`.

## Halt-pause behavior

When a sub-skill emits a blocker YAML:
- Chain pauses (does NOT continue)
- Blocker surfaced verbatim
- User decides next: retry, fix, cancel
- Final summary lists completed/paused/skipped per step

## Greenfield vs brownfield detection

| Signals | Mode inferred |
|---|---|
| No `.git`, no package manifests | greenfield (warn if vault says existing) |
| `.git` + package manifest | brownfield (warn if vault says greenfield) |
| Vault explicit `mode:` overrides inference if user confirmed during generate-intent | — |

If detection conflicts with vault `mode:`, halt with mode-migration prompt.

## First-run dependency check

On first invocation in a session that will reach `execute-bolts`, perform pre-flight:
- If neither superpowers nor `_vendored/` is ready → halt, offer install
- Defer the check until bolt phase is actually proposed (cheap check, runs once)
