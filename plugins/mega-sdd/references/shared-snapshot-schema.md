# Shared Snapshot Schema (v1.1, Iter 30 → extended Iter 46)

Canonical JSON schema for code-state snapshots consumed by mega-sdd skills across hops. **v1.1 extension (Iter 46)** broadens scope from the original Iter 30 `execute-bolts ↔ detect-drift` hop to additionally cover `scan-codebase → bind-codebase` (new `codebase-map` snapshot_type) and `extract-intelligence → generate-intent --kb` (new `extracted-kb` snapshot_type). Each extension preserves Iter 30 backward compatibility — v1.0 readers simply skip unfamiliar snapshot_type values.

Goal: every consumer skill that re-reads state already captured by an upstream producer can shortcut to the captured snapshot when source files match. Iter 30 baseline savings (~28s → ≤5s for drift gate on 20-bolt batch); Iter 46 extension adds a one-sha freshness attestation on the scan→bind hop (NOT a parsing shortcut — binding correctness is unchanged either way) + the KB freshness check (extract→intent hop).

## Contents

- Schema
- Producer responsibilities
- Consumer responsibilities
- Anti-halu rails
- Backward compatibility
- File locations summary

## Schema

```json
{
  "snapshot_schema_version": "1.1",
  "snapshot_type": "preflight | postflight | drift-baseline | codebase-map | extracted-kb",
  "generated_by": "<skill name + version, e.g., execute-bolts@2.6.0 | detect-drift@1.4.0>",
  "generated_at": "<ISO8601 timestamp>",
  "scope": "<scope id from vault.json when multi-scope vault; null otherwise>",
  "files": [
    {
      "path": "<absolute or repo-relative path>",
      "sha256": "<64-char hex>",
      "exists": true,
      "size_bytes": <int>,
      "ast_signatures": {
        "class_definitions": ["<class name>", "..."],
        "method_signatures": [
          {"name": "<method>", "params": "<param list>", "return": "<return type>"}
        ],
        "trait_uses": ["<trait>", "..."],
        "function_definitions": ["<function name>", "..."],
        "imports": ["<import path>", "..."]
      },
      "captured_via": "tree-sitter | ast-grep | regex-fallback"
    }
  ],
  "rules_validated": [
    {
      "rule_id": "<rule identifier>",
      "rule_source": "<framework-conventions/<pack>.md §<section> | constitution §<id> | unit-derived>",
      "status": "satisfied | violated",
      "evidence": "<file:line OR null when satisfied>"
    }
  ],
  "context": {
    "unit_id": "<U-XXX when bolt-emitted; null when standalone drift>",
    "binding_state_at_capture": "<CONFIRMED | NEW | UNKNOWN | PARTIAL_FIELDS_* | null>",
    "vault_sha256": "<vault.json hash at capture time>"
  },
  "codebase_map_sha256": "<sha256 of codebase-map.md content; ONLY when snapshot_type == codebase-map; null otherwise>",
  "source_files_sha256_map": {
    "<repo-relative-path>": "<sha256-hex>",
    "...": "..."
  }
}
```

**v1.1 fields (Iter 46 — OPTIONAL):**
- `codebase_map_sha256` — populated when `snapshot_type == codebase-map`. Allows downstream `bind-codebase` to detect codebase-map.md staleness in one check vs N source-file checks.
- `source_files_sha256_map` — populated for the `extracted-kb` type ONLY (its generate-intent freshness check reads it, path-by-path). For `codebase-map` it is written EMPTY `{}` — no consumer reads it (bind-codebase compares `codebase_map_sha256` only) and per-file hashes already live in the map's §2 `Last_Scanned_Sha256` column.

## Producer responsibilities

### execute-bolts (preflight)

Write to `<vault>/bolts/U-XXX/preflight.json` BEFORE bolt subagent dispatch:

- `snapshot_type: "preflight"`
- `generated_by: "execute-bolts@<version>"`
- `context.unit_id: "U-XXX"`
- `files[]`: every file in unit's `target_files` + every anchor file from unit's `## Anchors` section
- `rules_validated[]`: every Hard Rule from unit's `## Hard rules` + framework pack rules matching target_files

### execute-bolts (postflight)

Write to `<vault>/bolts/U-XXX/postflight.json` AFTER bolt subagent commits:

- `snapshot_type: "postflight"`
- Same files as preflight + any new files created during bolt
- Same rules_validated array but with post-bolt verdict
- Used by detect-drift for fast incremental scans (no re-read of files)

### detect-drift (baseline)

Write to `<vault>/_drift-baseline.json` after `bind-codebase` (Iter 30+ when no baseline exists):

