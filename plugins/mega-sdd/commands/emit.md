---
description: Emit one of the three team documents — /mega-sdd:emit <prd|fsd|sit> dispatches the matching doc-pack skill (flags pass through). No arg → list the three docs with current maturity from their doc-control stamps.
argument-hint: "<prd|fsd|sit> [vault-path] [--no-pdf] [--auto] [doc-specific flags]"
---

The single emission verb of the 5.0.0 surface. **Dispatch is via the Skill tool — never the Agent tool** (the doc-pack gates key on Skill calls).

User arguments: $ARGUMENTS

## Dispatch table

| First positional | Dispatch (Skill tool) | Doc | Output |
|---|---|---|---|
| `prd` | `mega-sdd:emit-prd` | Product Requirements Document (forward from vault / REVERSE from KB) | `<vault>/prd/PRD.md` |
| `fsd` | `mega-sdd:emit-fsd` | Hybrid Confluence FSD | `<vault>/fsd/FSD.md` (+ PDF/HTML) |
| `sit` | `mega-sdd:emit-sit` | Bank-style SIT with script-derived evidence | `<vault>/sit/SIT.md` |

Strip the first positional (`prd|fsd|sit`) and pass EVERY remaining argument through to the dispatched skill unchanged — each doc-pack skill owns its own flag parsing, rails, and halt taxonomy (this command adds none).

An unknown first positional (not `prd|fsd|sit` and not empty) → do not guess; show the dispatch table and ask which document was meant (keterangan in Indonesian).

## No argument — the doc-maturity listing

When `$ARGUMENTS` is empty, do NOT emit anything. For each vault (canonical `.mega-sdd/vaults/*/` first, legacy `docs/mega-sdd/vaults/*/`), probe the three doc paths and read each doc-control stamp (the `<!-- mega-sdd:doc-control` … `-->` block written by `scripts/refresh-doc-stamps.sh` — fields `maturity` / `position` / `generated_at`):

```
Dokumen tim (vault: <name>)
- PRD  <vault>/prd/PRD.md  — maturity: <draft-from-legacy|reviewed|final>   (generated_at: …)
- FSD  <vault>/fsd/FSD.md  — maturity: <pre-development|post-development>   (generated_at: …)
- SIT  <vault>/sit/SIT.md  — maturity: <planned|partial|executed>           (generated_at: …)
```

A doc that does not exist → `belum pernah di-emit — jalankan /mega-sdd:emit <doc>`. A doc without a doc-control block → `maturity: unset (stamp belum ada)`. Never invent a maturity value; the stamp (or its absence) is the only source.

Close the listing with the one-line hint: `Pakai /mega-sdd:emit <prd|fsd|sit> [flags] untuk emit/regenerate.`
