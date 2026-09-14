---
id: U-004
title: Make teal-700 the default primary color
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:115, PRD/prd-clinic.md:116]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-platform
depends_on: []
target_files:
  - path: src/configs/primaryColorConfig.ts
    operation: delete
  - path: src/configs/primaryColorConfig/index.ts
    operation: create
  - path: src/configs/primaryColorConfig/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "uses teal-700 as the default primary color"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "keeps white-on-primary contrast at or above 4.5 to 1"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "never uses a raw brand hue as a main color"
binding_refs: [OQ-CN-1]
---## Goal


Change the default primary preset to the AA-safe teal-700 `#0E7490` from PRD §8.2, and give the config module its own test by promoting it to a folder.

## Context (read first)


PRD §8.2 sets `--primary` to teal-700 `#0E7490` (5.36:1 with white text) and forbids the raw brand `#0891B2` / `#16A34A` as a primary with white foreground. The theme reads its primary from `settings.primaryColor`, whose default is `primaryColorConfig[2].main` (vendored `settingsContext`), so replacing the third preset changes the product default without touching vendored template files (constitution C-004). The module gains a test, so it moves to `primaryColorConfig/index.ts` (constitution A-002) and every `@configs/primaryColorConfig` import keeps resolving.

## Anchors


- src/configs/primaryColorConfig.ts:1-42 — current preset list; the third entry (`primary-3`, orange `#FFAB1D`) is the default
- src/@core/contexts/settingsContext.tsx:63 — `primaryColor: primaryColorConfig[2].main` (read-only reference; vendored)
- src/components/theme/index.tsx:68-79 — theme derives light/dark from `settings.primaryColor` (read-only reference; vendored)

## Claims


- C-U004-01 "the primary preset module exists as a flat file today" — expect: src/configs/primaryColorConfig.ts — must-exist
- C-U004-02 "the vendored settings context reads the default from preset index 2" — expect: src/@core/contexts/settingsContext.tsx — must-exist
- C-U004-03 "PrimaryColorConfig is the exported preset type" — expect: src/configs/primaryColorConfig.ts:PrimaryColorConfig

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/@core/contexts/settingsContext.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- DO NOT modify src/components/theme/index.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- file src/configs/primaryColorConfig/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep the `PrimaryColorConfig` type export and the default export array shape so existing imports compile (constitution C-004)
  Source: constitution.md §C C-004
- MUST use teal-700 #0E7490 as the default primary and never raw #0891B2 or #16A34A as a main color (constitution F-003)
  Source: constitution.md §F F-003

## Migration notes


- **REMOVE**: the flat file `src/configs/primaryColorConfig.ts` (its content moves into the folder module) and the orange values of preset `primary-3`.
- **KEEP**: the `PrimaryColorConfig` type, presets `primary-1`, `primary-2`, `primary-4`, `primary-5`, the array order and the default export.
- **ADD**: `src/configs/primaryColorConfig/index.ts` with preset `primary-3` = teal-700, and `index.test.ts`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- Browsers holding an old settings cookie keep their saved color until the customizer is reset (existing behavior, themeConfig.ts header comment).

## Out of scope


- Success/accent green-700 theme wiring — would require editing the vendored theme; the status chip (U-003) applies status colors locally
- Typography and radius changes from PRD §8.3
