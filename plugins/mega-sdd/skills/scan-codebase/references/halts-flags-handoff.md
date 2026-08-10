# scan-codebase — halts, flags, handoff & memory

## Contents
- Anti-hallucination rails
- Halt conditions (dep_missing; spawn budget; >100k files; monorepo ambiguity; the 0-interface NON-halt)
- scan_spawn_budget_exceeded (STOP)
- scan_repo_too_large (STOP)
- scan_primary_app_ambiguous (STOP)
- deep_scan_subagent_failed (SOFT)
- deep_scan_cache_corrupt (SOFT)
- deep_scan_subagent_all_failed (ALWAYS STOP)
- Deterministic behavior (non-interactive; `--auto` selects the chain lane)
- Flags catalog
- Hand-off announcement + handoff YAML emission (UNCONDITIONAL)
- Memory layer (reads / writes / anti-halu rails)

Loaded by `scan-codebase` for failure handling, flag resolution, and chain/memory integration. The surface scan procedure and the deep-scan stage are separate references the SKILL.md router links to.

## Anti-hallucination rails

- If a section has no detection: write "None detected" — do NOT invent.
- Limit symbol extraction to **first 200 per category** (prevents giant maps). When a cap fires, stamp `truncated_sections: ["<section numbers>"]` in the map frontmatter — binding MUST treat absence-in-a-truncated-section as UNKNOWN, never as NEW/absent evidence (a truncated-away implemented element must not become a duplicate-implementation `create` task).
- Cite line numbers for routes/models (`src/foo.ts:42`) so binding can verify.
- Deep-scan no-fabrication: each subagent MUST emit `lib: not_detected` when no fingerprint matches, NEVER guess. The consolidator self-validates each slice against starterkit-context-schema.md before write and drops violators (a rules-tier LLM check, not a hook).
- Deep-scan citation rail: every starterkit-context.yaml field MUST be backed by `_source: [<file>, ...]` companion field (libs slice: `_source` names the producing manifest). Slices without `_source` are dropped by the consolidator self-validation.
- Deep-scan read-only: every extractor prompt template carries the READ-ONLY rail (no Edit/Write/mutating Bash). This is a **prompt-level rule (rules tier), not a dispatch-level tool restriction** — the extractors are prompt-template dispatches, not plugin agents with a `tools:` allowlist. A slice whose output evidences a rail violation is dropped at consolidation.
- Secret-scan gate: assembled `codebase-map.md` / `starterkit-context.yaml` / `reuse-index.yaml` content is scrubbed BEFORE write by `scripts/secret-scan.sh --redact` (deterministic; matched values become `[REDACTED-SECRET]`; a private-key match redacts the WHOLE block, header through END marker). **For `codebase-map.md` the scrub is CHAINED by `derive-codebase-map.sh`** — the deriver runs the redactor on its temp before renaming (the write path cannot skip it) and surfaces the findings in its stdout `secret_findings` for the model to route, on EVERY non-empty result including the exit-4 halt path. The two deep-scan writes in `references/deep-scan-dispatch.md` Step 10.5.3 steps 3+6 (`starterkit-context.yaml` + `reuse-index.yaml`) remain model-run scrubs. **Findings from EVERY scrub site are routed to disk** — append the affected source `file:line` + pattern class (never the matched value) to `<project>/.mega-sdd/codebase/SECRET-FINDINGS.md`, then also emit one chat line (`references/scan-procedure.md` Step 10a owns the file's table shape). Disk is the durable channel because this skill is non-interactive: the artifact keeps only `[REDACTED-SECRET]`, the handoff schema carries `blockers[]` and no warnings key, and a chat-only warning would leave the live credential's location recoverable nowhere. The gate redacts scan outputs only — it never edits repo source.

## Halt conditions

scan-codebase is **non-interactive on every path**: every condition below resolves to a named blocker carrying its exact re-run command, emitted with `status: halted`, and the run STOPS. None of them is a question, and none of them waits. The ONE lane-dependent condition is the Step 5 spawn budget — see its bullet.

- **Repo > 100k files AND no `--force-large`:** emit `scan_repo_too_large` (re-run with `--force-large` to accept the cost, or `--include=<glob>` to narrow). Proceed silently when `--force-large` was passed.
- **Estimated extraction time > 60 s** (Step 5 spawn-cost gate) — **LANE-DEPENDENT, the only such condition**. Lane 1, an explicit `--engine=` or `--include=`, already IS the caller's precision-vs-latency decision → proceed, log the estimate, no blocker. Lane 2, **undecided STANDALONE** (a direct user invocation carrying none of lane 3's signals): emit `scan_spawn_budget_exceeded` before extracting, carrying `N_total` (= `N_hash` + `N_extract`), the estimate, the OS, and the re-run commands (`--engine=ast-grep` / `--engine=regex` / `--engine=tree-sitter` / `--include=<glob>`). Lane 3, **UNATTENDED** — `--auto`, a forked body, or an orchestrator-dispatched phase (how the Mode-D `--changed-only` sync hop arrives); `--auto` alone is NOT the discriminator, since no routing row renders it on the scan hop: **neither halt nor stall** — downgrade to the highest OOM-safe tier: `ast-grep` when the Step-0 digest carries `astgrep_version` (extraction ~ONE spawn, `precision_tier` STAYS `ast`), else `regex`; record it in the map frontmatter (`precision_downgrade_reason`, plus `precision_tier: regex` only on the regex fall), one chat line, and the handoff `next_action.rationale` with the AST-recovery command; `status: completed`, no `blockers[]` entry. A blocker on that lane would halt phase 1 of nearly every brownfield chain, and no routing row pre-resolves `--engine`/`--include`. This gate fires FAR earlier than the 100k halt on Windows — at ~220 ms/spawn a 100k-file repo is 6.1 hours (and the gate trips at ~272 files), so the file-count halt is a POSIX-era guard that never gets reached there. Lane rationale + the record shape: `references/scan-procedure.md §Spawn-cost gate`.
- **Monorepo primary-app unresolvable** (≥2 app-root manifests, no explicit `--include`, no root manifest that owns them — Step 2 precedence exhausted): emit `scan_primary_app_ambiguous` listing the candidate app roots. See `references/scan-procedure.md §Step 2`.
- **A forced `--engine=tree-sitter|ast-grep` whose binary is not on PATH:** halt `dep_missing` naming the forced binary — never a silent fall-through (install guidance is in the tree-sitter integration reference).
- **Map-write deriver failures (Step 10):** `derive-codebase-map.sh` exit 2 → emit **`codebase_map_derive_failed`** (`details`: the stderr line + the delta dir; remedy = fix the named delta gap and re-run the same scan). Exit 4 → emit **`codebase_map_invalid`** (`details`: `rejected_path` + the validator verdict; NOTHING was renamed — the prior map is intact; remedy = inspect `<out>.rejected`, correct the delta, re-run) — and route any `secret_findings` from the deriver's stdout to `SECRET-FINDINGS.md` BEFORE emitting the blocker. Exit 3 is a **recorded recovery, not a halt**: re-run the scan as FULL (`status: completed` on the re-run; on the sync lane it takes the step-2 full-scan-fallback branch). Both blockers use the standard envelope (`type` + `source_skill: scan-codebase` + `details` + the re-run command); no bespoke YAML shape is needed.
- **Detection produces 0 public interfaces — NOT a halt, by decision.** A repo can legitimately expose nothing, and the alternative reading (a misconfigured `--include`) is fixed by re-running, not by waiting. Record the suggested re-run command (`--include=<glob>`) in the scan summary AND in the handoff `next_action.rationale`, emit `status: completed`, and finish. Do not add it to the halted trigger list below.

