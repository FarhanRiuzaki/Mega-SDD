# Iter 46 — Snapshot Reuse Extension Design

**Status:** Approved (autonomous execution)
**Source:** Iter 38 audit Queue #6 (D1-006 + D2-007)
**Plugin:** v3.30.0 → v3.31.0 (MINOR — shared-snapshot scope extension + new optional metadata)
**Estimated effort:** ~2hr (markdown-driven; less than 5hr audit estimate)

---

## §1 — Problems

### D1-006: shared-snapshot reuse NOT extended to all hops

Iter 30 introduced shared-snapshot reuse (`<vault>/.internal/snapshots/*.json` schema in `plugins/mega-sdd/references/shared-snapshot-schema.md`) scoped to ONE hop: `execute-bolts ↔ detect-drift`. The audit identifies 2 more hops where the pattern would yield 30-50% re-run I/O savings on incremental edits:

1. **scan → bind hop:** `bind-codebase` re-reads source files when computing claim-vs-code matches. If `scan-codebase` recently wrote `codebase-map.md` (and its sha256 matches), bind-codebase can reuse the parsed symbol data from the codebase-map directly instead of re-tokenizing source files.

2. **extract → intent hop:** when `generate-intent --kb=<kb-dir>` runs after `extract-intelligence`, it could verify the KB is still source-current via shared-snapshot. If source files haven't changed since KB generation, KB is reusable as-is. If source files have drifted, generate-intent should warn + suggest re-extracting.

### D2-007: symbol-graph re-built on every scan-codebase run (even shallow)

`scan-codebase --shallow-scan` skips the Step 10.5 deep-scan stage but still re-runs Steps 1-10 which include tree-sitter symbol extraction (`codebase-map.md §2 Public interfaces`). Currently this re-extracts symbols for EVERY file in repo on every run, even files that haven't changed since the last codebase-map.md write.

**Audit savings estimate:** 5-10s rebuild on shallow-scan re-runs (per-file invalidation eliminates).

---

## §2 — Design

### Change 1 (D1-006): shared-snapshot scope extension

**Schema extension (shared-snapshot-schema.md v1.0 → v1.1):**

Add new `snapshot_type` enum values:
- `codebase-map` — written by `scan-codebase` after Step 10 completes; consumed by `bind-codebase` Step 3 (claim-vs-code matching)
- `extracted-kb` — written by `extract-intelligence` after wave-4 consolidation; consumed by `generate-intent --kb=<kb-dir>` preflight

New OPTIONAL field per snapshot: `source_files_sha256_map: { <repo-relative-path>: <sha256-hex>, ... }` — captures input files' content hashes at snapshot generation time so downstream consumers can verify reusability.

**scan-codebase v2.7.0+ (Step 10.6 NEW — snapshot emission):**

After Step 10 (codebase-map.md write), additionally write `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` per schema:
```json
{
  "snapshot_schema_version": "1.1",
  "snapshot_type": "codebase-map",
  "generated_by": "scan-codebase@2.7.1",
  "generated_at": "<ISO8601>",
  "codebase_map_sha256": "<sha256 of codebase-map.md content>",
  "source_files_sha256_map": {
    "app/Http/Controllers/UserController.php": "<sha256>",
    "app/Models/User.php": "<sha256>",
    "...": "..."
  }
}
```

**bind-codebase v1.10+ (Step 3 reuse path):**

Before Step 3 (claim-vs-code matching), check if shared snapshot exists at `<project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` AND `codebase_map_sha256` matches the current `codebase-map.md` sha256:
- Snapshot fresh → reuse parsed symbol data from snapshot's `source_files_sha256_map` keys (cross-reference codebase-map §2 entries by path); skip per-source-file re-tokenization
- Snapshot stale OR absent → fall back to current per-file re-read behavior (no regression)

**extract-intelligence v1.1+ (Step 5.5 NEW — snapshot emission):**

