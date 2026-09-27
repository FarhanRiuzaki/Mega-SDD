# Lib-Pattern Detection Catalogs

> Per-framework reference catalogs of library detection patterns behind the legacy `starterkit-context.yaml` (its deep-scan producer was removed in 9.0; pre-9.0 files stay readable).

**Introduced:** v3.23.0 (Iter 32)

## Directory layout

```
plugins/mega-sdd/references/lib-patterns/
  README.md                  # this file
  laravel/
    auth-libs.md             # Sanctum / Breeze / Jetstream / Fortify / Passport
    rbac-libs.md             # Spatie/permission / laravel-permission / custom
    ui-libs.md               # JS / CSS / notification / icon / datatable
    generic-libs.md          # queue / cache / log / test / misc
  django/                    # compact bullet pack (2-4 lines per file; no manifest / file-fingerprint / YAML sections)
    auth-libs.md
    rbac-libs.md
    ui-libs.md
    generic-libs.md
```

## Anti-halu

Pattern files describe what to LOOK FOR; subagents MUST NOT invent libs that match no fingerprint. Absence is marked `lib: not_detected`. Every detection MUST cite the file(s) used (`_source:` array per starterkit-context-schema.md).
