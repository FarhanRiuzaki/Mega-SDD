# scan-codebase — halts, flags, handoff & memory

## Contents
- Anti-hallucination rails
- Halt conditions (dep_missing; 0-interface; >100k files)
- deep_scan_subagent_failed (SOFT)
- deep_scan_cache_corrupt (SOFT)
- deep_scan_subagent_all_failed (ALWAYS STOP)
- Flags catalog
- Hand-off announcement + handoff YAML emission
- Memory layer (reads / writes / anti-halu rails)

Loaded by `scan-codebase` for failure handling, flag resolution, and chain/memory integration. The surface scan procedure and the deep-scan stage are separate references the SKILL.md router links to.

## Anti-hallucination rails

- If a section has no detection: write "None detected" — do NOT invent.
- Limit symbol extraction to **first 200 per category** (prevents giant maps). When a cap fires, stamp `truncated_sections: ["<section numbers>"]` in the map frontmatter — binding MUST treat absence-in-a-truncated-section as UNKNOWN, never as NEW/absent evidence (a truncated-away implemented element must not become a duplicate-implementation `create` task).
- Cite line numbers for routes/models (`src/foo.ts:42`) so binding can verify.
- Deep-scan no-fabrication: each subagent MUST emit `lib: not_detected` when no fingerprint matches, NEVER guess. The consolidator self-validates each slice against starterkit-context-schema.md before write and drops violators (a rules-tier LLM check, not a hook).
- Deep-scan citation rail: every starterkit-context.yaml field MUST be backed by `_source: [<file>, ...]` companion field (libs slice: `_source` names the producing manifest). Slices without `_source` are dropped by the consolidator self-validation.
- Deep-scan read-only: every extractor prompt template carries the READ-ONLY rail (no Edit/Write/mutating Bash). This is a **prompt-level rule (rules tier), not a dispatch-level tool restriction** — the extractors are prompt-template dispatches, not plugin agents with a `tools:` allowlist. A slice whose output evidences a rail violation is dropped at consolidation.
- Secret-scan gate: assembled `codebase-map.md` / `starterkit-context.yaml` / `reuse-index.yaml` content is scrubbed BEFORE write by running `scripts/secret-scan.sh --redact` (deterministic; matched values become `[REDACTED-SECRET]`; a private-key match redacts the WHOLE block, header through END marker) + one chat warning citing the source `file:line` (per `references/scan-procedure.md` Step 10a; the deep-scan write sites are Step 10.5.3 steps 3+6). The gate redacts scan outputs only — it never edits repo source.

## Halt conditions

- **Repo > 100k files:** confirm with user (`--force-large` flag required to proceed).
- **Detection produces 0 public interfaces:** warn user — likely scan misconfiguration; offer to re-run with different `--include`.
- **`--engine=tree-sitter` set AND tree-sitter not on PATH:** halt `dep_missing` with install commands (install guidance is in the tree-sitter integration reference).

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
next_action: "Re-run /mega-sdd:scan-codebase later (likely API outage; user retry required). Existing starterkit-context.yaml (if any) preserved untouched."
```

Recovery: user re-runs scan-codebase later. Chain halts.

## Flags catalog

- `--depth=N`: tree depth (default 8)
- `--include=<glob>`: scan only matching files (repeatable)
- `--exclude=<glob>`: skip matching files (repeatable; **appended** to defaults — the default exclusion list is a separate reference)
- `--no-default-excludes`: disable the default exclusion list entirely (rare; opt-in scan of dep trees)
- `--out=<path>`: override output location
  - Default: `<project-root>/.mega-sdd/codebase/codebase-map.md` per `plugins/mega-sdd/references/paths.md`
  - Legacy default: `<project-root>/codebase-map.md` (preserved when `.mega-sdd/` dir absent OR `layout: legacy` in config)
  - User explicit `--out=<path>` always respected
- `--auto`: skip confirmation prompts
- `--force-large`: proceed on >100k file repos
- `--engine=tree-sitter|regex`: force engine; default auto-detect via `command -v tree-sitter`
- `--shallow-scan`: two coupled fast-path semantics — (a) skip the Step 10.5 deep-scan stage (emit only the surface codebase-map.md), and (b) enable the Step 5 per-file invalidation gate (reuse prior §2 rows whose `Last_Scanned_Sha256` matches the file's current hash; only changed files re-extract — per `references/scan-procedure.md` §Step 5)
- `--force-deep`: force deep-scan even when framework confidence is LOW (override Step 10.5.0 trigger check)
- `--no-cache`: invalidate deep-scan cache; re-run all 5 slice subagents even if lock files unchanged
- `--changed-only`: incremental re-scan — resolve changed paths (dirty journal ∪ `git diff <last_scanned_commit>..HEAD` ∪ uncommitted), re-extract only those, merge into the prior map, consume the journal (rotate-and-delete per `references/scan-procedure.md` §Incremental step 4 — never truncate-in-place, which loses concurrent-session appends); auto-falls back to full scan when preconditions absent (per §Incremental mode). On incremental success with a vault present (sync lane) it ALSO writes the resolved changed set to `<vault>/.sync-changed-paths.txt` (one path per line, overwrite) — the durable scope channel for the two forked downstream phases that accept a path scope (`detect-drift --scope=@…` / `bind-codebase --paths=@…`; `generate-units --reconcile` reconciles from the refreshed `binding.md`, not this file), which can't self-resolve because the journal is already consumed and the stamp advanced by the time they run (§Incremental step 5); the full-scan fallback writes no such file, deletes any stale one, and continues Mode D straight to a FULL re-bind (`bind-codebase --auto`) — detect-drift is skipped on that branch (§Hand-off; spec §3.8(b)(1))
- `--memory-off`: disable memory-layer reads and writes

## Hand-off announcement

On completion, announce: "Codebase map written to `<path>`." followed by the CWD-conditional next step (a vault exists → `/mega-sdd:bind-codebase <vault>`; none yet → `/mega-sdd:generate-intent --scan=<map>`).

## Handoff YAML emission

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per the local template below — the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

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

Status `halted` on: `dep_missing` | `deep_scan_subagent_all_failed` | `memory_in_use`. Required ONLY under `--auto`.

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