### `scan_spawn_budget_exceeded` — STOP (lane 2 only: undecided STANDALONE)

**Emitted ONLY on the undecided STANDALONE lane** — a direct user invocation, with no explicit
`--engine=`/`--include=` and none of the unattended signals (`--auto`, a forked
body, an orchestrator-dispatched phase). On ANY unattended invocation this condition
does NOT produce a blocker at all: the chain lane downgrades to the
highest OOM-safe tier (ast-grep when present — `precision_tier` stays `ast` — else regex)
and records it (`precision_downgrade_reason` in the map frontmatter, `precision_tier: regex`
only on the regex fall, one chat line, the AST-recovery command in `next_action.rationale`)
and finishes with `status: completed`. Both branches are the same
policy — the caller keeps the precision decision — expressed for the lane that has a caller to
hand it back to. → `references/scan-procedure.md §Spawn-cost gate`.

```yaml
type: scan_spawn_budget_exceeded
source_skill: scan-codebase
details:
  engine: tree-sitter
  os: <"windows-bash" | "posix">
  n_hash: <int>                      # invalidation-gate spawns (0 without --shallow-scan)
  n_extract: <int>                   # files that would actually be extracted
  n_total: <int>                     # n_hash + n_extract — the TOTAL bill
  per_spawn_sec: <0.22 on windows-bash, else 0.02>
  estimate_sec: <int>
  budget_sec: 60
next_action: "Re-run with ONE of — (a) `--engine=ast-grep` (tier-1 D2): SATU proses untuk seluruh set (grammar embedded, tanpa kompilasi clang), presisi TETAP tier `ast`; (b) `--engine=regex`: satu panggilan per bahasa, selesai dalam detik, presisi turun ke tier `regex` dan peta mencatatnya di `precision_tier`; (c) `--engine=tree-sitter` (lane opt-in): presisi AST penuh dengan biaya SATU proses per FILE — jauh di atas estimasi ini di mesin ber-EDR; (d) `--include=<glob>`: persempit himpunan file sehingga n_extract turun. Presisi adalah properti yang DILAPORKAN peta, jadi pilihannya milik pengguna — skill tidak menurunkan engine diam-diam."
```

