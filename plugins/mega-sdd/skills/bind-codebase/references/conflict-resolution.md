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
KEEP_CODE / SPLIT (vault edited) → re-run /mega-sdd:bind-codebase <vault> <codebase-map>
   │        → conflicts = 0: bound-vault produced; pipeline unblocks
   │        → conflicts > 0: repeat
   │
KEEP_VAULT / DEFER (vault + code unchanged) → NO re-bind (it would re-raise the
   same CONFLICT — bind re-derives verdicts from the unchanged contradiction).
   The resolved-marked binding.md passes the handoff validator → proceed to
   /mega-sdd:generate-units; bound/ arrives via a re-bind AFTER the code change lands.
```

## Resolution actions (per conflict)

### a. KEEP_VAULT — vault is correct, code must change
- Action: vault unchanged; resolve-oq marks the CONFLICT-N detail heading `✅ RESOLVED (KEEP_VAULT — code update pending)` (the structural marker the gate reads; per `resolve-oq/references/binding-mode.md` write-back grammar)
- Effect: the code-update obligation stays traceable via the CONFLICT-N reference — the affected units MUST carry it in `binding_refs` (the handoff validator's propagation drop enforces the citation), and their unit bodies cite the KEEP_VAULT resolution so the bolt implements toward the VAULT's claim, not current code
- Use when: architect decision overrides current implementation (refactor/migration)
- NOTE: a re-bind BEFORE the code change re-raises this CONFLICT (bind re-derives from the unchanged contradiction; prior calls surface from decisions.md as suggestions only) — proceed to generate-units instead; re-bind after the code lands

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
- Resolutions written back to binding.md (structural ✅ RESOLVED markers), binding.json (`resolution:` field), vault.json changelog, and decisions.md (durable across re-binds)
- After resolution loop: hand-off is action-mix dependent (KEEP_CODE/SPLIT → re-bind; KEEP_VAULT/DEFER-only → generate-units) per `resolve-oq/references/binding-mode.md` Step 5
