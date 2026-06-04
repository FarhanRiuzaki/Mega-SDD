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
- Limit symbol extraction to **first 200 per category** (prevents giant maps). Note "truncated at 200, see file scan log for full list."
- Cite line numbers for routes/models (`src/foo.ts:42`) so binding can verify.
- Deep-scan no-fabrication: each subagent MUST emit `lib: not_detected` when no fingerprint matches, NEVER guess. Schema-validation drops slices that violate.
- Deep-scan citation rail: every starterkit-context.yaml field MUST be backed by `_source: [<file>, ...]` companion field. Schema-validation drops slices without `_source`.
- Deep-scan read-only: subagents have NO Edit/Write/mutating-Bash tool access. Read-only enforced at dispatch.

## Halt conditions

- **Repo > 100k files:** confirm with user (`--force-large` flag required to proceed).
- **Detection produces 0 public interfaces:** warn user — likely scan misconfiguration; offer to re-run with different `--include`.
- **`--engine=tree-sitter` set AND tree-sitter not on PATH:** halt `dep_missing` with install commands (install guidance is in the tree-sitter integration reference).

### `deep_scan_subagent_failed` — SOFT

```yaml
type: deep_scan_subagent_failed
source_skill: scan-codebase
details:
  domain: <auth | rbac | ui_ux | libs>
  subagent_index: <1-4>
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
  failed_domains: [auth, rbac, ui_ux, libs]
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
- `--shallow-scan`: skip Step 10.5 deep-scan stage; emit only surface codebase-map.md (opt-out for deep-scan)
- `--force-deep`: force deep-scan even when framework confidence is LOW (override Step 10.5.0 trigger check)
- `--no-cache`: invalidate deep-scan cache; re-run all 4 subagents even if lock files unchanged
- `--memory-off`: disable memory-layer reads and writes

## Hand-off announcement

On completion, announce: "Codebase map written to `<path>`. Run `/mega-sdd:bind-codebase <vault>` to validate your vault against it."

## Handoff YAML emission

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: scan-codebase
  emitted_at: <ISO8601 timestamp>
  status: completed                                 # or paused | halted
  artifacts:
    - <absolute path to .mega-sdd/codebase/codebase-map.md>
    - <absolute path to .mega-sdd/codebase/starterkit-context.yaml>  # only when deep-scan ran
  starterkit_context:                                                  # block only when deep-scan ran
    reused: false                                                       # true if cache hit
    framework: laravel
    auth_lib: sanctum
    rbac_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
  next_action:
    suggested_skill: mega-sdd:generate-intent
    suggested_args:
      - "--scan=<absolute path to .mega-sdd/codebase/codebase-map.md>"
      - "--auto"
    rationale: "Scan complete; starterkit-first ordering — generate-intent consumes codebase-map.md as scan-pack input for pack-aware vault generation."
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
| After scan completes | `<project>/.mega-sdd/memory/conventions.md` | Append detected conventions: test framework, naming case, file suffix, error format. Each entry includes detection count + `status: detected` (first time) or `status: established` (per MEMORY-OQ-4 threshold) |

### Reads

| What | Source | How used |
|---|---|---|
| Past convention detections | `<project>/.mega-sdd/memory/conventions.md` | SKIP re-detection for conventions marked `status: established` (per learning-rules.md §2.5); just confirm signal still present |

### Anti-halu rails

- Memory write happens AFTER `codebase-map.md` is written (memory is derivative).
- Conventions marked `established` STILL get re-verified each scan; status only affects whether the verbose detection is re-emitted.
- `--memory-off` disables both reads and writes.
- Skipped conventions are logged in scan output for transparency.