Recovery: caller re-runs with one of the four flags. An explicit `--engine=`/`--include=` suppresses this gate, so the remedy always terminates. The `--auto` lane's recovery command (`--engine=tree-sitter` / `--include=<glob>`) terminates for the same reason.

### `scan_repo_too_large` — STOP

```yaml
type: scan_repo_too_large
source_skill: scan-codebase
details:
  files_enumerated: <int>
  threshold: 100000
next_action: "Re-run with `--force-large` untuk tetap memindai seluruh repo (biaya waktu penuh diterima), atau `--include=<glob>` untuk mempersempit ke app/paket yang relevan. Scan tidak menebak dan tidak menunggu jawaban."
```

Recovery: caller re-runs with `--force-large` or `--include=<glob>`.

### `scan_primary_app_ambiguous` — STOP

```yaml
type: scan_primary_app_ambiguous
source_skill: scan-codebase
details:
  candidate_app_roots:
    - path: "apps/web"
      manifest: "apps/web/package.json"
    - path: "apps/api"
      manifest: "apps/api/composer.json"
  root_manifest: <"none" | "workspace-pointer-only: <file>">
  precedence_exhausted: "no --include, no owning root manifest, >1 app-root manifest"
next_action: "Re-run with `--include=<glob>` menunjuk app yang jadi target (mis. `--include='apps/api/**'`). Peta yang menggabungkan beberapa app akan salah saat di-bind, jadi pilihan app adalah keputusan pemanggil — scan tidak memilih sendiri dan tidak bertanya."
```

Recovery: caller re-runs with `--include=<glob>`.

### `deep_scan_subagent_failed` — SOFT

