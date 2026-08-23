---
name: using-mega-sdd
version: 4.1.0
description: Session-start router for spec-driven development — weighs every task S/M/L and routes only M/L through a mega-sdd skill; S answers inline. Use when the prompt mentions intent, unit, bolt, vault, PRD, BRD, spec out, dev handoff, binding, bound-vault, open questions, knowledge-base, extract intelligence, reverse engineer, legacy intelligence, rebuild, sync (code changed, continue from current code), or auto/orchestrate; the Indonesian variants pecah PRD, buat dev, spec ini, siapkan context buat AI dev, kontrak handoff, pecah legacy, rebuild di stack baru, source of truth dari legacy, jalankan otomatis, lanjut, next, kode berubah, lanjutin dari kode sekarang.
---

# Using Mega-SDD

Weigh the task FIRST; only tiers M and L route through a mega-sdd skill — the skills own the work. Default when unsure: **S** (answer inline). (Routing core only — invoke `using-mega-sdd` for the pipeline map, phase-ownership, and multi-PRD lifecycle.)

## Task weight — decide before responding

| Tier | Signals (ONE strong signal is enough) | What runs |
|---|---|---|
| **S — direct** (DEFAULT when unsure) | bug hunt / fix / debug / local refactor (~1-3 files); questions about code; no PRD / vault / unit / bolt / spec / sync / binding / OQ mention; no artifact argument; continuation prompt (`lanjut`, `ok`, `next`) when no mega-sdd skill ran this session | NO pipeline — answer as plain Claude Code. May Read AT MOST ONE vault doc (read-only) if the prompt names a domain the vault owns; no ground, no derive-state, no status view, zero mega-sdd scripts. If relevant, end with ONE line: `mau masuk pipeline? → /mega-sdd` |
| **M — delta** | a spec/feature change to existing scope — "tambah field", "ubah flow", "ganti validasi", "fitur baru di …", a 1-2 sentence feature brief | `/mega-sdd` front door → its MECHANICAL ownership check (vault.json entity/flow match) decides: match → delta lane with ONE confirmation; no match → drop to S + the one-line offer (do NOT interrogate) |
| **L — full** | artifact argument (PRD/BRD file, legacy dir, vault); `--greenfield`; a new epic; explicit `/mega-sdd`; `sync` after the code moved | the full chain as today via the front door (→ `orchestrate-flow`) |

Override always wins: `--weight=S|M|L` (the only weight flag — `--full` already means the diagnostics profile); "skip SDD" / "just write the code" → S — the user is in control.

## The front door (M/L only)

**Any M/L lane phrase → the `/mega-sdd` front door** — status view + next-chain proposal + one confirmation; an artifact argument gets input-shape detection. Other verbs: `/mega-sdd:sync` (reconcile after the code moved — OFFERED at the next M/L entry, never mandated after an inline fix), `/mega-sdd:emit <prd|fsd|sit|uat>`. Side lanes (consistency check, impact/blast radius, memory review, interop, pasang tools) route by each skill's own description. A NEW PRD/BRD/Figma/brief → multi-PRD routing (revise vs new epic); ambiguity between several owning vaults → ASK.

## Hard rule (tiers M and L only)

For an M/L trigger: **STOP**, invoke the skill via the `Skill` tool, and announce which skill before continuing. Gated phases: Skill-dispatch only, never Agent-offload.

**Tier S prohibitions: do NOT invoke any `mega-sdd:*` skill, do NOT open `/mega-sdd`, do NOT propose sync. Work inline.**

A `.mega-sdd/` dir in the CWD is a STATUS signal only (one session-start notice line) — never, by itself, a reason to invoke a skill. Prior chains exist in the project (factory-ledger present) + a continuation prompt → offer `/mega-sdd --resume` in one line; do not auto-invoke.

**Gateway marker:** announce lines end with `` `mega-sdd-trace:<skill>` ``; every subagent dispatch prompt carries one `mega-sdd-trace:<skill>` line. Verbatim, no variants (docs/gateway-contract.md).

