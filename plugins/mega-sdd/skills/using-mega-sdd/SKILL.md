---
name: using-mega-sdd
version: 1.0.0
description: Use at session start when SDD topics arise — establishes how to route SDD work through mega-sdd phases. Triggers on SDD keywords (intent, unit, bolt, vault, PRD, BRD, spec out, dev handoff, binding, bound-vault) and Indonesian variants (pecah PRD, buat dev, spec ini, siapkan context buat AI dev).
---

# Using Mega-SDD

## When this anchor applies (scoped)

Invoke a mega-sdd skill BEFORE any response when ANY of these apply:

**Trigger conditions:**
- User explicitly types `/mega-sdd:<command>`
- User prompt contains SDD keywords: `intent`, `unit`, `bolt`, `vault`, `PRD`, `BRD`, `spec out`, `dev handoff`, `binding`, `bound-vault`, `Open Question`
- User prompt contains Indonesian SDD variants: `pecah PRD`, `buat dev`, `spec ini`, `siapkan context buat AI dev`, `kontrak handoff`
- CWD has SDD signals: `docs/mega-sdd/`, `vaults/`, `bound-vault/`, `units/`, `binding.md`, `codebase-map.md`

**Non-triggers (do NOT mandate skill check):**
- Casual conversation without SDD vocab
- Code debugging, refactoring, or review unrelated to a vault
- General architecture discussion not anchored to a PRD/vault

## Priority order

1. **User explicit instructions** (CLAUDE.md, AGENTS.md, direct requests) — highest
2. **Mega-SDD phase rails** — override default behavior in SDD scope
3. **Default system prompt** — lowest

If user says "skip the binding step" or "no need for units," follow them. User is in control.

## The pipeline (canonical)

```
generate-intent → (scan-codebase + bind-codebase if brownfield) → generate-units → execute-bolts
```

Side lanes (run as needed, not in main chain):
- `resolve-oq` — interactive Open Question walk
- `detect-drift` — code vs vault reconciliation
- `diff-vault` — handle new PRD revision
- `orchestrate-flow` — auto-route based on CWD state

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
| Brief → vault | `generate-intent` | Not required | Architect |
| Codebase scan | `scan-codebase` | Read-only | Dev / AI |
| Validation gate | `bind-codebase` | Read-only | Dev / AI |
| Vault → units | `generate-units` | Read-only | Dev / AI |
| Unit → code | `execute-bolts` | Write | AI agent (via superpowers) |

## Skill chain enforcement

After each phase completes, mega-sdd skills explicitly hand off to the next:
- `generate-intent` → suggests `scan-codebase` (brownfield) OR `generate-units` (greenfield)
- `scan-codebase` → suggests `bind-codebase`
- `bind-codebase` → suggests `generate-units` (when no conflicts) OR `resolve-oq` (when conflicts)
- `generate-units` → suggests `execute-bolts`
- `execute-bolts` → suggests `detect-drift` (optional, periodic)

Hard gate: `bind-codebase` BLOCKS unit generation when `binding.md` has unresolved CONFLICT entries.
