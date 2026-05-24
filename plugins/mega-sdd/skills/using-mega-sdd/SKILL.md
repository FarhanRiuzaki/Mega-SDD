---
name: using-mega-sdd
version: 1.3.4
description: Use at session start when SDD topics arise — establishes how to route SDD work through mega-sdd phases. (v1.2+, Iter 4) Sharper auto-trigger — when CWD signals are strong (PRD upload + no vault, legacy codebase + rebuild intent, vault present + no units) AND user prompt contains mega-sdd intent keywords OR is empty/continuation, auto-invoke `orchestrate-flow --deep` for pipeline-end execution. Triggers on SDD keywords (intent, unit, bolt, vault, PRD, BRD, spec out, dev handoff, binding, bound-vault, knowledge-base, extract intelligence, reverse engineer, auto, rebuild) and Indonesian variants (pecah PRD, buat dev, spec ini, siapkan context buat AI dev, pecah legacy, rebuild di stack baru, jalankan otomatis, lanjut, next).
---

# Using Mega-SDD

## When this anchor applies (scoped)

Invoke a mega-sdd skill BEFORE any response when ANY of these apply:

**Trigger conditions:**
- User explicitly types `/mega-sdd:<command>`
- User prompt contains SDD keywords: `intent`, `unit`, `bolt`, `vault`, `PRD`, `BRD`, `spec out`, `dev handoff`, `binding`, `bound-vault`, `Open Question`, `knowledge-base`, `extract intelligence`, `reverse engineer`, `legacy intelligence`, `auto`, `rebuild`
- User prompt contains Indonesian SDD variants: `pecah PRD`, `buat dev`, `spec ini`, `siapkan context buat AI dev`, `kontrak handoff`, `pecah legacy`, `rebuild di stack baru`, `source of truth dari legacy`, `jalankan otomatis`, `lanjut`, `next`
- CWD has SDD signals (priority order — new `.mega-sdd/` layout first per v3.4+ Iter 10): `.mega-sdd/`, `.mega-sdd/vaults/`, `.mega-sdd/knowledge-base/`, `.mega-sdd/codebase/codebase-map.md` — back-compat: `docs/mega-sdd/`, `vaults/`, `bound-vault/`, `units/`, `binding.md`, `codebase-map.md`, `docs/knowledge-base/`, `docs/mega-sdd/knowledge-base/`, `old-reference/knowledge-base/`

### Sharper auto-trigger (v1.2+, Iter 4)

When BOTH of these conditions hold, auto-invoke `/mega-sdd:auto` (or `orchestrate-flow --deep`) — proposing the chain to the user with single upfront confirmation — WITHOUT waiting for the user to type an SDD command explicitly:

**Condition A** (strong CWD signal):
- Legacy codebase present (`.git` + package manifest + code files) AND no `prd.md` / `seed-PRD.md` AND no vault
- OR `*PRD*.{md,pdf,docx}` file uploaded/present in CWD AND no vault exists yet
- OR vault present AND no `units/` directory
- OR bound-vault present + units present + no `bolts/U-*/bolt-report.md`

**Condition B** (user prompt signal):
- Contains an SDD intent keyword from the list above (`rebuild`, `auto`, `lanjut`, `next`, etc.)
- OR is empty / a continuation prompt (`lanjut`, `ok`, `proceed`, `go`)
- OR explicitly asks for end-to-end pipeline execution

When both hold → auto-invoke `/mega-sdd:auto` (which routes to `orchestrate-flow --deep --auto`). Per AUTONOMY-OQ-3 resolved: general questions ("how do I do X", "explain Y", "fix this bug") do NOT auto-trigger even with strong CWD signals — the prompt must contain mega-sdd intent.

**Examples that auto-trigger:**
- CWD has PRD, vault absent, prompt = `lanjut`
- CWD has legacy code, vault absent, prompt = `mau rebuild ini di Laravel`
- CWD has units, no bolts, prompt = `proceed`

**Examples that do NOT auto-trigger** (even with strong CWD):
- CWD has vault, prompt = `apa itu OQ?` (general question)
- CWD has units, prompt = `lihat unit U-005` (specific inspection, not execution)
- CWD has PRD, prompt = `apa bedanya PRD dan vault?` (conceptual question)

**Non-triggers (do NOT mandate skill check):**
- Casual conversation without SDD vocab
- Code debugging, refactoring, or review unrelated to a vault
- General architecture discussion not anchored to a PRD/vault

### Starterkit-first mode (v1.3+, Iter 27)

`/mega-sdd:auto` defaults to **starterkit-first**: scan-codebase runs FIRST when a framework manifest exists; vault generation becomes pack-aware via dual-citation format (Intent + Starterkit binding) per `generate-intent/references/vault-contract.md` §Starterkit-binding.

**Auto-trigger refinement**: when proposing the chain to the user, surface starterkit detection result upfront:

```
Detected starterkit: laravel-base-26 (composer.json — Vuexy fingerprint)
  Pack: framework-conventions/laravel-base-26.md (extends laravel.md, _universal.md)

Proposed pipeline (--deep, starterkit-first mode):
  1. scan-codebase ./       → codebase-map.md (loads pack into context)
  2. generate-intent --scan=<map> ./prd.md  → vault (pack-aware, dual-citation)
  3. bind-codebase          → binding.md + bound-vault/
  4. generate-units         → units/
  5. execute-bolts --all    → bolts/

[Run] [Edit] [Cancel]
```

