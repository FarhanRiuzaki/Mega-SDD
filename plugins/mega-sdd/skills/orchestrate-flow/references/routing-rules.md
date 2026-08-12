# Orchestrate-Flow Routing Rules

`orchestrate-flow` inspects CWD and proposes a chain of skills based on detected state. This document specifies the decision matrix.

> **`--lean` profile (tranche E):** when `.mega-sdd/config.yaml` carries `profile: lean`, the state engine (`scripts/_lib/state_probes.py`, `derived.profile`) appends `--no-advisor` (a `--lean` FLAG without the config key is applied by the orchestrator at dispatch time — the engine reads only the config) to the `generate-intent` and `bind-codebase` hops in every proposed chain below — the engine and this table are one contract (the 2a lesson). No other row changes; no gate reads the profile.

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

**`Run: scripts/derive-state.sh --cwd=<WORK_DIR>`** — the ONE probe engine. Every probe below executes inside the shared library `scripts/_lib/state_probes.py` (the SAME library `validate-preflight.sh` reads its `has_vault()`-class predicates from) and lands in `<root>/.mega-sdd/state.json` (a `probes` object + a `derived` object) plus a one-line stdout digest. **Read `state.json`; never re-probe by hand** — hand-probing is exactly how the pre-P1 routing↔preflight `has_vault` fork happened. When no `.mega-sdd/` exists yet the script writes no file (it never mints an SDD signal in an unrelated directory); pass `--json-only` and read stdout instead.

The probes (10 core + the P2 foreign-SDD adoption probe) and where each lands:

| # | Probe (identical semantics to the pre-P1 prose) | `state.json` field |
|---|---|---|
| 1 | **PRD/seed detection** — `prd.md`, `seed-PRD.md`, or `*.md` PRD candidates at the ROOT **plus one level inside dirs whose name case-insensitively matches `PRD`/`docs`/`documents`/`requirements`** (fixed set, never a repo walk; subdir hits keep their ON-DISK prefix, e.g. `PRD/prd-simkredit.md`; dirs deduped by inode on case-insensitive filesystems) | `probes.prd` (`present` / `candidates[]` / `newest_mtime`) |
| 2 | **Vault detection** — priority order: `.mega-sdd/vaults/*` (canonical — `vault.json` OR bare `0[0-6]-*.md` docs count, SAME semantics as `validate-preflight.sh has_vault()`, now literally the same library function: a 7-file vault without `vault.json` is still a vault, never invisible to routing) → `docs/mega-sdd/vaults/*/vault.json` (legacy) → `vaults/*/vault.json` (oldest legacy). First hit wins (`probes.vaults[0]` / `derived.vault`). When vault docs exist but `vault.json` is absent (`derived.manifest_derive_needed: true`), the proposed chain FIRST runs `scripts/derive-vault-json.sh --vault <vault>` (derives the manifest deterministically from the docs — never hand-write it) before any phase that reads `vault.json` — the script already prepends this step to `derived.proposed_next` | `probes.vaults[]` |
| 3 | **Bound-vault detection** — `<vault>/bound/` (canonical) or legacy `<vault>-bound/` sibling | `probes.vaults[].bound_present` |
| 4 | **Units detection** — `units/U-*.md` (+ `U-*/unit.md` layout + legacy sibling) | `probes.vaults[].units_count` |
| 5 | **Bolts detection** — `bolts/U-*/bolt-report.md` | `probes.vaults[].bolts_count` |
| 6 | **Repo detection** — inside a git repo? package manifests? existing code files? | `probes.git` / `probes.manifests[]` / `probes.code` |
| 7 | **Codebase-map detection** — `.mega-sdd/codebase/codebase-map.md` (canonical) → `<repo-root>/codebase-map.md` (legacy); first hit wins; + frontmatter `last_scanned_commit` vs git HEAD | `probes.codebase_map` (`present` / `path` / `last_scanned_commit` / `matches_head`) |
| 8 | **Knowledge-base detection** — `.mega-sdd/knowledge-base/README.md` (default) → `docs/knowledge-base/README.md` (legacy) → `docs/mega-sdd/knowledge-base/README.md` → `old-reference/knowledge-base/README.md`; first hit wins; report as `knowledge_base: present (path: <hit>)` or `absent` | `probes.knowledge_base` |
| 9 | **Open Questions count** — P0/P1 OQs split open-vs-deferred per the §OQ counting note (vault.json first, shared `vault_md` OQ grammar fallback) | `probes.vaults[].oq` (`pending_p0_p1` / `deferred_p0_p1`) |
| 10 | **Drift signals** — `DRIFT-REPORT.md` presence + recency (drift report at least as new as the newest bolt-report) | `probes.vaults[].drift_report` / `derived.drift_recent` |
| 11 | **Foreign-SDD detection** (P2 adoption) — spec-kit `.specify/`, Kiro `.kiro/specs/`, OpenSpec `openspec/`\|`.openspec/`, plus generic `specs/*.md` whose head opens with YAML frontmatter. Recognition only — the verdict comes from `scripts/certify-artifact.sh` | `probes.foreign_sdd` / `derived.foreign_sdd` (+ a `derived.notes[]` adoption note; the stdout digest appends `foreign_sdd=<tools>` only when non-empty) |

