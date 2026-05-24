# Shared Snapshot Schema (v1.0, Iter 30)

Canonical JSON schema for code-state snapshots consumed by both `execute-bolts` (preflight/postflight per Iter 3 + Iter 6) AND `detect-drift` (baseline + per-scan, v1.4+ Iter 30).

Goal: detect-drift can reuse bolt postflight snapshots when present (≤5s drift gate on 20-bolt batch vs ≥28s full re-scan). Falls back to fresh scan when standalone drift run.

## Schema

```json
{
  "snapshot_schema_version": "1.0",
  "snapshot_type": "preflight | postflight | drift-baseline",
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
  }
}
```

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
