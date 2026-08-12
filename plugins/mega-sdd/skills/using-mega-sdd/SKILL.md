---
name: using-mega-sdd
version: 3.3.3
description: Session-start router for spec-driven development — decides whether a task should go through a mega-sdd skill and which one. Use when the prompt mentions intent, unit, bolt, vault, PRD, BRD, spec out, dev handoff, binding, bound-vault, open questions, knowledge-base, extract intelligence, reverse engineer, legacy intelligence, rebuild, sync (code changed, continue from current code), or auto/orchestrate; the Indonesian variants pecah PRD, buat dev, spec ini, siapkan context buat AI dev, kontrak handoff, pecah legacy, rebuild di stack baru, source of truth dari legacy, jalankan otomatis, lanjut, next, kode berubah, lanjutin dari kode sekarang; or the CWD shows .mega-sdd/ signals.
---

# Using Mega-SDD

Route SDD work through mega-sdd phases, not inline answers. This anchor decides *whether* a mega-sdd skill applies and *which*; the skills own the work. (Routing core only — invoke `using-mega-sdd` for the pipeline map, phase-ownership, multi-PRD lifecycle, and red-flags detail.)

## When this applies

Invoke a mega-sdd skill BEFORE responding when ANY hold: **(a)** the prompt types `/mega-sdd` or any `/mega-sdd:<verb>` (typed stage verbs retired — arrive as text; route to the skill); **(b)** it carries an SDD trigger keyword — the full EN + Indonesian keyword census lives in this skill's always-loaded description; or **(c)** the CWD shows SDD signals: a `.mega-sdd/` dir (vaults/, knowledge-base/, codebase-map) or a legacy layout (`docs/mega-sdd/`, `bound-vault/`, `binding.md` — the resolver handles them).

### Auto-trigger on a strong signal

CWD signal strong AND the prompt carries SDD intent (or is an empty/continuation prompt — `lanjut`, `ok`, `proceed`, `go`) → propose `/mega-sdd` (→ `orchestrate-flow --deep --auto`) with one upfront confirmation. Strong CWD = one of: legacy code + no PRD + no vault; a PRD present + no vault; vault + no units; units + no bolts; **map+binding present + change signal** (dirty journal non-empty OR HEAD ≠ map stamp) → propose `/mega-sdd:sync --auto` instead. General questions ("what is an OQ?", "explain X", "fix this bug", "show unit U-005"), casual conversation, and debugging/refactoring unrelated to a vault do NOT auto-trigger — the prompt must carry mega-sdd intent. If the user says "skip binding" / "just write the code" / "ignore SDD", follow them — they are in control.

## The front door (one rule)

**Any SDD lane phrase → the `/mega-sdd` front door** — status view + next-chain proposal + one confirmation; an artifact argument gets input-shape detection. Other verbs: `/mega-sdd:sync` (after ANY out-of-pipeline change: manual/AI edit, hotfix, git pull), `/mega-sdd:emit <prd|fsd|sit|uat>`. Side lanes (consistency check, impact/blast radius, memory review, interop, pasang tools) route by each skill's own description. A NEW PRD/BRD/Figma/brief → multi-PRD routing (revise vs new epic); **when unsure, ASK**.

## Hard rule

For any trigger above: **STOP**, invoke the skill via the `Skill` tool (default route when unsure: `orchestrate-flow`), and announce which skill before continuing. Gated phases: Skill-dispatch only, never Agent-offload.

**Observability tag:** every skill announce line MUST end with `` `mega-sdd-trace:<skill>` ``; every subagent dispatch prompt MUST contain a `mega-sdd-trace:<skill>` line (fresh-context subagents are otherwise invisible to the AI-gateway/Langfuse filter). One token, verbatim, no variants.

**Hard gate:** `bind-codebase` BLOCKS unit generation while `binding.md` has unresolved CONFLICT entries.

## Output language

Narrate (chat, halts, recommendations) in **Indonesian + English technical terms by default**. Precedence: explicit request this session (e.g. "use English", "pakai bahasa X") > the language the user is writing in > Indonesian for short/ambiguous input (`gas`, `go`, `lanjut`). **Tier-1 structural tokens stay English always** (`CONFIRMED`/`CONFLICT`/`OQ`, enums, IDs, field names, paths, commands) — full census + per-artifact rules in `plugins/mega-sdd/references/output-language.md`. Reasoning stays English; only output changes.

