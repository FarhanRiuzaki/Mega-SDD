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

## Pass criteria

All triggers fire, pre-flight gates behave, whitelist + retry/halt protocol works.
