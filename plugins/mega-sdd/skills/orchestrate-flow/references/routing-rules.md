# Orchestrate-Flow Routing Rules

`orchestrate-flow` inspects CWD and proposes a chain of skills based on detected state. This document specifies the decision matrix.

> **Task weight (upstream of every row here):** the S/M/L weight decision happens BEFORE orchestrate-flow — in the `using-mega-sdd` anchor's weight table and the front door's mechanical ownership check (spec `2026-08-21-v7-weighted-routing-design.md`). By the time any chain in this document is proposed, the task is already tier **M** (delta lane) or **L** (full chain); tier-S work never reaches orchestrate-flow at all. Nothing in this matrix changes per tier — M simply enters at the delta-lane row, and `--weight=S|M|L` on the front door overrides the anchor's call. The lane router (`scripts/route-lane.sh`) also runs first: `direct` / `assisted` work never reaches this document — only guarded runs and the maintenance lanes do.

> **`--lean` profile:** when `.mega-sdd/config.yaml` carries `profile: lean`, the state engine (`scripts/_lib/state_probes.py`, `derived.profile`) reports the profile and the Stop-hook analyze aggregate stays off — the engine and the orchestrator's §Auto-integrated diagnostics are one contract. No chain row changes; no gate reads the profile. (The former `--no-advisor` hop transform died with the phase-advisor's removal.)

## Contents

