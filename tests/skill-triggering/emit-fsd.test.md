# /mega-sdd:emit-fsd Trigger + Behavior Test

Iter 54 — Hybrid Confluence FSD emitter skill. Anti-hallucination citation discipline via `.citation-map.json`. PDF via scripts/md2pdf.sh (pandoc HTML + Chrome print, GitHub style; HTML fallback without Chrome; NEVER LaTeX).

## Trigger cases

### EF1: Explicit invocation on stable vault
- **Setup:** vault exists at `<project>/.mega-sdd/vaults/<slug>/` with vault.json + 01-overview.md + 02-functional.md; no units/ yet
- **Prompt:** `/mega-sdd:emit-fsd`
- **Expect:** Skill invoked; mode auto-detected as `pre-dev`; FSD.md + (if Chrome available) FSD.pdf else FSD.html + .citation-map.json written to `<vault>/fsd/`; FSD.md has `DRAFT` watermark + section 9 = "TBD — pending bolt execution"

### EF2: Post-development mode auto-detection
- **Setup:** vault + units/ + bolts/ all present; bolt-reports include acceptance_test results
- **Prompt:** `/mega-sdd:emit-fsd`
- **Expect:** Mode = `post-dev`; section 9 populated with actual UAT results table; section 10 includes aggregated `acceptance_test_concerns` from bolt-reports

### EF3: Pandoc absent → markdown-only graceful degrade
- **Setup:** vault exists; `command -v pandoc` returns non-zero
- **Prompt:** `/mega-sdd:emit-fsd`
- **Expect:** Predictive check `pandoc_installed` warns; FSD.md emitted; FSD.pdf NOT emitted; handoff metric `fallback_format: markdown`

### EF4: Chrome absent → HTML fallback
- **Setup:** pandoc present; Chrome/Chromium not on PATH
- **Prompt:** `/mega-sdd:emit-fsd`
- **Expect:** FSD.md emitted; pandoc generates FSD.html (standalone, self-contained) instead of PDF; handoff metric `fallback_format: html`

### EF5: Drift detection on re-emit
- **Setup:** prior `.citation-map.json` exists from earlier emit; user edits `vault/01-overview.md` (sha256 changes)
- **Prompt:** `/mega-sdd:emit-fsd`
- **Expect:** Skill runs `scripts/build-citation-map.sh (--check-drift mode)` (Step 2) and consumes its `DRIFT <section> <path> <old12> <new12>` line — it NEVER Reads `.citation-map.json` directly; the `⚠ Updated since last emit` callout inserted BEFORE regenerated section 1 uses the script's old12/new12 prefixes; handoff metric `drift_callouts_count: 1`

### EF6: Section subset via --sections flag
- **Setup:** vault stable; user only wants stakeholder + FR + design sections
- **Prompt:** `/mega-sdd:emit-fsd --sections=1,2,5,7,8,10`
- **Expect:** FSD.md emitted with only sections 1, 2, 5, 7, 8, 10; sections 3, 4, 6, 9 skipped per styling.include_sections filter; handoff metric `sections_excluded: 4`

### EF7: Anti-halu — missing source artifact emits placeholder, never fabricates
- **Setup:** vault has 01-overview.md + 02-functional.md but NO binding.md (scan-codebase + bind-codebase not yet run)
- **Prompt:** `/mega-sdd:emit-fsd`
- **Expect:** Section 7 (Design / Architecture) emits `[Pending — binding.md not yet generated. Run /mega-sdd:bind-codebase.]` placeholder; NEVER fabricates design content from vault alone

### EF8: Auto-invocation from /mega-sdd front-door pipeline
- **Setup:** vault + units + bolts complete; `/mega-sdd ./prd.md` running
- **Expect:** At chain end (after emit-agents-md), orchestrate-flow Step 6 auto-invokes `/mega-sdd:emit-fsd --auto`; FSD.pdf emitted; chain summary includes "FSD emitted: N sections, M citations, mode: post-dev"

### EF9: --no-fsd flag skips auto-invocation
- **Setup:** same as EF8
- **Prompt:** `/mega-sdd ./prd.md --no-fsd`
- **Expect:** Chain runs to completion WITHOUT invoking emit-fsd; chain summary OMITS FSD line

### EF10: --dry-run prints plan without execution
- **Setup:** vault stable
- **Prompt:** `/mega-sdd:emit-fsd --dry-run`
- **Expect:** Skill prints what WOULD be emitted (sections, source artifacts, estimated PDF page count) without writing FSD.md or .citation-map.json

## Pass criteria

All EF1-EF10 succeed per `skills/emit-fsd/SKILL.md` Procedure. FSD output is human-readable, citation-grounded (every section traces to source artifact via `.citation-map.json` — script-computed by `scripts/build-citation-map.sh`, Step 4.6), idempotent on stable vault, drift-aware on regeneration.

## Anti-halu rail verification

- EF7: missing source → `[Pending — X not yet generated]` placeholder; NEVER fabricates content
- Iter 61 Step 4.5 check: post-emission scan halts on any remaining `{{slot}}` markers (defensive — should never fire if section-mapping.md extraction rules are correct)
- Sha256 stamps + `.citation-map.json` computed at emit-time by `scripts/build-citation-map.sh` from file bytes; the model emits `(sha256: pending)` placeholders and never writes hash strings; a citation to a nonexistent path is a deterministic exit-1 → `quality_gate_failed:citation_unresolvable` halt; drift list produced by `scripts/build-citation-map.sh (--check-drift mode)`
