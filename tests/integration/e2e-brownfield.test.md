# E2E Brownfield Pipeline Test

Walks the full pipeline on a real existing repo. Manual run.

## Setup

Use any small existing repo with:
- `.git` initialized
- A `package.json` or `composer.json` (anything that signals language)
- At least 1 existing route/endpoint
- At least 1 existing data model

For reproducibility:
```bash
cd /tmp
git clone --depth=1 https://github.com/expressjs/express.git megasdd-brownfield-test
cd megasdd-brownfield-test
```

## Walk

### Step 1: prepare PRD that mostly matches code

Create `prd.md` describing a small feature that mostly aligns with existing code patterns. Include 2-3 claims that DO match (endpoint, naming) and 1-2 claims that DON'T (e.g., reference a non-existent middleware).

### Step 2: generate-intent
```
/mega-sdd:generate-intent ./prd.md
```
**Expect:**
- vault produced under `docs/mega-sdd/vaults/<name>/`
- mode: existing (brownfield auto-detected from .git presence)

### Step 3: scan-codebase
```
/mega-sdd:scan-codebase
```
**Expect:**
- `codebase-map.md` produced
- Sections populated: top-level structure, public interfaces, routes, conventions
- Existing routes from express app cataloged

### Step 4: bind-codebase (expect BLOCKING)
```
/mega-sdd:bind-codebase docs/mega-sdd/vaults/<name>
```
**Expect:**
- `binding.md` produced
- At least 1 CONFLICT entry (the mismatched claims)
- `bound-vault/` NOT produced (pipeline BLOCKED)
- Hand-off message points to `resolve-oq --binding`

### Step 5: resolve-oq --binding (interactive)
```
/mega-sdd:resolve-oq --binding ./binding.md
```
**Expect:**
- Interactive walker shows each CONFLICT
- User chooses resolution per conflict (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT)
- Vault updated with resolutions
- binding.md updated

### Step 6: bind-codebase (re-run, expect clean)
```
/mega-sdd:bind-codebase docs/mega-sdd/vaults/<name>
```
**Expect:**
- `bound-vault/` produced now (conflicts resolved)
- Hand-off message points to `generate-units`

### Step 7: generate-units
```
/mega-sdd:generate-units docs/mega-sdd/vaults/<name>-bound
```
**Expect:**
- `units/U-*.md` produced
- Each unit has target_files citing real existing express files (e.g., `lib/router.js`)
- binding_refs populated with resolved CONFLICT IDs

### Step 8: execute-bolts (small unit first)
```
/mega-sdd:execute-bolts U-001
```
**Expect:**
- TDD cycle: failing test → impl → passing test → commit
- Commit touches only files in U-001's target_files
- bolt-report.md written

### Step 9: detect-drift
```
/mega-sdd:detect-drift
```
**Expect:**
- DRIFT-REPORT.md produced
- Reports the new bolt's changes vs vault — should be consistent (or surface meaningful drift)

## Pass criteria

End-to-end brownfield pipeline:
- Architect/dev separation honored (no code touched until execute-bolts)
- Binding gate BLOCKS on real conflict
- Resolution loop works (resolve-oq → re-bind → unblocked)
- Units cite real existing code via target_files
- Bolt produces atomic commit honoring whitelist
- Drift detected & reported

## Cleanup

```bash
cd /tmp && rm -rf megasdd-brownfield-test
```
