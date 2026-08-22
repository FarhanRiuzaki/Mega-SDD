# Multi-PRD lifecycle — how a project grows PRD-by-PRD

A real project does not stop at PRD 1. PRD 1 ships, PRD 2 adds an epic, PRD 3 adds another — and the docs can be PRD, BRD, Figma, or a free-text brief. This reference is the contract that keeps that sequence **unambiguous and inline** (a new doc never silently contradicts shipped work).

## Contents

- The decision rule (the only thing you must get right)
- Project index
- Project constitution (shared, inherited)
- Doc-type agnosticism

## The decision rule — new vault vs diff-vault vs sync

When a doc arrives or the project moves, route by **what actually changed**, never guess:

| Situation | Route | Why |
|---|---|---|
| The SAME source doc was **revised** (PRD v1 → v1.1; a BRD edit) | **`diff-vault`** | One vault evolves; resolved OQs + ADR history preserved; conflicts surfaced. |
| A **new epic / feature-set** on top of shipped work (PRD 2, a genuinely new doc) | **new vault** via `generate-intent`, then `bind-codebase` **brownfield** | PRD 2 is grounded against the codebase that now contains PRD 1; the binding gate catches any contradiction with shipped reality + the project constitution. |
| **Code moved** outside the pipeline (manual edit, hotfix, git pull) | **`sync`** | Reconcile map → drift → binding → units for the affected vault(s). |
| A **ticket-scale chat requirement** against an existing vault ("tambah kolom npwp di form nasabah" — no doc at all) | **delta lane**: `diff-vault --from-prompt` | The brief IS the comparison input; scoped patch → claim-scoped re-bind → `--reconcile` units; the `delta_too_large` cap forces an epic-in-disguise to the new-vault row. |

**Disambiguation signal:** if the incoming doc's title/scope matches an existing vault's `source` (same product, same epic) → it's a revision → `diff-vault`. If it introduces a new feature area not owned by any existing vault → new vault. **Prompt-scale signal (no doc, just a sentence):** the sentence names an entity/flow/screen an existing vault's docs own (heading/entity match on its vault.md/constraints.md headings; legacy: the 00-index roll-up) → delta lane; it names a feature area no vault owns → new vault. When unsure, the router ASKS (it must not guess between evolve-in-place and new-epic — they diverge hard).

## Project index — `.mega-sdd/project.md`

Derived view (v7: the dedicated index script was removed — derive it on demand by listing `.mega-sdd/vaults/*/vault.json`): one row per vault — slug, title, source doc, version, status (`intent` / `units-ready` / `in-progress` / `shipped`), unit + bolt counts, feature area. **The sequence of vaults IS the project's PRD/epic history.** A new vault reads this index to know what PRD 1..N-1 shipped, so it binds against the right reality. Re-derive whenever the answer matters (vault list + counts are cheap reads).

## Project constitution — `.mega-sdd/constitution.md` (shared, inherited)

Per-vault constitutions (`<vault>/constitution.md`) carry the locked rules of THAT vault. Project-wide invariants that must hold across every epic — the datastore choice, the auth model, "no payment code paths", the framework — belong in a **project-scope constitution** at `.mega-sdd/constitution.md`. Every vault **inherits** it: a new vault's constitution `extends` the project one, and `bind-codebase` reads the project constitution as a locked layer. A new PRD that contradicts a project-locked clause (e.g. PRD 2 proposes MongoDB when the project constitution locks PostgreSQL) is a **CONFLICT at the binding gate** — surfaced, never silently accepted. This is what keeps PRD 2..N inline with PRD 1.

- Project constitution clauses use the same `§A–§F` / `A-001` grammar as a vault constitution.
- It is authored once (lift the cross-cutting clauses out of PRD 1's vault constitution at first ship, or write it explicitly) and only changes by explicit user action — never auto-edited.
- `constitution-propagation` checks project → vault inheritance in addition to binding → units.

## Doc-type agnosticism

`generate-intent` already accepts PRD / BRD / Figma / free-text brief / KB (`--kb`). The lifecycle above is **doc-type agnostic** — "a new doc" means any of these. An EPIC-SCALE brief (a BRD for epic 2, a free-text brief for epic 3) becomes a new vault, bound against the accumulating codebase + the one project constitution; a TICKET-SCALE brief naming content an existing vault owns takes the delta lane (`diff-vault --from-prompt`) instead — the cap decides honestly when a "ticket" is really an epic.
