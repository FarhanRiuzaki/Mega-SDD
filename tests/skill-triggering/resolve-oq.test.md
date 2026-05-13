# resolve-oq Trigger + Behavior Test

Manual-run fixture for the `resolve-oq` skill.

## Trigger cases

### R1: Explicit standalone (intent mode)
- **Prompt:** `/mega-sdd:resolve-oq`
- **Expect:** Skill invocation; walks OQs from vault in CWD (auto-detect vault dir)

### R2: Explicit with vault path
- **Prompt:** `/mega-sdd:resolve-oq ./docs/mega-sdd/vaults/my-app`
- **Expect:** Walks OQs from the specified vault

### R3: Binding mode
- **Prompt:** `/mega-sdd:resolve-oq --binding ./vaults/v1-bound/binding.md`
- **Expect:** Walks CONFLICT + Open Questions entries from binding.md

### R4: Natural English
- **Prompt:** `resolve open questions`
- **Expect:** Skill invocation

### R5: Natural Indonesian
- **Prompt:** `jawab OQ list`
- **Expect:** Skill invocation

### R6: Auto-route from orchestrate-flow (intent gate)
- **Setup:** vault has 2 P1 OQs, status=pending
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes resolve-oq first (before scan/bind/units)

### R7: Auto-route hidden when only deferred OQs
- **Setup:** vault has 2 P1 OQs, all status=deferred, mode=existing, .git present
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes scan-codebase next (deferred OQs do NOT gate the chain)

## Behavior — 4-action menu

### B1: All 4 options offered (brownfield)
- **Setup:** vault.mode=existing AND .git present
- **Expect:** Per OQ, options [A] Answer / [B] Defer / [C] Out-of-scope / [D] Skip shown

### B2: Defer option hidden (greenfield)
- **Setup:** vault.mode=greenfield
- **Expect:** Per OQ, only options [A] / [C] / [D] shown

### B3: Defer option hidden (no repo signals)
- **Setup:** vault.mode=existing but CWD has no .git/package.json/etc.
- **Expect:** Only options [A] / [C] / [D] shown; skill warns user about the mode/CWD mismatch

### B4: State transitions per action
- **[A] Answer** → OQ becomes `status: resolved`, `resolved_at: <iso>`, `resolution: <text>`
- **[B] Defer to binding** → `status: deferred`, `defer_to: binding`, `deferred_at: <iso>`, optional `deferred_reason`
- **[C] Out of scope** → `status: out-of-scope`, `out_of_scope_reason: <text>`
- **[D] Skip** → no field change; OQ remains pending

### B5: Vault.json changelog appended
- **After any action:** vault.json gets a new changelog entry: `{ "event": "oq-<action>", "id": "OQ-XXX", "at": "<iso>", "action": "A|B|C|D" }`

## Behavior — --binding mode

### BM1: Walks conflicts
- **Setup:** binding.md has 2 CONFLICT rows
- **Expect:** Skill prompts per conflict with [K] KEEP_VAULT / [C] KEEP_CODE / [D] DEFER / [S] SPLIT

### BM2: Walks propagated deferred OQs
- **Setup:** binding.md has 1 CONFLICT + 2 Open Questions rows
- **Expect:** Skill walks CONFLICTs first, then OQs (with 4-action menu, Option B hidden because nested deferral not supported)

### BM3: Resolutions persist
- **After resolving 1 conflict + 1 OQ:** binding.md updated, vault.json changelog entry added

### BM4: Hand-off after binding mode
- **After loop:** suggests `/mega-sdd:bind-codebase` re-run (since conflicts now resolved)

## Pass criteria

All R1-R7 invoke skill correctly. 4-action menu obeys brownfield/greenfield/repo-signal conditions. State transitions match B4. Binding mode walks conflicts and OQs per BM1-BM3.