`derived.position` + `derived.proposed_next` carry the script's default reading of the decision matrix below. The matrix stays authoritative: flag- and intent-conditioned rows (`--greenfield`, `--sync`, `--from`/`--to`, rebuild intent, memory-informed overrides) are applied by the orchestrator ON TOP of the digest — the script never invents intent (such rows surface as `derived.notes[]` with an empty chain).

### Derived-position map (script default ↔ matrix row)

| `derived.position` | Encodes matrix row | Default `proposed_next` |
|---|---|---|
| `empty` | no inputs at all | `[]` (ask for PRD/brief) |
| `legacy_code_only` | code, no PRD/KB/vault — rebuild-intent rows need the user's word | `[]` + note |
| `prd_no_vault` | PRD, no vault (starterkit rows; absent starterkit → halt `no_starterkit_detected` note) | **express (default):** intent → bind `--express` → units (GROUND already ran as a script — no scan hop, no `--scan=`); **classic:** scan → intent → bind → units |
| `kb_no_vault` | `knowledge_base: present` + no vault | `generate-intent --kb=<kb>` |
| `oq_gate` | unresolved blocking-tier OQs, status != deferred (field `pending_p0_p1`; the grammar has NO P0 — P1 "Sprint-0 blocker" IS the blocking tier) | `resolve-oq` (express chain + `--auto`: the P3 batched walk — P1 asked ≤4-per-call, P2/P3 auto-defer RECORDED; standalone/classic: full interactive walk) |
| `prd_revision` | new PRD revision (file newer than vault) | `diff-vault <prd>` |
| `maintenance_sync` | Mode D row (freshness substrate = map OR symbol-index) | the full sync chain (below); express-born (index, no map) swaps hop 1 for `scripts/derive-changed-paths.sh` |
| `vault_greenfield_no_units` | vault mode=greenfield, no units | `generate-units` |
| `vault_no_map` | vault mode=existing, no codebase-map | **express (default):** bind `--express` → units (the map never exists on this spine — a scan demand here would trap every brownfield vault forever); **classic:** scan → bind → units |
| `vault_map_unbound` | vault + map, no bound-vault (incl. ACTIVE conflicts / mixed resolutions) | `bind-codebase` |
| `binding_resolved_no_rebind` | KEEP_VAULT/DEFER-only resolved binding (row below) | `generate-units` |
| `bound_no_units` | bound-vault exists, no units | `generate-units` |
| `units_pending_bolts` | units exist, some not in bolts | `execute-bolts --all --parallel` (`--per-squad` when `squad_count ≥ 2` — already parallel by procedure) |
| `all_units_executed` | all units executed, no recent drift check | `detect-drift` |
| `pipeline_complete` | all executed + recent drift check | `[]` |