- [CWD inspection (deterministic, in order)](#cwd-inspection-deterministic-in-order)
- [Decision matrix](#decision-matrix)
- [Multi-squad detection](#multi-squad-detection)
- [Chain depth limit](#chain-depth-limit)
- [Deep-chain decision matrix](#deep-chain-decision-matrix)
- [Resume + skip](#resume--skip)
- [Single confirmation](#single-confirmation)
- [Halt-pause behavior](#halt-pause-behavior)
- [Greenfield vs brownfield detection](#greenfield-vs-brownfield-detection)
- [Mode inference vs vault `mode:` (mode_migrate table)](#mode-inference-vs-vault-mode-mode_migrate-table)
- [First-run dependency check](#first-run-dependency-check)

## CWD inspection (deterministic, in order)

**`Run: scripts/derive-state.sh --cwd=<WORK_DIR>`** — the ONE probe engine. Every probe below executes inside the shared library `scripts/_lib/state_probes.py` (the SAME library `validate-preflight.sh` reads its `has_vault()`-class predicates from) and lands in `<root>/.mega-sdd/state.json` (a `probes` object + a `derived` object) plus a one-line stdout digest. **Read `state.json`; never re-probe by hand** — hand-probing is exactly how the pre-P1 routing↔preflight `has_vault` fork happened. When no `.mega-sdd/` exists yet the script writes no file (it never mints an SDD signal in an unrelated directory); pass `--json-only` and read stdout instead.

The probes (10 core + the P2 foreign-SDD adoption probe) and where each lands:

| # | Probe (identical semantics to the pre-P1 prose) | `state.json` field |
|---|---|---|
| 1 | **PRD/seed detection** — `prd.md`, `seed-PRD.md`, or `*.md` PRD candidates at the ROOT **plus one level inside dirs whose name case-insensitively matches `PRD`/`docs`/`documents`/`requirements`** (fixed set, never a repo walk; subdir hits keep their ON-DISK prefix, e.g. `PRD/prd-simkredit.md`; dirs deduped by inode on case-insensitive filesystems) | `probes.prd` (`present` / `candidates[]` / `newest_mtime`) |
| 2 | **Vault detection** — priority order: `.mega-sdd/vaults/*` (canonical — `vault.json` OR bare `0[0-6]-*.md` docs (or the layout-2 four docs / layout-3 `context.md`) count, SAME semantics as `validate-preflight.sh has_vault()`, now literally the same library function: a 7-file vault without `vault.json` is still a vault, never invisible to routing) → `docs/mega-sdd/vaults/*/vault.json` (legacy) → `vaults/*/vault.json` (oldest legacy). First hit wins (`probes.vaults[0]` / `derived.vault`). When vault docs exist but `vault.json` is absent (`derived.manifest_derive_needed: true`), the proposed chain FIRST runs `scripts/derive-vault-json.sh --vault <vault>` (derives the manifest deterministically from the docs — never hand-write it) before any phase that reads `vault.json` — the script already prepends this step to `derived.proposed_next` | `probes.vaults[]` |
| 3 | **Bound-vault detection** — `<vault>/bound/` (canonical) or legacy `<vault>-bound/` sibling. Layout-2 only: read, never a routing key (a vault carrying it lands on the layout-2 migrate row) | `probes.vaults[].bound_present` |
| 4 | **Units detection** — `units/U-*.md` (+ `U-*/unit.md` layout + legacy sibling) | `probes.vaults[].units_count` |
| 5 | **Bolts detection** — `bolts/U-*/bolt-report.md` | `probes.vaults[].bolts_count` |
| 6 | **Repo detection** — inside a git repo? package manifests? existing code files? | `probes.git` / `probes.manifests[]` / `probes.code` |
| 7 | **Codebase-map detection** — `.mega-sdd/codebase/codebase-map.md` (canonical) → `<repo-root>/codebase-map.md` (legacy); first hit wins; + frontmatter `last_scanned_commit` vs git HEAD. A pre-9.0 artefact: optional context for readers, never a routing key or sync trigger (nothing refreshes it) | `probes.codebase_map` (`present` / `path` / `last_scanned_commit` / `matches_head`) |
| 8 | **Knowledge-base detection** — `knowledge_base: <dir>` in `.mega-sdd/config.yaml` first (a shared KB outside the tree, e.g. a monorepo submodule; configured-but-missing = `absent` + `configured_missing` + a `derived.notes` line, NEVER a fall-through to a local copy), then `.mega-sdd/knowledge-base/README.md` (default) → `docs/knowledge-base/README.md` (legacy) → `docs/mega-sdd/knowledge-base/README.md` → `old-reference/knowledge-base/README.md`; first hit wins; report as `knowledge_base: present (path: <hit>, source: config\|default)` or `absent` | `probes.knowledge_base` |
| 9 | **Open Questions count** — P0/P1 OQs split open-vs-deferred per the §OQ counting note (vault.json first, shared `vault_md` OQ grammar fallback) | `probes.vaults[].oq` (`pending_p0_p1` / `deferred_p0_p1`) |
| 10 | **Drift signals** — `DRIFT-REPORT.md` presence + recency (drift report at least as new as the newest bolt-report) | `probes.vaults[].drift_report` / `derived.drift_recent` |
| 11 | **Foreign-SDD detection** (P2 adoption) — spec-kit `.specify/`, Kiro `.kiro/specs/`, OpenSpec `openspec/`\|`.openspec/`, plus generic `specs/*.md` whose head opens with YAML frontmatter. Recognition only — the verdict comes from `scripts/certify-artifact.sh` | `probes.foreign_sdd` / `derived.foreign_sdd` (+ a `derived.notes[]` adoption note; the stdout digest appends `foreign_sdd=<tools>` only when non-empty) |

`derived.position` + `derived.proposed_next` carry the script's default reading of the decision matrix below. The matrix stays authoritative: flag- and intent-conditioned rows (`--greenfield`, `--sync`, `--from`/`--to`, rebuild intent, memory-informed overrides) are applied by the orchestrator ON TOP of the digest — the script never invents intent (such rows surface as `derived.notes[]` with an empty chain).

### Derived-position map (script default ↔ matrix row)

| `derived.position` | Encodes matrix row | Default `proposed_next` |
|---|---|---|
| `empty` | no inputs at all | `[]` (ask for PRD/brief) |
| `legacy_code_only` | code, no PRD/KB/vault — needs the user's word: rebuild (`extract-intelligence` → `plan --kb`) or a brief (`route-lane.sh`) | `[]` + note |
| `prd_no_vault` | PRD, no vault (starterkit rows; absent starterkit → halt `no_starterkit_detected` note) | `plan <prd> --lite --mode=<existing\|new>` → `execute-bolts --all --lite` |
| `kb_no_vault` | `knowledge_base: present` + no vault | `plan --kb=<kb> --lite --mode=<existing\|new>` → `execute-bolts --all --lite` (the bolts hop only when a target scaffold is detected; otherwise a note) |
| `oq_gate` | unresolved blocking-tier OQs, status != deferred (field `pending_p0_p1`; the grammar has NO P0 — P1 "Sprint-0 blocker" IS the blocking tier) | `resolve-oq` (chain + `--auto`: the P3 batched walk — P1 asked ≤4-per-call, P2/P3 auto-defer RECORDED; standalone: full interactive walk) |
| `prd_revision` | new PRD revision (file newer than vault) | `diff-vault <prd>` |
| `maintenance_sync` | Mode D row (freshness substrate + binding + a change signal) | the sync chain (§Mode D — maintenance/sync detail) |
| `lite_context_no_units` | plan-born vault (`context.md`), no units | `plan <prd> --lite --regenerate` → `execute-bolts --all --lite` |
| `layout2_needs_migration` | layout-2 vault (no `context.md`; built by the pre-9.0 classic chain) that needs building or syncing | `[]` + note: propose `/mega-sdd:migrate-paths --vault-layout=3` (never run silently; a mandatory full JIT re-bind follows it) |
| `units_pending_bolts` | units exist, some not in bolts | `execute-bolts --all --lite` (the default inline run: one context, plan order) |
| `all_units_executed` | all units executed, no recent drift check | `detect-drift` |
| `pipeline_complete` | all executed + recent drift check | `[]` |

## Decision matrix

**One pipeline.** GROUND (`scripts/ground.sh`: `derive-state.sh` + `build-symbol-index.sh` + pack resolve) runs at the front door, and no chain has a scan or bind hop: binding is the per-unit JIT bind in `execute-bolts` (`write-unit-binding.sh` → `bolts/U-XXX/binding.json`; run start + each task), and the CONFLICT gate closes before the unit is built. `--classic`, `spine: classic` and `lane: standard` are retired: say so in one line, then ignore them.

### Starterkit-first ordering

The original directive "scan code base harusnya di atur di depan ... starterkit itu wajib ada. jika tidak ada baru greenfield" carried TWO obligations: starterkit is mandatory (unchanged — the halt below stands, fed by the script-side pack matcher in `state.json` `derived.framework_pack`), and code-awareness must precede vault generation. The carrier is GROUND (manifest sniff + pack resolve + symbol index, seconds) + `plan`'s index queries under `--mode=existing`. The fabrication risk the old ordering guarded ("vault gen'd without code awareness") is covered by the verification that was always the moat: an ungrounded unit claim cannot pass the per-unit JIT bind (`write-unit-binding.sh` → `bolts/U-XXX/binding.json`) or its CONFLICT gate.

| State (from inspection) | Proposed chain |
|---|---|
| **Lane lite** — starterkit detected + no vault + PRD present (every guarded run; `--lite` / config `lane: lite` are accepted markers) | **2-hop:** `plan <prd> --lite --mode=<existing\|new>` → `execute-bolts --all --lite` — no bind hop (the JIT bind runs inside execute-bolts), no handoff YAML between the hops (state re-derived from disk + `validate-preflight.sh --predictive --chain=execute-bolts`); `--mode=existing` when the repo carries code, `new` for a bare scaffold (never asked). A plan-born vault (`context.md`) with no units → `plan <prd> --lite --regenerate` (position `lite_context_no_units`). A brief goes to `route-lane.sh` (direct / assisted); under `--guarded` the front door first writes it to a seed PRD file (unspecified items become OQs) and `plan` takes that file |
| **Starterkit detected** + Legacy codebase + rebuild intent + no vault | `extract-intelligence <legacy>` (KB) → `plan --kb=<kb> --lite --mode=<existing\|new>` → `execute-bolts --all --lite`. Judge `--mode` on the TARGET scaffold (GROUND's manifests + symbol index), never on a legacy tree inside the repo |
| **Starterkit ABSENT** + `--greenfield` flag set | PRD → `plan <prd> --lite --mode=new` (stack-agnostic units, every unit `create`); no `execute-bolts` until the user scaffolds — the JIT bind then runs per unit. A brief → `route-lane.sh` (direct lane), or under `--guarded` the seed PRD file → `plan` |
| **Starterkit ABSENT** + no `--greenfield` flag | HALT `no_starterkit_detected` with options (scaffold first / opt in greenfield / cancel) |

### Pre-existing flows (legacy starterkit-absent path; preserved for back-compat)

| State (from inspection) | Proposed chain |
|---|---|
| Legacy codebase + no PRD + no vault + rebuild intent (user mentioned "rebuild di stack baru" / "reverse engineer" / "extract intelligence") | `extract-intelligence <legacy>` → `plan --kb=<kb> --lite --mode=<existing\|new>` |
| `knowledge_base: present` + no vault | `plan --kb=<kb> --lite --mode=<existing\|new>` (skip extract-intelligence — already done). **+ MENTION the `emit-prd` reverse lane** (one line, never auto-chained): a team-readable PRD draft from the KB with `[VERIFIED]/[INFERRED]/[OPEN]` markers carried verbatim (`/mega-sdd:emit prd`, reverse mode). Docs are OUTPUTS — `plan --kb` stays the pipeline continuation. |
| **Layout-2 vault** (no `context.md` — built by the pre-9.0 classic chain) that needs building or syncing | PROPOSE `/mega-sdd:migrate-paths --vault-layout=3` (layout-2 → `context.md`, then a mandatory full JIT re-bind; never run silently). Afterwards the rows below apply. Reading stays: emit-* and the status view work on layout-2 as they are |
| Units exist, some not in bolts | `execute-bolts --all --lite` |
| Vault has `squad_count: ≥2`, units exist, user invokes from a single-squad context (e.g., on a dev's laptop with a specific role) | Ask: "Run for which squad?" then propose `execute-bolts --squad=<answer>` |
| Vault has `squad_count: ≥2` but `interfaces_count: 0` and ≥1 unit has cross-squad coupling hint in `context_source` | `plan <prd> --lite --regenerate` (plan carries the `interface_ref_missing` halt) — proposed only with explicit consent, because it rewrites `context.md` and the units of a vault that has bolts |
| All units executed, no recent drift check | `detect-drift` |
| **All units executed + acceptance evidence present** (≥1 `bolts/U-*/acceptance.json` — `state.json` `probes.vaults[].bolts_count` > 0 signals the bolts state; the evidence file is the P4 B4 artifact) | PROPOSE `emit-sit` alongside the row above (one line, never auto-chained): the SIT §4 executed-evidence tables are script-derived by `scripts/build-sit-evidence.sh` from `acceptance.json`/`postflight.json`/`_batch-suite.json`; units without evidence surface as `[Pending — bolt U-XXX belum dieksekusi]`, never invented; maturity (`planned→partial→executed`) comes from evidence coverage. Docs are OUTPUTS — emit-sit never gates the pipeline. |
| **Mode D — maintenance/sync** (a freshness substrate — the symbol index; a leftover pre-9.0 map is not one — + a binding (`bolts/U-*/binding.json`, or a layout-2 `binding.md`) exist AND a change signal is present: `.mega-sdd/codebase/.dirty-paths.jsonl` non-empty OR git HEAD ≠ the index's `head_commit` — i.e. `derived.change_signal` in `state.json`; the map stamp never triggers) | The never-ending-development sync chain: changed-set derivation → short-circuit gate → scoped `detect-drift` → `rebind-units.sh --paths` → `plan --reconcile` → `execute-bolts --all --lite` (stale units only). Per-hop semantics and the fallbacks: **§Mode D — maintenance/sync detail** below. `--sync` forces this row regardless of other inference. A layout-2 vault takes the migrate row first. |
| Vault has unresolved P0/P1 OQs with status != deferred | `resolve-oq` first (intent gate, before any other chain) |
| New PRD revision detected (file newer than vault) | `diff-vault <new-prd>` first |
| **Delta lane — ticket-scale quoted free-text + owned vault** (overlay only: the front door or explicit user intent hands over a chat brief; the sentence names an entity/flow an existing vault's OQ/heading surface owns (context.md; layout-2: constraints.md + vault.md; legacy: the 00-index roll-up); NEVER fired from derived state alone) | `diff-vault --from-prompt "<brief>"` → on clean apply the chain continues per **§Delta lane detail** below. A `prd_revision` (file newer than vault) OUTRANKS this row — a real PRD revision wins over a chat sentence. |
| **Adoption — foreign SDD detected** (`derived.foreign_sdd` non-empty: spec-kit `.specify/`, Kiro `.kiro/specs/`, OpenSpec, generic frontmatter'd `specs/*.md`) | PROPOSE the DEMOTE lane — their spec files enter at the **PRD rung**: `Run: scripts/certify-artifact.sh --cwd=<root> --rung=prd --path=<spec-file>` per file, then `plan <certified-spec-file> --lite --mode=<existing\|new>` (the PRD rung is plan's input). Never ingest a foreign artifact mid-pipeline (vault/kb rungs are grammar-gated). The script only NOTES this lane (`derived.notes[]`) — it never auto-chains it, because a re-ingest needs the user's word (the DEMOTE policy below). |
| **Adoption — external vault placed by hand** (a vault dir whose `vault.json` is absent AND `derive-vault-json` was never run) | PROPOSE `Run: scripts/certify-artifact.sh --rung=vault --path=<artifact>` FIRST — the verdict (CERTIFIED / CERTIFIED_DEGRADED / DEMOTE / REJECTED, each with keterangan) decides the lane BEFORE any phase consumes the artifact. CERTIFIED/CERTIFIED_DEGRADED → continue the normal rows above. REJECTED → surface the keterangan verbatim (it carries the re-ingest offer). |

**DEMOTE under `--auto` (LOCKED):** a `DEMOTE` verdict from `certify-artifact.sh` is **ALWAYS a C2 halt** — `type: adoption_demote_confirm` (see `plugins/mega-sdd/references/halt-protocol.md`) with the certify keterangan rendered first and ONE AskUserQuestion-shaped confirmation (re-ingest / manual fix / cancel). Never unconfirmed: the demotion burns plan tokens and produces a DIFFERENT vault than the artifact the user placed. A mega-sdd-authored artifact is never REJECTED (migration guarantee — CERTIFIED_DEGRADED floor).

**OQ counting note:** When inspecting vault for P0/P1 OQ counts, distinguish:
- `pending_p0_p1_count`: OQs with `status: open` (or status field absent; a legacy `pending` value reads the same) at P0/P1 priority. These gate the chain via the intent rule above. **Not counted:** an open `[tech / scan]` OQ — never a human's question: `plan` decides tech OQs in-phase (`plugins/mega-sdd/references/vault-core.md §AI technical decisions`). A leftover one on a migrated layout-2 vault lost its decider (the retired whole-vault bind); it is still `[ ]`, so the next `resolve-oq` walk queues it and it is decided there.
- `deferred_p0_p1_count`: OQs with `status: deferred`. These do NOT gate; they ride the units to `execute-bolts`, which lists them in its handoff (the JIT bind does not resolve OQs).

### Mode D — maintenance/sync detail

- **The chain:** `scripts/derive-changed-paths.sh --vault <vault>` (hop 1 for every vault: git diff index `head_commit`..HEAD ∪ working tree ∪ dirty journal → `<vault>/.sync-changed-paths.txt` — the durable changed set the non-interactive downstream reads once the journal is consumed, because by then the journal is rotated, so it cannot be reconstructed) → short-circuit gate (next bullet) → `detect-drift --scope=@<vault>/.sync-changed-paths.txt` (scoped to those changed paths; its OWN handoff CONTINUES the sync lane straight to the re-bind hop, NEVER to resolve-oq — resolve-oq has no drift-consumption mode) → [`resolve-oq` ONLY if the drift scan CREATED an `OQ-DC-N` stub — resolve-oq handles that stub in its ordinary intent mode; it never ingests drift findings] → `scripts/rebind-units.sh --cwd=. --vault=<vault> --paths=@<vault>/.sync-changed-paths.txt` → `plan --reconcile` → `execute-bolts --all --lite` (stale units only; `superseded` skipped).
- **Short-circuit gate (after the changed set exists): `scripts/sync-intersect.sh --cwd=<root> --vault=<vault> --paths=@<vault>/.sync-changed-paths.txt` — exit 0 (`in_sync`: changed ∩ binding anchors ∪ unit target_files = ∅) → stamp freshness, one-line SYNC-REPORT.md, chain ENDS (nothing to re-verdict — proportional verification); exit 4 → proceed; exit 2 or ANY other unexpected exit → fail-closed, full chain.** `sync-intersect.sh` and `derive-delta-paths.sh` read the union of `bolts/U-*/binding.json` anchors ∪ units' `## Anchors`; a vault with NO per-unit binding at all → exit 2 → full JIT re-bind.
- **The re-bind hop** binds PER UNIT (there is no whole-vault binding): `rebind-units.sh` exit 0 = nothing affected (in_sync for the hop), 4 = re-bound (read `gate` — a CONFLICT closes the gate for the affected units exactly as in execute-bolts), 2/3 = fail-closed → full JIT re-bind.
- **No baseline** (no symbol index, or `derive-changed-paths.sh` exit 3: no baseline stamp / git unavailable / write failed) → skip detect-drift (nothing to scope — a scope-less detect-drift would null-terminate the chain before the re-bind) and run the FULL re-bind `scripts/rebind-units.sh --cwd=. --vault=<vault> --units=all` → `plan --reconcile` → `execute-bolts --all --lite` — never a guessed scope.
- `plan --reconcile` flips `task_type` / status from the per-unit binding evidence and marks superseded units; it writes no new units (a new requirement goes through `diff-vault` → `plan --regenerate`).
- The never-ending-development lane per spec `2026-06-10-living-vault-continuous-sync-design.md` §3.3 (per-hop handoff semantics clarified by §3.8).

**Mode D autonomous policy (`--sync --auto`):** one upfront confirmation covers the whole chain; mid-chain decisions are DEFERRED, never asked — drift direction calls + write-back drafts + re-bind CONFLICTs queue into `<vault>/PENDING-SYNC.md` (mode note: `DRIFT-ACTIONS.md` is the RETIRED pre-v3.0.0 interactive artifact — no step writes it in any mode; `PENDING-SYNC.md` is the only queue, so its absence is never a missing file); the chain executes everything the gates allow and ends by writing `<vault>/SYNC-REPORT.md` (applied vs queued, conflicts, reconcile outcomes, closing staleness verification via `scripts/compute-unit-staleness.sh`). A queued CONFLICT yields handoff `status: paused` with the digest path in `next_action` — never `completed`-with-silence.

- **Cache-warm the graph (non-blocking).** After `SYNC-REPORT.md` is written,
  `Run: scripts/build-graph.sh --root <project>` to refresh `.mega-sdd/graph.json`.
  This is cache-warming only — a failure here NEVER blocks sync and emits no halt
  YAML (the graph is rebuilt lazily on next `graph` query regardless).

**Mode D change-signal inspection (from the digest — same two probes, script-run):** read `derived.change_signal` in `state.json` — `dirty_journal_rows` (IN-REPO rows of `.mega-sdd/codebase/.dirty-paths.jsonl` — absolute-path rows are out-of-repo pollution and never count) and `index_stamp_matches_head` (symbol-index `head_commit` vs `git rev-parse HEAD`). `dirty_journal_rows > 0` OR `index_stamp_matches_head: no` → Mode D candidate. `map_stamp_matches_head` is informational only: nothing refreshes a leftover pre-9.0 map, so its stamp would fire Mode D forever. Mode D NEVER fires on a repo without the symbol index (the one freshness substrate — a leftover map is not one: without an index `derive-changed-paths.sh` exits 3, so a map-keyed row would re-fire on every derive) + a binding (that's a normal first run, rows above; a forced `--sync` there takes the no-baseline fallback). Precedence: the P0/P1 OQ intent gate still runs first; a new PRD revision (diff-vault row) outranks sync. The delta lane never contends with either: it fires only on an explicit chat-brief overlay (different entry signal), and a present PRD revision outranks it too.

### Delta lane detail (`diff-vault --from-prompt` — spec `2026-08-11-free-text-delta-lane.md`)

- **Entry** is ALWAYS an overlay (front-door proposal or explicit user intent) — the state engine never invents a delta from derived state, and the lane is propose-first: a bare "tambah kolom X" with no mega-sdd intent routes NOWHERE (the user-control escape hatch stands).
- **The chain:** `diff-vault --from-prompt "<brief>"` (narrow-scope diff + `delta_too_large` cap + apply + Step 7.5 writes `<vault>/.delta-changed-paths.txt`; `derive-delta-paths.sh` maps each changed `context.md#<section>` to the units that cite it) → `scripts/rebind-units.sh --cwd=. --vault=<vault> --paths=@<vault>/.delta-changed-paths.txt` (claim-scoped re-bind) → `plan --reconcile` → `execute-bolts --all --lite` (stale units only; `superseded` skipped). The reconcile step's transitive-impact advisory (`derive-transitive-impact.sh`, `plan/references/task-typing.md` step 2.6) rides the reconcile output — dependents of changed units are OFFERED as verify-recommended bolts, never auto-run, never a gate (fail-open on a missing graph).
- **Fail-closed edges (the script's exit codes, nothing else):** `derive-delta-paths.sh` exit 3 (no `binding.json` and no `bolts/U-*/binding.json` — unbound vault) → NO scoped hop; the normal chain rows above apply. Exit 2 (ANY parse failure) → `scripts/rebind-units.sh --cwd=. --vault=<vault> --units=all` → `plan --reconcile` — a FULL re-bind, never a guessed scope (same shape as Mode D's no-baseline fallback).
- **NOT the sync lane:** no detect-drift hop (no code moved — nothing to drift-check), own scope file (`.delta-changed-paths.txt`, never `.sync-changed-paths.txt` — that basename is the sync discriminator, owned by `derive-changed-paths.sh`). The delta scope file is SINGLE-USE by convention: overwritten by every from-prompt apply, read only by this overlay's bind proposal — a stale leftover is never consumed by another lane.
- **Halted `delta_too_large`** → the user's choice routes: `full_lane` → the front door writes the brief to a file and re-enters `route-lane.sh` (under `--guarded`: `plan <brief-file> --lite` into a NEW vault dir — never `plan --regenerate` on this vault); `split_ticket` → user re-enters with a smaller brief; `cancel` → end, vault untouched.

## Multi-squad detection

When CWD inspection finds `<vault>/_meta/squads.yaml` with ≥2 squads (only migrated pre-9.0 vaults carry one — no surviving phase authors squads):

- Set `squad_count` in state snapshot to the count
- Read declared squad IDs to validate any `--squad=<id>` user input
- If user is running in a context that suggests single-squad focus
  (e.g., explicit `--squad=<id>` arg passed to orchestrate-flow, or
  a hint like "I'm on the FE team"), propose `--squad=<id>`; otherwise
  `--all` — the inline run takes every unit in one context

If the count is exactly 1 (or file absent): treat as single-squad mode.
Use `--all` or unit-by-unit.

If interface files exist (`<vault>/interfaces/*.md`):
- Report `interfaces_count` in state snapshot
- Don't read content (cheap inspection); just count files
- `derive-exec-plan.sh` quarantines a unit whose consumed interface is still draft at run start

## Chain depth limit

Hard cap: **3 sub-skills per chain** (default mode).

`--deep` flag LIFTS the cap. Chain extends to pipeline-end with auto-continue via the handoff YAML protocol (the handoff-contract reference is indexed in SKILL.md §Specialist references). Cap-lift is opt-in; default mode unchanged for backward compatibility.

## Deep-chain decision matrix

When `--deep` flag is set, the cap-3 rule is replaced with pipeline-end chains.

**Brownfield code-awareness**: vault generation must have codebase context (conventions, existing entities, framework signals) — a vault gen'd blind fabricates entities, discovers PARTIAL_FIELDS_MISSING late, and cold-starts the OQ classifier. The carrier is GROUND (`state.json` manifests + `derived.framework_pack` + the symbol index) + `plan --mode=existing` index queries; the per-unit JIT bind in `execute-bolts` is the verification backstop (its CONFLICT gate).

| State (from inspection) | `--deep` proposed chain |
|---|---|
| Legacy + no PRD + no vault + rebuild intent | `extract-intelligence` → `plan --kb=<kb> --lite --mode=<existing\|new>` → `execute-bolts --all --lite` (3 phases) |
| PRD exists, no vault, brownfield (existing code present) | `plan <prd> --lite --mode=existing` → `execute-bolts --all --lite` (2 phases) |
| PRD exists, no vault, greenfield (empty repo) | `plan <prd> --lite --mode=new` → `execute-bolts --all --lite` (2 phases) |
| `knowledge_base: present` + no vault + brownfield | `plan --kb=<kb> --lite --mode=existing` → `execute-bolts --all --lite` (2 phases) |
| Brief only (no vault, no PRD, no KB) | `route-lane.sh` decides (direct / assisted — no pipeline). Under `--guarded`: the front door writes the brief to a seed PRD file → `plan <brief-file> --lite --mode=<existing\|new>` → `execute-bolts --all --lite` (2 phases) |
| Plan-born vault (`context.md`), no units | `plan <prd> --lite --regenerate` → `execute-bolts --all --lite` (2 phases) |
| Layout-2 vault (no `context.md`) | PROPOSE `/mega-sdd:migrate-paths --vault-layout=3` first (never silent; a mandatory full JIT re-bind follows), then the rows above/below |
| Units exist, some not in bolts | `execute-bolts --all --lite` (1 phase) |

### Greenfield vs brownfield detection

When `--deep` chain plans, orchestrator probes:

- `.git` present + existing code files (`.{php,js,ts,py,rs,go,rb}` etc.), or only scaffolding files (e.g., bare Laravel boilerplate, no business logic) → **brownfield**: GROUND (already run at the front door) supplies the context; the `plan --mode=` pin follows the engine (`existing` when the repo carries code, `new` for a bare scaffold)
- No `.git` OR fresh `composer create-project`/`npx create-*` with no manual edits → **greenfield** (`plan --mode=new`)

Override via `--brownfield` / `--greenfield` flag on `auto`/`orchestrate-flow`.

**Halt behavior unchanged**: any blocker (CONFLICT, business OQ, hard_rule_violated, dedup_ambiguous, etc.) pauses the deep chain identically to current cap-3 behavior. User resolves, then runs `orchestrate-flow --deep --resume`.

**Confirmation behavior in `--deep`**: ONE upfront confirmation listing ALL phases. User picks Run / Edit / Cancel. A single upfront confirmation covers the entire chain INCLUDING destructive phases (`execute-bolts`); bolts have their own existing safety (target_files whitelist, Hard rules).

### `--from=<phase>` and `--to=<phase>` interaction with `--deep`

- `--from=<phase>` skips earlier phases regardless of CWD state. Useful for forcing re-execution of a specific later phase.
- `--to=<phase>` stops at that phase. Useful for staging (run extract + plan, review, then run bolts separately).
- `--from` + `--to` + `--deep` combine cleanly. Example: `/mega-sdd --deep --from=extract-intelligence --to=plan` runs only the 2-phase window.

### `--resume` mechanics

`--resume` does NOT read a persisted state file. It:
1. Skips upfront confirmation (chain was approved before)
2. Re-runs CWD inspection (same as a fresh invocation)
3. Builds chain per routing-rules
4. Automatically skips phases whose artifacts already exist (e.g., if `vault.json` + `units/_index.md` exist, skip `plan`)
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

## Mode inference vs vault `mode:` (mode_migrate table)

| Signals | Mode inferred |
|---|---|
| No `.git`, no package manifests | greenfield (warn if vault says existing) |
| `.git` + package manifest | brownfield (warn if vault says greenfield) |
| Vault explicit `implementation_mode:` (layout-3 `context.md`, pinned by `plan --mode=new\|existing`) or `mode:` (layout-2, still read) overrides inference | — |

If detection conflicts with vault `mode:`, halt with mode-migration prompt.

## First-run dependency check

The first-class agents ship in the plugin tree; no
superpowers/vendored probe exists and nothing halts on it.