- `snapshot_type: "drift-baseline"`
- `generated_by: "detect-drift@<version>"`
- `context.unit_id: null`
- `files[]`: all files referenced by vault claims (per binding.md anchors)

### scan-codebase (codebase-map snapshot — v2.7.1+, Iter 46)

> **Express-spine note (P2):** on the default spine this snapshot has no producer (scan runs on-demand only) and no consumer (bind `--express` skips the currency check, provenance fixed `no-snapshot` — `bind-codebase/references/auto-memory-handoff.md`). The lane stays fully live for classic-spine and on-demand scan runs.

Write to `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` after Step 10 codebase-map.md write:

- `snapshot_type: "codebase-map"`
- `generated_by: "scan-codebase@<version>"`
- `codebase_map_sha256: "<sha256 of just-written codebase-map.md>"`
- `source_files_sha256_map: {}` — EMPTY for this type (no consumer; §2's `Last_Scanned_Sha256` column already carries per-file hashes)
- `files[]: []` (empty)

### extract-intelligence (extracted-kb snapshot — v1.6+, Iter 46)

Write to `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` after wave-4 consolidation completes:

- `snapshot_type: "extracted-kb"`
- `generated_by: "extract-intelligence@<version>"`
- `source_files_sha256_map: {<repo-relative-path>: <sha256>, ...}` — every source file consumed by the extraction waves (captured at extraction time)
- `files[]: []` (KB itself is the consumable output; this snapshot exists for freshness verification only)

## Consumer responsibilities

### detect-drift

When invoked with `--reuse-bolt-snapshots` (auto-set when chained after execute-bolts batch):

1. For each unit in vault.json: read `<vault>/bolts/U-XXX/postflight.json` if present
2. Aggregate file-level sha256 + ast_signatures across all postflight snapshots
3. Compare aggregated state vs vault expectations (per detect-drift Steps 1-4)
4. For files NOT in any bolt postflight: fall back to fresh scan (typically small remainder)
5. Performance gain: skip Read + ast-extract for files already captured by bolts

When invoked standalone (`/mega-sdd:detect-drift` no chain context):

- Behave as v1.2.x: fresh full scan; ignore bolt snapshots (avoid stale data)

### bind-codebase (codebase-map snapshot consumer — v1.10+, Iter 46)

Before Step 3 (claim-vs-code matching):

1. Check if `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` exists
2. Read its `codebase_map_sha256` field; compare to current `codebase-map.md` sha256
3. If MATCH → map freshness attested (one sha compare); binding proceeds against codebase-map.md as usual
4. If MISMATCH OR snapshot absent → same binding behavior, minus the attestation (no regression)

This hop is a **freshness attestation, NOT a parsing shortcut** (bind-codebase `auto-memory-handoff.md` is the consumer-side contract) — binding correctness and its read path are unchanged whether the attestation confirms or rejects.

### generate-intent --kb (extracted-kb snapshot consumer — v1.15+, Iter 46)

Before reading `<kb-dir>`:

1. Check if `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` exists
2. For each path in `source_files_sha256_map`: compute current sha256 of the file in repo
3. If ALL files unchanged → KB freshness confirmed; log "KB freshness: confirmed (X source files unchanged since extraction)"
4. If SOME files drifted → log warning: "KB may be stale: <N> of <M> source files changed since extraction. Consider `/mega-sdd:extract-intelligence --force` to refresh." DO NOT halt — user decides
5. If snapshot absent → log advisory; behave as today (assume KB fresh)

## Anti-halu rails

- `sha256` MUST be computed from file content at capture time (not cached from disk metadata)
- `snapshot_type` MUST match the producer's intent (mismatch → halt `snapshot_type_invalid`)
- `vault_sha256` MUST be captured at the SAME moment as `files[]` (vault edit during scan → halt `vault_modified_during_scan`)
- detect-drift MUST verify postflight snapshot is fresher than vault.json modification time (else fresh scan)
- snapshot schema version mismatch → consumer falls back to fresh scan + emits advisory

## Backward compatibility

Pre-Iter-30 bolts wrote preflight/postflight with informal JSON (per Iter 3). Iter 30 migration:

- First Iter 30 bolt run writes new schema; older snapshots remain readable but consumer treats them as `snapshot_schema_version: "0.x (legacy)"` and falls back to fresh scan
- No data migration required; old snapshots aged out naturally as bolts re-execute

## File locations summary

- Bolt snapshots: `<vault>/bolts/U-XXX/{preflight,postflight}.json`
- Drift baseline: `<vault>/_drift-baseline.json`
- Drift report: `<vault>/DRIFT-REPORT.md` (existing, per detect-drift v1.x)
- Codebase-map snapshot (v1.1+, Iter 46): `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json`
- Extracted-KB snapshot (v1.1+, Iter 46): `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json`
