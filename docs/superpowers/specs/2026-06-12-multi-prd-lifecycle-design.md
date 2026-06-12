# Multi-PRD lifecycle — project index + shared constitution + explicit router

**Date:** 2026-06-12 · **Reference:** `plugins/mega-sdd/references/multi-prd-lifecycle.md`
**Problem:** the plugin handled one-PRD-at-a-time well (generate-intent → … → bolts), same-PRD revision (diff-vault), and code drift (sync) — but a project that grows PRD-by-PRD (PRD 1 ships, PRD 2 adds an epic) had no first-class linking, so multi-vault was real but ambiguous and could drift out of "inline."

## Three additions

1. **Project index** (`scripts/build-project-index.sh` → `.mega-sdd/project.md`): derived manifest of every vault — slug, title, source, version, status (intent/units-ready/in-progress/shipped), unit+bolt counts, area. The vault sequence IS the PRD/epic history. Regenerated at chain end (wired into `run-analyze.sh`). Cheap pure-read; exit 0 always.
2. **Project constitution** (`.mega-sdd/constitution.md`): project-scope locked rules inherited by every vault. `bind-codebase` reads it before binding a NEW vault — a claim contradicting a project-locked clause is a CONFLICT at the gate (keeps PRD 2..N inline with PRD 1). Absent = unchanged behavior.
3. **Explicit router** (`using-mega-sdd` SKILL): a new doc routes by what changed — same source revised → diff-vault; new epic → new vault + brownfield bind; code moved → sync. Doc-type agnostic (PRD/BRD/Figma/brief). When the doc's title/scope matches an existing vault's source → revision; new feature area → new vault; **when unsure, ASK**.

## Doctrine

Index + router are advisory/navigational (no new blocking hook). The only enforcement is the project-constitution CONFLICT at the existing binding gate — reusing the moat, not adding surface. Tests: `tests/multi-prd/` (index functional on a 2-vault fixture: shipped + intent; empty/non-sdd safety; wiring pins). plugin → 4.28.0.
