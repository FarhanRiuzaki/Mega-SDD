# Iter 42 — Deep-Scan Manifest Pre-Parse + Per-Slice Cache Design

**Status:** Approved (autonomous execution per user directive)
**Source:** Iter 38 audit Queue #3 (D1-002 + D2-003)
**Plugin:** v3.27.1 → v3.28.0 (MINOR — new optimization step, new cache schema fields)
**Estimated effort:** ~3hr (markdown-driven; less than 4hr audit estimate due to surgical scope)

---

## §1 — Problems

### D1-002: redundant manifest reads (token waste)

Current behavior (scan-codebase v2.6.0+, Iter 32 §Step 10.5.2):
- 4 deep-scan subagents dispatched in parallel (auth/rbac/ui-ux/libs)
- Each subagent prompt instructs `Read <project>/composer.json` AND `Read <project>/package.json`
- Result: same 2 files read 4× per scan, plus their lock files
- I/O waste: ~9-24KB per scan
- Token waste: ~10-20% of each subagent's context budget

**External research:** Subagent token pattern (Sathish Raju Medium) — "pass analytical outputs, not raw data."

### D2-003: coarse cache invalidation (re-work waste)

Current behavior (scan-codebase v2.6.0+, Iter 32 §Step 10.5.1):
- Single composite cache_key: `(composer_lock_sha256, package_lock_sha256, framework_pack)`
- If ANY of the 3 components changes → ALL 4 slices re-dispatch
- Example: change a Vuexy CSS dep in package.json → auth + rbac re-dispatch unnecessarily (PHP-side hasn't changed)
- Re-work waste: 1-3 subagent runs per minor edit (~25-75% wasted compute)

**External research:** Real-time codebase indexing (cocoindex-io) — "per-file invalidation via XXH3 hash."

---

## §2 — Design

### Change 1: Manifest pre-parse (closes D1-002)

**New step `10.5.1.5` — Manifest pre-parse:**

Inserted between cache-check (`10.5.1`) and subagent dispatch (`10.5.2`). Runs only on CACHE MISS (not on cache HIT — no need).

Main thread parses manifest files ONCE, builds `manifest_facts` struct, injects into all 4 subagent prompts as `<MANIFEST_FACTS>` placeholder:

```yaml
manifest_facts:
  composer:
    dependencies:       # require: block
      laravel/framework: "^11.0"
      pixinvent/vuexy-laravel-bootstrap-jetstream: "^1.0"
      # ...
    dev_dependencies:   # require-dev: block
      pestphp/pest: "^3.0"
    scripts:            # scripts: block
      test: "pest"
  package:
    dependencies:       # dependencies: block
      vue: "^3.4"
      # ...
    dev_dependencies:
      vite: "^6.0"
    peer_dependencies:
      # ...
    scripts:
      build: "vite build"
```

Subagent prompts (in `references/deep-scan-prompts.md`) updated to:
- Receive `<MANIFEST_FACTS>` block in T1 preamble
- Instructed: "Manifest facts already parsed; do NOT re-read composer.json / package.json / lock files. Build your analysis from `<MANIFEST_FACTS>` + glob globs of source files."
- Subagent saves ~1 Read call (composer.json) + 1 Read call (package.json) = ~2KB-6KB context per subagent

**Net savings:** ~9-24KB per scan (4 subagents × ~2-6KB).

### Change 2: Per-slice cache (closes D2-003)

**Updated Step `10.5.1` cache-check + Step `10.5.3` consolidation:**

Replace single composite cache_key with per-slice cache_signature:

```yaml
# Current (Iter 32):
cache_key:
  composer_lock_sha256: <hex>
  package_lock_sha256: <hex>
  framework_pack: <pack-name>

# New (Iter 42):
cache_signatures:
  schema_version: 2.0          # Iter 42 bump
  composer_lock_sha256: <hex>  # retained for reproducibility
  package_lock_sha256: <hex>   # retained for reproducibility
  framework_pack: <pack-name>  # retained
  per_slice:
    auth:
      signature_sha256: <hex>  # sha256(composer.lock + framework_pack auth section + lib-patterns/<fw>/auth-libs.md)
      generated_at: <ISO8601>
    rbac:
      signature_sha256: <hex>  # sha256(composer.lock + framework_pack rbac section + lib-patterns/<fw>/rbac-libs.md)
      generated_at: <ISO8601>
    ui_ux:
      signature_sha256: <hex>  # sha256(package.lock + framework_pack ui section + lib-patterns/<fw>/ui-libs.md)
      generated_at: <ISO8601>
    libs:
      signature_sha256: <hex>  # sha256(composer.lock + package.lock + framework_pack libs section + lib-patterns/<fw>/generic-libs.md)
      generated_at: <ISO8601>
```

**Per-slice routing logic:**

```
For each of 4 slices (auth, rbac, ui_ux, libs):
  current_signature = sha256(<slice-specific inputs above>)
  IF prior.per_slice[<domain>].signature_sha256 == current_signature:
    → SLICE CACHE HIT: reuse prior slice content; skip subagent
  ELSE:
    → SLICE CACHE MISS: dispatch subagent for this domain only

IF all 4 slices hit cache → no dispatch needed (full cache hit)
IF 1-3 slices miss → dispatch ONLY those subagents (selective re-dispatch)
IF all 4 slices miss → dispatch all 4 (current behavior)
```

**Net savings (incremental edits):**
- composer.json frontend dep added → ui_ux + libs invalidate, auth + rbac cached → save 2 subagent runs (50%)
- Lib-pattern file edited (e.g., auth-libs.md) → only auth slice invalidates → save 3 subagent runs (75%)
- Framework pack edit → all 4 invalidate (no savings) — equivalent to current

### Backward compatibility

Existing `cache_key` block format (Iter 32 schema_version 1.0) still readable:
- If reading prior YAML with `cache_key:` (v1.0) → treat as "all slices stale; full re-dispatch"
- Write new `cache_signatures:` (v2.0) format going forward
- One-time migration cost; no breaking change for users

---

## §3 — Surface updates (4 surfaces)

| Surface | Change |
|---|---|
| `scan-codebase/SKILL.md` | + Step `10.5.1.5` Manifest pre-parse; modify Step `10.5.1` (per-slice cache check); modify Step `10.5.3` (per-slice cache write); modify Step `10.5.2` (selective dispatch); bump v2.6.x → v2.7.0 |
| `scan-codebase/references/deep-scan-prompts.md` | + `<MANIFEST_FACTS>` placeholder block to T1 preamble; instructions "do NOT re-read manifests" |
| `scan-codebase/references/starterkit-context-schema.md` | + `cache_signatures:` v2.0 schema; deprecate `cache_key:` v1.0 with backward-compat note |
| `references/shared-snapshot-schema.md` | (consult — does it need extension? Likely no; this is scan-codebase-internal cache, not shared-snapshot) |

---

## §4 — Version bumps

- `plugin.json`: 3.27.1 → **3.28.0** (MINOR — new optimization step + cache schema bump)
- `scan-codebase` SKILL.md: 2.6.3 → **2.7.0** (MINOR — new step + cache schema bump)
- `deep-scan-prompts.md`: documentation-only; no version

---

## §5 — Out of scope

- **D1-001 (handoff redundancy):** separate iter; touches handoff propagation logic across multiple skills
- **D1-006 (snapshot reuse extension):** separate iter; cross-skill scope
- **Symbol-graph per-file invalidation (D2-007):** different cache mechanism (scan-codebase v2.0 codebase-map), separate iter
- **Test fixtures:** test fixtures for cache HIT vs MISS scenarios — defer to Iter 43 if proven necessary in field

---

## §6 — Standing directives applied

- **simplifikasi:** 2 audit findings → 1 iter, 2 atomic changes, no new SKILL.md files
- **flawless:** producer (scan-codebase Step 10.5) + consumer (downstream skills reading starterkit-context.yaml) ship in-iter — schema bump is fully backward-compat; consumers don't break
- **reuse-first:** extends existing cache-check pattern (Iter 30 shared-snapshot reuse); reuses existing prompt template pattern; reuses existing handoff propagation
