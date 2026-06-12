---
name: using-mega-sdd
version: 2.2.0
description: Session-start router for spec-driven development — decides whether a task should go through a mega-sdd skill and which one. Use when the prompt mentions intent, unit, bolt, vault, PRD, BRD, spec out, dev handoff, binding, open questions, knowledge-base, extract intelligence, reverse engineer, rebuild, or auto/orchestrate; the Indonesian variants pecah PRD, buat dev, spec ini, siapkan context buat AI dev, kontrak handoff, pecah legacy, rebuild di stack baru, jalankan otomatis, lanjut, next, sync, kode berubah, lanjutin dari kode sekarang; or the CWD shows .mega-sdd/ signals.
---

# Using Mega-SDD

Route SDD work through mega-sdd phases instead of answering inline. This anchor decides *whether* a mega-sdd skill applies and *which* one; the skills own the work.

## When this applies

Invoke a mega-sdd skill BEFORE responding when ANY of these hold:

- User types `/mega-sdd:<command>`.
- Prompt contains SDD keywords: intent, unit, bolt, vault, PRD, BRD, spec out, dev handoff, binding, bound-vault, Open Question, knowledge-base, extract intelligence, reverse engineer, legacy intelligence, auto, rebuild, sync ("code changed, catch the vault up", "continue from current code").
- Indonesian variants: pecah PRD, buat dev, spec ini, siapkan context buat AI dev, kontrak handoff, pecah legacy, rebuild di stack baru, source of truth dari legacy, jalankan otomatis, lanjut, next.
- CWD has SDD signals: `.mega-sdd/`, `.mega-sdd/vaults/`, `.mega-sdd/knowledge-base/`, `.mega-sdd/codebase/codebase-map.md` (back-compat: `docs/mega-sdd/`, `vaults/`, `bound-vault/`, `units/`, `binding.md`, `codebase-map.md`).

### Auto-trigger on a strong signal

When the CWD signal is strong AND the prompt carries SDD intent (or is an empty/continuation prompt like `lanjut`, `ok`, `proceed`, `go`), propose `/mega-sdd:auto` (→ `orchestrate-flow --deep --auto`) with one upfront confirmation — don't wait for an explicit command.

Strong CWD = one of: legacy code + no PRD + no vault; a PRD file present + no vault; vault present + no units; units present + no bolts; **map+binding present + change signal** (dirty journal non-empty OR HEAD ≠ map stamp) → propose `/mega-sdd:sync --auto` instead of the full pipeline.

General questions ("what is an OQ?", "explain X", "fix this bug", "show unit U-005") do NOT auto-trigger even on a strong CWD signal — the prompt must carry mega-sdd intent.

Do NOT trigger on casual conversation, debugging/refactoring unrelated to a vault, or architecture talk not anchored to a PRD/vault. If the user says "skip binding" / "just write the code" / "ignore SDD", follow them — they are in control.

## Priority order

1. User instructions (CLAUDE.md, AGENTS.md, direct requests) — highest.
2. Mega-SDD phase rails — override default behavior within SDD scope.
3. Default system prompt — lowest.

## The pipeline

```
generate-intent → (scan-codebase + bind-codebase if brownfield) → generate-units → execute-bolts
```

Legacy-rebuild upstream lane (code is the only spec):

```
extract-intelligence → generate-intent --kb=<kb> → (canonical pipeline)
```

Side lanes (as needed): `resolve-oq` (OQ walk), `detect-drift` (code vs vault), `diff-vault` (new PRD revision), `orchestrate-flow` (auto-route by CWD state).

Maintenance lane (never-ending development): after ANY out-of-pipeline change (manual edit, AI-prompted edit, hotfix, git pull), `/mega-sdd:sync` (→ `orchestrate-flow --sync`) reconciles: incremental re-scan → drift triage → re-bind → unit reconcile. The session-start notice surfaces when the code moved since the last scan.

Multi-PRD lane (a project that grows PRD-by-PRD — PRD 1 ships, PRD 2 adds an epic, doc can be PRD/BRD/Figma/brief): route a NEW doc by what changed, never guess (full contract → `plugins/mega-sdd/references/multi-prd-lifecycle.md`):
- Same source **revised** (PRD v1 → v1.1) → `diff-vault` (one vault evolves; history preserved).
- **New epic** on top of shipped work → **new vault** via `generate-intent`, then `bind-codebase` **brownfield** against the codebase that now contains PRD 1 (+ the project constitution) — the binding gate catches contradictions with shipped reality.
- **Code moved** → `sync`.
When the doc's title/scope matches an existing vault's source → revision (diff-vault); a new feature area → new vault; **when unsure, ASK** (evolve-in-place vs new-epic diverge hard). `.mega-sdd/project.md` (the project index) lists every vault + status so PRD N knows what shipped; `.mega-sdd/constitution.md` (project-scope, inherited by every vault) keeps PRD 2..N from contradicting PRD 1's locked decisions.

## Phase ownership

| Phase | Skill | Repo access |
|---|---|---|
| Legacy → knowledge-base | extract-intelligence | read-only |
| Brief → vault | generate-intent | not required (consumes KB if `--kb`) |
| Codebase scan | scan-codebase | read-only |
| Validation gate | bind-codebase | read-only |
| Vault → units | generate-units | read-only |
| Unit → code | execute-bolts | write |

## Hard rule

For any trigger above: **STOP**, invoke the skill via the `Skill` tool (default route when unsure: `orchestrate-flow`), and announce which skill before continuing.

**Hard gate:** `bind-codebase` BLOCKS unit generation while `binding.md` has unresolved CONFLICT entries.

## Red flags (STOP — rationalizations)

| Thought | Reality |
|---|---|
| "I'll draft the vault inline, faster" | Use `generate-intent` — the anti-hallucination rails matter |
| "Binding is overkill here" | Run `bind-codebase` in brownfield anyway — the gate exists for a reason |
| "Skip units, it's trivial" | Units encode grounding — don't skip in real pipelines |
| "Execute inline, superpowers is heavy" | Bolts route through `execute-bolts` (vendored fallback OK) |

## Reference

Pipeline-stage reading guide → `plugins/mega-sdd/references/reading-map.md`. Upgrade / compatibility → `plugins/mega-sdd/references/upgrade-from-old-version.md`.
