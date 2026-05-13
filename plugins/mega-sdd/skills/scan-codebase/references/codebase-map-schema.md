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
scan_excludes: ["node_modules/**", "dist/**", "vendor/**"]
languages_detected: ["typescript", "php", "javascript"]
package_managers: ["npm", "composer"]
test_frameworks: ["jest", "phpunit"]
---

# Codebase Map

## 1. Top-level structure
[ tree of dirs, depth-limited ]

## 2. Public interfaces
| File | Type | Symbol | Signature |
|---|---|---|---|

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
```

## How `bind-codebase` uses this

For each vault claim referencing code (endpoint, field, file path), `bind-codebase` greps codebase-map sections 2-4 and naming conventions. Match → CONFIRMED. Mismatch → CONFLICT. Absent → OQ.

## Detection precision

v1.0 scan is **heuristic** (regex + file traversal). It will miss:
- Dynamic routes generated at runtime
- Magic methods / metaprogramming
- Out-of-tree dependencies

These misses surface as OQ during binding, not silent gaps. Acceptable trade-off for v1.
