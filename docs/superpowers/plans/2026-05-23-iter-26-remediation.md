# Iter 26 Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the 5 highest-leverage gaps surfaced by the v3.17.0 verification audit — fix the emit-agents-md output template, complete the 3 P0 partials from Iter 25, sweep stale README version metadata, refresh `commands/orchestrate-flow.md`, and close P1-9 by adding PBT/replay/convergence fields to `agents-md-schema.md`.

**Architecture:** Pure documentation/template-file remediation across the mega-sdd plugin. No code changes, no runtime dependencies added. Each task is a targeted edit with grep-based verification (this plugin's "tests" are markdown content invariants, not unit tests). Commits are atomic per task. Final task bumps plugin version 3.17.0 → 3.18.0 and appends a v3.18.0 entry to CHANGELOG.md per `plugins/mega-sdd/CLAUDE.md` §Release Process.

**Tech Stack:** Markdown content edits. Verification via `grep -F` (literal), `grep -c` (count), and `test -f` (path resolution). No build step.

**Source audit:** [docs/superpowers/audits/2026-05-23-iter-25-verification-audit.md](../audits/2026-05-23-iter-25-verification-audit.md)

**Contributor contract (per [plugins/mega-sdd/CLAUDE.md](../../../plugins/mega-sdd/CLAUDE.md)):**
- Every skill content change requires SKILL.md `version:` frontmatter bump
- CHANGELOG.md gets a new `[3.18.0]` entry
- Renames/cross-ref fixes must update referencing files (verified per task)
- Anti-hallucination rails MUST NOT be downgraded; this plan does not touch them

---

### Task 1: Fix emit-agents-md output template — replace hard-coded legacy paths with template variables

**Severity:** P1-A (highest user-visible bug — every emitted AGENTS.md carries legacy `docs/mega-sdd/vaults/` annotation that doesn't exist in v3.4+ projects)

**Files:**
- Modify: `plugins/mega-sdd/skills/emit-agents-md/SKILL.md` (lines 44 + 78 of the output template, plus procedure step 5 to populate the variable)

- [ ] **Step 1: Verify the bug exists before fixing**

Run: `grep -nF 'docs/mega-sdd/vaults' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/SKILL.md`
Expected output (current state):
```
44:<!-- vault_source: docs/mega-sdd/vaults/<slug>/vault.json -->
78:- Full vault at: `docs/mega-sdd/vaults/<slug>/`
```

- [ ] **Step 2: Replace line 44 — vault_source HTML comment**

Current text at line 44:
```
<!-- vault_source: docs/mega-sdd/vaults/<slug>/vault.json -->
```

Replace with:
```
<!-- vault_source: {{vault_path}}/vault.json -->
```

- [ ] **Step 3: Replace line 78 — "Full vault at" interop line**

Current text at line 78:
```
- Full vault at: `docs/mega-sdd/vaults/<slug>/`
```

Replace with:
```
- Full vault at: `{{vault_path}}/`
```

- [ ] **Step 4: Document the `{{vault_path}}` substitution in procedure step 5**

Current text at line 108 (procedure step 5):
```
5. **Render per template** in `references/agents-md-schema.md`. Cite vault file:section for every claim (anti-halu rail: AGENTS.md is a flattened view, must cite source).
```

Replace with:
```
5. **Render per template** in `references/agents-md-schema.md`. Cite vault file:section for every claim (anti-halu rail: AGENTS.md is a flattened view, must cite source). **Variable substitution (v1.2.3+, Iter 26 — closes P1-A from v3.17.0 verification audit):** the `{{vault_path}}` template token in the output is replaced at render time with the actual detected vault directory (relative to repo root). On v3.4+ canonical layout → `.mega-sdd/vaults/<slug>`; on legacy layout → `docs/mega-sdd/vaults/<slug>`. NEVER hard-code either path — use the probe result from step 1.
```

- [ ] **Step 5: Bump skill version 1.2.2 → 1.2.3**

Current text at line 3:
```
version: 1.2.2
```

Replace with:
```
version: 1.2.3
```

- [ ] **Step 6: Verify zero legacy `docs/mega-sdd/vaults` references remain in the SKILL.md output template**

Run: `grep -nF 'docs/mega-sdd/vaults' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/SKILL.md`
Expected output: (empty — exit code 1)

Run: `grep -nF '{{vault_path}}' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/SKILL.md`
Expected output:
```
44:<!-- vault_source: {{vault_path}}/vault.json -->
78:- Full vault at: `{{vault_path}}/`
```

- [ ] **Step 7: Commit**

```bash
cd /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec
git add plugins/mega-sdd/skills/emit-agents-md/SKILL.md
git commit -m "$(cat <<'EOF'
fix(iter-26): emit-agents-md output template uses {{vault_path}} (P1-A)

Closes P1-A from v3.17.0 verification audit. Previously the output
template hard-coded `docs/mega-sdd/vaults/<slug>/` in two locations
(vault_source HTML comment + interop "Full vault at" line). Every
v3.4+ project running emit-agents-md got a polluted AGENTS.md whose
annotations pointed to a path that did not exist in their layout.

Template now uses `{{vault_path}}` substitution populated at render
time from the same CWD probe used to locate the vault. v3.4+ →
`.mega-sdd/vaults/<slug>`; legacy → `docs/mega-sdd/vaults/<slug>`.

Skill bump: 1.2.2 -> 1.2.3.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Fix bind-codebase step 2.10 placement (P0-1 partial closure)

**Severity:** P0 — step sequence is non-linear; a reader executing the procedure top-to-bottom would skip the constitution-aware CONFLICT surfacing entirely (it sits AFTER step 6, the audit-log step that ends the procedure).

**Files:**
- Modify: `plugins/mega-sdd/skills/bind-codebase/SKILL.md` (move lines 420-453 block; touches 2.11→3 boundary)

**Current sequence (broken):**
```
... 2.5 → 2.6 → 2.7 → 2.8 → 2.9 → 2.11 (was 2.5 duplicate, renumbered Iter 25) → 3 → 4 → 5 → 6 → 2.10 (constitution — misplaced) ...
```

**Target sequence:**
```
... 2.5 → 2.6 → 2.7 → 2.8 → 2.9 → 2.10 (constitution) → 2.11 (deferred-OQ) → 3 → 4 → 5 → 6 ...
```

- [ ] **Step 1: Read the current state to anchor the move**

Run: `grep -nF '2.10.' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/bind-codebase/SKILL.md`

Expected current matches:
- Line 420 (step 2.10 header — misplaced)
- Line 452 (back-compat note referencing "Step 2.10 SKIPPED gracefully")

Run: `grep -nF '2.11.' plugins/mega-sdd/skills/bind-codebase/SKILL.md`
Expected current matches:
- Line 278 (step 2.11 — the previously-duplicate-2.5, renumbered)

- [ ] **Step 2: Extract the misplaced 2.10 block (lines 420-448)**

Use Read with offset=420, limit=29 to capture exactly the step 2.10 block + its halt YAML. The block content to extract is:

```
2.10. **Constitution-aware CONFLICT surfacing.**

   Per `generate-intent/references/vault-contract.md` §constitution. When `<vault>/constitution.md` exists:

   a. **Read constitution.md** at the start of step 2 (binding); cache for cross-referencing
   b. **For each CONFLICT detected**: scan constitution §A-F clauses for relevant rules
   c. **Cite constitution clauses** in binding.md CONFLICT entries when applicable:
      ```
      | C-007 | Auth uses Bearer | Code uses session | Constitution §B-001 mandates Sanctum auth on /api/* (clause precedence) | KEEP_VAULT |
      ```
   d. **Constitution-violation as halt**: if existing code is in CONFLICT with constitution AND user opted for `--strict-constitution`, surface as `bind_conflict_constitution_violation` halt; user resolves before vault locks

   e. **Constitution hash persistence**: write `constitution_hash` (sha256 of constitution.md content) to binding.md frontmatter for later drift detection by `detect-drift`

### Halt YAML for bind_conflict_constitution_violation

```yaml
blocker:
  type: bind_conflict_constitution_violation
  emitted_at: <ISO8601>
  emitted_by: bind-codebase
  details:
    conflict_id: C-007
    vault_claim: "<verbatim from vault>"
    codebase_reality: "<verbatim from codebase-map>"
    constitution_clause: "§B-001 — All API endpoints MUST use Sanctum auth middleware"
    violation_severity: high
  next_action: "Constitution clause §B-001 takes precedence. Either: (1) update codebase to satisfy constitution (recommended; preserves invariant), (2) update constitution clause if no longer applicable (rare; requires user sign-off), (3) accept conflict via /mega-sdd:resolve-oq --binding."
```

### Backward compat

- v3.12 vaults without constitution.md → Step 2.10 SKIPPED gracefully; no halt, no citation
- `--no-constitution` flag opt-out preserves pre-v1.8 binding behavior
```

Use Edit with `old_string` = entire block above (verbatim from file lines 420-453) and `new_string` = empty string. This deletes the misplaced block.

- [ ] **Step 3: Insert the block in its correct position before step 3 (Aggregate counts)**

Find the line that ends step 2.11's body. After step 2.11's last paragraph (around line 313 — "Update aggregate counts (claims_total / confirmed / conflict / oq) to include any newly auto-resolved deferred OQs in `confirmed`."), there is a blank line, then "3. **Aggregate counts.**" at line 315.

Use Edit on `bind-codebase/SKILL.md` with:

`old_string`:
```
   Update aggregate counts (claims_total / confirmed / conflict / oq) to include any newly auto-resolved deferred OQs in `confirmed`.

3. **Aggregate counts.** Track `claims_total`, `confirmed`, `conflict`, `oq`.
```

`new_string`:
```
   Update aggregate counts (claims_total / confirmed / conflict / oq) to include any newly auto-resolved deferred OQs in `confirmed`.

2.10. **Constitution-aware CONFLICT surfacing.**

   Per `generate-intent/references/vault-contract.md` §constitution. When `<vault>/constitution.md` exists:

   a. **Read constitution.md** at the start of step 2 (binding); cache for cross-referencing
   b. **For each CONFLICT detected**: scan constitution §A-F clauses for relevant rules
   c. **Cite constitution clauses** in binding.md CONFLICT entries when applicable:
      ```
      | C-007 | Auth uses Bearer | Code uses session | Constitution §B-001 mandates Sanctum auth on /api/* (clause precedence) | KEEP_VAULT |
      ```
   d. **Constitution-violation as halt**: if existing code is in CONFLICT with constitution AND user opted for `--strict-constitution`, surface as `bind_conflict_constitution_violation` halt; user resolves before vault locks

   e. **Constitution hash persistence**: write `constitution_hash` (sha256 of constitution.md content) to binding.md frontmatter for later drift detection by `detect-drift`

### Halt YAML for bind_conflict_constitution_violation

```yaml
blocker:
  type: bind_conflict_constitution_violation
  emitted_at: <ISO8601>
  emitted_by: bind-codebase
  details:
    conflict_id: C-007
    vault_claim: "<verbatim from vault>"
    codebase_reality: "<verbatim from codebase-map>"
    constitution_clause: "§B-001 — All API endpoints MUST use Sanctum auth middleware"
    violation_severity: high
  next_action: "Constitution clause §B-001 takes precedence. Either: (1) update codebase to satisfy constitution (recommended; preserves invariant), (2) update constitution clause if no longer applicable (rare; requires user sign-off), (3) accept conflict via /mega-sdd:resolve-oq --binding."
```

### Backward compat

- v3.12 vaults without constitution.md → Step 2.10 SKIPPED gracefully; no halt, no citation
- `--no-constitution` flag opt-out preserves pre-v1.8 binding behavior

3. **Aggregate counts.** Track `claims_total`, `confirmed`, `conflict`, `oq`.
```

- [ ] **Step 4: Bump bind-codebase version 1.9.1 → 1.9.2**

Current text at line 3:
```
version: 1.9.1
```

Replace with:
```
version: 1.9.2
```

- [ ] **Step 5: Update the in-line iter annotation on step 2.11 to remove the chatty self-reference (closes P2-3 regressed-style)**

Current text near step 2.11 (find via grep `2.11. \*\*Deferred-OQ auto-resolution\*\*`):
```
2.11. **Deferred-OQ auto-resolution** (renumbered v1.9.1 Iter 25 — was duplicate `2.5`; logical position is after Hard Rules emission since it processes user-deferred OQs against the now-augmented codebase-map).
```

Replace with:
```
2.11. **Deferred-OQ auto-resolution.** Logical position: after Hard Rules emission since it processes user-deferred OQs against the now-augmented codebase-map.
```

- [ ] **Step 6: Verify linear sequence**

Run: `grep -nE '^[0-9]+\.[0-9]*\.' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/bind-codebase/SKILL.md`

Expected output should show step numbers in monotonically increasing order: 1, 2, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 3, 4, 5, 6 (line numbers will increase too). No backwards jumps.

- [ ] **Step 7: Verify the back-compat note still resolves**

Run: `grep -nF 'Step 2.10 SKIPPED gracefully' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/bind-codebase/SKILL.md`

Expected: exactly 1 match (the back-compat note moved with the 2.10 block).

- [ ] **Step 8: Commit**

```bash
git add plugins/mega-sdd/skills/bind-codebase/SKILL.md
git commit -m "$(cat <<'EOF'
fix(iter-26): bind-codebase step 2.10 placed in linear sequence (P0-1)

Closes P0-1 partial from v3.17.0 verification audit. Iter 25 renumbered
the duplicate 2.5 to 2.11 but left step 2.10 (Constitution-aware
CONFLICT surfacing) physically positioned AFTER step 6 (Audit log),
breaking linear procedure flow.

Step 2.10 + its halt YAML + Backward compat note are now positioned
between step 2.11 and step 3, restoring monotonic step order.

Also de-clutters step 2.11's chatty renumbering self-reference (closes
P2-3 regressed-style from the verification audit).

Skill bump: 1.9.1 -> 1.9.2.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Fix generate-units step 7.5/7.6 swap + step 12 audit-log placement (P0-4 partial closure)

**Severity:** P0 — step 7.6 physically precedes step 7.5; step 12 (audit log) precedes its own substeps 12.3-12.6.

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/SKILL.md`

- [ ] **Step 1: Verify current ordering bugs**

Run: `grep -nE '^(7|12)\.[0-9]*\.' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-units/SKILL.md`

Expected output (current — broken):
```
235:7.6. **Per-unit target_files collision check (v2.1+, Iter 8).**
261:7.5. **PageRank target_files suggestions (v2.0+, Iter 6).**
293:12. **Audit log.** Append to `vault.json`: ...
295:12.3. **Per-anchor verification (v2.1+, Iter 8 — renumbered v2.5.1 Iter 25...
309:12.4. **Inject constitution clauses (v2.4+, Iter 17 — renumbered v2.5.1 Iter 25).**
346:12.4.5. **Framework pack provenance citation (v2.5.1+, Iter 25 — propagates Iter 23 framework pack into unit body).**
381:12.5. **Polished-prompt render pass (v1.3+, Iter 3 — renumbered v2.5.1 Iter 25).**
420:12.6. **Deduplication check (v1.2+, Iter 1 — renumbered v2.5.1 Iter 25).**
```

- [ ] **Step 2: Swap 7.5 and 7.6 — move PageRank step BEFORE collision check**

The semantic order is: PageRank suggestions surface (`7.5`) → collision check runs before write (`7.6`). The fix is to physically place the 7.5 block ahead of 7.6.

Use Edit on `generate-units/SKILL.md` with:

`old_string`:
```
7.6. **Per-unit target_files collision check (v2.1+, Iter 8).**

   Per `references/defensive-generation.md` §Step 7.6. Before writing each unit:

   For EACH `target_files` entry where `operation: create`:
   1. Probe path existence (fs check OR codebase-map §1)
   2. If file does NOT exist → proceed normally (true create)
   3. If file EXISTS:
      - If binding has IMPLEMENTED state for related claim → INTERACTIVE prompt:
        ```
        "Target `<path>` already exists. Binding state: IMPLEMENTED.
         Options for unit U-XXX:
           1. Convert to `verify` (no code change) (recommended)
           2. Convert to `extend` (modify; fill Migration notes)
           3. Rename target file
           4. Force `create` (overwrite — DANGEROUS)
           5. Skip this unit"
        ```
      - If binding state PARTIAL_FIELDS_* or NEW or UNKNOWN → INTERACTIVE prompt with `extend` as recommended default

   **Prompt frequency control**:
   - Prompts fire ONLY on genuine collision (file exists + task_type=create)
   - Same-session memory: previous picks default future similar collisions
   - `--auto` flag suppresses interactive — picks safest default (`extend`)
   - `--collision-policy=<extend|verify|skip|prompt>` flag overrides for batch behavior

7.5. **PageRank target_files suggestions (v2.0+, Iter 6).**

   When `codebase-map.md` frontmatter has `precision_tier: ast` (tree-sitter scan, Iter 6 Swap #1):

   - Build/load symbol-reference graph per `references/pagerank-targeting.md` §Algorithm
   - For each unit, compute personalized PageRank with seed = current `target_files` + binding citations
   - Surface top-K (default K=5) non-seed file suggestions in unit body's `## PageRank suggestions` section
   - User reviews + manually promotes to `target_files` frontmatter (NEVER silent rewrite per anti-halu)

   Skipped when `precision_tier: regex` or `--skip-pagerank` flag set. Falls back to v1.5 behavior (binding-only target_files).

   Symbol graph cached at `<vault>/.internal/symbol-graph.json` (v3.4+ canonical per paths.md) per scan-codebase run; reused across all units.
```

`new_string`:
```
7.5. **PageRank target_files suggestions (v2.0+, Iter 6).**

   When `codebase-map.md` frontmatter has `precision_tier: ast` (tree-sitter scan, Iter 6 Swap #1):

   - Build/load symbol-reference graph per `references/pagerank-targeting.md` §Algorithm
   - For each unit, compute personalized PageRank with seed = current `target_files` + binding citations
   - Surface top-K (default K=5) non-seed file suggestions in unit body's `## PageRank suggestions` section
   - User reviews + manually promotes to `target_files` frontmatter (NEVER silent rewrite per anti-halu)

   Skipped when `precision_tier: regex` or `--skip-pagerank` flag set. Falls back to v1.5 behavior (binding-only target_files).

   Symbol graph cached at `<vault>/.internal/symbol-graph.json` (v3.4+ canonical per paths.md) per scan-codebase run; reused across all units.

7.6. **Per-unit target_files collision check (v2.1+, Iter 8).**

   Per `references/defensive-generation.md` §Step 7.6. Before writing each unit:

   For EACH `target_files` entry where `operation: create`:
   1. Probe path existence (fs check OR codebase-map §1)
   2. If file does NOT exist → proceed normally (true create)
   3. If file EXISTS:
      - If binding has IMPLEMENTED state for related claim → INTERACTIVE prompt:
        ```
        "Target `<path>` already exists. Binding state: IMPLEMENTED.
         Options for unit U-XXX:
           1. Convert to `verify` (no code change) (recommended)
           2. Convert to `extend` (modify; fill Migration notes)
           3. Rename target file
           4. Force `create` (overwrite — DANGEROUS)
           5. Skip this unit"
        ```
      - If binding state PARTIAL_FIELDS_* or NEW or UNKNOWN → INTERACTIVE prompt with `extend` as recommended default

   **Prompt frequency control**:
   - Prompts fire ONLY on genuine collision (file exists + task_type=create)
   - Same-session memory: previous picks default future similar collisions
   - `--auto` flag suppresses interactive — picks safest default (`extend`)
   - `--collision-policy=<extend|verify|skip|prompt>` flag overrides for batch behavior
```

- [ ] **Step 3: Renumber step 12 (audit log) to step 13 and move it to AFTER step 12.6**

The audit log step is semantically last (after all unit processing). Currently it sits at line 293 before its own substeps. Fix: renumber to step 13, move to after step 12.6's body.

First, locate step 12.6's end. Step 12.6 starts at line 420 with `12.6. **Deduplication check...` and ends with its halt YAML block. Read the file at offset 420, limit 50 to capture the full block.

Use Edit on `generate-units/SKILL.md` with:

`old_string` (the misplaced "12. Audit log." line, currently between "## Backward compat" of step 11 and the start of step 12.3):
```
12. **Audit log.** Append to `vault.json`: `{ "event": "units_generated", "at": "...", "count": N }`.

12.3. **Per-anchor verification (v2.1+, Iter 8 — renumbered v2.5.1 Iter 25; runs FIRST as precondition check before constitution inject + render).**
```

`new_string`:
```
12. **Post-write validation + audit (the 12.x sub-procedures below run in declared order, then step 13 logs).**

12.3. **Per-anchor verification (v2.1+, Iter 8 — renumbered v2.5.1 Iter 25; runs FIRST as precondition check before constitution inject + render).**
```

- [ ] **Step 4: Add step 13 (Audit log) after step 12.6 body ends**

Find the end of step 12.6's halt YAML block. The block ends with the closing fence:
```
       reason: "Unit task_type=create but all target_files already exist in codebase-map. Implementation State Map did not classify these claims as IMPLEMENTED — possible binding gap OR genuine intent to overwrite."
```

(The closing ``` of the yaml fence + a trailing blank line, then the next section starts.)

Use Read at offset=420 limit=80 to find the exact end of 12.6. The section after 12.6 in the current file should be either "## Anti-hallucination rails" or another top-level section.

Use Edit with `old_string` matching the closing fence of 12.6's halt YAML + the blank line + the next section heading, and `new_string` inserting "13. **Audit log.**" between them.

Concrete edit — locate the exact spot via:

Run: `grep -nE '^(##|13\. \*\*Audit)' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-units/SKILL.md`

This shows where 12.6's body transitions to the next top-level section. Identify the exact "## <next-section>" heading that follows 12.6.

Then Edit:

`old_string` (replace with what you see — example shape):
```
       reason: "Unit task_type=create but all target_files already exist in codebase-map. Implementation State Map did not classify these claims as IMPLEMENTED — possible binding gap OR genuine intent to overwrite."
   ```

## Anti-hallucination rails
```

`new_string`:
```
       reason: "Unit task_type=create but all target_files already exist in codebase-map. Implementation State Map did not classify these claims as IMPLEMENTED — possible binding gap OR genuine intent to overwrite."
   ```

13. **Audit log.** Append to `vault.json`: `{ "event": "units_generated", "at": "...", "count": N }`. Runs last so the event reflects all post-write validation outcomes.

## Anti-hallucination rails
```

(If grep reveals the next section is something other than "Anti-hallucination rails", adjust accordingly — the principle is unchanged.)

- [ ] **Step 5: Bump generate-units version 2.5.1 → 2.5.2**

Current text at line 3:
```
version: 2.5.1
```

Replace with:
```
version: 2.5.2
```

- [ ] **Step 6: Verify final step order**

Run: `grep -nE '^(7|11|12|13)\.[0-9]*\.' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-units/SKILL.md`

Expected output (line numbers will vary post-edit but step labels must be monotonic):
- 7.5 BEFORE 7.6
- 11 BEFORE 12, 12.3, 12.4, 12.4.5, 12.5, 12.6
- 13 (audit log) AFTER 12.6

- [ ] **Step 7: Commit**

```bash
git add plugins/mega-sdd/skills/generate-units/SKILL.md
git commit -m "$(cat <<'EOF'
fix(iter-26): generate-units step ordering — 7.5/7.6 swap + audit log -> step 13 (P0-4)

Closes P0-4 partial from v3.17.0 verification audit. Two ordering bugs:
- Step 7.6 (collision check) physically preceded step 7.5 (PageRank
  suggestions). Now placed in monotonic order.
- Step 12 (Audit log) preceded its own substeps 12.3-12.6 (post-write
  validation runs). Renumbered to step 13 and moved after step 12.6 so
  the audit event reflects all validation outcomes.

Skill bump: 2.5.1 -> 2.5.2.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Fix diff-vault:318 remaining broken cross-reference (P0-8 partial closure)

**Severity:** P0 — one of the two original P0-8 cross-refs was fixed in Iter 25; this one was missed.

**Files:**
- Modify: `plugins/mega-sdd/skills/diff-vault/SKILL.md` (line 318)

- [ ] **Step 1: Verify the broken cross-ref**

Run: `grep -nF 'references/vault-contract.md' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/diff-vault/SKILL.md`

Expected current matches include line 318 with `references/vault-contract.md` (no parent path prefix — would resolve to `diff-vault/references/vault-contract.md` which does not exist):

Run: `test -f /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/diff-vault/references/vault-contract.md && echo EXISTS || echo MISSING`

Expected: `MISSING`

Run: `test -f /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-intent/references/vault-contract.md && echo EXISTS || echo MISSING`

Expected: `EXISTS`

- [ ] **Step 2: Fix the cross-reference**

Current text at line 318:
```
2. Rebuild the manifest fields per `references/vault-contract.md` §schema:
```

Replace with:
```
2. Rebuild the manifest fields per `../generate-intent/references/vault-contract.md` §schema:
```

- [ ] **Step 3: Bump diff-vault version 1.2.0 → 1.2.1**

Find the version line via `grep -n '^version:' plugins/mega-sdd/skills/diff-vault/SKILL.md` — expected `version: 1.2.0`.

Replace with `version: 1.2.1`.

- [ ] **Step 4: Verify the fix resolves**

Run: `grep -nF 'vault-contract.md' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/diff-vault/SKILL.md`

Expected: every match either uses `../generate-intent/references/vault-contract.md` or is a back-compat clause. NO bare `references/vault-contract.md` (without parent path).

Run resolver check on each match — for each path printed, run `test -f <resolved-path>` from the skill directory.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/diff-vault/SKILL.md
git commit -m "$(cat <<'EOF'
fix(iter-26): diff-vault:318 cross-ref points to real vault-contract.md (P0-8)

Closes P0-8 remaining partial from v3.17.0 verification audit. Iter 25
fixed two of three broken cross-refs to vault-contract.md across the
plugin (detect-drift:571 + diff-vault:471) but missed diff-vault:318
which still pointed to local `references/vault-contract.md` — a file
that does not exist in diff-vault/references/.

Now points to `../generate-intent/references/vault-contract.md` (the
canonical home of the schema).

Skill bump: 1.2.0 -> 1.2.1.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: README + plugin README version metadata sweep (P1-B)

**Severity:** P1 — both READMEs ship v3.13.0 and v3.8.0 metadata after a v3.17.0 release. Skill inventory table has all 13 per-skill versions stale.

**Files:**
- Modify: `README.md` (repo root) — lines 9, 90, 334, plus "anti-hallucination" list truncation
- Modify: `plugins/mega-sdd/README.md` — lines 6, 44, 47-58, 97 + the truncated anti-halu list at 99-108

> **Note:** This task is reached AFTER Iter 26's other tasks complete. Skill version numbers cited below are the POST-Iter-26 values from Tasks 1-4. Skills not modified by Iter 26 retain their Iter 25 versions.

**Post-Iter-26 skill versions (single source of truth — verify via `grep '^version:' plugins/mega-sdd/skills/*/SKILL.md`):**

| Skill | Version | Source |
|---|---|---|
| bind-codebase | 1.9.2 | Task 2 bump |
| detect-drift | 1.2.1 | Iter 25 |
| diff-vault | 1.2.1 | Task 4 bump |
| emit-agents-md | 1.2.3 | Task 1 bump |
| execute-bolts | 2.4.1 | Iter 25 |
| extract-intelligence | 1.4.0 | Iter 22 |
| generate-intent | 1.10.0 | Iter 22 |
| generate-units | 2.5.2 | Task 3 bump |
| memory | 1.2.1 | Iter 25 |
| orchestrate-flow | 2.3.2 | Iter 25 |
| resolve-oq | 0.9.0 | Iter 20 |
| scan-codebase | 2.4.2 | Iter 25 |
| using-mega-sdd | 1.2.1 | Iter 21 |

- [ ] **Step 1: Verify current stale state in root README**

Run: `grep -nE '(3\.13\.0|3\.8\.0|11 skills)' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/README.md`

Expected matches: lines 9 (`Version: 3.13.0`), 90 (`(v3.13.0)`), 334 (`(v3.8.0)`).

- [ ] **Step 2: Update root README line 9 — version banner**

Current:
```
**Plugin:** `mega-sdd` · **Version:** 3.13.0 · **License:** MIT
```

Replace with:
```
**Plugin:** `mega-sdd` · **Version:** 3.18.0 · **License:** MIT
```

- [ ] **Step 3: Update root README line 90 — anti-halu version annotation**

Current:
```
**13-layer anti-hallucination defense** (v3.13.0):
```

Replace with:
```
**13-layer anti-hallucination defense** (v3.18.0):
```

- [ ] **Step 4: Update root README line 334 — repo structure plugin annotation**

Current:
```
├── plugins/mega-sdd/                       # the plugin itself (v3.8.0)
```

Replace with:
```
├── plugins/mega-sdd/                       # the plugin itself (v3.18.0)
```

- [ ] **Step 5: Verify plugin README current stale state**

Run: `grep -nE '(3\.13\.0|3\.8\.0|11 skills)' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/README.md`

Expected matches: lines 6 (`Version: 3.13.0`), 44 (`v3.8.0` comment), 45 (`11 skills`).

- [ ] **Step 6: Update plugin README line 6 — version banner**

Current:
```
**Version:** 3.13.0 · **License:** MIT
```

Replace with:
```
**Version:** 3.18.0 · **License:** MIT
```

- [ ] **Step 7: Update plugin README line 44 — manifest version comment**

Current:
```
├── .claude-plugin/plugin.json    # plugin manifest (v3.8.0)
```

Replace with:
```
├── .claude-plugin/plugin.json    # plugin manifest (v3.18.0)
```

- [ ] **Step 8: Update plugin README line 45 — skill count**

Current:
```
├── skills/                       # 11 skills + _vendored/
```

Replace with:
```
├── skills/                       # 13 skills + _vendored/
```

- [ ] **Step 9: Update plugin README lines 46-58 — skill inventory table**

Find the block via `grep -n '│   ├── ' plugins/mega-sdd/README.md | head -20`.

Use Edit to replace the inventory block:

`old_string`:
```
│   ├── using-mega-sdd/           # anchor skill (auto-injected)
│   ├── memory/                   # memory + self-learning (v1.2)
│   ├── emit-agents-md/           # AGENTS.md flatten (v1.1)
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.2)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.7)
│   ├── scan-codebase/            # tree-sitter AST scan (v2.3)
│   ├── bind-codebase/            # validation gate + field diff (v1.7.1)
│   ├── generate-units/           # atomic decomposition (v2.3)
│   ├── execute-bolts/            # superpowers TDD bridge (v2.2)
│   ├── orchestrate-flow/         # lifecycle router (v2.2)
│   ├── resolve-oq/               # OQ resolver + recommendations (v0.7)
│   ├── detect-drift/             # code vs vault (v1.0)
│   ├── diff-vault/               # PRD revision + jd patches (v1.1)
│   └── _vendored/                # superpowers fallback
```

`new_string`:
```
│   ├── using-mega-sdd/           # anchor skill (auto-injected) (v1.2.1)
│   ├── memory/                   # memory + self-learning (v1.2.1)
│   ├── emit-agents-md/           # AGENTS.md flatten (v1.2.3)
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.4.0)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.10.0)
│   ├── scan-codebase/            # tree-sitter AST scan (v2.4.2)
│   ├── bind-codebase/            # validation gate + field diff (v1.9.2)
│   ├── generate-units/           # atomic decomposition (v2.5.2)
│   ├── execute-bolts/            # superpowers TDD bridge (v2.4.1)
│   ├── orchestrate-flow/         # lifecycle router (v2.3.2)
│   ├── resolve-oq/               # OQ resolver + recommendations (v0.9.0)
│   ├── detect-drift/             # code vs vault (v1.2.1)
│   ├── diff-vault/               # PRD revision + jd patches (v1.2.1)
│   └── _vendored/                # superpowers fallback
```

- [ ] **Step 10: Update plugin README "What's new" header (line 85) to reference v3.18.0**

Current text at line 85:
```
## What's new in v3.17.0 (Iters 17-25)
```

Replace with:
```
## What's new in v3.18.0 (Iters 17-26)
```

- [ ] **Step 11: Append Iter 26 bullet to "What's new" list (after the Iter 25 bullet at line 95)**

Use Edit with:

`old_string`:
```
- **Iter 25 Audit closure** — closed 27 findings from v3.16.0 deep audit: completed Iter 21 hotfix across 6 commands + handoff-contract + memory schema + recommendation-context + checkpoint paths; fixed bind-codebase step sequence (duplicate 2.5 + dangling 2.10) + halt-conditions completion; fixed generate-units step jumble; propagated Iter 22 mutability to 6 consumer skills (bind, drift, resolve-oq, generate-units, agents-md, handoff); propagated Iter 23 framework pack to generate-units (provenance citation) + execute-bolts + AGENTS.md header; fixed 2 broken cross-references; updated scenario-4 to demo tier flow + starterkit detection

## Anti-hallucination defense (13 layers)
```

`new_string`:
```
- **Iter 25 Audit closure** — closed 27 findings from v3.16.0 deep audit: completed Iter 21 hotfix across 6 commands + handoff-contract + memory schema + recommendation-context + checkpoint paths; fixed bind-codebase step sequence (duplicate 2.5 + dangling 2.10) + halt-conditions completion; fixed generate-units step jumble; propagated Iter 22 mutability to 6 consumer skills (bind, drift, resolve-oq, generate-units, agents-md, handoff); propagated Iter 23 framework pack to generate-units (provenance citation) + execute-bolts + AGENTS.md header; fixed 2 broken cross-references; updated scenario-4 to demo tier flow + starterkit detection
- **Iter 26 Verification closure** — closed 5 highest-leverage gaps from v3.17.0 verification audit: emit-agents-md output template now uses `{{vault_path}}` substitution (no more legacy paths in every AGENTS.md emitted); bind-codebase step 2.10 placed in linear sequence; generate-units 7.5/7.6 swap + audit log → step 13; diff-vault:318 cross-ref fixed; commands/orchestrate-flow.md refreshed for `--deep` + `--resume`; AGENTS.md schema gains PBT/replay/convergence header fields (P1-9)

## Anti-hallucination defense (13 layers)
```

- [ ] **Step 12: Replace the truncated 10-item anti-halu list in plugin README with the full 13**

Use Edit with:

`old_string`:
```
1. **Intent** — uncertain claims promote to Open Questions
2. **OQ classification** — business vs tech; tech auto-resolves
3. **Binding gate** — CONFLICT blocks
4. **Implementation state** — IMPLEMENTED / NEW / PARTIAL_FIELDS_MISSING / UNKNOWN
5. **Unit grounding** — target_files whitelist + acceptance_test + Anchors
6. **Hard Rules pre/post-flight** — ast-grep validates at bolt time
7. **AST-precise extraction** — tree-sitter (Aider pattern)
8. **Memory** — suggestion-only with audit log
9. **Drift detection** — code vs vault reconciliation
10. **Interface lock** — cross-squad consumed interfaces must be locked
```

`new_string`:
```
1. **Intent** — uncertain claims promote to Open Questions
2. **OQ classification** — business vs tech; tech auto-resolves
3. **Binding gate** — CONFLICT blocks
4. **Implementation state** — IMPLEMENTED / NEW / PARTIAL_FIELDS_MISSING / UNKNOWN
5. **Unit grounding** — target_files whitelist + acceptance_test + Anchors
6. **Hard Rules pre/post-flight** — ast-grep validates at bolt time
7. **AST-precise extraction** — tree-sitter (Aider pattern)
8. **Memory** — suggestion-only with audit log
9. **Drift detection** — code vs vault reconciliation
10. **Interface lock** — cross-squad consumed interfaces must be locked
11. **Mutability tier classification** — [LOCKED]/[INTENT]/[ARTIFACT] orthogonal to confidence (Iter 22)
12. **Constitution layer** — project invariants enforced as Hard Rules at bolt time (Iter 17)
13. **Framework convention packs** — laravel/django/rails/etc. conventions inject into Suggested Unit Hard Rules (Iter 23)
```

- [ ] **Step 13: Verify all updates landed correctly**

Run: `grep -nE '3\.18\.0' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/README.md`
Expected matches: lines 9, 90, 334 (3 hits).

Run: `grep -nE '3\.18\.0|13 skills' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/README.md`
Expected matches: lines 6, 44, 45, 85 (4 hits).

Run: `grep -cE '^[0-9]+\.\s\*\*' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/README.md | head -1`
Expected: count of anti-halu items now equals 13 (post-edit). Sanity check by reading the list.

Run: `grep -nE '3\.13\.0|3\.8\.0' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/README.md /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/README.md`
Expected: empty (no stale version annotations remaining).

- [ ] **Step 14: Commit**

```bash
git add README.md plugins/mega-sdd/README.md
git commit -m "$(cat <<'EOF'
docs(iter-26): README + plugin README version sweep (P1-B)

Closes P1-B from v3.17.0 verification audit. Both READMEs advertised
v3.13.0 / v3.8.0 metadata and an 11-skill inventory table whose
per-skill versions were 12 of 13 stale.

Updates:
- Root README version banner (line 9): 3.13.0 -> 3.18.0
- Root README anti-halu annotation (line 90): v3.13.0 -> v3.18.0
- Root README repo-structure annotation (line 334): v3.8.0 -> v3.18.0
- Plugin README version banner (line 6): 3.13.0 -> 3.18.0
- Plugin README manifest annotation (line 44): v3.8.0 -> v3.18.0
- Plugin README skill count (line 45): 11 -> 13
- Plugin README skill inventory table (lines 47-58): all 13 versions
  refreshed against current SKILL.md frontmatter
- Plugin README "What's new" header bumped to v3.18.0 + Iter 26 bullet
- Plugin README anti-halu list completed from 10 to claimed 13 (added
  mutability tier, constitution layer, framework convention packs)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Refresh `commands/orchestrate-flow.md` for `--deep` and `--resume` (P1-C)

**Severity:** P1 — command file is 2 iterations behind. `--deep` (Iter 4, v2.3.0) and `--resume` (Iter 4, v2.3.0) are not discoverable via `--help`.

**Files:**
- Modify: `plugins/mega-sdd/commands/orchestrate-flow.md`

- [ ] **Step 1: Verify current state**

Run: `cat /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/commands/orchestrate-flow.md`

Expected: file shows "max 3 per chain" + argument-hint missing `--deep` and `--resume`.

- [ ] **Step 2: Rewrite the file with current contract**

Use Write (overwrite) on `plugins/mega-sdd/commands/orchestrate-flow.md` with content:

```markdown
---
description: Inspect CWD and orchestrate a chain of mega-sdd sub-skills with single confirmation. Halt-pauses on blockers. `--deep` chains to pipeline-end; `--resume` continues a paused chain from CWD state.
argument-hint: [vault-path] [--from=<phase>] [--to=<phase>] [--dry-run] [--deep] [--resume] [--auto]
---

Invoke `mega-sdd:orchestrate-flow` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional (if not a flag): vault path or PRD path; otherwise auto-detect from CWD.
- Flags:
  - `--from`, `--to` — pin chain entry/exit (override CWD-driven detection)
  - `--dry-run` — print proposed chain without executing
  - `--deep` (v2.3+, Iter 4) — lift the 3-sub-skill chain cap; chain auto-continues to pipeline-end via handoff YAML
  - `--resume` (v2.3+, Iter 4) — resume a paused/halted chain from CWD state (no persisted state file; CWD probes rebuild cursor)
  - `--auto` — non-interactive substance-prompt suppression; single upfront confirmation only

Follow `skills/orchestrate-flow/SKILL.md` procedure. Default behavior: 3-sub-skill chain with single upfront confirmation. `--deep` lifts the cap and chains to pipeline-end; `--resume` continues from current CWD state.

Hard rails:
- No content generation by orchestrator itself
- No persisted state file (re-invoke OR `--resume` to continue; CWD probes rebuild cursor)
- No parallel sub-skills
- Substance prompts (real blockers) surface to human even under `--auto`; conventional prompts (CWD detection, defaults) suppressed
- Blocker artifacts pause chain; handoff YAML records halt reason + `next_action`
```

- [ ] **Step 3: Verify file shape**

Run: `head -5 /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/commands/orchestrate-flow.md`

Expected: frontmatter shows `--deep` and `--resume` in argument-hint.

Run: `grep -F 'max 3 per chain' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/commands/orchestrate-flow.md`
Expected: empty (the obsolete claim is removed).

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/commands/orchestrate-flow.md
git commit -m "$(cat <<'EOF'
docs(iter-26): orchestrate-flow command refresh — add --deep + --resume (P1-C)

Closes P1-C from v3.17.0 verification audit. Command file was 2 iters
behind the skill: claimed "max 3 per chain" (obsolete since Iter 4
--deep flag in v2.3.0) and omitted both --deep and --resume from
argument-hint, making them undiscoverable via slash-command help.

Refreshed argument-hint, description, flag documentation, and hard
rails section to match orchestrate-flow/SKILL.md v2.3.2 contract.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Close P1-9 — add PBT / replay / convergence fields to agents-md-schema.md

**Severity:** P1 — Iter 17 (constitution) was propagated to AGENTS.md; Iter 18 (PBT) and Iter 19 (convergence loops) were not. Tools consuming AGENTS.md cannot see this vault state.

**Files:**
- Modify: `plugins/mega-sdd/skills/emit-agents-md/references/agents-md-schema.md` (Header section + new conditional sections)
- Modify: `plugins/mega-sdd/skills/emit-agents-md/SKILL.md` (header template + procedure note to populate new fields)

- [ ] **Step 1: Verify the gap**

Run: `grep -ciE 'properties_validated|cycle_count|replay_snapshot' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/references/agents-md-schema.md`

Expected: `0`

Run: `grep -cF 'constitution_hash' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/references/agents-md-schema.md`

Expected: `1` (Iter 17 only).

- [ ] **Step 2: Extend the header schema (around lines 10-17) with PBT + replay + convergence fields**

Use Edit on `agents-md-schema.md`:

`old_string`:
```
<!-- generated_by: mega-sdd:emit-agents-md v1.2.2 -->
<!-- vault_source: .mega-sdd/vaults/<slug>/vault.json -->
<!-- generated_at: <ISO8601> -->
<!-- vault_version: <vault.json version field> -->
<!-- framework: <detected from codebase-map.md §7 — e.g., laravel-base-26, laravel, django, _universal> -->
<!-- framework_pack_path: <relative path to plugins/mega-sdd/references/framework-conventions/<framework>.md> -->
<!-- mutability_summary: locked=<N> intent=<N> artifact=<N> (counts from data-mutation-policy.md when KB-derived vault) -->
<!-- DO NOT EDIT BELOW THIS LINE — regenerate via /mega-sdd:emit-agents-md -->
```

`new_string`:
```
<!-- generated_by: mega-sdd:emit-agents-md v1.2.3 -->
<!-- vault_source: {{vault_path}}/vault.json -->
<!-- generated_at: <ISO8601> -->
<!-- vault_version: <vault.json version field> -->
<!-- framework: <detected from codebase-map.md §7 — e.g., laravel-base-26, laravel, django, _universal> -->
<!-- framework_pack_path: <relative path to plugins/mega-sdd/references/framework-conventions/<framework>.md> -->
<!-- mutability_summary: locked=<N> intent=<N> artifact=<N> (counts from data-mutation-policy.md when KB-derived vault) -->
<!-- constitution_hash: <sha256 of constitution.md content, if present; from binding.md frontmatter> -->
<!-- properties_validated: <N total invariants across units that hold properties: blocks; from vault.json properties_summary> -->
<!-- replay_snapshot_count: <N replay snapshots recorded; from vault.json replay_state> -->
<!-- convergence_cycle_count: <N successful convergence cycles since vault inception; from vault.json convergence_state> -->
<!-- DO NOT EDIT BELOW THIS LINE — regenerate via /mega-sdd:emit-agents-md -->
```

- [ ] **Step 3: Update the v1.2.2+ explainer line to mention v1.2.3 additions**

Use Edit on `agents-md-schema.md`:

`old_string`:
```
> **v1.2.2+ Iter 25**: Header now declares framework pack + mutability summary so tools consuming AGENTS.md can resolve which conventions apply + which vault claims are LOCKED vs free to redesign.
```

`new_string`:
```
> **v1.2.2+ Iter 25**: Header declares framework pack + mutability summary so tools consuming AGENTS.md can resolve which conventions apply + which vault claims are LOCKED vs free to redesign.
> **v1.2.3+ Iter 26 (closes P1-9)**: Header also declares `constitution_hash` (Iter 17 sha256 for staleness detection), `properties_validated` (Iter 18 PBT invariant count), `replay_snapshot_count` (Iter 18 regression baseline count), and `convergence_cycle_count` (Iter 19 auto-recovery cycle count). Tools consuming AGENTS.md can now surface these as caution badges (e.g., "this AGENTS.md was generated after N convergence cycles — vault has undergone semi-automated repair; review for divergence from human intent").
```

- [ ] **Step 4: Add conditional-presence rules for the new fields**

Find the "Conditional section presence" table (around line 200). Add rows for the new header fields — these are header HTML comments, not body sections, so document them in the procedure note.

Use Edit on `agents-md-schema.md`:

`old_string`:
```
## Conditional section presence

| Section | Required when |
|---|---|
| Project overview | Always (always have 01-overview.md) |
| Build commands | Detected build tooling (composer/npm/cargo/gradle/etc.) |
| Test commands | Test framework detected in conventions.md OR DoD in 04-flows.md |
| Code style + conventions | conventions.md exists OR 06-constraints.md has style section |
| Architecture overview | Always (always have 02-architecture.md) |
| Key decisions | 05-decisions.md has ≥1 ADR |
| Open questions | vault.json `open_questions_summary.total > 0` |
| Mega-sdd interop notes | Always (signals mega-sdd presence to AGENTS.md-aware tools) |

Empty sections OMITTED (not rendered with placeholders).
```

`new_string`:
```
## Conditional section presence

| Section | Required when |
|---|---|
| Project overview | Always (always have 01-overview.md) |
| Build commands | Detected build tooling (composer/npm/cargo/gradle/etc.) |
| Test commands | Test framework detected in conventions.md OR DoD in 04-flows.md |
| Code style + conventions | conventions.md exists OR 06-constraints.md has style section |
| Architecture overview | Always (always have 02-architecture.md) |
| Key decisions | 05-decisions.md has ≥1 ADR |
| Open questions | vault.json `open_questions_summary.total > 0` |
| Mega-sdd interop notes | Always (signals mega-sdd presence to AGENTS.md-aware tools) |

Empty sections OMITTED (not rendered with placeholders).

## Conditional header field presence (v1.2.3+, Iter 26 — closes P1-9)

Header HTML comments declare vault-state fields. Each field renders ONLY when its source data exists; otherwise the line is OMITTED entirely (NOT rendered with a placeholder).

| Header field | Source | Render when |
|---|---|---|
| `constitution_hash` | `binding.md` frontmatter `constitution_hash` | `<vault>/constitution.md` exists AND binding.md has been written (Iter 17+) |
| `properties_validated` | `vault.json` `properties_summary.total` | vault has ≥1 unit with `properties:` block (Iter 18+) |
| `replay_snapshot_count` | `vault.json` `replay_state.snapshot_count` | vault has been replayed at least once via `/mega-sdd:replay` (Iter 18+) |
| `replay_snapshot_count` value 0 | omit field entirely | new vault, never replayed |
| `convergence_cycle_count` | `vault.json` `convergence_state.cycles_completed` | `/mega-sdd:auto --converge` has run ≥1 successful cycle (Iter 19+) |
| `convergence_cycle_count` value 0 | omit field entirely | no convergence runs |

**Anti-halu rails (Iter 26):**

- Each header field cites a SPECIFIC source location in vault.json or binding.md. NEVER invented; if the source is missing, the field is omitted.
- `constitution_hash` is the canonical staleness signal — if AGENTS.md emit predates a constitution.md update, the hash differs and downstream tools flag this AGENTS.md as stale.
- `convergence_cycle_count > 0` is a SOFT CAUTION signal to AI tools consuming AGENTS.md — vault has undergone semi-automated repair, so manual review is recommended.
```

- [ ] **Step 5: Update emit-agents-md SKILL.md output template to mirror schema header**

This was partially done in Task 1 (`{{vault_path}}` substitution). Now add the four new HTML comment lines.

Run: `grep -n '<!-- generated_at' plugins/mega-sdd/skills/emit-agents-md/SKILL.md`

Locate the existing header template (around line 43-46 post-Task-1).

Use Edit on `emit-agents-md/SKILL.md`:

`old_string`:
```
<!-- generated_by: mega-sdd:emit-agents-md v1.0.0 -->
<!-- vault_source: {{vault_path}}/vault.json -->
<!-- generated_at: <ISO8601> -->
```

`new_string`:
```
<!-- generated_by: mega-sdd:emit-agents-md v1.2.3 -->
<!-- vault_source: {{vault_path}}/vault.json -->
<!-- generated_at: <ISO8601> -->
<!-- vault_version: {{vault_version}} -->
<!-- constitution_hash: {{constitution_hash}}   ← OMIT line if source absent -->
<!-- properties_validated: {{properties_validated}}   ← OMIT line if source absent -->
<!-- replay_snapshot_count: {{replay_snapshot_count}}   ← OMIT line if value is 0 -->
<!-- convergence_cycle_count: {{convergence_cycle_count}}   ← OMIT line if value is 0 -->
```

- [ ] **Step 6: Document the new header fields in procedure step 5**

Use Edit on `emit-agents-md/SKILL.md` — find the Task-1-modified step 5 (variable substitution paragraph) and extend it.

`old_string`:
```
5. **Render per template** in `references/agents-md-schema.md`. Cite vault file:section for every claim (anti-halu rail: AGENTS.md is a flattened view, must cite source). **Variable substitution (v1.2.3+, Iter 26 — closes P1-A from v3.17.0 verification audit):** the `{{vault_path}}` template token in the output is replaced at render time with the actual detected vault directory (relative to repo root). On v3.4+ canonical layout → `.mega-sdd/vaults/<slug>`; on legacy layout → `docs/mega-sdd/vaults/<slug>`. NEVER hard-code either path — use the probe result from step 1.
```

`new_string`:
```
5. **Render per template** in `references/agents-md-schema.md`. Cite vault file:section for every claim (anti-halu rail: AGENTS.md is a flattened view, must cite source). **Variable substitution (v1.2.3+, Iter 26 — closes P1-A + P1-9 from v3.17.0 verification audit):**
   - `{{vault_path}}` → actual detected vault directory relative to repo root. v3.4+ canonical → `.mega-sdd/vaults/<slug>`; legacy → `docs/mega-sdd/vaults/<slug>`. NEVER hard-code either path.
   - `{{vault_version}}` → `vault.json` `version` field
   - `{{constitution_hash}}` → from `binding.md` frontmatter (only if `<vault>/constitution.md` exists AND binding has been written); OMIT entire header line otherwise
   - `{{properties_validated}}` → from `vault.json` `properties_summary.total` (only if ≥1 unit has `properties:` block); OMIT line otherwise
   - `{{replay_snapshot_count}}` → from `vault.json` `replay_state.snapshot_count` (only if value > 0); OMIT line otherwise
   - `{{convergence_cycle_count}}` → from `vault.json` `convergence_state.cycles_completed` (only if value > 0); OMIT line otherwise
   - Per `references/agents-md-schema.md` §Conditional header field presence — each field renders ONLY when its source data exists; absent → line omitted, NEVER rendered with placeholder values.
```

- [ ] **Step 7: Verify both files updated**

Run: `grep -ciE 'properties_validated|cycle_count|replay_snapshot|convergence_cycle_count' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/references/agents-md-schema.md`

Expected: ≥3 (each field mentioned at least once in header schema + conditional table + anti-halu rails).

Run: `grep -ciE '{{properties_validated}}|{{replay_snapshot_count}}|{{convergence_cycle_count}}|{{constitution_hash}}' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/SKILL.md`

Expected: 4 (each template var appears in the output template).

- [ ] **Step 8: Commit (no version bump — emit-agents-md was already bumped to 1.2.3 in Task 1)**

```bash
git add plugins/mega-sdd/skills/emit-agents-md/references/agents-md-schema.md plugins/mega-sdd/skills/emit-agents-md/SKILL.md
git commit -m "$(cat <<'EOF'
feat(iter-26): emit-agents-md schema surfaces PBT/replay/convergence (P1-9)

Closes P1-9 from v3.17.0 verification audit. Iter 17 propagated
constitution_hash to AGENTS.md header; Iter 18 (PBT properties)
and Iter 19 (convergence loops) state were never surfaced. Tools
consuming AGENTS.md could not see this vault state.

AGENTS.md header now optionally declares:
- constitution_hash (Iter 17 — was partially present; now formalized)
- properties_validated (Iter 18 — PBT invariant total)
- replay_snapshot_count (Iter 18 — regression baseline count)
- convergence_cycle_count (Iter 19 — auto-recovery cycle count)

All four fields are CONDITIONAL — rendered only when source data
exists in vault.json or binding.md; omitted (not placeholdered)
otherwise. Schema doc + emit template + procedure all updated.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Bump plugin version + CHANGELOG entry

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md` (root)

- [ ] **Step 1: Bump plugin.json version 3.17.0 → 3.18.0**

Read current state via `cat plugins/mega-sdd/.claude-plugin/plugin.json` to see current shape.

Use Edit:

`old_string`:
```
  "version": "3.17.0",
```

`new_string`:
```
  "version": "3.18.0",
```

- [ ] **Step 2: Append `[3.18.0]` entry to CHANGELOG.md**

Read the top of CHANGELOG.md to find the existing `[3.17.0]` entry and the section above it (the `## [Unreleased]` section if present, or the first version section).

Use Edit to insert a new `## [3.18.0] — 2026-05-23` section above the existing `## [3.17.0]` entry:

`old_string`:
```
## [3.17.0] — 2026-05-23
```

`new_string`:
```
## [3.18.0] — 2026-05-23

### Iter 26 — Verification audit closure

Closes 5 highest-leverage gaps from v3.17.0 verification audit at `docs/superpowers/audits/2026-05-23-iter-25-verification-audit.md`.

**Fixed**
- **(P1-A)** `emit-agents-md` output template — hard-coded `docs/mega-sdd/vaults/<slug>/` paths replaced with `{{vault_path}}` substitution. Every v3.4+ project running emit-agents-md was getting a polluted AGENTS.md whose annotations pointed to a non-existent path. Skill bump: 1.2.2 → 1.2.3.
- **(P0-1)** `bind-codebase` step 2.10 (Constitution-aware CONFLICT surfacing) placed in linear sequence between 2.11 and step 3. Was physically positioned AFTER step 6 (audit log), breaking procedure flow. Also de-cluttered step 2.11's chatty renumbering self-reference. Skill bump: 1.9.1 → 1.9.2.
- **(P0-4)** `generate-units` step ordering: 7.5 (PageRank) and 7.6 (collision check) swapped to monotonic order; step 12 (audit log) renumbered to step 13 and moved AFTER step 12.6 so the audit event reflects all post-write validation outcomes. Skill bump: 2.5.1 → 2.5.2.
- **(P0-8)** `diff-vault:318` cross-reference to `references/vault-contract.md` (which doesn't exist in diff-vault/references/) repointed to `../generate-intent/references/vault-contract.md`. Skill bump: 1.2.0 → 1.2.1.
- **(P1-B)** README + plugin README version metadata sweep — root README and plugin README both shipped v3.13.0 / v3.8.0 banners and a stale 11-skill inventory table with 12 of 13 stale per-skill versions. All bumped to v3.18.0 + current skill versions; anti-halu list completed from 10 to claimed 13 items.
- **(P1-C)** `commands/orchestrate-flow.md` refreshed — added `--deep` and `--resume` flags to argument-hint, removed obsolete "max 3 per chain" claim.
- **(P1-9)** `agents-md-schema.md` extended with PBT (`properties_validated`), replay (`replay_snapshot_count`), and convergence (`convergence_cycle_count`) header fields. Iter 17 constitution_hash formalized in the same conditional-rendering schema. Output template + procedure updated to populate the new fields (conditional render — omit, never placeholder).

**Updated skills**
- `emit-agents-md` 1.2.2 → 1.2.3
- `bind-codebase` 1.9.1 → 1.9.2
- `generate-units` 2.5.1 → 2.5.2
- `diff-vault` 1.2.0 → 1.2.1

**Plugin** 3.17.0 → 3.18.0.

**Audit closure rate (per verification methodology):** 7 of 7 P0/P1 high-leverage findings closed. Architectural items (halt-taxonomy consolidation, schema-coherence linter) intentionally deferred to a later iter per audit recommendation.

---

## [3.17.0] — 2026-05-23
```

- [ ] **Step 3: Verify plugin manifest + CHANGELOG state**

Run: `grep '"version":' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/.claude-plugin/plugin.json`

Expected:
```
  "version": "3.18.0",
```

Run: `grep -m 2 '^## \[' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/CHANGELOG.md`

Expected:
```
## [3.18.0] — 2026-05-23
## [3.17.0] — 2026-05-23
```

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(iter-26): bump plugin 3.17.0 -> 3.18.0 + CHANGELOG entry

Iter 26 release — verification audit closure (7 of 7 highest-leverage
P0/P1 findings closed). See CHANGELOG.md [3.18.0] for details.

Architectural items (halt-taxonomy consolidation, schema-coherence
linter) intentionally deferred per audit recommendation.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Run trigger-tests + final cross-cutting verification

**Files:** No edits. Read-only verification.

Per `plugins/mega-sdd/CLAUDE.md` §Release Process step 2: "Run all `tests/skill-triggering/*.test.md` manually". These are markdown fixtures, not executable tests — verification is by reading and confirming the trigger fixtures still match current skill descriptions.

- [ ] **Step 1: Inventory trigger tests**

Run: `ls /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/tests/skill-triggering/`

Expected: list of `<skill>.test.md` fixtures (one per skill). Spot-check at least the 4 skills modified in this iter:
- emit-agents-md
- bind-codebase
- generate-units
- diff-vault

- [ ] **Step 2: Read each modified-skill trigger test and confirm fixture phrases still appear in the current SKILL.md description**

For each of the 4 skills above:

Run: `cat tests/skill-triggering/<skill>.test.md` and note the keyword phrases listed as "triggers".

Run: `grep -F '<phrase>' plugins/mega-sdd/skills/<skill>/SKILL.md` for each phrase.

Expected: every trigger phrase from the test fixture still resolves in the SKILL.md description field. If any fixture phrase no longer matches the description (because we de-cluttered chatty annotations in Task 2), update the fixture to match. Note any drift but do NOT silently rewrite — surface to user.

- [ ] **Step 3: Cross-cutting grep — no stale legacy paths in production templates**

These greps must return zero hits in template/emission contexts (legacy in compat-clause is OK):

Run: `grep -rn 'docs/mega-sdd/vaults' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/emit-agents-md/SKILL.md`

Expected: empty (Task 1 closed this).

Run: `grep -nE '^version: ' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/*/SKILL.md`

Expected: 13 lines, all present, all bumped post-Iter-26 to the values declared in Task 5's table.

- [ ] **Step 4: Cross-cutting grep — version consistency**

Run: `grep -rn '3\.18\.0' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/README.md /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/README.md /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/CHANGELOG.md /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/.claude-plugin/plugin.json`

Expected: ≥8 hits across all 4 files (3 in root README, ≥4 in plugin README, ≥1 in plugin.json, ≥1 in CHANGELOG).

Run: `grep -E '3\.13\.0|3\.8\.0' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/README.md /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/README.md`

Expected: empty (no stale annotations remaining outside of CHANGELOG history).

- [ ] **Step 5: Cross-cutting grep — step monotonicity in modified skills**

Run: `grep -nE '^[0-9]+\.[0-9]*\.' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/bind-codebase/SKILL.md | head -25`

Expected: step numbers appear in monotonically non-decreasing order. No "2.10" appearing after "3", "4", "5", "6".

Run: `grep -nE '^[0-9]+\.[0-9]*\.' /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/skills/generate-units/SKILL.md | head -30`

Expected: step numbers appear in monotonically non-decreasing order. 7.5 before 7.6; 13 after 12.6.

- [ ] **Step 6: Final git log review**

Run: `git -C /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec log --oneline -10`

Expected: 8 new commits added on top of `69fb3c3` (Tasks 1-8). Each commit message references the audit ID it closes.

- [ ] **Step 7: Per `CLAUDE.md` step 5, do NOT tag/push without user approval**

Show user the complete diff (`git -C ... log --stat -8`) and the final state. Surface any drift discovered in Step 2 (trigger-test phrase mismatches) for user review BEFORE tagging or pushing. User explicitly approves before `git tag` or `git push`.

This task is COMPLETE when verification passes; tagging and push remain user-gated per CLAUDE.md.

---

## Self-review

**Spec coverage:** Each of the 5 audit-recommended Iter 26 items maps to one or more tasks:
- (1) emit-agents-md output template → Task 1
- (2) P0-1/P0-4/P0-8 partials → Tasks 2, 3, 4
- (3) README version sweep → Task 5
- (4) commands/orchestrate-flow.md refresh → Task 6
- (5) P1-9 PBT/replay/convergence in agents-md-schema → Task 7

Plus required infra: Task 8 (plugin bump + CHANGELOG) and Task 9 (verification + trigger tests).

**Placeholder scan:** Every step has concrete edits, exact strings, and verification commands. No "TBD", "implement later", or "appropriate error handling". Two edits in Task 3 (Step 4) use a conditional pattern ("If grep reveals the next section is something other than X, adjust accordingly") — this is appropriate because the surrounding context depends on the file's actual current state at the time of execution; the principle is unambiguous.

**Type consistency:**
- `{{vault_path}}`, `{{vault_version}}`, `{{constitution_hash}}`, `{{properties_validated}}`, `{{replay_snapshot_count}}`, `{{convergence_cycle_count}}` — same template-variable shape used in both schema doc (Task 7 Step 2) and emit template (Task 7 Step 5). Consistent.
- Version-bump targets in Task 5's table match what Tasks 1-4 declare. Consistent.
- Skill version strings: `1.2.3`, `1.9.2`, `2.5.2`, `1.2.1` appear in commits, README, and CHANGELOG identically.
- Plugin version `3.18.0` consistent across plugin.json (Task 8), READMEs (Task 5), CHANGELOG (Task 8).

**Audit ID consistency:** P1-A, P1-B, P1-C, P0-1, P0-4, P0-8, P1-9 — every commit message cites the audit finding ID; every audit finding has a closing task. No orphans.

Self-review complete — plan ready for execution.