<!-- ANCHOR-CORE ends here — everything below is loadable detail (invoke the `using-mega-sdd` skill for it). session-start injects only the routing core above, to keep the per-session / per-compaction footprint small. Do not move a trigger keyword or the hard rule below this line. -->

## Priority order

1. User instructions (CLAUDE.md, AGENTS.md, direct requests) — highest.
2. Mega-SDD phase rails — override default behavior within SDD scope.
3. Default system prompt — lowest.

## The pipeline

```
generate-intent → (bind-codebase --express if brownfield — claim-scoped, zero map load; scan-codebase is ON-DEMAND / classic-spine only) → generate-units → execute-bolts
```

Legacy-rebuild upstream lane (code is the only spec):

```
extract-intelligence → generate-intent --kb=<kb> → (canonical pipeline)
```

Side lanes (as needed): `resolve-oq` (OQ walk), `detect-drift` (code vs vault), `diff-vault` (new PRD revision), `orchestrate-flow` (auto-route by CWD state).

Diagnostic & output lanes compress to the front-door rule — any SDD lane phrase routes to `/mega-sdd`; the side-lane skills (`analyze` "check consistency", `graph` "impact / blast radius", `memory` "review learnings", `emit-fsd`/`emit-prd`/`emit-sit`/`emit-uat` (`UAT`, `test script`, `skrip uji`, `berita acara UAT`) via `/mega-sdd:emit`, `emit-agents-md`, `install-deps`) each carry their own trigger census in their always-loaded description and may be invoked directly.

Maintenance lane (never-ending development): after ANY out-of-pipeline change (manual edit, AI-prompted edit, hotfix, git pull), `/mega-sdd:sync` (→ `orchestrate-flow --sync`) reconciles: incremental re-scan → drift triage → re-bind → unit reconcile. The session-start notice surfaces when the code moved since the last scan.

Standalone slicing lane (command-only): `/mega-sdd:slice` — implement UI from a design reference (Figma export / URL / image) with a Playwright-MCP render check; never auto-routed from free text, never writes the vault (spec 2026-08-12).

Multi-PRD lane (a project that grows PRD-by-PRD — PRD 1 ships, PRD 2 adds an epic, doc can be PRD/BRD/Figma/brief): route a NEW doc by what changed, never guess (full contract → `plugins/mega-sdd/references/multi-prd-lifecycle.md`):
- Same source **revised** (PRD v1 → v1.1) → `diff-vault` (one vault evolves; history preserved).
- **Ticket-scale chat delta** to an owned vault ("tambah kolom X di form Y" — no doc) → the delta lane: `diff-vault --from-prompt` (scoped patch → claim-scoped re-bind → `--reconcile` units; the `delta_too_large` cap forces an epic-in-disguise to the next row).
- **New epic** on top of shipped work → **new vault** via `generate-intent`, then `bind-codebase` **brownfield** against the codebase that now contains PRD 1 (+ the project constitution) — the binding gate catches contradictions with shipped reality.
- **Code moved** → `sync`.
When the doc's title/scope matches an existing vault's source → revision (diff-vault); a new feature area → new vault; **when unsure, ASK** (evolve-in-place vs new-epic diverge hard). `.mega-sdd/project.md` (the project index) lists every vault + status so PRD N knows what shipped; `.mega-sdd/constitution.md` (project-scope, inherited by every vault) keeps PRD 2..N from contradicting PRD 1's locked decisions.

## Phase ownership

| Phase | Skill | Repo access |
|---|---|---|
| Legacy → knowledge-base | extract-intelligence | read-only |
| Brief → vault | generate-intent | not required (consumes KB if `--kb`) |
| Codebase scan (on-demand map producer; classic-spine chain phase) | scan-codebase | read-only |
| Validation gate | bind-codebase | read-only |
| Vault → units | generate-units | read-only |
| Unit → code | execute-bolts | write |

## Red flags (STOP — rationalizations)

| Thought | Reality |
|---|---|
| "I'll draft the vault inline, faster" | Use `generate-intent` — the anti-hallucination rails matter |
| "Binding is overkill here" | Run `bind-codebase` in brownfield anyway — the gate exists for a reason |
| "Skip units, it's trivial" | Units encode grounding — don't skip in real pipelines |
| "Execute inline, superpowers is heavy" | Bolts route through `execute-bolts` (vendored fallback OK) |

## Reference

Pipeline-stage reading guide → `plugins/mega-sdd/references/reading-map.md`. Upgrade / compatibility → `plugins/mega-sdd/references/upgrade-from-old-version.md`.
