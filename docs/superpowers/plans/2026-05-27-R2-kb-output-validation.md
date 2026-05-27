# R2: KB Output Validation Hook — `validate-kb-output.sh`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `validate-kb-output.sh` script that validates knowledge-base output completeness (11-section template, frontmatter field consistency, dependency graph validity, confidence marker count accuracy). Hook it into PostToolUse Write on `.mega-sdd/knowledge-base/*.md` files.

**Architecture:** New validator script (`scripts/validate-kb-output.sh`) following the existing validate-*.sh pattern. Writes `.mega-sdd/.kb-output-state.json`. Hook registration via PostToolUse Write matcher in `post-tool-use` hook (extends existing Write|Edit branch).

**Tech Stack:** Bash + Python (matches existing validator pattern).

**Enforcement Surface:** [HOOK-VALIDATE] — PostToolUse Write on KB files → validator → state file. Generate-intent `--kb` preflight reads state to warn on FAIL.

**HONESTY distinction:** Logic proven on real data (TF Import KB). Hook-firing in production DEFERRED to clean-project test.

---

### Task 1: Create `validate-kb-output.sh` (walking-skeleton)

**Files:**
- Create: `plugins/mega-sdd/scripts/validate-kb-output.sh`

Walking-skeleton scope: validate frontmatter `verified_count` matches body `[VERIFIED]` grep count for a single domain file passed via `--file-path`.

- [ ] **Step 1: Write the validator script**

Inputs: `--cwd=<project>` `--file-path=<kb-domain-file.md>` `[--quiet]`
Outputs: JSON to stdout; writes `<cwd>/.mega-sdd/.kb-output-state.json`
Exit: 0=PASS, 1=FAIL, 2=error

Validation checks:
1. `frontmatter_present` — file has YAML frontmatter (`---` delimited)
2. `verified_count_match` — frontmatter `verified_count` == body `[VERIFIED]` occurrences
3. `inferred_count_match` — frontmatter `inferred_count` == body `[INFERRED]` occurrences
4. `open_count_match` — frontmatter `open_count` == body `[OPEN]` occurrences
5. `locked_count_match` — frontmatter `locked_count` == body `[LOCKED]` occurrences
6. `eleven_sections_present` — all 11 required section headers exist (§1 Purpose through §11 Source Files)
7. `depends_on_valid` — each `depends_on` entry resolves to an existing file in the same KB directory

- [ ] **Step 2: Make executable and proof on TF Import KB**

Run:
```bash
chmod +x plugins/mega-sdd/scripts/validate-kb-output.sh
# Pick a real domain file from TF Import KB:
bash plugins/mega-sdd/scripts/validate-kb-output.sh \
  --cwd=/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import \
  --file-path=/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/tradefinance-import/.mega-sdd/knowledge-base/10-domains/<first-domain-file>.md
```

Expected: JSON report with per-check PASS/FAIL + state file written.

- [ ] **Step 3: Commit**

---

### Task 2: Wire into PostToolUse hook + integrate with run-analyze.sh

**Files:**
- Modify: `plugins/mega-sdd/hooks/post-tool-use` (add KB path matcher in Write|Edit branch)
- Modify: `plugins/mega-sdd/scripts/run-analyze.sh` (add KB validator to registry)

- [ ] **Step 1: Add KB validator to PostToolUse Write|Edit branch**

In the `Write|Edit` case of post-tool-use, add a new validator call for KB domain files:
```bash
case "$FILE_PATH" in
  *.mega-sdd/knowledge-base/10-domains/*.md|*.mega-sdd/knowledge-base/20-workflows/*.md|...)
    VALIDATOR_KB="${SCRIPT_DIR}/../scripts/validate-kb-output.sh"
    run_validator_and_emit "$VALIDATOR_KB" "${CWD}/.mega-sdd/.kb-output-state.json" "PostToolUse-Write-validate-kb-output"
    ;;
esac
```

- [ ] **Step 2: Add KB validator to run-analyze.sh registry**

Add to the VALIDATORS array and the per-file invocation loop.

- [ ] **Step 3: Proof — run analyze again on TF Import to see KB results**

---

### Task 3: HONESTY boundary

**Logic-proven (this iteration):**
- validate-kb-output.sh runs on real TF Import KB domain files
- Frontmatter count checks fire and detect mismatches
- Section presence checks fire
- State file written correctly

**Deferred (NOT claimed):**
- Hook-firing via PostToolUse Write in production session
- Generate-intent --kb preflight check integration
- Plugin cache rebuild + fresh session verification
