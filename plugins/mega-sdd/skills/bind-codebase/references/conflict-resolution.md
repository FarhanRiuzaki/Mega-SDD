# Conflict Resolution Guide

When `bind-codebase` produces CONFLICT entries, downstream pipeline is blocked. This document specifies how the user resolves conflicts and how `bind-codebase` interacts with `resolve-oq` for the flow.

## Flow

```
bind-codebase detects N conflicts
   │
   ▼
binding.md written with CONFLICT table
   │
   ▼
User chooses resolution path:
   │
   ├─ Path 1: /mega-sdd:resolve-oq --binding ./binding.md
   │            (interactive walker prompts per conflict)
   │            For each conflict, ONE of:
   │             a. KEEP_VAULT — update code (out of band)
   │             b. KEEP_CODE  — update vault to match code
   │             c. DEFER      — convert CONFLICT → OQ (downgrade)
   │             d. SPLIT      — vault claim splits into two units
   │
   └─ Path 2: Manual vault edit + re-run bind-codebase
   │
   ▼
Re-run /mega-sdd:bind-codebase <vault> <codebase-map>
   │
   ▼
If conflicts = 0: bound-vault produced; pipeline unblocks
If conflicts > 0: repeat
```

## Resolution actions (per conflict)

### a. KEEP_VAULT — vault is correct, code must change
- Action: vault unchanged; binding marks claim as `CONFIRMED_PENDING_CODE_UPDATE`
- Effect: generated units include "update code to match" task as a prerequisite
- Use when: architect decision overrides current implementation (refactor/migration)

### b. KEEP_CODE — code is correct, vault must update
- Action: bind-codebase prompts user to confirm; vault is patched in place; resolve-oq logs the patch in vault.json changelog
- Effect: vault now matches code; CONFIRMED on next bind
- Use when: vault claim was made without code context; code reality is the truth

### c. DEFER — neither side wins yet
- Action: CONFLICT → OQ; binding records both options for later
- Effect: bound-vault produced (since CONFLICTs cleared) but OQ propagates to unit grounding
- Use when: decision genuinely cannot be made right now; needs stakeholder

### d. SPLIT — vault claim was too coarse
- Action: vault claim is broken into 2+ claims, each individually bindable
- Effect: re-bind produces verdicts per sub-claim
- Use when: vault said "users have auth" but code has 2 auth flows (admin + member)

## Anti-pattern: silent skip

Never auto-resolve. `bind-codebase` MUST NOT silently downgrade CONFLICT to OQ or auto-patch vault without user choice. The blocking gate exists to force human-in-the-loop at the architect/dev boundary.

## Resolve-oq integration

`/mega-sdd:resolve-oq --binding <path>` switches resolve-oq into binding mode:
- Items walked: CONFLICT entries from binding.md (in addition to/before regular OQs)
- Each item shows: vault claim + codebase evidence + action menu (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT)
- Resolutions written back to binding.md AND vault.json changelog
- After resolution loop: prompt user to re-run `bind-codebase`
