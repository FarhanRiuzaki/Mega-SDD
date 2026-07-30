# Codebase Map Schema

`codebase-map.md` is the structured output of `scan-codebase`. It is consumed by `bind-codebase` to validate vault claims against repo reality. It is regenerable — never edited manually.

## Required sections

```yaml
---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-05-13T10:00:00Z
repo_root: ./
scan_depth: 8
scan_includes: ["src/**", "app/**", "lib/**"]
scan_excludes: ["node_modules/**", "vendor/**", "dist/**", "build/**", "target/**", ".next/**", ".gradle/**", "storage/framework/**", "__pycache__/**", ".venv/**", "coverage/**", ".git/**", ".idea/**", ".mega-sdd/**", "..."]  # Full list per references/exclusions.md (the owner)
languages_detected: ["typescript", "php", "javascript"]
package_managers: ["npm", "composer"]
test_frameworks: ["jest", "phpunit"]
# engine + precision metadata
engine: tree-sitter | regex
precision_tier: ast | regex
# downgrade record — present ONLY when the Step 5 spawn-cost gate's `--auto` lane traded
# tree-sitter for regex (references/scan-procedure.md §Spawn-cost gate, lane 3). One line
# carrying four facts: estimate, N_total (N_hash + N_extract), OS, budget. Its ABSENCE means
# `precision_tier` is the tier the invocation selected; its PRESENCE means the tier was lowered
# unattended and says exactly why — the durable half of the "record, not the action" rail.
precision_downgrade_reason: "step-5 spawn budget: N_total=2000 (N_hash=0 + N_extract=2000) x 0.22s/spawn (os=windows-bash) = ~440s > 60s budget; --auto lane downgraded tree-sitter -> regex"
tree_sitter_version: <version-string>          # only when engine=tree-sitter
grammars_used: ["typescript", "php"]            # only when engine=tree-sitter
# staleness stamp — verified git HEAD at scan time (omit when the repo has no .git OR
# `git rev-parse --verify 'HEAD^{commit}'` fails, e.g. a fresh zero-commit repo; consumers
# treat a stamp equal to the literal string "HEAD" as missing)
last_scanned_commit: <git rev-parse --verify HEAD^{commit}>
# truncation marker — present ONLY when a 200-per-category extraction cap fired (anti-halu
# rail). Lists the section numbers whose content is INCOMPLETE; binding treats absence in a
# truncated section as UNKNOWN, never as evidence-of-absence (NEW / OQ-create).
truncated_sections: ["2"]
---

# Codebase Map

## 1. Top-level structure
[ tree of dirs, depth-limited ]

## 2. Public interfaces
| File | Type | Symbol | Signature | Last_Scanned_Sha256 |
|---|---|---|---|---|

> The `Last_Scanned_Sha256` column captures the source file's content hash at the time symbols were extracted. `scan-codebase --shallow-scan` uses this for per-file invalidation — only files whose current sha256 differs trigger re-extraction (saves 5-10s on iterative shallow re-scans). The column is OPTIONAL — older codebase-map.md files that lack it trigger full re-extraction on the first `--shallow-scan` after upgrade.

## 3. Routes / Endpoints
| Method | Path | Handler |
|---|---|---|

## 4. Data models / Schemas
| Entity | File | Fields |
|---|---|---|

## 5. Naming conventions
- Case style: camelCase | snake_case | kebab-case
- File suffix: .service.ts, Controller.php, etc
- Test files: .test.ts, Test.php

## 6. Pattern signatures

> Consumers: `bind-codebase` validates `06-constraints.md` claims against these rows (binding-contract §Claim categories); `execute-bolts` injects them as the `Codebase patterns:` dispatch line when `starterkit-context.yaml` is absent (context-enrichment §Map §6 fallback) — the section is never write-only.
- Auth pattern: middleware|session|jwt|none
- Error handling: try-catch|result-monad|throw
- State: redux|context|none|composer-event
- View/component pattern: the presentation-layer convention — view dir + naming
  + `exemplar_selection: linter-clean`. This is the codebase-map counterpart of the
  `starterkit-context.yaml` `patterns.view` / `patterns.component` categories (scan-codebase
  Step 10.5.2.5). `exemplar_selection: linter-clean` records that, for a presentation exemplar,
  the cleanest/most-idiomatic sample (passes the pack `## UI quality signatures` scaffold_tells)
  is selected — NOT the first file found — because the sample becomes a few-shot the UI bolt
  mirrors. API-only stacks emit this as `none`/absent (no presentation layer).
  - View dir: <e.g. resources/views/ | src/pages/ | templates/ | none>
  - View naming: <e.g. {model}.blade.php | {Model}Page.tsx | none>
  - Exemplar selection: linter-clean | none

## 7. Framework
framework:
  name: <framework-id from references/framework-conventions/>
  version: <e.g., "11.x" or "unknown">
  confidence: high | medium | low | fallback
  pack_path: <relative path to matching pack, or _universal.md if no match>
  detection_source: <manifest filename + dependency marker that triggered detection>
```

## Staleness detection (`last_scanned_commit`)

`last_scanned_commit` records `git rev-parse HEAD` at scan time. Consumers use it to detect a stale map cheaply:

- `detect-drift` compares it to current HEAD; if it differs, `git diff --name-only <last_scanned_commit>..HEAD` yields exactly the paths that changed since the scan — a scoped re-scan signal far cheaper than re-walking the repo.
- `bind-codebase` Step 1 (S4) reads the stamp for its currency check: `snapshot-verified` provenance requires BOTH the shared-snapshot sha256 match AND stamp == current HEAD (or not-a-git); a HEAD mismatch downgrades provenance to `snapshot-stale` with a re-scan recommendation — the sha256 alone only proves the map FILE is unchanged, not that the CODE hasn't moved since the scan.
- The field is OPTIONAL: maps scanned outside a git repo omit it, and consumers fall back to full-content comparison. Older maps that lack the field are treated the same way.

## How `bind-codebase` uses this

For each vault claim referencing code (endpoint, field, file path), `bind-codebase` greps codebase-map sections 2-4 and naming conventions. Match → CONFIRMED. Mismatch → CONFLICT. Absent → OQ — **except** when the claim's section is listed in `truncated_sections`: absence there is NOT evidence (the element may be beyond the extraction cap) → classify UNKNOWN, and never emit a `create`-type task from it.

## Detection precision

The scan is **heuristic** (AST captures when `engine: tree-sitter`, regex + file traversal otherwise). Either engine will miss:
- Dynamic routes generated at runtime
- Magic methods / metaprogramming
- Out-of-tree dependencies

These misses surface as OQ during binding, not silent gaps — an acceptable trade-off the binding gate is designed to absorb.
