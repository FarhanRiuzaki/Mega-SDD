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
scan_excludes: ["node_modules/**", "vendor/**", "dist/**", "build/**", "target/**", ".next/**", ".gradle/**", "storage/framework/**", "__pycache__/**", ".venv/**", "coverage/**", ".git/**", ".idea/**", ".mega-sdd/**", "..."]  # Full list per SKILL.md §Default exclusions
languages_detected: ["typescript", "php", "javascript"]
package_managers: ["npm", "composer"]
test_frameworks: ["jest", "phpunit"]
# v2.0+ (Iter 6): engine + precision metadata
engine: tree-sitter | regex
precision_tier: ast | regex
tree_sitter_version: <version-string>          # only when engine=tree-sitter
grammars_used: ["typescript", "php"]            # only when engine=tree-sitter
---

# Codebase Map

## 1. Top-level structure
[ tree of dirs, depth-limited ]

## 2. Public interfaces
| File | Type | Symbol | Signature | Last_Scanned_Sha256 |
|---|---|---|---|---|

> **v2.7.1+, Iter 46 (D2-007 closure):** the `Last_Scanned_Sha256` column captures the source file's content hash at the time symbols were extracted. `scan-codebase --shallow-scan` uses this for per-file invalidation — only files whose current sha256 differs trigger re-extraction (saves 5-10s on iterative shallow re-scans). The column is OPTIONAL — pre-Iter-46 codebase-map.md files lack it and trigger full re-extraction on first --shallow-scan after upgrade.

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
- Auth pattern: middleware|session|jwt|none
- Error handling: try-catch|result-monad|throw
- State: redux|context|none|composer-event
- View/component pattern (v2.5+, Task F): the presentation-layer convention — view dir + naming
  + `exemplar_selection: linter-clean`. This is the codebase-map counterpart of the
  `starterkit-context.yaml` `patterns.view` / `patterns.component` categories (scan-codebase
  Step 10.5.2.5). `exemplar_selection: linter-clean` records that, for a presentation exemplar,
  the cleanest/most-idiomatic sample (passes the pack `## UI quality signatures` scaffold_tells)
  is selected — NOT the first file found — because the sample becomes a few-shot the UI bolt
  mirrors. API-only stacks emit this as `none`/absent (no presentation layer).
  - View dir: <e.g. resources/views/ | src/pages/ | templates/ | none>
  - View naming: <e.g. {model}.blade.php | {Model}Page.tsx | none>
  - Exemplar selection: linter-clean | none

## 7. Framework (v2.4+, Iter 23)
framework:
  name: <framework-id from references/framework-conventions/>
  version: <e.g., "11.x" or "unknown">
  confidence: high | medium | low | fallback
  pack_path: <relative path to matching pack, or _universal.md if no match>
  detection_source: <manifest filename + dependency marker that triggered detection>
```

## How `bind-codebase` uses this

For each vault claim referencing code (endpoint, field, file path), `bind-codebase` greps codebase-map sections 2-4 and naming conventions. Match → CONFIRMED. Mismatch → CONFLICT. Absent → OQ.

## Detection precision

v1.0 scan is **heuristic** (regex + file traversal). It will miss:
- Dynamic routes generated at runtime
- Magic methods / metaprogramming
- Out-of-tree dependencies

These misses surface as OQ during binding, not silent gaps. Acceptable trade-off for v1.
