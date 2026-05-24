# execute-bolts Trigger Test

## Trigger cases

### E1: Explicit unit ID
- **Prompt:** `/mega-sdd:execute-bolts U-001`
- **Expect:** Skill invoked

### E2: --all
- **Prompt:** `/mega-sdd:execute-bolts --all`
- **Expect:** Skill invoked with topo-sort over all units

### E3: Indonesian
- **Prompt:** `jalanin unit semua`
- **Expect:** Skill invoked

## Pre-flight checks

### P1: No superpowers, no vendored
- **Setup:** delete `_vendored/`; uninstall superpowers
- **Expect:** halt with install instructions

### P2: Vendored present, no real install
- **Setup:** `_vendored/` populated; no superpowers plugin
- **Expect:** uses vendored skills

### P3: Both present
- **Setup:** both available
- **Expect:** uses real install (vendored dormant)

## Behavior

### BH1: target_files whitelist enforced
- **Setup:** unit has `target_files: [src/foo.ts]`; implementation step tries to edit `src/bar.ts`
- **Expect:** halt before write

### BH2: Test failure → retry → halt
- **Setup:** unit with always-failing test
- **Expect:** 3 retries, then halt + bolt-report with failure details

### BH3: --dry-run does not commit
- **Setup:** any valid unit
- **Prompt:** `/mega-sdd:execute-bolts U-001 --dry-run`
- **Expect:** procedure walks; no `git commit` calls; bolt-report still written marked status=preview

### BH4 (v1.1+): --per-squad requires multi-squad config
- **Setup:** vault has no `_meta/squads.yaml`
- **Prompt:** `/mega-sdd:execute-bolts --per-squad`
- **Expect:** halt with informative message; suggest `--all` or `generate-intent` to add squad config

### BH5 (v1.1+): --per-squad fans out subagents
- **Setup:** vault with 3 declared squads, units assigned across squads (e.g., 4 BE + 3 FE + 2 integrations)
- **Prompt:** `/mega-sdd:execute-bolts --per-squad`
- **Expect:**
  - 3 Agent() dispatches with run_in_background: true
  - Each subagent prompted with its squad ID and filter instructions per references/squad-subagent.md
  - Parent consolidates results into per-squad table after all complete

### BH6 (v1.1+): --squad=<id> filters and runs single squad
- **Setup:** vault with 3 squads; user runs on their FE laptop
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** only units where `squad: squad-fe-web` execute; BE and integrations units skipped; bolts written only for FE units

### BH7 (v1.1+): --squad=<id> halts on draft consumed interface
- **Setup:** FE unit U-FE-002 declares `consumes_interfaces: [api-x]`; `interfaces/api-x.md` has `status: draft`
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** halt with `cross_squad_interface_draft` blocker; next_action names producer squad

### BH8 (v1.1+): --per-squad combined with --parallel
- **Setup:** vault with 2 squads; each has internally independent units
- **Prompt:** `/mega-sdd:execute-bolts --per-squad --parallel`
- **Expect:** 2 squad-level subagents, each internally using subagent-driven-development for parallel unit dispatch; no resource collision (different working sets)

## Hard Rule pre-flight + post-flight (v1.2+, Iter 3)

### HR1: Pre-flight snapshot persisted
- **Setup:** unit U-001 has `## Hard rules` with 2 rules: `DO NOT modify src/Models/User.php` + `function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>`
- **Expect:**
  - Pre-flight runs before bolt execution
  - `<vault>/bolts/U-001/preflight.json` exists with sha256 of User.php + signature snapshot of authenticateUser
  - Bolt proceeds to executing-plans

### HR2: Hard rule violated — DO_NOT_MODIFY
- **Setup:** unit U-002 has `DO NOT modify src/Models/User.php`; bolt's implementation steps modify User.php
- **Expect:**
  - Pre-flight snapshot captured (sha256 = X)
  - executing-plans runs, modifies User.php
  - acceptance tests pass
  - Post-flight: new sha256 ≠ snapshot
  - HALT with `hard_rule_violated` blocker YAML
  - Code changes remain in working tree (NOT committed)
  - bolt-report.md has `status: halted_postflight` with violation list

### HR3: Hard rule violated — DO_NOT_ADD_DEPS
- **Setup:** unit U-003 has `DO NOT add new package.json dependencies`; bolt adds a new dependency to package.json
- **Expect:** post-flight diff detects new top-level dep entry; HALT with `hard_rule_violated`; violation evidence quotes added entry

### HR4: Hard rule violated — SIGNATURE_RULE
- **Setup:** unit U-004 has `function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>`; bolt modifies the function to add a `twoFactor?: string` parameter
- **Expect:** signature re-extract shows extra param; HALT with violation evidence quoting old vs new signature

### HR5: Hard rule violated — FILE_PRESENCE_RULE
- **Setup:** unit U-005 has `file src/Models/AuditLog.php MUST exist after bolt`; bolt forgets to create the file (or deletes it)
- **Expect:** post-flight probe shows file missing; HALT with violation

