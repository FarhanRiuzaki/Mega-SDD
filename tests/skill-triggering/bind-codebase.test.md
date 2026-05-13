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

### B6: Deferred-OQ auto-resolution (v1.1+)
- **Setup:** vault has OQ-X with `status: deferred, defer_to: binding`, AND codebase-map.md has an exact unambiguous match for the entity/endpoint/file referenced in OQ-X.text
- **Run:** `/mega-sdd:bind-codebase ./vault`
- **Expect:**
  - `binding.md` has a "## Auto-Resolved Deferred OQs" section listing OQ-X with evidence citation
  - vault.json: OQ-X is now `status: resolved`, has `resolved_at` and `resolution` (citing evidence)
  - aggregate counts: OQ-X is included in `confirmed`, not in `oq`

### B7: Deferred-OQ propagation when no match
- **Setup:** vault has OQ-Y with `status: deferred, defer_to: binding`, AND codebase-map.md has NO evidence for it
- **Run:** `/mega-sdd:bind-codebase ./vault`
- **Expect:**
  - `binding.md` has "## Open Questions" section with OQ-Y as a row
  - vault.json: OQ-Y still `status: deferred` (unchanged)
  - Hand-off message suggests `/mega-sdd:resolve-oq --binding`

### B8: Mixed deferred + CONFLICT scenario
- **Setup:** vault has 1 OQ deferred (auto-resolves) + 1 OQ deferred (propagates) + 1 vault claim that conflicts with code
- **Expect:**
  - `bound-vault/` NOT produced (CONFLICT blocks)
  - binding.md has all three sections: Auto-Resolved Deferred OQs (1), Open Questions (1), Conflicts (1, BLOCKING)
  - Hand-off points to `resolve-oq --binding`

## Pass criteria

All triggers fire. Blocking gate behaves per binding-contract.md. Deferred-OQ auto-resolution (B6) and propagation (B7) follow bind-codebase §2.5. No unguarded auto-resolution under any condition.
