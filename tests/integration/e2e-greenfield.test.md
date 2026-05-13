# E2E Greenfield Pipeline Test

Walks the full pipeline on a synthetic greenfield project. Manual run.

## Setup

```bash
mkdir -p /tmp/megasdd-e2e && cd /tmp/megasdd-e2e
git init
echo "# Test Project" > README.md
git add . && git commit -m "init"
```

## Walk

### Step 1: from-prompt → intent
```
/mega-sdd:generate-intent --from-prompt "build a simple TODO CLI in Python with add/list/done commands persisted as JSON"
```
**Expect:**
- ≤10 Q&A turns
- `docs/mega-sdd/vaults/<name>/` produced with 7 files + vault.json
- mode: greenfield

### Step 2: generate-units (skip scan + bind for greenfield)
```
/mega-sdd:generate-units docs/mega-sdd/vaults/<name>
```
**Expect:**
- `units/U-001.md`, `U-002.md`, ... produced
- Each unit has target_files, acceptance_test, depends_on
- `_index.md` with Mermaid DAG

### Step 3: execute-bolts --all
```
/mega-sdd:execute-bolts --all
```
**Expect:**
- Each unit goes through TDD (failing test → impl → passing test → commit)
- Final state: working TODO CLI with passing tests
- `bolts/U-XXX/bolt-report.md` per unit

### Step 4: detect-drift
```
/mega-sdd:detect-drift
```
**Expect:**
- Report shows 0 drift (code matches vault)

## Pass criteria

End-to-end pipeline produces working CLI from one free-text brief, with TDD discipline, no manual coding required.
