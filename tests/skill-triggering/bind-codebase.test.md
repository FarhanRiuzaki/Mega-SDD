# bind-codebase Trigger + Blocking Test

## Trigger cases

### B1: Explicit
- **Prompt:** `/mega-sdd:bind-codebase ./vaults/v1`
- **Expect:** Skill invocation; reads `./codebase-map.md` by default

### B2: Auto-route from orchestrate-flow (brownfield)
- **Setup:** CWD has vault + codebase-map, no bound-vault
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes bind-codebase next

## Behavior — clean binding

### CB1: All CONFIRMED
- **Setup:** vault with claims that all match codebase-map
- **Expect:**
  - `binding.md` written with `conflict: 0`
  - `bound-vault/` produced
  - Hand-off message points to `generate-units`

## Behavior — blocking

### BL1: One CONFLICT
- **Setup:** vault has "API uses Bearer auth", codebase-map says "session cookies"
- **Expect:**
  - `binding.md` written with `conflict: 1`, table shows the conflict
  - `bound-vault/` NOT produced (does not exist)
  - Blocker YAML emitted
  - Hand-off message points to `resolve-oq --binding`

### BL2: All OQ, --strict
- **Setup:** vault references "user.deleted_at field", codebase-map data model doesn't mention it (treated as OQ); user invokes with `--strict`
- **Expect:**
  - `binding.md` written with `oq: 1, conflict: 0`
  - `bound-vault/` NOT produced (because --strict)
  - Hand-off to resolve-oq

### BL3: All OQ, default mode
- **Same setup as BL2** but no `--strict`
- **Expect:**
  - `bound-vault/` produced (default mode treats OQ as non-blocking)
  - OQ propagated to bound-vault for unit grounding

## Halt cases

### H1: Missing codebase-map
- **Setup:** no codebase-map.md exists
- **Expect:** halt with instruction to run scan-codebase

### H2: Vault missing vault.json
- **Setup:** malformed vault directory
- **Expect:** halt with vault repair instruction

## Pass criteria

All triggers fire. Blocking gate behaves per binding-contract.md. No auto-resolution under any condition.
