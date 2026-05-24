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

## Deep-chain mode (v1.3+, Iter 4)

### DC1: `--deep` lifts the 3-skill cap
- **Setup:** legacy codebase + no PRD + no vault; user mentions rebuild intent
- **Prompt:** `/mega-sdd:orchestrate-flow --deep`
- **Expect:** chain proposes ALL 6 phases (extract-intelligence → generate-intent --kb → scan-codebase → bind-codebase → generate-units → execute-bolts) in single upfront confirmation

### DC2: Default mode (no `--deep`) still cap-3
- **Setup:** same as DC1
- **Prompt:** `/mega-sdd:orchestrate-flow` (no --deep)
- **Expect:** chain proposes 3 phases (extract → generate-intent → scan-codebase); user re-invokes after for next chain

### DC3: Auto-continue via handoff YAML
- **Setup:** `--deep` mode chain proposed and approved; first skill (extract-intelligence) completes with `status: completed` handoff
- **Expect:** orchestrator parses handoff YAML; auto-invokes `next_action.suggested_skill` with `next_action.suggested_args`; user does NOT need to type next command

### DC4: Progress indication
- **Setup:** `--deep` chain running, currently on phase 3 of 5
- **Expect:** chat shows `▶ Phase 3 of 5: invoking bind-codebase (--auto)` before invocation and `✓ Phase 3 of 5: bind-codebase → status: completed, items: 87, blocked: 0` after

### DC5: Pause on `status: paused`
- **Setup:** `--deep` chain; generate-intent emits `status: paused` because P1 business OQs were produced
- **Expect:** chain STOPS after generate-intent; chat shows paused-item summary; orchestrator does NOT auto-invoke next phase; awaits user `--resume` after OQs triaged

### DC6: Halt on `status: halted`
- **Setup:** `--deep` chain; bind-codebase emits `status: halted` with `bind_conflict` blocker
- **Expect:** chain STOPS; blocker YAML surfaced verbatim; user resolves via resolve-oq

## Resume mechanics (v1.3+, Iter 4)

### RES1: --resume re-enters paused chain
- **Setup:** previous `--deep` run paused after generate-intent (P1 business OQs); user resolved OQs via `/mega-sdd:resolve-oq`
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:**
  - NO upfront confirmation (chain was approved earlier)
  - CWD inspection rebuilds state: vault.json exists, codebase-map absent
  - Chain resumes from `scan-codebase` (cursor advances past `generate-intent` because artifact exists)
  - Runs forward to pipeline-end

### RES2: --resume halts again if blocker unresolved
- **Setup:** previous run halted on bind_conflict; user did NOT resolve
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:** chain re-runs bind-codebase; same halt fires; user gets identical blocker (correct safety behavior)

### RES3: --from override skips earlier completed phases
- **Setup:** all 6 phases completed; user wants to re-run only `generate-units` + `execute-bolts`
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --from=generate-units`
- **Expect:** chain skips first 4 phases regardless of artifact presence; runs generate-units forward

## Pass criteria (Iter 4)

All deep-chain rules (DC1-DC6) follow `references/routing-rules.md` §Deep-chain decision matrix + `references/handoff-contract.md` §Orchestrator consumption logic. All resume mechanics (RES1-RES3) follow §Resume mechanics. Halt-protocol behavior unchanged in `--deep` mode vs cap-3 mode. No persisted state file.

---

## Iter 32 — End-to-end starterkit_context propagation case (v2.5.1+)

### OF-SK1 — Full --auto pipeline propagates starterkit_context through all 5 phases

**Setup:**
- Laravel starterkit at `<project_root>` (Sanctum + Spatie/permission + Alpine + Tailwind + SweetAlert2)
- PRD at `<project_root>/prd.md` describing "User management feature"
- No prior vault, no prior codebase-map.md, no prior starterkit-context.yaml

**Trigger:** `/mega-sdd:auto`

**Expected pipeline:**
1. orchestrate-flow detects: PRD + starterkit + no vault → starterkit-first chain
2. Phase 1: `mega-sdd:scan-codebase` invoked
   - Deep-scan stage runs (4 subagents)
   - `.mega-sdd/codebase/starterkit-context.yaml` written
   - Handoff: `starterkit_context: { reused: false, framework: laravel, auth_lib: sanctum, ... }`
3. orchestrate-flow propagates handoff `starterkit_context:` into `metadata.starterkit_context`
4. Phase 2: `mega-sdd:generate-intent --scan=<codebase-map>` invoked
   - Receives `metadata.starterkit_context` in dispatch context
   - Vault generated under `.mega-sdd/vaults/<auto-generated-id>/`
   - Handoff: `starterkit_context:` passthrough (unchanged from scan-codebase)
5. Phase 3: `mega-sdd:bind-codebase` invoked
   - Handoff: `starterkit_context:` passthrough
6. Phase 4: `mega-sdd:generate-units` invoked
   - Step 7.7 fires for all generated units
   - Units that touch UI/auth/RBAC/libs gain starterkit anchors + Hard Rules
   - Handoff: `starterkit_context:` + 2 new metrics (`units_with_starterkit_anchors: <N>`, `units_with_starterkit_rules: <N>`)
7. Phase 5: `mega-sdd:execute-bolts --all --auto` invoked
   - Per-unit T2.3 slice injection for units with non-empty starterkit_relevance
   - Bolts produce code matching starterkit patterns (extends layouts.app, uses SweetAlert2, Spatie middleware)
   - Handoff: `starterkit_context:` + 2 new metrics (`bolts_used_starterkit_slice: <N>`, `slice_avg_size_kb: <X.X>`)

**Verification at each handoff boundary:**
- starterkit_context.framework field is `laravel` in ALL 5 handoffs
- starterkit_context.auth_lib field is `sanctum` in ALL 5 handoffs
- Final execute-bolts handoff metrics show non-zero bolts_used_starterkit_slice
- Final bolt-report.md files (per unit) cite `starterkit-context.yaml` in their context section