After wave-4 consolidation (KB finalization), write `<kb-dir>/.shared-snapshots/extracted-kb.snapshot.json` capturing source files' sha256 at extraction time.

**generate-intent v1.7+ (--kb preflight reuse check):**

Before reading `<kb-dir>`, check if `extracted-kb.snapshot.json` exists AND source files in current repo match the snapshot's hashes:
- All source files unchanged → KB is reusable; log "KB freshness: confirmed (X source files unchanged since extraction)"
- Some source files drifted → log warning + suggest re-extract: "KB may be stale: 3 of 47 source files changed since extraction (last_extracted: 2026-05-20; current: 2026-05-25). Consider `/mega-sdd:extract-intelligence --force` to refresh."
- DO NOT halt — preserves backward compat; user decides

### Change 2 (D2-007): per-file symbol invalidation

**codebase-map.md schema extension (codebase-map-schema.md v2.x):**

§2 "Public interfaces" table gains optional column `Last_Scanned_Sha256` — captures sha256 of the source file at the time symbols were extracted. When this matches the current file sha256, the symbol entries are considered fresh.

**scan-codebase v2.7.1+ (Step 9 — per-file invalidation):**

If `--shallow-scan` AND prior `codebase-map.md` exists:
1. Parse prior codebase-map.md §2; build `prior_sha256_map: {file_path: last_scanned_sha256, ...}`
2. For each source file in repo, compute current sha256
3. If current matches prior → REUSE prior §2 entries for this file (no tree-sitter re-extract)
4. If current differs OR file not in prior map → re-extract symbols + update `Last_Scanned_Sha256`
5. Files removed from repo since prior scan → drop their §2 entries

For full `--deep-scan` (default) OR `--no-cache` → behave as today (full re-extract).

**Savings:** on iterative dev (most files unchanged), shallow re-scan goes from 5-10s → <1s.

---

## §3 — Surface updates

| Surface | Change |
|---|---|
| `references/shared-snapshot-schema.md` | v1.0 → v1.1: + `codebase-map` and `extracted-kb` snapshot_type values; + OPTIONAL `source_files_sha256_map` and `codebase_map_sha256` fields |
| `scan-codebase/SKILL.md` | + Step 10.6 (snapshot emission); + Step 9 per-file invalidation path for `--shallow-scan`; bump 2.7.0 → 2.7.1 |
| `scan-codebase/references/codebase-map-schema.md` | + `Last_Scanned_Sha256` column in §2 Public interfaces; bump doc version |
| `bind-codebase/SKILL.md` | + Step 3 reuse path; bump to next minor |
| `extract-intelligence/SKILL.md` | + Step 5.5 snapshot emission; bump to next minor |
| `generate-intent/SKILL.md` | + --kb preflight freshness check; bump to next minor |

---

## §4 — Version bumps

- `plugin.json`: 3.30.0 → **3.31.0** (MINOR)
- `scan-codebase`: 2.7.0 → 2.7.1 (PATCH — additive snapshot emission + new shallow-scan path; no breaking)
- `bind-codebase`: lookup current; bump MINOR
- `extract-intelligence`: lookup current; bump MINOR
- `generate-intent`: lookup current; bump MINOR

---

## §5 — Out of scope

- **Auto re-extract on KB drift:** preserve user agency; warn-only
- **Cache eviction policy:** snapshot files are small (~10-100KB); no LRU yet
- **Distributed cache:** local-only per project

---

## §6 — Standing directives applied

- **simplifikasi:** 2 audit findings → 1 iter; schema extension + 1 new step per producer + 1 reuse path per consumer
- **flawless:** producer (scan/extract emits snapshot) + consumer (bind/intent reuses) ship in-iter; v1.0 readers gracefully degrade (no snapshot field → behave as today)
- **reuse-first:** extends Iter 30 shared-snapshot pattern + extends existing codebase-map.md §2 table schema; no new files for cache (snapshots live in existing `.shared-snapshots/` convention)