## Decision matrix

**Spine rendering rule (P2 — the engine is authoritative, this table mirrors it).** The default spine is **express**: chains render WITHOUT a `scan-codebase` hop (GROUND — `derive-state.sh` extended probes + `build-symbol-index.sh` — already ran as a zero-token script step at the front door), and every `bind-codebase` hop carries `--express` (injected once, in the engine's `finish()`, the lean pattern). `--classic` / `spine: classic` renders the rows below verbatim as written. Scan-bearing rows in this table are therefore the CLASSIC rendering; under express the scan hop and any `--scan=` argument are dropped. Demote ≠ delete: `scan-codebase` stays fully invocable on demand — it is the only codebase-map producer.

### Starterkit-first ordering

The original directive "scan code base harusnya di atur di depan ... starterkit itu wajib ada. jika tidak ada baru greenfield" carried TWO obligations: starterkit is mandatory (unchanged — the halt below stands, now fed by the script-side pack matcher in `state.json` `derived.framework_pack`), and code-awareness must precede vault generation. P2 keeps the second obligation but moves its carrier: code-awareness now comes from GROUND (manifest sniff + pack resolve + symbol index, seconds) + intent's index-grounding + `bind --express` verification — not from a scan phase. The fabrication risk the old ordering guarded ("vault gen'd without code awareness") is covered by the same verification that was always the moat: an ungrounded vault claim cannot pass bind.

| State (from inspection) | Proposed chain |
|---|---|
| **Starterkit detected** + no vault + no codebase-map + PRD or brief present | express (default): `generate-intent [<prd>\|--from-prompt]` (index/state-grounded vault) → `bind-codebase --express` → `generate-units`. Classic: `scan-codebase` (load pack into context) → `generate-intent --scan=<codebase-map> [<prd>\|--from-prompt]` (pack-aware vault) → `bind-codebase` → `generate-units` |
| **Starterkit detected** + Legacy codebase + rebuild intent + no vault | express (default): `extract-intelligence <legacy>` (KB) → `generate-intent --kb=<kb>` → `bind-codebase --express` → `generate-units`. Classic: `extract-intelligence <legacy>` (KB) → `scan-codebase` (TARGET scaffold) → `generate-intent --kb=<kb> --scan=<codebase-map>` (KB + pack aware) → `bind-codebase` → `generate-units` |
| **Starterkit ABSENT** + `--greenfield` flag set | `generate-intent --greenfield [<prd>\|--from-prompt]` (stack-agnostic vault) → `generate-units` (no scan/bind until user scaffolds) |
| **Starterkit ABSENT** + no `--greenfield` flag | HALT `no_starterkit_detected` with options (scaffold first / opt in greenfield / cancel) |

### Pre-existing flows (legacy starterkit-absent path; preserved for back-compat)

| State (from inspection) | Proposed chain |
|---|---|
| Legacy codebase + no PRD + no vault + rebuild intent (user mentioned "rebuild di stack baru" / "reverse engineer" / "extract intelligence") | `extract-intelligence <legacy>` → `generate-intent --kb=<kb>` |
| `knowledge_base: present` + no vault | `generate-intent --kb=<kb>` (skip extract-intelligence — already done). **+ MENTION the `emit-prd` reverse lane** (one line, never auto-chained): a team-readable PRD draft from the KB with `[VERIFIED]/[INFERRED]/[OPEN]` markers carried verbatim (`/mega-sdd:emit prd`, reverse mode). Docs are OUTPUTS — `generate-intent --kb` stays the pipeline continuation. |
| Brief only (no vault, no PRD, no KB) + starterkit absent + `--greenfield` | `generate-intent --from-prompt --greenfield` (Q&A first) |
| PRD exists, no vault, starterkit absent + `--greenfield` | `generate-intent <prd> --greenfield` |
| Vault exists, mode=greenfield, no units | `generate-units` |
| Vault exists, mode=existing, no codebase-map | express (default): `bind-codebase --express` → `generate-units`. Classic: `scan-codebase` → `bind-codebase` → `generate-units` |
| Vault exists, codebase-map exists, no bound-vault, BUT `binding.md` has NO ACTIVE (unresolved) conflict block AND every resolution action is KEEP_VAULT or DEFER (ZERO KEEP_CODE/SPLIT — those edited the vault and still need a re-bind) — a KEEP_VAULT/DEFER-only resolution leaves `bound/` absent by design | `generate-units` (the resolution-marked binding.md needs no re-bind; routing to `bind-codebase` would re-derive the unchanged vault-vs-code contradiction, re-raise the SAME CONFLICT and infinite-loop — per `resolve-oq/references/binding-mode.md` Step 5 + `convergence-loops.md`). NOTE: a MIXED / KEEP_CODE / SPLIT resolution ALSO leaves `bound/` absent but the vault WAS edited — it falls through to the `bind-codebase` row below (re-bind), matching the resolve-oq handoff + convergence surfaces |
| Vault exists, codebase-map exists, no bound-vault | `bind-codebase` (alone if blocking; chain if clean) |
| Bound-vault exists, no units | `generate-units` |
| Units exist, some not in bolts | `execute-bolts --all --parallel` |
| Vault has `squad_count: ≥2`, units exist, some not in bolts | `execute-bolts --per-squad` |
| Vault has `squad_count: ≥2`, units exist, user invokes from a single-squad context (e.g., on a dev's laptop with a specific role) | Ask: "Run for which squad?" then propose `execute-bolts --squad=<answer>` |
| Vault has `squad_count: ≥2` but `interfaces_count: 0` and ≥1 unit has cross-squad coupling hint in vault_source | `generate-units` (re-run, will surface `interface_ref_missing` halts as needed) |
| All units executed, no recent drift check | `detect-drift` |
| **All units executed + acceptance evidence present** (≥1 `bolts/U-*/acceptance.json` — `state.json` `probes.vaults[].bolts_count` > 0 signals the bolts state; the evidence file is the P4 B4 artifact) | PROPOSE `emit-sit` alongside the row above (one line, never auto-chained): the SIT §4 executed-evidence tables are script-derived by `scripts/build-sit-evidence.sh` from `acceptance.json`/`postflight.json`/`_batch-suite.json`; units without evidence surface as `[Pending — bolt U-XXX belum dieksekusi]`, never invented; maturity (`planned→partial→executed`) comes from evidence coverage. Docs are OUTPUTS — emit-sit never gates the pipeline. |
| **Mode D — maintenance/sync** (a freshness substrate — map OR symbol-index (P2: express-born projects never grow a map) — + binding exist AND change signal present: `.mega-sdd/codebase/.dirty-paths.jsonl` non-empty OR git HEAD ≠ the map's `last_scanned_commit` OR git HEAD ≠ the index's `head_commit` — i.e. `derived.change_signal` in `state.json`) | The never-ending-development sync chain: changed-set derivation → scoped `detect-drift` → `bind-codebase --paths` → `generate-units --reconcile` → `execute-bolts` (stale/new units only). Per-hop semantics, the express-born branch, the Short-circuit gate, and the fallback lanes: **§Mode D — maintenance/sync detail** below. `--sync` forces this row regardless of other inference. |
| Vault has unresolved P0/P1 OQs with status != deferred | `resolve-oq` first (intent gate, before any other chain) |
| Vault has only deferred P0/P1 OQs + brownfield context | express (default): `bind-codebase --express` (auto-resolves deferred OQs from index/manifest probes). Classic: `scan-codebase` → `bind-codebase` |
| New PRD revision detected (file newer than vault) | `diff-vault <new-prd>` first |
| **Delta lane — ticket-scale quoted free-text + owned vault** (overlay only: the front door or explicit user intent hands over a chat brief; the sentence names an entity/flow an existing vault's `00-index.md` roll-up owns; NEVER fired from derived state alone) | `diff-vault --from-prompt "<brief>"` → on clean apply the chain continues per **§Delta lane detail** below. A `prd_revision` (file newer than vault) OUTRANKS this row — a real PRD revision wins over a chat sentence. |
| **Adoption — foreign SDD detected** (`derived.foreign_sdd` non-empty: spec-kit `.specify/`, Kiro `.kiro/specs/`, OpenSpec, generic frontmatter'd `specs/*.md`) | PROPOSE the DEMOTE lane — their spec files enter at the **PRD rung**: `Run: scripts/certify-artifact.sh --cwd=<root> --rung=prd --path=<spec-file>` per file, then `generate-intent` on the certified files. Never ingest a foreign artifact mid-pipeline (vault/map/kb rungs are grammar-gated). The script only NOTES this lane (`derived.notes[]`) — it never auto-chains it, because a re-ingest needs the user's word (the DEMOTE policy below). |
| **Adoption — external map / vault placed by hand** (map present but `validate-codebase-map` records FAIL / `codebase_map_fm_missing` — the unverified-external shape; or a vault dir whose `vault.json` is absent AND `derive-vault-json` was never run) | PROPOSE `Run: scripts/certify-artifact.sh --rung=map\|vault --path=<artifact>` FIRST — the verdict (CERTIFIED / CERTIFIED_DEGRADED / DEMOTE / REJECTED, each with keterangan) decides the lane BEFORE any phase consumes the artifact. CERTIFIED/CERTIFIED_DEGRADED → continue the normal rows above (a DEGRADED map binds with `codebase_map_provenance: unverified-external`). REJECTED → surface the keterangan verbatim (it carries the re-scan / re-ingest offer). |

**DEMOTE under `--auto` (LOCKED):** a `DEMOTE` verdict from `certify-artifact.sh` is **ALWAYS a C2 halt** — `type: adoption_demote_confirm` (see `plugins/mega-sdd/references/halt-protocol.md`) with the certify keterangan rendered first and ONE AskUserQuestion-shaped confirmation (re-ingest / manual fix / cancel). Never unconfirmed: the demotion burns generate-intent tokens and produces a DIFFERENT vault than the artifact the user placed. A v4-mega-sdd-authored artifact is never REJECTED (migration guarantee — CERTIFIED_DEGRADED floor).

**OQ counting note:** When inspecting vault for P0/P1 OQ counts, distinguish:
- `pending_p0_p1_count`: OQs with `status: open` (or status field absent; a legacy `pending` value in a pre-W5 manifest reads the same) at P0/P1 priority. These gate the chain via the intent rule above.
- `deferred_p0_p1_count`: OQs with `status: deferred`. These do NOT gate; they propagate to binding phase.

### Mode D — maintenance/sync detail

- **Express-born branch (index, no map — EXPRESS spine only; classic falls through to the scan-first repair rows): hop 1 is `scripts/derive-changed-paths.sh --vault <vault>`** — git diff `head_commit`..HEAD ∪ working tree ∪ dirty journal → the same `.sync-changed-paths.txt`, then the chain below continues identically with `bind --paths --express`.
- **Short-circuit gate (BOTH lanes, after the changed set exists): `scripts/sync-intersect.sh --cwd=<root> --vault=<vault> --paths=@<vault>/.sync-changed-paths.txt` — exit 0 (`in_sync`: changed ∩ binding anchors ∪ unit target_files = ∅) → stamp freshness, one-line SYNC-REPORT.md, chain ENDS (nothing to re-verdict — proportional verification); exit 4 → proceed; exit 2 or ANY other unexpected exit → fail-closed, full chain.**
- **Script exit 3** (no baseline stamp / git unavailable / write failed) → the SAME full-scan-fallback shape as the map lane: skip detect-drift, hand off `bind-codebase <vault> --auto --express` directly — a FULL re-bind, never a guessed scope.
- The chain: `scan-codebase --changed-only` (writes `<vault>/.sync-changed-paths.txt` — the durable changed set the non-interactive downstream reads once the journal is consumed, because by then the journal is deleted and the stamp advanced, so it cannot be reconstructed; **on the full-scan fallback** it writes no changed set and hands off `bind-codebase <vault> --auto` DIRECTLY — a FULL re-bind, detect-drift SKIPPED because there is nothing to scope, §3.8(b)(1); a scope-less detect-drift would null-terminate the chain before the re-bind. The `<vault>` is mandatory: with no `.sync-changed-paths.txt` on this branch it is the only signal the non-interactive downstream bind receives) → `detect-drift --scope=@<vault>/.sync-changed-paths.txt` (scoped to those changed paths; its OWN handoff CONTINUES the sync lane straight to `bind-codebase --paths`, NEVER to resolve-oq — resolve-oq has no drift-consumption mode) → [`resolve-oq` ONLY if the drift scan CREATED an `OQ-DC-N` stub — resolve-oq handles that stub in its ordinary intent mode; it never ingests drift findings] → `bind-codebase --paths=@<vault>/.sync-changed-paths.txt` → `generate-units --reconcile` → `execute-bolts` (stale/new units only; `superseded` skipped).
- The never-ending-development lane per spec `2026-06-10-living-vault-continuous-sync-design.md` §3.3 (per-hop handoff semantics clarified by §3.8).

**Mode D autonomous policy (`--sync --auto`):** one upfront confirmation covers the whole chain; mid-chain decisions are DEFERRED, never asked — drift direction calls + write-back drafts + re-bind CONFLICTs queue into `<vault>/PENDING-SYNC.md` (mode note: `DRIFT-ACTIONS.md` is the RETIRED pre-v3.0.0 interactive artifact — no step writes it in any mode; `PENDING-SYNC.md` is the only queue, so its absence is never a missing file); the chain executes everything the gates allow and ends by writing `<vault>/SYNC-REPORT.md` (applied vs queued, conflicts, reconcile outcomes, closing staleness verification via `scripts/compute-unit-staleness.sh`). A queued CONFLICT yields handoff `status: paused` with the digest path in `next_action` — never `completed`-with-silence.

- **Cache-warm the graph (non-blocking).** After `SYNC-REPORT.md` is written,
  `Run: scripts/build-graph.sh --root <project>` to refresh `.mega-sdd/graph.json`.
  This is cache-warming only — a failure here NEVER blocks sync and emits no halt
  YAML (the graph is rebuilt lazily on next `graph` query regardless).

**Mode D change-signal inspection (from the digest — same two probes, script-run):** read `derived.change_signal` in `state.json` — `dirty_journal_rows` (IN-REPO rows of `.mega-sdd/codebase/.dirty-paths.jsonl` — absolute-path rows are pre-6.0.1 out-of-repo pollution and never count) and `map_stamp_matches_head` (map frontmatter `last_scanned_commit` vs `git rev-parse HEAD`). `dirty_journal_rows > 0` OR `map_stamp_matches_head: no` → Mode D candidate. Mode D NEVER fires on a repo without an existing map+binding (that's a normal brownfield first-run, rows above). Precedence: the P0/P1 OQ intent gate still runs first; a new PRD revision (diff-vault row) outranks sync. The delta lane never contends with either: it fires only on an explicit chat-brief overlay (different entry signal), and a present PRD revision outranks it too.

### Delta lane detail (`diff-vault --from-prompt` — spec `2026-08-11-free-text-delta-lane.md`)

- **Entry** is ALWAYS an overlay (front-door proposal or explicit user intent) — the state engine never invents a delta from derived state, and the lane is propose-first: a bare "tambah kolom X" with no mega-sdd intent routes NOWHERE (the user-control escape hatch stands).
- **The chain:** `diff-vault --from-prompt "<brief>"` (narrow-scope diff + `delta_too_large` cap + apply + Step 7.5 writes `<vault>/.delta-changed-paths.txt`) → `bind-codebase --paths=@<vault>/.delta-changed-paths.txt` (claim-scoped re-bind; the lane default `--express` applies as on every bind hop; the vault-section leg additionally reads `VAULT-DIFF.md` per `binding-contract.md §Claim-scoped re-bind`) → `generate-units --reconcile` → `execute-bolts` (stale/new units only; `superseded` skipped). Bind's own STATE-AWARE handoff decides `--reconcile` vs bare `--auto` (a fallback-to-full re-bind hands off bare — existing `auto-memory-handoff.md` contract). The reconcile step's transitive-impact advisory (`derive-transitive-impact.sh`, task-typing.md step 2.6) rides the handoff — dependents of changed units are OFFERED as verify-recommended bolts, never auto-run, never a gate (fail-open on a missing graph).
- **Fail-closed edges (the script's exit codes, nothing else):** `derive-delta-paths.sh` exit 3 (no `binding.json` — unbound vault) → NO scoped hop; the normal chain rows above apply. Exit 2 (ANY parse failure) → `bind-codebase <vault> --auto --express` DIRECTLY — a FULL re-bind, never a guessed scope (same shape as Mode D's exit-3 fallback).
- **NOT the sync lane:** no scan hop, no detect-drift hop (no code moved — nothing to drift-check), own scope file (`.delta-changed-paths.txt`, never `.sync-changed-paths.txt` — that basename is the sync discriminator with a scan-owned lifecycle). The delta scope file is SINGLE-USE by convention: overwritten by every from-prompt apply, read only by this overlay's bind proposal — a stale leftover is never consumed by another lane.
- **Halted `delta_too_large`** → the user's choice routes: `full_lane` → `generate-intent --from-prompt` (new-vault row); `split_ticket` → user re-enters with a smaller brief; `cancel` → end, vault untouched.

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

**Brownfield code-awareness**: vault generation must have codebase context (conventions, existing entities, framework signals) — a vault gen'd blind fabricates entities, discovers PARTIAL_FIELDS_MISSING late, and cold-starts the OQ classifier. **The carrier changed in P2:** on the express spine (default) that context comes from GROUND (`state.json` manifests + `derived.framework_pack` + symbol-index queries) with `bind --express` as the verification backstop — the scan-bearing rows below are the CLASSIC rendering (Spine rendering rule above: under express the scan hop + `--scan=` drop out).

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
| Units exist, some not in bolts | `execute-bolts --all --parallel` (1 phase) |

### Greenfield vs brownfield detection

When `--deep` chain plans, orchestrator probes:

- `.git` present + existing code files (`.{php,js,ts,py,rs,go,rb}` etc.) → **brownfield** (classic: run scan-codebase first; express: GROUND already supplied the context)
- `.git` present + only scaffolding files (e.g., bare Laravel boilerplate, no business logic) → **brownfield-light** (classic: run scan-codebase --quick first; express: same as brownfield)
- No `.git` OR fresh `composer create-project`/`npx create-*` with no manual edits → **greenfield** (skip scan-codebase upfront)

Override via `--brownfield` / `--greenfield` flag on `auto`/`orchestrate-flow`.

**Halt behavior unchanged**: any blocker (CONFLICT, business OQ, hard_rule_violated, dedup_ambiguous, etc.) pauses the deep chain identically to current cap-3 behavior. User resolves, then runs `orchestrate-flow --deep --resume`.

**Confirmation behavior in `--deep`**: ONE upfront confirmation listing ALL phases. User picks Run / Edit / Cancel. A single upfront confirmation covers the entire chain INCLUDING destructive phases (`execute-bolts`); bolts have their own existing safety (target_files whitelist, Hard rules).

### `--from=<phase>` and `--to=<phase>` interaction with `--deep`

- `--from=<phase>` skips earlier phases regardless of CWD state. Useful for forcing re-execution of a specific later phase.
- `--to=<phase>` stops at that phase. Useful for staging (run extract + intent, review, then run bind + units + bolts separately).
- `--from` + `--to` + `--deep` combine cleanly. Example: `/mega-sdd --deep --from=bind-codebase --to=generate-units` runs only the 2-phase window.

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