```yaml
type: deep_scan_subagent_failed
source_skill: scan-codebase
details:
  domain: <auth | authz | ui_ux | libs | reuse>
  subagent_index: <1-5>
  failure_reason: <"timeout" | "malformed_yaml" | "api_error: <msg>">
  retry_count: <1 or 2>
next_action: "Continue with partial output — starterkit-context.yaml will be emitted with partial: true and partial_slices: [<domain>]. Pipeline continues; downstream consumers degrade gracefully for missing slices."
```

Recovery: auto-retry once. On second failure: emit partial output. Soft halt — chain continues.

### `deep_scan_cache_corrupt` — SOFT

```yaml
type: deep_scan_cache_corrupt
source_skill: scan-codebase
details:
  file_path: "<project>/.mega-sdd/codebase/starterkit-context.yaml"
  parse_error: "<error message from YAML parser>"
next_action: "Auto-invalidate corrupt cache and re-dispatch subagents. Transparent to user; no manual action required."
```

Recovery: auto-invalidate cache + re-run subagents. Soft halt — chain continues.

### `deep_scan_subagent_all_failed` — ALWAYS STOP

```yaml
type: deep_scan_subagent_all_failed
source_skill: scan-codebase
details:
  failed_domains: [auth, authz, ui_ux, libs, reuse]
  common_failure_reason: <"api_outage" | "rate_limited" | "unknown">
next_action: "Re-run scan-codebase later (likely API outage; user retry required). Existing starterkit-context.yaml (if any) preserved untouched."
```

Recovery: user re-runs scan-codebase later. Chain halts.

## Deterministic behavior (non-interactive; `--auto` selects the chain lane)

scan-codebase has **no interactive mode**, so this table describes the *only* behavior. `--auto` is **not** a no-op and **not** merely "implied": it names the **CHAIN LANE** — an `orchestrate-flow` / `/mega-sdd` / `sync` hop, and every forked run — where nobody is on the other end. Exactly ONE row is lane-dependent (Step 5's spawn budget); every other row behaves identically with or without the flag. Each row is a former human-stop site converted to a deterministic outcome. The safety property those stops protected (a costly / wrong-scope / lossy scan never proceeds on the skill's own unrecorded authority) survives in one of two shapes: a **named blocker that stops the run and hands the decision back with the exact command to make it**, or — where stopping is itself the unsafe act — a **RECORDED downgrade** that states in the artifact exactly what was traded and how to get it back.

| Site | Deterministic behavior (never prompts, never waits) |
|---|---|
| Step 0 (engine) | Run `scripts/probe-scan-engine.sh` — ONE spawn: D2 ladder digest (AUTO `ast-grep → regex`, tree-sitter never invoked; `--engine=tree-sitter` opt-in runs the serial bounded smoke tests); ast-grep absent → `engine: regex` with a chat note. A forced `--engine=` whose binary is absent → `dep_missing` |
| Step 2 (monorepo primary app) | Precedence: explicit `--include` > owning root manifest > single app-root manifest; residual ambiguity → `scan_primary_app_ambiguous` |
| Step 4 (repo > 100k files) | `--force-large` passed → proceed; else → `scan_repo_too_large` |
| Step 5 (spawn-cost gate, `estimate` > 60 s) — **the one lane-dependent row** | **Lane 1** explicit `--engine=`/`--include=` → proceed, log the estimate. **Lane 2** undecided STANDALONE (a direct user invocation) → `scan_spawn_budget_exceeded`, STOP. **Lane 3** UNATTENDED (`--auto` / forked / orchestrator-dispatched — ties go here) → downgrade to the highest OOM-safe tier (ast-grep when the Step-0 digest has `astgrep_version` — `precision_tier` stays `ast`; else regex) and RECORD it (map `precision_downgrade_reason`, `precision_tier: regex` only on the regex fall, one chat line, AST-recovery command in `next_action.rationale`), `status: completed`. **Never** an UNRECORDED downgrade — `precision_tier` is a property the map reports, so lane 2 keeps the choice with the caller and lane 3 keeps the map honest about the tier it delivered |
| Step 5 (0 public interfaces) | NOT a halt — record the suggested `--include=<glob>` re-run in the summary + handoff, `status: completed` |
| Step 10a / 10.5.3 (secret findings) | Redact the artifact, append the `file:line` rows to `.mega-sdd/codebase/SECRET-FINDINGS.md`, list it in `artifacts[]`, emit one chat line; never blocks, never waits |
| Step 10.5 (deep-scan slices) | `deep_scan_subagent_failed` / `deep_scan_cache_corrupt` auto-recover (partial output / cache invalidate); all five fail → `deep_scan_subagent_all_failed` |
| Hand-off | Emitted on **every** invocation, `--auto` or not (see §Handoff YAML emission) |

