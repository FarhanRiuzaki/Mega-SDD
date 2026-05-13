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

## Pass criteria

All triggers fire, pre-flight gates behave, whitelist + retry/halt protocol works.
