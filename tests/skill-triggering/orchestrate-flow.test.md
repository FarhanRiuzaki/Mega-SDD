# orchestrate-flow Routing Test

## Trigger cases

### OF1: Explicit
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Inspect + propose

### OF2: Natural
- **Prompt:** `what's next?`
- **Setup:** any SDD signal in CWD
- **Expect:** Skill invoked

## Routing scenarios

### R1: Empty CWD, free-text prompt
- **State:** no PRD, no vault, no git
- **Expect:** Propose `generate-intent --from-prompt`

### R2: PRD present, no vault
- **State:** `prd.md` in CWD
- **Expect:** Propose `generate-intent ./prd.md`

### R3: Vault greenfield, no units
- **State:** vault.json mode=greenfield, no units/
- **Expect:** Propose `generate-units` (skip scan/bind)

### R4: Vault brownfield, no codebase-map
- **State:** vault.json mode=existing, .git present, no codebase-map.md
- **Expect:** Propose chain `scan-codebase → bind-codebase → generate-units` (3-cap reached, no execute-bolts in same chain)

### R5: Bound-vault clean, no units
- **State:** bound-vault exists, binding.md conflict=0
- **Expect:** Propose `generate-units`

### R6: Units exist, no bolts
- **State:** units/U-001.md etc., no bolts/
- **Expect:** Propose `execute-bolts --all`

### R7: P0 OQs present
- **State:** any state, vault has unresolved P0 OQs
- **Expect:** Propose `resolve-oq` first (overrides other proposals)

### R8: PRD newer than vault
- **State:** `prd.md` mtime > vault.json mtime
- **Expect:** Propose `diff-vault ./prd.md` first

### R9: Mode mismatch
- **State:** vault says greenfield, CWD has .git + package.json
- **Expect:** Halt with mode-migration prompt

## Pre-flight

### PF1: Chain includes execute-bolts, no superpowers, no vendored
- **Expect:** Halt with install offer; do NOT propose chain

### PF2: Chain includes execute-bolts, vendored ready
- **Expect:** Chain proposed; pre-flight passes

## Pass criteria

All routing rules per routing-rules.md fire deterministically. Pre-flight gates correctly.

## Multi-squad routing (v1.1+)

### MS1: CWD inspection reports squad count
- **Setup:** vault has `_meta/squads.yaml` with 3 squads
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot includes `squad_count: 3`

### MS2: Multi-squad + pending units → suggest --per-squad
- **Setup:** vault with 3 squads, units exist, no bolts yet
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposed chain contains `execute-bolts --per-squad`

### MS3: Single-squad (squad_count=1) → existing behavior
- **Setup:** vault has `_meta/squads.yaml` with exactly 1 squad declared
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposes `execute-bolts --all` (NOT `--per-squad`)

### MS4: No squads.yaml → existing behavior
- **Setup:** vault has no `_meta/squads.yaml`
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot `squad_count: 0`; proposes `execute-bolts --all`