When NO starterkit detected:
- Default → halt with `no_starterkit_detected` (user picks: scaffold / opt-in greenfield / cancel)
- User explicit `--greenfield` → skip halt; proceed with stack-agnostic vault generation (Mode C)

### Multi-scope PRD picker (v1.3.1+, Iter 28)

When `/mega-sdd:auto` invoked on a PRD with canonical multi-scope format (`scopes:` frontmatter), the chain proposal surfaces scope picker upfront:

```
Detected scopes in PRD: BE, MW, FE
Smart default: BE (cwd basename matches)

❓ This vault is for which scope?
   [1] BE — Backend API (recommended)
   [2] MW — Integration Middleware
   [3] FE — Frontend Web
   [4] All scopes (legacy single-vault)
   [5] Cancel
```

When PRD lacks scopes block → retrofit bridge fires (per `generate-intent/references/legacy-retrofit-prompt.md`).

When memory has prior scope for this PRD + same cwd → silent default with confirm-once UX (5s timeout).

`--scope=<id>` flag bypasses picker entirely. `--scope=all` falls back to legacy single-vault behavior.

See `tests/scenarios/scenario-7-multi-architect.md` for end-to-end walkthrough.

## Priority order

1. **User explicit instructions** (CLAUDE.md, AGENTS.md, direct requests) — highest
2. **Mega-SDD phase rails** — override default behavior in SDD scope
3. **Default system prompt** — lowest

If user says "skip the binding step" or "no need for units," follow them. User is in control.

## The pipeline (canonical)

```
generate-intent → (scan-codebase + bind-codebase if brownfield) → generate-units → execute-bolts
```

Upstream lane for legacy-rebuild scenarios (no PRD, code is the only spec):

```
extract-intelligence → generate-intent --kb=<kb> → (… canonical pipeline)
```

Side lanes (run as needed, not in main chain):
- `resolve-oq` — interactive Open Question walk
- `detect-drift` — code vs vault reconciliation
- `diff-vault` — handle new PRD revision
- `extract-intelligence` — reverse-engineer legacy codebase into tech-agnostic knowledge base (when rebuild is on a different stack)
- `orchestrate-flow` — auto-route based on CWD state

## Reading guide (v1.3.3+, Iter 35)

For users wondering "at this pipeline stage, where do I look?" — see `plugins/mega-sdd/references/reading-map.md`. Indexed by 7 pipeline stages with ⭐ markers for primary entry-points. Companion to implementer-facing `paths.md`.

## Upgrade guide (v1.3.4+, Iter 36)

For users coming from older mega-sdd versions — `plugins/mega-sdd/references/upgrade-from-old-version.md` consolidates compatibility matrix + migration command order + halt-by-halt recovery + decision tree. Cross-refs `tests/scenarios/scenario-6-recovery-from-halt.md` for generic halt walkthrough.

## Hard rule

For ANY trigger condition above:
1. **STOP**. Do not respond yet.
2. **Invoke the appropriate skill** via `Skill` tool. Default route when unsure: `orchestrate-flow` (it auto-routes).
3. **Announce** which skill you're invoking before continuing.

## Red flags (rationalization patterns — STOP)

| Thought | Reality |
|---|---|
| "I'll just draft the vault inline, faster" | Use `generate-intent` — anti-hallucination rails matter |
| "Binding is overkill for this small change" | Run `bind-codebase` anyway in brownfield — gate exists for a reason |
| "I can skip units, the change is trivial" | Units encode grounding, never skip in real pipelines |
| "Superpowers is heavy, I'll execute inline" | Bolts MUST route through superpowers (vendored fallback OK) |
| "User just wants a quick answer" | Quick answers are fine OUTSIDE SDD scope; inside, use skills |
| "Detecting brownfield is hard, assume greenfield" | `orchestrate-flow` already detects — defer to it |

## When NOT to use mega-sdd

- User asks unrelated coding questions
- User says "ignore SDD" or "just write the code"
- Quick scripting, debugging session, or tool config

## Phase ownership

| Phase | Skill | Repo access | Runs |
|---|---|---|---|
| Legacy → knowledge-base | `extract-intelligence` | Read-only | Dev / AI (wave-based subagents) |
| Brief → vault | `generate-intent` | Not required (consumes KB if `--kb` provided) | Architect |
| Codebase scan | `scan-codebase` | Read-only | Dev / AI |
| Validation gate | `bind-codebase` | Read-only (consults KB if present) | Dev / AI |
| Vault → units | `generate-units` | Read-only | Dev / AI |
| Unit → code | `execute-bolts` | Write | AI agent (via superpowers) |

## Skill chain enforcement

After each phase completes, mega-sdd skills explicitly hand off to the next:
- `extract-intelligence` → suggests `generate-intent --kb=<kb>` (rebuild on different stack) OR manual rebuild planning via `99-rebuild-architecture/suggested-phasing.md`
- `generate-intent` → suggests `scan-codebase` (brownfield) OR `generate-units` (greenfield)
- `scan-codebase` → suggests `bind-codebase`
- `bind-codebase` → suggests `generate-units` (when no conflicts) OR `resolve-oq` (when conflicts). Consults KB as secondary ground truth when present.
- `generate-units` → suggests `execute-bolts`
- `execute-bolts` → suggests `detect-drift` (optional, periodic)

Hard gate: `bind-codebase` BLOCKS unit generation when `binding.md` has unresolved CONFLICT entries.
