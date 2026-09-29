# Shared Snapshot Schema

Canonical JSON schema for code-state snapshots consumed by mega-sdd skills across hops. The schema covers the `execute-bolts ↔ detect-drift` hop plus `extract-intelligence → plan --kb` (`extracted-kb` snapshot_type). Readers skip unfamiliar snapshot_type values (backward-compatible by construction).

Goal: every consumer skill that re-reads state already captured by an upstream producer can shortcut to the captured snapshot when source files match. Baseline savings (~28s → ≤5s for drift gate on 20-bolt batch); the v1.1 extension adds the KB freshness check (extract→plan --kb hop).

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
  "snapshot_type": "preflight | postflight | drift-baseline | extracted-kb",
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
      "captured_via": "ast-grep | regex-fallback"   // legacy snapshots may carry "tree-sitter" (pre-7.4 producer)
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
  "source_files_sha256_map": {
    "<repo-relative-path>": "<sha256-hex>",
    "...": "..."
  }
}
```

**v1.1 field (OPTIONAL):**
- `source_files_sha256_map` — populated for the `extracted-kb` type ONLY (the `plan --kb` freshness check reads it, path-by-path; legacy numbered-tree KBs only).

## Producer responsibilities

### execute-bolts (preflight / postflight) — NOT this schema

The bolt artifacts `<vault>/bolts/U-XXX/preflight.json` and `postflight.json` never adopted the snapshot schema above. They are written ONLY by the hook-guarded script pair `scripts/run-preflight-scan.sh` / `scripts/run-postflight-scan.sh` (shared engine `scripts/_lib/postflight_rules.py`; contract in `execute-bolts/references/hard-rule-scan.md`). Preflight records `unit_id`, `grammar`, `head_sha`, `snapshot_at`, `signature_at_preflight`, the extracted Hard `rules[]` (`{type, path | manifest | function}`), `matched_files` and `written_by`; postflight records `unit_id`, `head_sha`, `scanned_at`, the per-rule verdicts (`rules[]`, `status`, `total` / `attested` / `unverified`, `directives`) and `written_by`. No `snapshot_type`, `files[].ast_signatures` or `rules_validated[]` field exists, nothing reads them as snapshots, and there is no `<vault>/_drift-baseline.json` producer — detect-drift always scans fresh.

### extract-intelligence (extracted-kb snapshot)

> **Producer retired:** the PRD-kontrak grammar carries freshness inside `census.json` (per-file `sha256`), so new extractions emit NO snapshot; `plan --kb` checks census freshness directly (per-file sha256 vs `legacy_root`). The consumer contract below still applies to legacy numbered-tree KBs that carry a snapshot on disk.

Write to `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` after wave-4 consolidation completes:

- `snapshot_type: "extracted-kb"`
- `generated_by: "extract-intelligence@<version>"`
- `source_files_sha256_map: {<repo-relative-path>: <sha256>, ...}` — every source file consumed by the extraction waves (captured at extraction time)
- `files[]: []` (KB itself is the consumable output; this snapshot exists for freshness verification only)

## Consumer responsibilities

### detect-drift

detect-drift has no snapshot consumer: there is no `--reuse-bolt-snapshots` flag and no baseline file — every run is a fresh scan of the live codebase against the vault (`DRIFT-REPORT.md` + `PENDING-SYNC.md`).

### plan --kb (extracted-kb snapshot consumer)

Before reading `<kb-dir>` (`plan/references/kb-input.md` §KB freshness preflight):

1. Check if `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` exists
2. For each path in `source_files_sha256_map`: compute current sha256 of the file in repo
3. If ALL files unchanged → KB freshness confirmed; log "KB freshness: confirmed (X source files unchanged since extraction)"
4. If SOME files drifted → log warning: "KB may be stale: <N> of <M> source files changed since extraction. Consider `extract-intelligence --force` to refresh." DO NOT halt — user decides
5. If snapshot absent → log advisory; behave as today (assume KB fresh)

## Anti-halu rails

- `sha256` MUST be computed from file content at capture time (not cached from disk metadata)
- snapshot schema version mismatch → consumer falls back to fresh scan + emits advisory

## Backward compatibility

Legacy bolts wrote preflight/postflight with informal JSON. Migration:

- The first bolt run writes the new schema; older snapshots remain readable but consumer treats them as `snapshot_schema_version: "0.x (legacy)"` and falls back to fresh scan
- No data migration required; old snapshots aged out naturally as bolts re-execute
- Pre-9.0 `codebase-map` snapshots (`<project>/.mega-sdd/codebase/.shared-snapshots/`) have no reader; readers skip the type

## File locations summary

- Bolt Hard-rule artifacts (script-written, NOT this schema — see §Producer responsibilities): `<vault>/bolts/U-XXX/{preflight,postflight}.json`
- Drift report: `<vault>/DRIFT-REPORT.md` (existing)
- Extracted-KB snapshot (v1.1+): `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json`
