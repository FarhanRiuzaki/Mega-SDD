# Lib-Pattern Detection Catalogs

> Per-framework reference catalogs of library detection patterns used by `scan-codebase` v2.6.0+ deep-scan subagents.

**Introduced:** v3.23.0 (Iter 32)
**Consumed by:** subagent prompts in `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md`

## Directory layout

```
plugins/mega-sdd/references/lib-patterns/
  README.md                  # this file
  laravel/
    auth-libs.md             # Sanctum / Breeze / Jetstream / Fortify / Passport
    rbac-libs.md             # Spatie/permission / laravel-permission / custom
    ui-libs.md               # JS / CSS / notification / icon / datatable
    generic-libs.md          # queue / cache / log / test / misc
```

## Adding a new framework

To add a new framework (e.g., `nextjs/`, `django/`, `rails/`):

1. Create directory `lib-patterns/<framework>/`
2. Add the 4 standard catalog files: `auth-libs.md`, `rbac-libs.md`, `ui-libs.md`, `generic-libs.md`
3. Each file follows the canonical "Detection Examples" structure:
   - **Manifest fingerprint**: which key in package manifest signals this lib
   - **File fingerprint**: where in the codebase the lib's usage appears
   - **Sample output YAML slice**: what the extractor should emit
4. Update `scan-codebase/SKILL.md` framework-pack detection to recognize the new framework
5. No skill code changes needed — subagent prompts auto-load `lib-patterns/<detected-framework>/` based on `codebase-map.md §7 Framework.name`

## Fallback behavior

When `scan-codebase` detects a framework but no matching `lib-patterns/<framework>/` directory exists:
- Subagents proceed using `_universal.md` patterns from `framework-conventions/`
- Detection becomes manifest-only (less precise)
- Log line emitted: `no lib-pattern pack for <framework>; using generic extraction`
- No halt (graceful degradation per Iter 32 design)

## Anti-halu

Pattern files describe what to LOOK FOR; subagents MUST NOT invent libs that match no fingerprint. Absence is marked `lib: not_detected`. Every detection MUST cite the file(s) used (`_source:` array per starterkit-context-schema.md).