**Hard gate:** `bind-codebase` BLOCKS unit generation while `binding.md` has unresolved CONFLICT entries.

## Output language

Narrate (chat, halts, recommendations) in **Indonesian + English technical terms by default**. Precedence: explicit request this session (e.g. "use English", "pakai bahasa X") > the language the user is writing in > Indonesian for short/ambiguous input (`gas`, `go`, `lanjut`). **Tier-1 structural tokens stay English always** (`CONFIRMED`/`CONFLICT`/`OQ`, enums, IDs, field names, paths, commands) — full census + per-artifact rules in `plugins/mega-sdd/references/output-language.md`. Reasoning stays English; only output changes.

<!-- ANCHOR-CORE ends here — everything below is loadable detail (invoke the `using-mega-sdd` skill for it). session-start injects only the routing core above, to keep the per-session / per-compaction footprint small. Do not move a trigger keyword or the hard rule below this line. -->

## Priority order

1. User instructions (CLAUDE.md, AGENTS.md, direct requests) — highest.
2. Mega-SDD phase rails — override default behavior within SDD scope (tiers M/L).
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

Diagnostic & output lanes compress to the front-door rule — any M/L lane phrase routes to `/mega-sdd`; the side-lane skills (`analyze` "check consistency", `graph` "impact / blast radius", `emit-fsd`/`emit-prd`/`emit-sit`/`emit-uat` (`UAT`, `test script`, `skrip uji`, `berita acara UAT`) via `/mega-sdd:emit`, `emit-agents-md`, `install-deps`) each carry their own trigger census in their always-loaded description and may be invoked directly.

Maintenance lane (never-ending development): when the code moved outside the pipeline (manual edit, AI-prompted edit, hotfix, git pull), `/mega-sdd:sync` (→ `orchestrate-flow --sync`) reconciles: incremental re-scan → drift triage → re-bind → unit reconcile. Sync is OFFERED at the next M/L entry — the front door surfaces the change signal there; it is never a mandatory follow-up to an inline tier-S fix, and the session-start staleness notice is informational only.


Multi-PRD lane (a project that grows PRD-by-PRD — PRD 1 ships, PRD 2 adds an epic, doc can be PRD/BRD/Figma/brief): route a NEW doc by what changed, never guess (full contract → `plugins/mega-sdd/references/multi-prd-lifecycle.md`):
- Same source **revised** (PRD v1 → v1.1) → `diff-vault` (one vault evolves; history preserved).
- **Ticket-scale chat delta** to an owned vault ("tambah kolom X di form Y" — no doc) → the delta lane: `diff-vault --from-prompt` (scoped patch → claim-scoped re-bind → `--reconcile` units; the `delta_too_large` cap forces an epic-in-disguise to the next row).
- **New epic** on top of shipped work → **new vault** via `generate-intent`, then `bind-codebase` **brownfield** against the codebase that now contains PRD 1 (+ the project constitution) — the binding gate catches contradictions with shipped reality.
- **Code moved** → `sync`.
When the doc's title/scope matches an existing vault's source → revision (diff-vault); a new feature area → new vault; several owning vaults plausible → **ASK** (evolve-in-place vs new-epic diverge hard). `.mega-sdd/project.md` (the project index) lists every vault + status so PRD N knows what shipped; `.mega-sdd/constitution.md` (project-scope, inherited by every vault) keeps PRD 2..N from contradicting PRD 1's locked decisions.

## Phase ownership

| Phase | Skill | Repo access |
|---|---|---|
| Legacy → knowledge-base | extract-intelligence | read-only |
| Brief → vault | generate-intent | not required (consumes KB if `--kb`) |
| Codebase scan (on-demand map producer; classic-spine chain phase) | scan-codebase | read-only |
| Validation gate | bind-codebase | read-only |
| Vault → units | generate-units | read-only |
| Unit → code | execute-bolts | write |

## Reference

Pipeline-stage reading guide + upgrade/compatibility → repo docs (`docs/mega-sdd/reading-map.md`, `docs/mega-sdd/upgrade-from-old-version.md` — maintainer-facing, moved out of the shipped references/ in v7.4.0).