### HR6: Hard rule violated — NAMING_RULE
- **Setup:** unit U-006 has `file:src/api/*.ts MUST follow kebab-case naming`; bolt creates `src/api/auditLog.ts` (camelCase)
- **Expect:** post-flight scans new files matching glob; auditLog.ts fails kebab-case regex; HALT with violation listing the file

### HR7: Hard rule unparseable → halt at pre-flight
- **Setup:** unit U-007 has `## Hard rules` with an unrecognized rule: `forbid users from x`
- **Expect:** pre-flight halts BEFORE bolt execution with `hard_rule_unparseable` listing the offending line + the 5 expected grammar productions

### HR8: Hard rule unanchored — function not in codebase-map
- **Setup:** unit U-008 has `function doesNotExist MUST preserve signature: () => void`; codebase-map has no symbol with that name
- **Expect:** pre-flight halts with `hard_rule_unanchored`; rule references a symbol that can't be snapshotted

### HR9: Verify-unit special path
- **Setup:** unit U-009 with `task_type: verify`, empty target_files, Anchors cite existing implementation, acceptance_test runs existing test suite
- **Expect:**
  - Pre-flight passes (no Hard rules required for verify; if present, parsed normally)
  - Skip executing-plans (no code to write)
  - Run acceptance tests
  - Skip post-flight Hard rule scan
  - Commit only bolt-report.md (or skip commit on `--no-empty-commits`)

### HR10: All clean — bolt proceeds normally
- **Setup:** unit U-010 has Hard rules; bolt's implementation respects all rules
- **Expect:**
  - Pre-flight snapshot taken
  - executing-plans runs
  - acceptance tests pass
  - Post-flight: all rules clean (snapshot matches / new files conform / file presence verified)
  - Commit proceeds
  - postflight.json shows all rules `status: passed`

### HR11: Multiple rules, one violated → halt
- **Setup:** unit U-011 has 3 Hard rules; bolt violates one
- **Expect:** post-flight detects 1 violation; HALT with `hard_rule_violated` listing all 3 rules in evidence (passed + failed); bolt-report.md captures per-rule status

## Pass criteria

All triggers fire, pre-flight gates behave, whitelist + retry/halt protocol works. Hard Rule pre/post-flight (HR1-HR11) follows §4 (pre-flight) + §Post-flight Hard Rule validation. Violations NEVER silent — always halt before commit with code changes preserved in working tree for user review.

---

## Iter 32 — Starterkit slice injection cases (v2.7.0+)

### EB-SK1 — T2.3 slice injection: UI-touching unit gets ui_ux + libs slices

**Setup:**
- Unit U-007 has `target_files: ["resources/views/users/index.blade.php", "app/Http/Controllers/UserController.php"]`
- Unit frontmatter: `starterkit_relevance: [ui_ux, libs]`
- `.mega-sdd/codebase/starterkit-context.yaml` exists (per GU-SK1 setup)

**Trigger:** `/mega-sdd:execute-bolts U-007`

**Expected:**
- Step 4.5.b-starterkit (Read): starterkit-context.yaml loaded; `unit.starterkit_relevance` read as `[ui_ux, libs]`
- Step 4.5.b-starterkit (Build slice): slice built with:
  - `slice.ui_ux` populated (layout_extends, notification_lib, idioms)
  - `slice.libs` filtered to libs whose usage_hint overlaps target_files
  - `slice.auth` ABSENT (not in starterkit_relevance)
  - `slice.rbac` ABSENT
- Step 4.5.b-starterkit (Inject): bolt-dispatch-prompt T2.3 section populated with:
  - "UI/UX: extends=layouts.app, notification=sweetalert2, idioms=[use document.addEventListener...; responsive mobile-first...]"
  - "Libs in scope: sweetalert2@11.x (used in: resources/js/app.js, ...)"
  - NO "Auth:" line
  - NO "RBAC:" line
- T2.3 slice size ≤2KB (verify via byte count of injected section)
- Bolt subagent dispatched with prompt containing T2.3 section
- Bolt's generated code (verified via post-flight) uses `@extends('layouts.app')` and `Swal.fire(...)` patterns (matches starterkit)

### EB-SK2 — Slice exceeds 2KB budget → truncation order applies → halt if still over

**Setup:**
- Unit U-008 with `starterkit_relevance: [ui_ux, libs]`
- `.mega-sdd/codebase/starterkit-context.yaml` has:
  - ui_ux.idioms: 20 entries (large)
  - libs[]: 100 entries, 60 of which overlap U-008's target_files

**Trigger:** `/mega-sdd:execute-bolts U-008`

**Expected:**
- Step 4.5.b-starterkit (Build slice): initial slice exceeds 2KB
- Truncation step 1: libs[] truncated to top 10 by relevance score (overlap count)
- If still >2KB: idioms[] truncated to top 3
- IF still >2KB: halt `dispatch_prompt_too_large` (existing Iter 30 halt) emitted; bolt NOT dispatched; chain stops
- IF ≤2KB after truncation: bolt dispatched with truncated slice; T2.3 section ≤2KB
- Truncation event logged in execute-bolts metrics: `slice_truncated_count: 1`, `slice_truncation_levels: [libs, idioms]`