**Never:** calls `AskUserQuestion`; waits for a reply; downgrades the engine WITHOUT stamping `precision_tier` + `precision_downgrade_reason` in the map, saying so in chat, and carrying the recovery command in the handoff; guesses a primary app; writes a handoff only under `--auto`; edits repo source.

## Flags catalog

- `--depth=N`: tree depth (default 8)
- `--include=<glob>`: scan only matching files (repeatable)
- `--exclude=<glob>`: skip matching files (repeatable; **appended** to defaults — the default exclusion list is a separate reference)
- `--no-default-excludes`: disable the default exclusion list entirely (rare; opt-in scan of dep trees)
- `--out=<path>`: override output location
  - Default: `<project-root>/.mega-sdd/codebase/codebase-map.md` per `plugins/mega-sdd/references/paths.md`
  - Legacy default: `<project-root>/codebase-map.md` (preserved when `.mega-sdd/` dir absent OR `layout: legacy` in config)
  - User explicit `--out=<path>` always respected
- `--auto`: **selects the CHAIN LANE — it is not semantically empty.** There are no prompts left to skip (§Deterministic behavior above is the only behavior), but the flag still carries meaning: it declares that nobody is on the other end (an `orchestrate-flow` / `/mega-sdd` / `sync` hop, or a forked body), which is what lets the Step 5 spawn-cost gate take the RECORDED downgrade (ast-grep when present, else regex) instead of halting phase 1 of the chain. Without it the run is STANDALONE and that gate emits `scan_spawn_budget_exceeded` instead. Every other outcome is identical either way, and its absence never suppresses the handoff
- `--force-large`: accept the cost on >100k file repos (without it, that condition emits `scan_repo_too_large`)
- `--engine=tree-sitter|ast-grep|regex`: force a lane; default auto = `ast-grep → regex` via `scripts/probe-scan-engine.sh` (tree-sitter is reachable ONLY through this flag)
- `--shallow-scan`: two coupled fast-path semantics — (a) skip the Step 10.5 deep-scan stage (emit only the surface codebase-map.md), and (b) enable the Step 5 per-file invalidation gate (reuse prior §2 rows whose `Last_Scanned_Sha256` matches the file's current hash; only changed files re-extract — per `references/scan-procedure.md` §Step 5)
- `--force-deep`: force deep-scan even when framework confidence is LOW (override Step 10.5.0 trigger check)
- `--no-cache`: invalidate deep-scan cache; re-run all 5 slice subagents even if lock files unchanged
- `--changed-only`: incremental re-scan — resolve changed paths (dirty journal ∪ `git diff <last_scanned_commit>..HEAD` ∪ uncommitted), re-extract only those, merge into the prior map, consume the journal (rotate-and-delete per `references/scan-procedure.md` §Incremental step 4 — never truncate-in-place, which loses concurrent-session appends); auto-falls back to full scan when preconditions absent (per §Incremental mode). On incremental success with a vault present (sync lane) it ALSO writes the resolved changed set to `<vault>/.sync-changed-paths.txt` (one path per line, overwrite) — the durable scope channel for the two non-interactive downstream phases that accept a path scope (`detect-drift --scope=@…`, which IS forked, and `bind-codebase --paths=@…`, which is a fork candidate but not yet forked; `generate-units --reconcile` reconciles from the refreshed `binding.md`, not this file), which can't self-resolve because the journal is already consumed and the stamp advanced by the time they run (§Incremental step 5); the full-scan fallback writes no such file, deletes any stale one, and continues Mode D straight to a FULL re-bind (`bind-codebase <vault> --auto` — the `<vault>` is mandatory: with no changed-set file on this branch it is the only signal the non-interactive downstream bind receives) — detect-drift is skipped on that branch (§Hand-off; spec §3.8(b)(1))
- `--memory-off`: disable memory-layer reads and writes

## Hand-off announcement

On completion, announce: "Codebase map written to `<path>`." followed by the CWD-conditional next step (a vault exists → `bind-codebase <vault>`; none yet → `generate-intent --scan=<map>`).

## Handoff YAML emission

**UNCONDITIONAL — emitted at the end of skill output on EVERY invocation**, chain (`--auto`, typically `orchestrate-flow --deep` or `/mega-sdd`) *and* standalone. It is deliberately NOT `--auto`-gated: a direct `scan-codebase` run never injects `--auto`, and this skill is non-interactive, so the handoff is the only channel by which the caller learns `next_action`, `artifacts[]` and `blockers[]`. Gating it on `--auto` would make a standalone run emit nothing at all. Template below is the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

```yaml
handoff:
  emitted_by: scan-codebase
  emitted_at: <ISO8601 timestamp>
  status: completed                                 # or paused | halted
  artifacts:
    - <absolute path to .mega-sdd/codebase/codebase-map.md>
    - <absolute path to .mega-sdd/codebase/starterkit-context.yaml>  # only when deep-scan ran
    - <absolute path to .mega-sdd/codebase/reuse-index.yaml>          # only when deep-scan ran (reuse slice)
    - <absolute path to .mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json>  # only when Step 10.6 wrote it
    - <absolute path to <vault>/.sync-changed-paths.txt>  # only on --changed-only incremental success with a vault present (sync-lane scope channel)
    - <absolute path to .mega-sdd/codebase/SECRET-FINDINGS.md>  # only when the Step 10a / 10.5.3 scrub found credentials this run (durable rotation worklist — the file:line the chat warning alone would lose)
  starterkit_context:                                                  # block only when deep-scan ran
    reused: false                                                       # true if cache hit
    framework: laravel
    auth_lib: sanctum
    authz_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
  next_action:
    # CWD-CONDITIONAL — resolve at emission time (the example below is the no-vault branch):
    #   no vault yet (starterkit-first Mode A/B default) → mega-sdd:generate-intent --scan=<map> --auto
    #   a vault already exists                           → mega-sdd:bind-codebase <vault> --auto
    #   invoked with --changed-only by the sync lane (Mode D), incremental ran → mega-sdd:detect-drift --vault=<vault> --scope=@<vault>/.sync-changed-paths.txt --auto
    #   full-scan fallback → SKIP detect-drift, hand off mega-sdd:bind-codebase <vault> --auto  (no changed set to scope; continue Mode D straight to a FULL re-bind per spec §3.8(b)(1) — a scope-less detect-drift would self-classify STANDALONE and null-terminate the chain before the re-bind)
    suggested_skill: mega-sdd:generate-intent
    suggested_args:
      - "--scan=<absolute path to .mega-sdd/codebase/codebase-map.md>"
      - "--auto"
    # APPEND to `rationale` when the Step 5 `--auto` lane downgraded the engine (map carries
    # precision_downgrade_reason; precision_tier: regex only when the fall went ALL the way to
    # regex — an ast-grep fall keeps tier ast): the estimate / N_total / OS / budget, the
    # AST-recovery path (install ast-grep + re-scan — the D2 tier-1; `--engine=tree-sitter`
    # remains the opt-in alternative — or `--include=<glob>` to narrow), and the consequence — ONLY at regex tier does
    # bind-codebase Step 2.5 implementation-state fall back to BINARY. This is the handoff
    # third of that lane's record (the other two: the map frontmatter and one chat line).
    # Status stays `completed`.
    rationale: "Scan complete; starterkit-first ordering — generate-intent consumes codebase-map.md as scan-pack input for pack-aware vault generation (bind-codebase when a vault already exists; detect-drift on the sync lane)."
  blockers: []                                          # populated when status: halted
  metrics:
    files_scanned: <int>
    symbols_extracted: <int>
    deep_scan_wall_clock_sec: <int>                     # 0 on cache hit
  scope:                                  # when vault has scope_metadata
    id: <scope id, e.g., "BE">
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

> The `starterkit_context:` block + the `starterkit-context.yaml` artifact entry are CONDITIONAL — emitted only when deep-scan ran successfully (framework detected at MEDIUM+ confidence). Skip both when deep-scan was skipped or failed entirely.

Status `halted` on: `dep_missing` | `scan_spawn_budget_exceeded` (STANDALONE lane only) | `scan_repo_too_large` | `scan_primary_app_ambiguous` | `deep_scan_subagent_all_failed` | `memory_in_use` — and `blockers[]` carries that blocker's YAML verbatim. A named blocker emitted with `status: completed` would be read downstream as a clean scan and the chain would continue on a map that was never produced, so the halting is the safety property the former human-stop sites protected. **`0 public interfaces` is deliberately NOT in this list** — it completes with the suggested `--include=<glob>` re-run recorded in the summary and in `next_action.rationale` (§Halt conditions). **Neither is the `--auto` lane's precision downgrade** — `scan_spawn_budget_exceeded` reaches `blockers[]` ONLY from the undecided standalone lane; under `--auto` the same condition produces a completed scan whose map carries `precision_tier: regex` + `precision_downgrade_reason` and whose `next_action.rationale` carries the AST-recovery command. A produced-but-lower-precision map is a real deliverable the chain can use; there is nothing for a downstream consumer to guess, because the tier is stamped in the artifact it reads.

The handoff is **required on every invocation**, not only under `--auto`.

## Memory layer

When memory enabled (default; opt-out via `--memory-off`), participates in the mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| After scan completes | `<project>/.mega-sdd/memory/conventions.md` | Append detected conventions: test framework, naming case, file suffix, error format. Each entry includes detection count + `status: detected` (first time) or `status: established` (threshold per `mega-sdd:memory/references/learning-rules.md`) |

Each append goes directly via `bash <plugin>/scripts/memory-write.sh --file=<resolved-path> --scope=project --cwd=<project-root>` at emission time (secret scan + lock + atomic append inside the script); the handoff carries only the receipt `metadata.memory_writes: {files_written: [...], rows_appended: N}`. Exit ≠ 0 → log and continue.

### Reads

| What | Source | How used |
|---|---|---|
| Past convention detections | `<project>/.mega-sdd/memory/conventions.md` | SKIP re-detection for conventions marked `status: established` (per learning-rules.md §2.5); just confirm signal still present |

### Anti-halu rails

- Memory write happens AFTER `codebase-map.md` is written (memory is derivative).
- Conventions marked `established` STILL get re-verified each scan; status only affects whether the verbose detection is re-emitted.
- **Detector versioning** (cache-version-bump pattern): each convention entry records the scan-codebase version that detected it. The skip-re-detect privilege applies ONLY while the current skill version matches the recorded one — a detector upgrade forces full re-detection (the entry is then re-recorded under the new version).
- `--memory-off` disables both reads and writes.
- Skipped conventions are logged in scan output for transparency.
