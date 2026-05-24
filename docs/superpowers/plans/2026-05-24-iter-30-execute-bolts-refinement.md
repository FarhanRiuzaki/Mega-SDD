# Iter 30 execute-bolts Refinement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bolt subagent dispatch SHARP via tiered context enrichment (T1/T2/T3) + seamless end-to-end pipeline (compact streaming + aggregate summary + propose-and-confirm halt UX + auto-drift gate + shared snapshot machinery + convergence bridge).

**Architecture:** Markdown-driven plugin updates spanning 3 skills (execute-bolts v2.4.2→v2.6.0, orchestrate-flow v2.4.1→v2.5.0, detect-drift v1.2.2→v1.4.0) + 3 new reference files. Driven by 10 AI-executor principles from spec §4. No runtime code; all changes are SKILL.md procedure additions, reference doc creates, and CHANGELOG/README updates.

**Tech Stack:** Markdown + YAML (handoff schemas, halt envelopes, vault.json) + bash verification commands. No language-specific code.

**Spec source:** `docs/superpowers/specs/2026-05-24-iter-30-execute-bolts-refinement-design.md`

---

## File Structure

### New files (3)

| Path | Responsibility |
|---|---|
| `plugins/mega-sdd/references/shared-snapshot-schema.md` | Canonical JSON schema for bolt preflight/postflight + drift baseline snapshots; consumed by both execute-bolts and detect-drift |
| `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` | T1/T2/T3 tiered context enrichment template for bolt subagent dispatch (≤7KB total budget per spec §10) |
| `plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md` | AI fix proposer subagent prompt template for halt resolution (test_fail / hard_rule_violated / pbt_property_violated) |

### Modified files (6)

| Path | Change |
|---|---|
| `plugins/mega-sdd/skills/execute-bolts/SKILL.md` | v2.4.2 → v2.6.0: add Step 4.5 tiered context enrichment + compact streaming + `_summary.md` + propose-and-confirm + per-bolt drift + partial-state + self-assessment + provenance trailer + 4 new halt types |
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | v2.4.1 → v2.5.0: hybrid drift gate phase (default-on) + convergence bridge for bolt halts |
| `plugins/mega-sdd/skills/detect-drift/SKILL.md` | v1.2.2 → v1.4.0: auto-trigger handoff + snapshot reuse + Suggested next actions block + per-bolt incremental scan mode |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | Bump 3.21.0 → 3.22.0 |
| `plugins/mega-sdd/README.md` | Add Iter 30 to "What's new" section |
| `CHANGELOG.md` | Add Iter 30 entry |

---

## Task 1: Create shared-snapshot-schema.md reference

**Files:**
- Create: `plugins/mega-sdd/references/shared-snapshot-schema.md`

- [ ] **Step 1.1: Verify target directory exists**

```bash
ls plugins/mega-sdd/references/
```

Expected: directory exists with existing reference files (paths.md, tooling-install.md, framework-conventions/).

- [ ] **Step 1.2: Write the shared snapshot schema reference**

Write to `plugins/mega-sdd/references/shared-snapshot-schema.md` with EXACTLY this content:

```markdown
# Shared Snapshot Schema (v1.0, Iter 30)

Canonical JSON schema for code-state snapshots consumed by both `execute-bolts` (preflight/postflight per Iter 3 + Iter 6) AND `detect-drift` (baseline + per-scan, v1.4+ Iter 30).

Goal: detect-drift can reuse bolt postflight snapshots when present (≤5s drift gate on 20-bolt batch vs ≥28s full re-scan). Falls back to fresh scan when standalone drift run.

## Schema

```json
{
  "snapshot_schema_version": "1.0",
  "snapshot_type": "preflight | postflight | drift-baseline",
  "generated_by": "<skill name + version, e.g., execute-bolts@2.6.0 | detect-drift@1.4.0>",
  "generated_at": "<ISO8601 timestamp>",
  "scope": "<scope id from vault.json when multi-scope vault; null otherwise>",
  "files": [
    {
      "path": "<absolute or repo-relative path>",
      "sha256": "<64-char hex>",
      "exists": true,
      "size_bytes": <int>,
      "ast_signatures": {
        "class_definitions": ["<class name>", "..."],
        "method_signatures": [
          {"name": "<method>", "params": "<param list>", "return": "<return type>"}
        ],
        "trait_uses": ["<trait>", "..."],
        "function_definitions": ["<function name>", "..."],
        "imports": ["<import path>", "..."]
      },
      "captured_via": "tree-sitter | ast-grep | regex-fallback"
    }
  ],
  "rules_validated": [
    {
      "rule_id": "<rule identifier>",
      "rule_source": "<framework-conventions/<pack>.md §<section> | constitution §<id> | unit-derived>",
      "status": "satisfied | violated",
      "evidence": "<file:line OR null when satisfied>"
    }
  ],
  "context": {
    "unit_id": "<U-XXX when bolt-emitted; null when standalone drift>",
    "binding_state_at_capture": "<CONFIRMED | NEW | UNKNOWN | PARTIAL_FIELDS_* | null>",
    "vault_sha256": "<vault.json hash at capture time>"
  }
}
```

## Producer responsibilities

### execute-bolts (preflight)

Write to `<vault>/bolts/U-XXX/preflight.json` BEFORE bolt subagent dispatch:

- `snapshot_type: "preflight"`
- `generated_by: "execute-bolts@<version>"`
- `context.unit_id: "U-XXX"`
- `files[]`: every file in unit's `target_files` + every anchor file from unit's `## Anchors` section
- `rules_validated[]`: every Hard Rule from unit's `## Hard rules` + framework pack rules matching target_files

### execute-bolts (postflight)

Write to `<vault>/bolts/U-XXX/postflight.json` AFTER bolt subagent commits:

- `snapshot_type: "postflight"`
- Same files as preflight + any new files created during bolt
- Same rules_validated array but with post-bolt verdict
- Used by detect-drift for fast incremental scans (no re-read of files)

### detect-drift (baseline)

Write to `<vault>/_drift-baseline.json` after `bind-codebase` (Iter 30+ when no baseline exists):

- `snapshot_type: "drift-baseline"`
- `generated_by: "detect-drift@<version>"`
- `context.unit_id: null`
- `files[]`: all files referenced by vault claims (per binding.md anchors)

## Consumer responsibilities

### detect-drift

When invoked with `--reuse-bolt-snapshots` (auto-set when chained after execute-bolts batch):

1. For each unit in vault.json: read `<vault>/bolts/U-XXX/postflight.json` if present
2. Aggregate file-level sha256 + ast_signatures across all postflight snapshots
3. Compare aggregated state vs vault expectations (per detect-drift Steps 1-4)
4. For files NOT in any bolt postflight: fall back to fresh scan (typically small remainder)
5. Performance gain: skip Read + ast-extract for files already captured by bolts

When invoked standalone (`/mega-sdd:detect-drift` no chain context):

- Behave as v1.2.x: fresh full scan; ignore bolt snapshots (avoid stale data)

## Anti-halu rails

- `sha256` MUST be computed from file content at capture time (not cached from disk metadata)
- `snapshot_type` MUST match the producer's intent (mismatch → halt `snapshot_type_invalid`)
- `vault_sha256` MUST be captured at the SAME moment as `files[]` (vault edit during scan → halt `vault_modified_during_scan`)
- detect-drift MUST verify postflight snapshot is fresher than vault.json modification time (else fresh scan)
- snapshot schema version mismatch → consumer falls back to fresh scan + emits advisory

## Backward compatibility

Pre-Iter-30 bolts wrote preflight/postflight with informal JSON (per Iter 3). Iter 30 migration:

- First Iter 30 bolt run writes new schema; older snapshots remain readable but consumer treats them as `snapshot_schema_version: "0.x (legacy)"` and falls back to fresh scan
- No data migration required; old snapshots aged out naturally as bolts re-execute

## File locations summary

- Bolt snapshots: `<vault>/bolts/U-XXX/{preflight,postflight}.json`
- Drift baseline: `<vault>/_drift-baseline.json`
- Drift report: `<vault>/DRIFT-REPORT.md` (existing, per detect-drift v1.x)
```

- [ ] **Step 1.3: Verify file structure**

```bash
test -f plugins/mega-sdd/references/shared-snapshot-schema.md && echo "EXISTS"
grep -c "snapshot_schema_version" plugins/mega-sdd/references/shared-snapshot-schema.md
grep -c "snapshot_type" plugins/mega-sdd/references/shared-snapshot-schema.md
grep -c "execute-bolts (preflight)\|execute-bolts (postflight)\|detect-drift (baseline)" plugins/mega-sdd/references/shared-snapshot-schema.md
```

Expected: EXISTS, 2+, 4+, 3

- [ ] **Step 1.4: Commit**

```bash
git add plugins/mega-sdd/references/shared-snapshot-schema.md
git commit -m "$(cat <<'EOF'
feat(iter-30): shared snapshot schema reference (Iter 30 §6)

Canonical JSON schema for code-state snapshots consumed by both
execute-bolts (preflight/postflight) and detect-drift (baseline +
per-scan). Enables detect-drift to reuse bolt snapshots (~5s gate
vs ~28s full scan on 20-bolt batch).

Schema: snapshot_schema_version + files[] with sha256 + ast_signatures,
rules_validated[], context block (unit_id, binding_state, vault_sha256).
Producer/consumer responsibilities documented per skill.

Anti-halu rails: sha256 computed at capture time, vault edit during
scan halts, snapshot schema version mismatch falls back to fresh scan.

Backward compat: pre-Iter-30 snapshots treated as legacy; aged out
naturally on next bolt run.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Create bolt-dispatch-prompt.md reference (the T1/T2/T3 template)

**Files:**
- Create: `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md`

- [ ] **Step 2.1: Write the tiered context enrichment template**

Write to `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` with EXACTLY this content:

```markdown
# Bolt Subagent Dispatch Prompt Template (v1.0, Iter 30)

Canonical prompt template for dispatching bolt subagent via superpowers `executing-plans`. Implements the 10 AI-executor principles from spec §4. Tiered context (T1/T2/T3) per spec §6.10.

**Token budget**: T1 ≤2KB, T2 ≤5KB, T3 reference-only. Total dispatch prompt ≤7KB (hard cap 10KB → halt `dispatch_prompt_too_large`).

## Template structure

```
═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-XXX
═══════════════════════════════════════════

UNIT: <id> "<title>"
SCOPE: <scope_id> (<scope_name>) — framework: <framework_pack>

═══════════════════════════════════════════
TIER 1 — Always read (target ≤2KB)
═══════════════════════════════════════════

## Unit body (verbatim)
<full unit frontmatter + body — non-negotiable>

## Halt vocabulary (pre-loaded for clean halts)

IF YOU CAN'T PROCEED, HALT WITH ONE OF:
  type: test_fail              (after 3 retries; include test name + output)
  type: hard_rule_violated     (cite rule + file:line evidence)
  type: ambiguous_spec         (cite ambiguity + 2 interpretations + your default)
  type: missing_dependency     (cite what's missing + where you looked)
  type: scope_creep_detected   (asked to touch files outside target_files)

Halt YAML template (fill placeholders):
```yaml
blocker:
  type: <halt_type>
  emitted_at: <ISO8601>
  emitted_by: bolt-subagent-U-XXX
  unit_id: U-XXX
  details:
    <halt-type-specific fields>
  next_action: "<suggested user action>"
```

## Self-assessment vocabulary (REQUIRED in bolt-report.md)

```yaml
bolt_self_report:
  confidence: <0.0-1.0>
  certain_decisions:
    - "<decision with HIGH confidence>"
  uncertain_decisions:
    - decision: "<what you did>"
      rationale: "<why>"
      fallback_if_wrong: "<safer alternative>"
  retry_history:
    - attempt: <int>
      failure: "<verbatim failure>"
      fix: "<what you changed>"
```

## Atomic discipline (scaffolded, not assumed)

- THIS BOLT = ONE COMMIT
- target_files whitelist: <list from unit frontmatter> — DO NOT touch outside
- Commit message format: "feat(U-XXX): <imperative phrase from unit title>"
- DO NOT bundle unrelated concerns
- If you find yourself wanting to modify unrelated file → halt `scope_creep_detected`

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY: <list of LOCKED files from data-mutation-policy.md>
DO NOT REPLICATE: <list of KB anti-patterns relevant to this unit's domain>
DO NOT WRITE: <forbidden patterns from framework pack — e.g., $(document).ready()>
DO NOT COMMIT IF: <preconditions — e.g., test failures, hard rule violations, missing provenance trailer>

## Provenance trailer (MANDATORY in every modified file)

Add at top of file (language-appropriate comment):
```
Generated by mega-sdd execute-bolts <version>
Unit: U-XXX (vault sha256: <hash>)
Implements claim: C-NNN "<claim text>"
Anchors consulted: <list>
Hard Rules active: <list of rule IDs>
```

Post-flight scan VERIFIES presence. Missing → halt `provenance_missing`.

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤5KB total)
═══════════════════════════════════════════

## Upstream bolts (depends_on chain — 1-line summary each)

<for each upstream bolt in depends_on:>
- U-<id> "<title>" → committed at <sha>
  └─ <1-line summary from bolt-report.md self-report>

## Framework pack rules (filtered by your target_files glob match)

<for each rule in framework pack where rule.path_glob matches any unit.target_files:>
- <rule-id> (from <pack>.md §<section>)
  └─ <rule body>

## Constitution clauses (referenced by your vault_source)

<for each clause in constitution.md where clause was cited in unit's vault_source sections:>
- §<id>: <clause text>

## KB anti-patterns (filtered by your domain tags)

<for each KB anti-pattern matching unit's domain tags:>
- KB <gotcha-id> from <kb-file>.md: <anti-pattern description>
  └─ DO NOT REPLICATE per <constitution clause OR explicit rationale>

## Historical memory (last 5 relevant patterns)

<from <project>/.mega-sdd/memory/outcomes.md, filtered by:>
<- bolts touching similar files (overlap with this unit's target_files)>
<- bolts with similar patterns (same unit type, same scope)>
<show last 5 only, most-recent-first>

Pattern: <pattern-description> → <past resolution>

## Confidence labels per claim

<for each claim this unit implements (from binding.md):>
- [<HIGH | MEDIUM | LOW>] <claim text>
  └─ Source: <binding citation OR KB inference OR heuristic default>

## Validation hints (specific, not vague)

After implementation, run:
```bash
<specific test command, e.g., ./vendor/bin/phpunit tests/Unit/UserModelTest.php>
```

Expected output pattern: <e.g., "OK (3 tests, X assertions)">
On fail: <failure interpretation — what failing test name encodes>

Also run static analysis (if framework pack specifies):
```bash
<e.g., ./vendor/bin/phpstan analyse <target file> -l 5>
```

Must pass at <pack-specified level>.

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `<vault>/bolts/U-XXX/bolt-report.md`
- Full constitution: `<vault>/constitution.md`
- Full KB domain files: `.mega-sdd/knowledge-base/10-domains/`
- Full memory tables: `<project>/.mega-sdd/memory/`
- Full framework pack: `plugins/mega-sdd/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
GENERATE CODE THAT:
═══════════════════════════════════════════

- Uses target framework conventions per pack (Tier 2 §Framework pack rules)
- Respects all [HIGH] claims 1:1 (Tier 2 §Confidence labels)
- Cites anchors when extending existing patterns
- NEVER replicates anti-patterns (Tier 2 §KB anti-patterns + Tier 1 §Anti-context)
- Emits provenance trailer in every modified file (Tier 1 §Provenance trailer)
- Halts cleanly per halt vocabulary if stuck (Tier 1 §Halt vocabulary)
- Self-reports via bolt_self_report YAML at end of bolt-report.md (Tier 1 §Self-assessment vocabulary)
```

## Tier-loading algorithm

Per execute-bolts SKILL.md Step 4.5:

```
ASSEMBLE_DISPATCH_PROMPT(unit, vault, codebase_map):
  prompt = ""

  # T1 — Always load (≤2KB)
  prompt += load_t1(unit)  # unit body + halt vocab + self-assess + atomic + anti-context + provenance

  # T2 — Conditional load (≤5KB total)
  prompt += load_upstream_summaries(unit.depends_on)
  prompt += filter_pack_rules(codebase_map.framework_pack, unit.target_files)
  prompt += filter_constitution(vault.constitution, unit.vault_source)
  prompt += filter_kb_anti_patterns(vault.kb, unit.domain_tags)
  prompt += filter_memory(project.memory.outcomes, unit, limit=5)
  prompt += confidence_labels(unit.claims, vault.binding)
  prompt += validation_hints(unit, codebase_map.framework_pack)

  # T3 — Reference-only (≤0.5KB just paths)
  prompt += t3_references_list(vault, project)

  # Size check
  if size(prompt) > 10_000:  # 10KB hard cap
    halt("dispatch_prompt_too_large", {
      "unit_id": unit.id,
      "current_size_bytes": size(prompt),
      "cap_bytes": 10000,
      "next_action": "Re-tier (move T2 items to T3 reference-only) OR split unit into smaller bolts"
    })

  return prompt
```

## Anti-halu rails

- T2 filtering MUST cite source for inclusion (e.g., "framework pack rule X loaded because target_files matched glob Y")
- Anti-context block populated from actual data sources (data-mutation-policy.md, KB, framework pack) — NEVER invented
- Confidence labels MUST cite source (binding C-NNN OR KB inference OR heuristic default with rationale)
- Validation hints MUST be specific commands (not "run tests")
- Provenance trailer template MUST include actual values (unit_id, vault_sha256, claim_id, anchors, rule_ids), not placeholders

## Logging

Per execute-bolts SKILL.md Step 4.5e: log final assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` for provenance + auditability.

## Backward compatibility

Pre-v2.6.0 execute-bolts dispatched bolt subagent with raw unit body + general project context (no tiered enrichment). v2.6.0 introduces this template; opt-out NOT available (the principles are the contract for AI-executor sharpness).

Pre-existing bolts (already-committed) are not re-dispatched; this template applies only to new bolt runs.
```

- [ ] **Step 2.2: Verify**

```bash
test -f plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md && echo "EXISTS"
grep -c "TIER 1\|TIER 2\|TIER 3" plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md
grep -c "Halt vocabulary\|Self-assessment vocabulary\|Atomic discipline\|Anti-context\|Provenance trailer" plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md
grep -c "ASSEMBLE_DISPATCH_PROMPT\|halt(\"dispatch_prompt_too_large\"" plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md
```

Expected: EXISTS, 4+, 5+, 2

- [ ] **Step 2.3: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md
git commit -m "$(cat <<'EOF'
feat(iter-30): bolt-dispatch-prompt.md template (Iter 30 §10)

Canonical T1/T2/T3 tiered context enrichment template for bolt
subagent dispatch. Implements 10 AI-executor principles from
spec §4.

T1 (always, ≤2KB): unit body + halt vocab + self-assess vocab
  + atomic discipline + anti-context + provenance trailer
T2 (conditional, ≤5KB): upstream summaries + filtered pack rules
  + constitution clauses + KB anti-patterns + memory patterns
  + confidence labels + validation hints
T3 (reference-only, ≤0.5KB): paths to full files for on-demand
  Read access

Total budget ≤7KB; hard cap 10KB → halt dispatch_prompt_too_large.

Includes pseudocode tier-loading algorithm + anti-halu rails
(source citations for every inclusion, no invention).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Create propose-and-confirm-prompt.md reference

**Files:**
- Create: `plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md`

- [ ] **Step 3.1: Write AI fix proposer subagent prompt template**

Write to `plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md` with EXACTLY this content:

```markdown
# Propose-and-Confirm Prompt Template (v1.0, Iter 30)

Canonical prompt for AI fix proposer subagent dispatched when bolt halts with eligible halt type. User reviews proposed fix + approves/rejects via AskUserQuestion.

**Eligible halt types** (per spec §6.3):
- `test_fail` (after default 3 retries)
- `hard_rule_violated` (with framework pack provenance evidence)
- `pbt_property_violated` (counterexample preserved)

**NOT eligible** (always pure pause; never propose fix):
- `oq_business_p1_unresolved` (needs human business decision)
- `dedup_ambiguous` (needs human judgment)
- `quality_gate_failed` (broader investigation needed)
- `constitution_drift_detected` (audit-significant)
- `bolt_repeated_partial_failure` (structural problem)
- `provenance_missing` (post-flight detected; user must add trailer)

## Subagent dispatch contract

execute-bolts post-flight detects halt → if halt type eligible → dispatch fix-proposer subagent with this template → render result via AskUserQuestion → on user-accept apply fix + re-execute bolt → on user-reject continue chain pause.

## Prompt template

```
ROLE: AI fix proposer for mega-sdd bolt halt.

CONTEXT:
- Bolt halt type: <halt_type>
- Unit: <unit_id> "<title>"
- Scope: <scope_id>
- Halt details (verbatim from halt YAML):
  <verbatim halt YAML block>

EVIDENCE FILES (read these via Read tool):
- Unit body: <vault>/units/U-XXX.md
- Bolt report: <vault>/bolts/U-XXX/bolt-report.md (includes bolt's self-assessment + retry history)
- Preflight snapshot: <vault>/bolts/U-XXX/preflight.json
- Postflight snapshot: <vault>/bolts/U-XXX/postflight.json (if any)
- Halt-type-specific evidence:
  - test_fail: failing test file from halt details
  - hard_rule_violated: violating file (from halt details) + framework pack rule definition
  - pbt_property_violated: counterexample input + failing property definition

TASK:

1. Read evidence files in order: bolt-report.md first (bolt's own assessment), then halt-type-specific evidence
2. Identify root cause:
   - For test_fail: parse failure output; cross-reference with bolt's uncertain_decisions to see if bolt flagged uncertainty in this area
   - For hard_rule_violated: locate violation file:line; understand rule intent from pack/constitution
   - For pbt_property_violated: analyze counterexample; identify code path that violates invariant
3. Propose SPECIFIC fix:
   - Identify minimal code change (single function, single validation rule, single config tweak — NOT broad refactor)
   - Cite exact file:line where fix should apply
   - Show diff-like before/after for the change
   - Cite EVIDENCE chain (e.g., "bolt's uncertain_decisions[0] already flagged validation area; test asserts 200 status (line 47); RefundRequest.php lacks rule for refund_amount cap")
4. Estimate confidence (0.0-1.0) that this fix will resolve the halt
5. Optionally propose 1-2 ALTERNATIVE fixes (if multiple valid approaches exist)

DISCIPLINE (non-negotiable):
- NEVER propose a fix without evidence chain (cite specific anchors in evidence files)
- NEVER propose changes outside the failing bolt's target_files (would be scope creep — surface as halt_escalation instead)
- NEVER propose changes to LOCKED files (per vault data-mutation-policy.md)
- If you cannot determine root cause from evidence → return overall_confidence: LOW + describe what additional context you'd need
- If halt type ineligible (somehow dispatched anyway) → return refusal with reason

OUTPUT FORMAT (exact YAML structure, no prose preamble):

```yaml
proposed_fix:
  unit_id: U-XXX
  halt_type: <halt_type>
  root_cause: "<1-2 sentence summary>"
  evidence_chain:
    - "<file:line> — <what it shows>"
    - "<file:line> — <what it shows>"
  fix:
    file: <relative path>
    location: "<line N OR after function X OR within Y block>"
    change_type: add | modify | remove
    diff:
      before: |
        <verbatim code before change OR null for additions>
      after: |
        <verbatim code after change>
    rationale: "<why this fix resolves the halt>"
  re_execution_plan:
    - "Apply fix to <file>"
    - "Run: <validation command from unit's acceptance_test>"
    - "Expect: <expected outcome>"
  confidence: <0.0-1.0>
  alternative_fixes:  # OPTIONAL, only if multiple valid approaches exist
    - file: <path>
      change: "<brief description>"
      tradeoff: "<why this is alternative, not primary>"
  refusal:  # ONLY if cannot propose fix (overrides above fields)
    reason: "<why fix cannot be proposed>"
    missing_context: ["<what would help>"]
```

## Main thread post-processing

After subagent returns:

1. Parse output YAML
2. Render to user via AskUserQuestion (per execute-bolts SKILL.md propose-and-confirm halt UX):

```
⛔ <Unit-ID> halted: <halt_type> (<retries> retries)
   <halt summary, e.g., test name + failure>
   Bolt confidence: <from bolt-report self-assessment>
   
   AI proposed fix (review evidence below):
   ┌─────────────────────────────────────────────────────────────
   │ Root cause: <proposed_fix.root_cause>
   │ 
   │ Fix: <file> @ <location>
   │   <diff.before> → <diff.after>
   │ 
   │ Re-run: <re_execution_plan command>
   │ 
   │ Evidence trace:
   │ - <evidence_chain[0]>
   │ - <evidence_chain[1]>
   │ - ...
   │ Confidence: <confidence>
   └─────────────────────────────────────────────────────────────
   
❓ How to proceed?
   [1] Apply proposed fix + re-execute (recommended if confidence ≥0.75)
   [2] Show alternative fix options (if alternative_fixes present)
   [3] Reject — I'll fix manually then /mega-sdd:auto --resume
   [4] Cancel chain — pause everything for review
   [5] Override halt — accept current state as "good enough" (logs to memory)
```

3. On user accept (option 1): apply diff to file → re-execute single bolt → continue batch
4. On user reject (option 3): write proposed_fix to `<vault>/bolts/U-XXX/proposed-fix.md` (preserved for next session) → continue chain pause
5. On user override (option 5): record decision to `<project>/.mega-sdd/memory/decisions.md` "Override accepted halt <halt_type> on <unit_id>" → mark unit as `status: forced_pass` → continue batch (high-risk; audit log mandatory)

## Confidence-driven defaults

- `confidence ≥0.85` → recommend option 1 (Apply + re-execute) as default
- `0.60 ≤ confidence < 0.85` → no default recommendation; user picks
- `confidence < 0.60` → default option 3 (Reject; manual fix) — fix-proposer flagging uncertainty
- Always show confidence prominently in UI

## Halt cycle safety

Per spec §6.7: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop). Logic:

```
if bolt.halt_history[-2:].halt_type == halt_type AND
   bolt.halt_history[-2:].proposed_fix_ids are different:
  halt("bolt_repeated_partial_failure", {...})
```

This prevents propose-and-confirm from looping on a structurally-broken unit.

## Anti-halu rails

- Subagent MUST cite line numbers for every evidence claim
- Subagent MUST NOT modify any files (read-only analyzer; main thread applies)
- Subagent MUST refuse if halt type is ineligible (defensive check even if main thread already filtered)
- Subagent confidence MUST be 0.0-1.0 (not "high" / "medium" / "low" strings — numeric for default-recommendation logic)
- alternative_fixes capped at 2 (avoid analysis paralysis)
- Refusal path takes precedence over fix path if both populated

## Performance

Subagent dispatch overhead: ~5-10s per halt. Acceptable because halts are rare in clean runs + user is already paused awaiting decision.

Average bolt run with 1 halt + propose-and-confirm: ~30s additional vs pure pause (~5s dispatch + ~20s user review + ~5s apply). vs current `--resume` flow (~minutes for user to fix manually).

## Backward compatibility

Pre-Iter-30 halts always paused for manual `--resume`. Iter 30 propose-and-confirm is opt-IN via halt type eligibility + user config (`~/.mega-sdd/memory/config.yaml` `halt_auto_propose` block per spec §6.3). Disable per-type via config:

```yaml
halt_auto_propose:
  test_fail: pause             # disable propose-and-confirm for test_fail
```

Default: all eligible types propose. User-explicit `pause` override always honored.
```

- [ ] **Step 3.2: Verify**

```bash
test -f plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md && echo "EXISTS"
grep -c "Eligible halt types\|NOT eligible\|OUTPUT FORMAT\|Anti-halu rails\|Halt cycle safety" plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md
grep -c "proposed_fix:\|evidence_chain:\|confidence:" plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md
grep -c "bolt_repeated_partial_failure" plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md
```

Expected: EXISTS, 5, 3+, 2 (cycle safety mention + halt type list)

- [ ] **Step 3.3: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md
git commit -m "$(cat <<'EOF'
feat(iter-30): propose-and-confirm-prompt.md template (Iter 30 §6.3)

AI fix proposer subagent prompt template for halt resolution.
Eligible halt types: test_fail, hard_rule_violated,
pbt_property_violated. Ineligible (always-pause): oq_business_p1_*,
dedup_ambiguous, quality_gate_failed, constitution_drift_detected,
bolt_repeated_partial_failure, provenance_missing.

Subagent reads evidence files (unit body, bolt-report, snapshots,
halt-type-specific files) → identifies root cause → proposes
SPECIFIC fix with diff + evidence chain + confidence score +
optional alternatives.

Main thread renders via AskUserQuestion (5 options: Apply / Alt /
Reject / Cancel / Override) with confidence-driven default
recommendation.

Halt cycle safety: same halt twice with different fixes →
bolt_repeated_partial_failure (always-stop).

Anti-halu rails: subagent NEVER modifies files (read-only
analyzer); main thread applies. Cite line numbers for every
evidence claim.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: execute-bolts SKILL.md — bump version + add Step 4.5 tiered context enrichment

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md`

- [ ] **Step 4.1: Read current version**

```bash
head -5 plugins/mega-sdd/skills/execute-bolts/SKILL.md
```

Expected: `version: 2.4.2`. If different, report STATE.

- [ ] **Step 4.2: Bump version**

Use Edit tool:
- Find: `version: 2.4.2`
- Replace: `version: 2.6.0`

- [ ] **Step 4.3: Add Step 4.5 to Procedure section**

First find where Step 4 ends and Step 5 begins:

```bash
grep -nE "^4\.\s|^5\.\s|## Procedure" plugins/mega-sdd/skills/execute-bolts/SKILL.md | head -10
```

Find existing Step 4 (Hard Rule pre-flight scan) — it ends with the snapshot persistence around line 90-100. Step 5 begins with execution via superpowers.

Use Edit tool. Find the existing text that introduces Step 5 (look for "Execution via superpowers" or similar). Insert new Step 4.5 BEFORE it:

```markdown

## Step 4.5: Tiered context enrichment per bolt (v2.6.0+, Iter 30)

Per `references/bolt-dispatch-prompt.md` template. Implements the 10 AI-executor principles from spec §4. Total dispatch prompt budget ≤7KB (hard cap 10KB → halt `dispatch_prompt_too_large`).

a. **Load TIER 1 (always included, target ≤2KB)**:
   - Unit body (frontmatter + body sections)
   - Halt vocabulary block (5 halt types + YAML templates)
   - Self-assessment vocabulary template
   - Atomic commit discipline reminder
   - Anti-context block (DO NOT MODIFY / DO NOT REPLICATE / DO NOT WRITE / DO NOT COMMIT IF)
   - Provenance trailer template

b. **Load TIER 2 (conditional, target ≤5KB total)**:
   - depends_on chain: 1-line summary per upstream bolt (read each bolt-report.md self-assessment)
   - Framework pack rules: filter pack file by `path_glob` match against this unit's `target_files`
   - Constitution clauses: ONLY clauses referenced in this unit's `vault_source` sections
   - KB anti-patterns: filter KB by this unit's domain tags
   - Historical memory: filter `<project>/.mega-sdd/memory/outcomes.md` for "bolts touching similar files OR similar pattern" — last 5 only
   - Confidence labels per claim (HIGH from binding C-NNN, MEDIUM from KB inference, LOW from heuristic with rationale)
   - Validation hints (specific test commands + expected output patterns)

c. **TIER 3 (NOT embedded; reference-on-demand via Read tool)**:
   - Full upstream bolt-reports
   - Full constitution
   - Full KB domain files
   - Full memory tables
   - Full framework pack

d. **Size check**:
   - If assembled prompt > 10KB → halt `dispatch_prompt_too_large` with re-tier guidance

e. **Log final prompt**:
   - Write assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` for provenance + auditability

f. **Partial-state contract**:
   - If bolt subagent crashes mid-execution, write `<vault>/bolts/U-XXX/partial-state.json` per `references/shared-snapshot-schema.md`-like format:
     - files modified (with current sha256)
     - last test result (if any)
     - last AI action / current step
   - Resume reads partial-state, doesn't start from zero
   - After 3 partial-state attempts → halt `bolt_repeated_partial_failure`

g. **Dispatch via superpowers.executing-plans** with the enriched prompt as plan body.

Anti-halu rails:
- T2 filtering MUST cite source for inclusion (e.g., "framework pack rule X loaded because target_files matched glob Y")
- Anti-context block populated from actual data sources (data-mutation-policy.md, KB, framework pack) — NEVER invented
- Self-assessment confidence MUST be 0.0-1.0 numeric (not strings); halt if omitted
- Provenance trailer MANDATORY in every modified file — post-flight scan verifies presence; missing → halt `provenance_missing`

```

- [ ] **Step 4.4: Verify**

```bash
grep "version: 2.6.0" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "Step 4.5" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "Tiered context enrichment\|TIER 1\|TIER 2\|TIER 3" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "dispatch_prompt_too_large\|bolt_repeated_partial_failure\|provenance_missing" plugins/mega-sdd/skills/execute-bolts/SKILL.md
```

Expected: 1, 1+, 4+, 3

- [ ] **Step 4.5: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md
git commit -m "$(cat <<'EOF'
feat(execute-bolts v2.6.0): Step 4.5 tiered context enrichment (Iter 30 §10)

Bumps version 2.4.2 → 2.6.0 (major minor — new dispatch model).

NEW Step 4.5 in Procedure: tiered context enrichment per
references/bolt-dispatch-prompt.md template. Replaces raw unit
body dispatch with structured T1/T2/T3 enriched prompt (≤7KB
budget, 10KB hard cap).

T1 always: unit body + halt vocab + self-assess + atomic +
anti-context + provenance trailer.
T2 conditional: upstream summaries + filtered pack rules +
constitution + KB anti-patterns + memory + confidence labels +
validation hints.
T3 reference-only: paths to full files for on-demand Read.

New halts: dispatch_prompt_too_large, bolt_repeated_partial_failure,
provenance_missing.

Includes partial-state preservation contract (crash mid-bolt
recoverable via partial-state.json).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: execute-bolts SKILL.md — compact streaming format + aggregate _summary.md

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md`

- [ ] **Step 5.1: Find Outputs section**

```bash
grep -n "^## Outputs\|^## Hand-off" plugins/mega-sdd/skills/execute-bolts/SKILL.md | head -3
```

- [ ] **Step 5.2: Add Compact streaming + summary section before Outputs**

Use Edit tool. Find `## Outputs` heading. Insert BEFORE it:

```markdown

## Compact streaming progress (v2.6.0+, Iter 30 §6.1)

Per-bolt status emitted as compact streaming format (chat-friendly, updated in-place):

```
▶ Bolt 7/20: U-007 "Create User model" (scope: BE)
  └─ Context: 6 upstream loaded, 3 anti-patterns flagged, confidence HIGH
  └─ Pre-flight: Hard Rules ✓ | PBT ready ✓ | Anchors verified 3/3 ✓
  └─ Execution: TDD red ✓ → green ✓ (45s)
  └─ Post-flight: Hard Rules ✓ | PBT ✓ | Drift check: clean ✓
  └─ Commit: 8a3f2e1 "feat(U-007): create User model"
✓ Bolt 7/20: U-007 → done in 1m23s, 0 retries, confidence 0.92
```

Halt cases get fuller treatment inline (see §Propose-and-confirm halt UX below).

After batch (printed at end of execute-bolts --all run):

```
══════════════════════════════════════════════════════════
✓ execute-bolts batch complete: 18/20 done, 2 halted, 1 auto-resolved
══════════════════════════════════════════════════════════
  Scope: BE | Duration: 24m11s | Retries: 3 total | Avg confidence: 0.87
  Halts open: U-012 (test_fail awaiting user), U-015 (hard_rule_violated)
  See <vault>/bolts/_summary.md for full table
  Next: detect-drift (auto-gate, hybrid mode — DEFAULT-ON per Iter 30 §6.4)
```

## Aggregate summary `<vault>/bolts/_summary.md` (v2.6.0+, Iter 30 §6.2)

Auto-generated AFTER every batch (overwrite-safe; idempotent regen).

Structure:

```markdown
# Bolts Summary — <Project Name>
**Generated**: <ISO8601> (mega-sdd execute-bolts v2.6.0+)
**Scope**: <scope_id> (<scope_name>)
**Batch**: <--all | --squad=X | --module=Y>
**Duration**: <duration>
**Avg AI confidence**: <0.0-1.0>

## Status table
| Unit | Title | Status | Duration | Retries | Confidence | Halt type | Commit |
|---|---|---|---|---|---|---|---|
| U-001 | <title> | ✓ done | 45s | 0 | 0.95 | — | <sha> |
| ... | ... | ... | ... | ... | ... | ... | ... |

## Halts open (N)
- U-XXX: <halt_type> after <retries> retries. <fix proposal status>. Resume: `/mega-sdd:auto --resume`.

## Hard rule violations across batch (by rule)
| Rule | Source | Violations | Resolution |
|---|---|---|---|

## Mutability tier coverage (when scope-tagged vault)
| Tier | Units touched | Status |
|---|---|---|

## Self-assessment summary (uncertain decisions across batch)
- U-XXX: "<decision>" — fallback: <safer alternative>

## Next steps
- Resolve <N> halts: `/mega-sdd:auto --resume`
- After all green: detect-drift will auto-run (hybrid gate; --no-drift-check opt-out)
```

Generation timing: written immediately after batch loop completes (whether all bolts succeeded, some halted, or chain cancelled). Overwrites any prior _summary.md (no append; full regen each batch).

```

- [ ] **Step 5.3: Verify**

```bash
grep -c "Compact streaming\|Aggregate summary" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "_summary.md\|Bolts Summary" plugins/mega-sdd/skills/execute-bolts/SKILL.md
```

Expected: 2+, 2+

- [ ] **Step 5.4: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md
git commit -m "$(cat <<'EOF'
feat(execute-bolts v2.6.0): compact streaming + aggregate summary (Iter 30 §6.1+§6.2)

Adds two output formats:

1. Compact streaming progress (§6.1): per-bolt status as 1 line
   updated in-place. Halt cases get fuller treatment inline.
   Batch summary at end of execute-bolts --all run.

2. Aggregate `<vault>/bolts/_summary.md` (§6.2): auto-generated
   after every batch. Includes status table, halts open list,
   hard rule violations by rule, mutability tier coverage,
   self-assessment summary, next steps.

Overwrite-safe (full regen each batch, no append).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: execute-bolts SKILL.md — propose-and-confirm halt UX + new halt types

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md`

- [ ] **Step 6.1: Find Halt protocol section**

```bash
grep -n "^## Halt protocol\|^### Violation handling" plugins/mega-sdd/skills/execute-bolts/SKILL.md | head -5
```

- [ ] **Step 6.2: Add Propose-and-confirm subsection within Halt protocol**

Use Edit tool. Find `## Halt protocol` heading. After existing halt protocol content (look for end of section), append new subsection:

```markdown

### Propose-and-confirm halt UX (v2.6.0+, Iter 30 §6.3)

Per `references/propose-and-confirm-prompt.md`. When bolt halts with eligible halt type, dispatch AI fix-proposer subagent → render proposal via AskUserQuestion → on user-accept apply fix + re-execute → on user-reject continue chain pause.

**Eligible halt types** (default propose-and-confirm; configurable per `~/.mega-sdd/memory/config.yaml` `halt_auto_propose`):
- `test_fail` (after default 3 retries via `--max-retries`)
- `hard_rule_violated` (with framework pack provenance evidence)
- `pbt_property_violated` (counterexample preserved in postflight)

**NOT eligible** (always pure pause):
- `oq_business_p1_unresolved` — human business decision required
- `dedup_ambiguous` — human judgment required
- `quality_gate_failed` — broader investigation needed
- `constitution_drift_detected` — audit-significant
- `bolt_repeated_partial_failure` — structural problem; fix won't help
- `provenance_missing` — user must add trailer
- `dispatch_prompt_too_large` — config issue, not bolt-fixable
- `dep_missing` — environment setup needed
- `hard_rule_unparseable` — config issue
- `hard_rule_unanchored` — config issue
- `verify_unit_writable` — config issue

**Dispatch contract**:
1. Bolt halt → check halt type eligibility + user config override
2. If eligible: dispatch fix-proposer subagent with `references/propose-and-confirm-prompt.md` template
3. Subagent returns proposed_fix YAML (root_cause + evidence_chain + fix diff + confidence + optional alternatives)
4. Render to user via AskUserQuestion (5 options: Apply / Alt / Reject / Cancel / Override)
5. On Apply: write proposed_fix to `<vault>/bolts/U-XXX/proposed-fix.md` → apply diff → re-execute single bolt → continue batch
6. On Reject: write proposed_fix to `<vault>/bolts/U-XXX/proposed-fix.md` (preserved for next session) → chain pauses
7. On Override: record to memory `decisions.md` as forced_pass → continue batch (audit-significant)

**Halt cycle safety**: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop).

**Configuration override** (`~/.mega-sdd/memory/config.yaml`):

```yaml
halt_auto_propose:
  test_fail: propose          # default
  hard_rule_violated: propose
  pbt_property_violated: propose
  oq_business_p1_unresolved: pause   # always
  dedup_ambiguous: pause             # always
  # ... rest pause by default
```

### New halt types (v2.6.0+, Iter 30)

Beyond existing halts, Iter 30 adds:

| Halt type | Fires when | Eligible for propose? |
|---|---|---|
| `dispatch_prompt_too_large` | Step 4.5 tiered prompt > 10KB hard cap | NO (config/spec issue) |
| `bolt_repeated_partial_failure` | 3+ partial-state attempts on same bolt OR propose-and-confirm cycled with different fixes | NO (structural) |
| `provenance_missing` | Post-flight detects missing provenance trailer in modified file | NO (user adds trailer) |

Halt YAML envelopes for each are documented in spec §Appendix B and `references/propose-and-confirm-prompt.md`.

```

- [ ] **Step 6.3: Verify**

```bash
grep -c "Propose-and-confirm\|Eligible halt types\|NOT eligible" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "dispatch_prompt_too_large\|bolt_repeated_partial_failure\|provenance_missing" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "halt_auto_propose:" plugins/mega-sdd/skills/execute-bolts/SKILL.md
```

Expected: 3+, 4+ (multiple mentions across the doc), 1

- [ ] **Step 6.4: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md
git commit -m "$(cat <<'EOF'
feat(execute-bolts v2.6.0): propose-and-confirm halt UX (Iter 30 §6.3)

Adds AI fix-proposer dispatch on eligible halt types (test_fail,
hard_rule_violated, pbt_property_violated). Subagent analyzes
evidence, proposes specific fix with diff + confidence + optional
alternatives. User reviews via AskUserQuestion (5 options).

NOT eligible (always pure pause): oq_business_p1_unresolved,
dedup_ambiguous, quality_gate_failed, constitution_drift_detected,
bolt_repeated_partial_failure, provenance_missing,
dispatch_prompt_too_large, dep_missing, hard_rule_unparseable,
hard_rule_unanchored, verify_unit_writable.

Halt cycle safety: same halt twice with different fixes →
bolt_repeated_partial_failure.

Config override via ~/.mega-sdd/memory/config.yaml halt_auto_propose.

3 new halt types documented: dispatch_prompt_too_large,
bolt_repeated_partial_failure, provenance_missing.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: execute-bolts SKILL.md — per-bolt drift check + self-assessment requirement

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md`

- [ ] **Step 7.1: Find Procedure step 5 (commit + bolt-report)**

```bash
grep -nE "^5\.|^### Post-flight|## Procedure" plugins/mega-sdd/skills/execute-bolts/SKILL.md | head -8
```

- [ ] **Step 7.2: Add per-bolt drift check + self-assessment requirement**

Use Edit tool. Find `### Post-flight Hard Rule validation` section (already exists per Iter 3). After it, find/add a new step OR insert before commit step:

Insert this new subsection:

```markdown

### Per-bolt lightweight drift check (v2.6.0+, Iter 30 §6.4)

After post-flight Hard Rule validation passes (or proposed-and-confirmed fix applied), AND BEFORE commit, run a quick scope-filtered drift scan vs vault:

a. Read vault.json scope (if multi-scope vault per Iter 28) OR skip scope filter
b. For each file in unit's target_files modified this bolt:
   - Compare current state vs vault's expected state (from binding.md anchors when present)
   - Detect: name drift, type drift, behavior drift (per detect-drift v1.4+ categories)
c. If drift detected on LOCKED entity (per `data-mutation-policy.md`) → halt `bolt_introduces_locked_drift` (eligible for propose-and-confirm OR override)
d. If drift detected on INTENT/ARTIFACT entity → log to bolt-report.md `## Drift introduced` section + continue (will surface in batch-end detect-drift gate)
e. If no drift → log "✓ Drift check: clean" to bolt-report.md

Compact streaming format reflects this:
```
└─ Post-flight: Hard Rules ✓ | PBT ✓ | Drift check: clean ✓
```

OR (drift detected case):
```
└─ Post-flight: Hard Rules ✓ | PBT ✓ | ⚠️ Drift: order.amount type changed (LOCKED — will halt at gate)
```

### Self-assessment requirement in bolt-report.md (v2.6.0+, Iter 30 §10)

Every bolt-report.md MUST include `bolt_self_report` YAML block at end:

```yaml
bolt_self_report:
  confidence: <0.0-1.0>   # bolt subagent's own confidence in this bolt's correctness
  certain_decisions:
    - "<decision with HIGH confidence + evidence>"
  uncertain_decisions:
    - decision: "<what bolt did>"
      rationale: "<why this path was taken>"
      fallback_if_wrong: "<safer alternative if this turns out wrong>"
  retry_history:
    - attempt: 1
      failure: "<verbatim failure if any>"
      fix: "<what was changed>"
```

If bolt-report.md lacks this block → halt `self_assessment_missing` (post-flight verification fails).

Aggregate `_summary.md` rolls up uncertain_decisions across batch for human review post-execution.

### Provenance trailer enforcement (v2.6.0+, Iter 30 §10 principle 9)

Post-flight scan also verifies every modified file has provenance trailer comment:

```
Generated by mega-sdd execute-bolts <version>
Unit: U-XXX (vault sha256: <hash>)
Implements claim: C-NNN "<claim text>"
Anchors consulted: <list>
Hard Rules active: <list of rule IDs>
```

Language-appropriate comment style (e.g., `//` for JS/PHP/Java, `#` for Python/Ruby, `--` for SQL).

Missing trailer → halt `provenance_missing` (always-pause per §6.3).

```

- [ ] **Step 7.3: Verify**

```bash
grep -c "Per-bolt lightweight drift check\|Self-assessment requirement\|Provenance trailer enforcement" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "bolt_introduces_locked_drift\|self_assessment_missing" plugins/mega-sdd/skills/execute-bolts/SKILL.md
grep -c "bolt_self_report:" plugins/mega-sdd/skills/execute-bolts/SKILL.md
```

Expected: 3, 2, 1+

- [ ] **Step 7.4: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md
git commit -m "$(cat <<'EOF'
feat(execute-bolts v2.6.0): per-bolt drift + self-assessment + provenance (Iter 30 §6.4+§10)

Three additions completing v2.6.0 surface:

1. Per-bolt lightweight drift check (§6.4): after post-flight
   Hard Rule validation, quick scope-filtered drift scan vs vault.
   LOCKED entity drift → halt bolt_introduces_locked_drift.
   INTENT/ARTIFACT drift → log + continue (surfaced at batch gate).

2. Self-assessment requirement (§10 principle 5): every
   bolt-report.md MUST include bolt_self_report YAML block
   (confidence, certain/uncertain_decisions, retry_history).
   Missing → halt self_assessment_missing.

3. Provenance trailer enforcement (§10 principle 9): post-flight
   verifies every modified file has provenance trailer comment.
   Missing → halt provenance_missing.

Compact streaming format reflects all three (Drift check status
inline; self-assessment confidence in done line).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: orchestrate-flow SKILL.md — hybrid drift gate phase + convergence bridge

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`

- [ ] **Step 8.1: Bump version**

```bash
grep "^version:" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
```

Expected `version: 2.4.1`. Edit:
- Find: `version: 2.4.1`
- Replace: `version: 2.5.0`

- [ ] **Step 8.2: Find Convergence loops section**

```bash
grep -n "^## Convergence loops\|^## Halt taxonomy\|^### --converge" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -5
```

- [ ] **Step 8.3: Add hybrid drift gate section**

Use Edit tool. Find `## Convergence loops` heading (or end of file if not present). Insert new section BEFORE it:

```markdown

## Hybrid drift gate phase (v2.5.0+, Iter 30 §6.4 — DEFAULT-ON)

After `execute-bolts --all` batch completes (or with retried halts), orchestrate-flow AUTO-invokes `detect-drift` as gate phase. Per spec §6.4 default-on policy.

### Gate behavior

```
✓ execute-bolts: 20/20 done (or 18/20 + 2 halts resolved via propose-and-confirm)
▶ Phase 5.5/6: detect-drift (auto-gate, hybrid mode — DEFAULT-ON)
  Scope: <scope_id> — scope-filtered scan
  Comparing: bolt postflight snapshots vs vault (shared snapshot machinery per references/shared-snapshot-schema.md)
  Speed: 4s (vs 28s full re-scan; snapshot reuse saves 6x)
  
⚠️ Drift findings: N (X CRITICAL, Y HIGH, Z MEDIUM, W LOW)
```

### Severity → chain action mapping (per Iter 25 + Iter 30)

| Severity | Trigger | Chain action |
|---|---|---|
| CRITICAL | Drift on LOCKED entity (data-mutation-policy.md tier) | HALT chain; user MUST resolve before proceeding |
| HIGH | Drift on CONFIRMED claim with no mutability source OR INTENT outcome change | PAUSE; user can override with audit-significant decision |
| MEDIUM | Drift on INTENT claim implementation change | LOG + continue; surface in batch summary |
| LOW | Drift on ARTIFACT cleanup OR style only | LOG only; no chain interruption |

### Opt-out

- `--no-drift-check` flag in `/mega-sdd:auto` or `execute-bolts` → skip auto-drift gate entirely
- Escape hatch, not default

### On-demand drift (separate from auto-gate)

`/mega-sdd:detect-drift` standalone (no chain context) → behaves as v1.2.x: fresh full scan; ignores bolt snapshots. Auto-gate path uses snapshot reuse per `references/shared-snapshot-schema.md`.

```

- [ ] **Step 8.4: Add convergence bridge for bolt halts**

Find existing `### --converge flag` or `## Convergence loops` content. Append new subsection at end:

```markdown

### Bolt halt convergence bridge (v2.5.0+, Iter 30 §6.7)

Iter 19 convergence loops handled: `bind_conflict`, `module_blocked_by`, `cross_squad_interface_draft`, `oq_recommend_underspecified`.

Iter 30 adds **propose-and-confirm bridge** for bolt halts:

| Bolt halt type | Convergence behavior |
|---|---|
| `test_fail` (after retries) | Propose-and-confirm fix → user approve → re-execute single bolt → continue batch |
| `hard_rule_violated` | Propose-and-confirm fix → user approve → re-execute → continue |
| `pbt_property_violated` | Propose-and-confirm fix → user approve → re-execute → continue |

Cycle counter respects `--max-cycles` (default 5). One cycle = 1 propose + 1 user decision + 1 re-execute attempt.

**Cycle escalation**: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop). Prevents propose-and-confirm from looping on structurally-broken unit.

**Configuration** (`~/.mega-sdd/memory/config.yaml`):
```yaml
halt_auto_propose:
  test_fail: propose
  hard_rule_violated: propose
  pbt_property_violated: propose
```

Per-halt-type override allowed (set to `pause` to disable propose for that type).

```

- [ ] **Step 8.5: Verify**

```bash
grep "version: 2.5.0" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
grep -c "Hybrid drift gate\|Bolt halt convergence bridge" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
grep -c "CRITICAL.*HALT\|HIGH.*PAUSE\|MEDIUM.*LOG" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
grep -c "--no-drift-check\|halt_auto_propose" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
```

Expected: 1, 2, 3+, 2

- [ ] **Step 8.6: Commit**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
git commit -m "$(cat <<'EOF'
feat(orchestrate-flow v2.5.0): hybrid drift gate + bolt halt bridge (Iter 30 §6.4+§6.7)

Bumps 2.4.1 → 2.5.0.

Two new sections:

1. Hybrid drift gate phase (§6.4): DEFAULT-ON after execute-bolts
   batch. Uses shared snapshot reuse for ~6x speedup. Severity →
   chain action mapping (CRITICAL halts, HIGH pauses, MEDIUM/LOW
   logs). Opt-out via --no-drift-check.

2. Bolt halt convergence bridge (§6.7): extends Iter 19 convergence
   loops with propose-and-confirm for test_fail / hard_rule_violated
   / pbt_property_violated. Cycle counter respects --max-cycles.
   Same halt twice with different fixes → bolt_repeated_partial_failure.

Configuration via ~/.mega-sdd/memory/config.yaml halt_auto_propose
block (per-halt-type override).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: detect-drift SKILL.md — auto-trigger + snapshot reuse + suggested actions

**Files:**
- Modify: `plugins/mega-sdd/skills/detect-drift/SKILL.md`

- [ ] **Step 9.1: Bump version**

```bash
grep "^version:" plugins/mega-sdd/skills/detect-drift/SKILL.md
```

Expected `version: 1.2.2`. Edit:
- Find: `version: 1.2.2`
- Replace: `version: 1.4.0`

- [ ] **Step 9.2: Find Procedure or Workflow section**

```bash
grep -n "^## \|^### Step" plugins/mega-sdd/skills/detect-drift/SKILL.md | head -10
```

- [ ] **Step 9.3: Add auto-trigger + snapshot reuse + suggested actions sections**

Use Edit tool. Find end of existing main procedure section. Append:

```markdown

## Auto-trigger handoff (v1.4.0+, Iter 30 §6.4)

When invoked by orchestrate-flow as chain phase (auto-gate after execute-bolts batch — default-on per `orchestrate-flow/SKILL.md` §Hybrid drift gate):

a. Detect chain context: `--auto-gate` flag + presence of `<vault>/bolts/` directory with recent postflight snapshots
b. Switch to incremental mode (see §Snapshot reuse below)
c. Apply severity → chain action per `orchestrate-flow/SKILL.md` mapping:
   - CRITICAL drift on LOCKED entity → emit halt blocker; orchestrate-flow halts chain
   - HIGH drift → emit pause signal; orchestrate-flow surfaces to user
   - MEDIUM/LOW drift → log only; chain continues

When invoked standalone (`/mega-sdd:detect-drift`, no chain context): behave as v1.2.x (fresh full scan; ignore bolt snapshots).

## Snapshot reuse (v1.4.0+, Iter 30 §6.6)

Per `plugins/mega-sdd/references/shared-snapshot-schema.md`.

When invoked with `--reuse-bolt-snapshots` flag (auto-set by orchestrate-flow auto-gate):

1. For each unit in vault.json: read `<vault>/bolts/U-XXX/postflight.json` if present (must be fresher than vault.json modification time)
2. Aggregate file-level sha256 + ast_signatures across all valid postflight snapshots
3. Compare aggregated state vs vault expectations (per existing detect-drift Steps 1-4)
4. For files NOT in any bolt postflight: fall back to fresh scan (typically small remainder)
5. Performance: skip Read + ast-extract for files already captured by bolts → ~5s on 20-bolt batch vs ~28s full re-scan

Stale snapshot detection: if `postflight.json.vault_sha256` mismatches current vault.json sha256 → fresh scan for that unit's files (snapshot invalid).

## Per-bolt incremental scan mode (v1.4.0+, Iter 30 §6.4)

Used by execute-bolts per-bolt drift check (§6.4 lightweight mode). Single-bolt scope:

a. Invoked from execute-bolts with `--per-bolt --unit=U-XXX` flags
b. Compare only this bolt's target_files vs vault expectations
c. Return synchronous result (no DRIFT-REPORT.md write):
   ```
   per_bolt_drift_result:
     unit_id: U-XXX
     drift_detected: true | false
     critical_findings: [<list>]
     non_critical_findings: [<list>]
   ```
d. Execute-bolts compact streaming format renders this inline

## Suggested next actions block in DRIFT-REPORT.md (v1.4.0+, Iter 30 §6.5)

DRIFT-REPORT.md gains `## Suggested next actions` section per finding. Each finding includes:

- Finding ID + severity + entity/field affected
- Source claim mutability tier (kb_locked / kb_intent / kb_artifact / vault_locked / inferred)
- Suggested action (concrete command with pre-filled flags)
- Auto-handoff command (for chain auto-continuation when safe)

Example:

```markdown
## Suggested next actions

### Finding D-001 (CRITICAL — drift on LOCKED entity)
- Entity: `orders` table, field `amount`
- Drift: vault says `decimal(15,2)`, code is `int` after U-018
- Source claim mutability: kb_locked (BI Reg 23/2/2021 §4)
- **Suggested action**: `/mega-sdd:resolve-oq --drift D-001` — choose:
  - (a) Revert code to vault spec (preserve LOCKED contract)
  - (b) Document deviation in 05-decisions.md with ADR (audit-significant)
- **Auto-handoff command**: `/mega-sdd:resolve-oq --drift D-001 --auto`

### Finding D-002 (LOW — style drift)
- File: `app/Http/Requests/RefundRequest.php` line 12
- Drift: unused import `use App\Models\User;`
- **Suggested action**: No action needed; style fixers (Pint) catch in next cycle.
- **Auto-handoff**: chain continues automatically (no halt for LOW)
```

```

- [ ] **Step 9.4: Verify**

```bash
grep "version: 1.4.0" plugins/mega-sdd/skills/detect-drift/SKILL.md
grep -c "Auto-trigger handoff\|Snapshot reuse\|Per-bolt incremental scan\|Suggested next actions block" plugins/mega-sdd/skills/detect-drift/SKILL.md
grep -c "shared-snapshot-schema.md\|--reuse-bolt-snapshots\|--per-bolt" plugins/mega-sdd/skills/detect-drift/SKILL.md
```

Expected: 1, 4, 3+

- [ ] **Step 9.5: Commit**

```bash
git add plugins/mega-sdd/skills/detect-drift/SKILL.md
git commit -m "$(cat <<'EOF'
feat(detect-drift v1.4.0): auto-trigger + snapshot reuse + suggested actions (Iter 30 §6.4+§6.5+§6.6)

Bumps 1.2.2 → 1.4.0 (minor bump — new auto-trigger mode).

Four new sections:

1. Auto-trigger handoff (§6.4): detect chain context; switch to
   incremental mode; apply severity → chain action mapping.

2. Snapshot reuse (§6.6): per references/shared-snapshot-schema.md.
   --reuse-bolt-snapshots flag auto-set by orchestrate-flow auto-gate.
   ~6x speedup (5s vs 28s on 20-bolt batch).

3. Per-bolt incremental scan mode (§6.4): used by execute-bolts
   per-bolt drift check. Single-bolt scope; synchronous result;
   no DRIFT-REPORT.md write.

4. Suggested next actions block in DRIFT-REPORT.md (§6.5): per
   finding includes severity, mutability tier, suggested action
   command (with pre-filled flags), auto-handoff command.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Release v3.22.0 — plugin bump + CHANGELOG + README + final commit + push

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json`
- Modify: `plugins/mega-sdd/README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 10.1: Bump plugin version**

```bash
grep '"version"' plugins/mega-sdd/.claude-plugin/plugin.json
```

Expected `"version": "3.21.0"`. Edit:
- Find: `"version": "3.21.0",`
- Replace: `"version": "3.22.0",`

- [ ] **Step 10.2: Update plugins/mega-sdd/README.md**

Find current "What's new" heading:

```bash
grep -n "What's new" plugins/mega-sdd/README.md | head -3
```

Find heading (likely `## What's new in v3.21.0 (Iters 17-29)`). Replace with `## What's new in v3.22.0 (Iters 17-30)`.

After the last existing bullet (likely Iter 29), append:

```markdown
- **Iter 30 execute-bolts seamless pipeline** — bolt subagent dispatched via tiered context enrichment (T1 always ≤2KB / T2 conditional ≤5KB / T3 reference-on-demand) per `references/bolt-dispatch-prompt.md`. Implements 10 AI-executor principles from spec (anti-context, confidence labels, past-failure intelligence, self-assessment vocabulary, halt vocabulary, validation hints, atomic discipline, provenance trailers, graceful partial-state). Plus seamless pipeline: compact streaming progress + aggregate `<vault>/bolts/_summary.md` + propose-and-confirm halt UX (AI fix proposer for test_fail / hard_rule_violated / pbt_property_violated; user single-click approve) + auto-drift gate DEFAULT-ON after batch (~6x faster via shared snapshot reuse) + DRIFT-REPORT.md `## Suggested next actions` with auto-handoff commands + convergence loops bridge bolt halts. New halts: dispatch_prompt_too_large, bolt_repeated_partial_failure, provenance_missing, self_assessment_missing, bolt_introduces_locked_drift
```

- [ ] **Step 10.3: Update CHANGELOG.md**

Read top of CHANGELOG:

```bash
head -10 CHANGELOG.md
```

Find current top entry (likely `## [3.21.0]`). Insert new section above:

```markdown
## [3.22.0] — 2026-05-24

### Added — Iter 30: execute-bolts Refinement (Tiered Context + Seamless Pipeline)

User flagged execute-bolts as MOST CRUCIAL skill (it's where AI actually writes code). Mid-brainstorm user reframe surfaced the deepest issue: bolt subagents dispatched with insufficient context — they re-discover what binding/units/KB already know, hallucinate where grounding exists.

Iter 30 makes bolts SHARP via tiered context enrichment + 10 AI-executor principles, AND makes the pipeline seamless via propose-and-confirm halt UX + auto-drift gate.

### The 10 AI-executor principles (foundation)

1. **Context budget discipline** — tiered T1/T2/T3 (≤7KB total vs 50KB scatter)
2. **Anti-context** — DO NOT MODIFY / REPLICATE / WRITE / COMMIT IF blocks
3. **Confidence-aware per claim** — HIGH/MEDIUM/LOW labels with source citation
4. **Past-failure intelligence** — memory.outcomes.md filtered for patterns matching this unit
5. **Self-assessment vocabulary** — structured certain_decisions + uncertain_decisions + fallback_if_wrong
6. **Halt vocabulary in prompt** — 5 halt types + YAML templates pre-loaded
7. **Validation hints, not "run tests"** — specific commands + expected output + failure interpretation
8. **Atomic discipline reinforced** — target_files whitelist + scope-creep halt + commit format
9. **Provenance chain** — every artifact cites unit ID, vault claim, anchors, active Hard Rules
10. **Graceful partial-state preservation** — crash mid-bolt recoverable via partial-state.json

### Updated skills

**execute-bolts v2.4.2 → v2.6.0** (major minor bump — new dispatch model):
- Step 4.5 tiered context enrichment per `references/bolt-dispatch-prompt.md`
- Compact streaming progress format
- Aggregate `<vault>/bolts/_summary.md` auto-generated
- Propose-and-confirm halt UX (AI fix-proposer for eligible halts)
- Per-bolt lightweight drift check (LOCKED entity drift → halt)
- Self-assessment YAML required in bolt-report.md
- Provenance trailer required in every modified file (post-flight verified)
- Partial-state preservation contract
- 3 new halt types: dispatch_prompt_too_large, bolt_repeated_partial_failure, provenance_missing

**orchestrate-flow v2.4.1 → v2.5.0**:
- Hybrid drift gate phase (DEFAULT-ON after execute-bolts batch)
- Severity → chain action mapping (CRITICAL halts, HIGH pauses, MEDIUM/LOW logs)
- Bolt halt convergence bridge (extends Iter 19 with propose-and-confirm for test_fail / hard_rule_violated / pbt_property_violated)

**detect-drift v1.2.2 → v1.4.0** (minor bump — new auto-trigger mode):
- Auto-trigger handoff from execute-bolts batch
- Snapshot reuse from bolt postflights (~6x speedup)
- Per-bolt incremental scan mode (used by execute-bolts per-bolt drift)
- `## Suggested next actions` block in DRIFT-REPORT.md with auto-handoff commands

### New reference files (3)

- `plugins/mega-sdd/references/shared-snapshot-schema.md` — canonical JSON schema for bolt + drift snapshots
- `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` — T1/T2/T3 tiered enrichment template
- `plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md` — AI fix proposer subagent prompt

### Composition with prior iters

- Iter 19 (convergence loops): extended with bolt halt propose-and-confirm bridge
- Iter 22 (mutability tiers): drift severity = CRITICAL when LOCKED entity changed
- Iter 23 (framework packs): Tier 2 context loads filtered pack rules per unit target_files
- Iter 27 (starterkit-first): scan-codebase pre-loads pack → execute-bolts dispatch
- Iter 28 (multi-scope): bolt dispatch includes scope context; scope filtering applies to drift
- Iter 29 (audit closure): scope: handoff block carries through execute-bolts → detect-drift

### End-to-end seamless flow (illustrative)

```
$ /mega-sdd:auto ./prd.md
▶ Phase 0: PRD scope picker → BE
▶ Phase 1: scan-codebase → pack loaded
▶ Phase 2: generate-intent → vault
▶ Phase 3: bind-codebase → 87 claims
▶ Phase 4: generate-units → 20 units
▶ Phase 5: execute-bolts --all (Iter 30 enrichment)
  Per-bolt: T1+T2 context (~5KB), compact streaming, per-bolt drift
  1 halt (test_fail) → propose-and-confirm → user one-click apply → continue
  All 20 done; _summary.md generated
▶ Phase 5.5: detect-drift (auto-gate DEFAULT-ON, snapshot reuse)
  1 LOW drift; chain continues
▶ Phase 6: emit-agents-md
✓ Pipeline complete: PRD → 20 bolts in 32m44s, 1 click intervention
```

### Plugin

3.21.0 → 3.22.0

### Skill version bumps

| Skill | Version |
|---|---|
| execute-bolts | 2.4.2 → 2.6.0 |
| orchestrate-flow | 2.4.1 → 2.5.0 |
| detect-drift | 1.2.2 → 1.4.0 |

### Field-test target

User-deferred field-test on tradefinance project becomes Iter 30 validation. First-run friction expected; tuning iterations follow.

---

```

- [ ] **Step 10.4: Verify**

```bash
grep '"version": "3.22.0"' plugins/mega-sdd/.claude-plugin/plugin.json
grep "v3.22.0" plugins/mega-sdd/README.md | head -3
grep "^## \\[3.22.0\\]" CHANGELOG.md
ls plugins/mega-sdd/references/shared-snapshot-schema.md plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md
```

Expected: 1 match, 1+ match, 1 match, all 3 files exist (no "No such file" errors)

- [ ] **Step 10.5: Final commit + push**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json plugins/mega-sdd/README.md CHANGELOG.md
git commit -m "$(cat <<'EOF'
feat(iter-30): execute-bolts seamless pipeline release (v3.22.0)

Plugin: 3.21.0 → 3.22.0
Skills bumped:
- execute-bolts: 2.4.2 → 2.6.0 (tiered context enrichment + 10 AI-executor principles)
- orchestrate-flow: 2.4.1 → 2.5.0 (hybrid drift gate + bolt halt bridge)
- detect-drift: 1.2.2 → 1.4.0 (auto-trigger + snapshot reuse + suggested actions)

Mid-brainstorm user reframe: deepest issue isn't UX smoothness —
it's that bolt subagents dispatched with insufficient context.
Iter 30 makes bolts SHARP via 10 AI-executor principles + tiered
context (T1 always ≤2KB / T2 conditional ≤5KB / T3 reference-only).

Plus seamless pipeline: compact streaming + aggregate _summary.md
+ propose-and-confirm halt UX + auto-drift gate DEFAULT-ON +
DRIFT-REPORT.md suggested actions + convergence loops bridge.

New halt types: dispatch_prompt_too_large, bolt_repeated_partial_failure,
provenance_missing, self_assessment_missing, bolt_introduces_locked_drift.

3 new reference files (shared-snapshot-schema + bolt-dispatch-prompt
+ propose-and-confirm-prompt).

Composes with Iter 19 (convergence), 22 (mutability), 23 (packs),
27 (starterkit-first), 28 (multi-scope), 29 (scope propagation).

Spec: docs/superpowers/specs/2026-05-24-iter-30-execute-bolts-refinement-design.md
Plan: docs/superpowers/plans/2026-05-24-iter-30-execute-bolts-refinement.md

Field-test target: deferred tradefinance run becomes Iter 30 validation.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"

git push origin main
```

Expected: `ok main` or similar success indicator.

- [ ] **Step 10.6: Verify final state**

```bash
git log --oneline -15
```

Expected: ~10 commits for Iter 30 all on origin/main, including the final release commit at top.

---

## Self-Review Notes (run after plan completion)

After implementing all tasks, verify:

1. **Spec coverage**: every section of `docs/superpowers/specs/2026-05-24-iter-30-execute-bolts-refinement-design.md` is implemented:
   - §4 (10 AI-executor principles): codified in bolt-dispatch-prompt.md template + execute-bolts Step 4.5 + bolt-report.md self-assessment requirement
   - §6.1 (compact streaming): in execute-bolts SKILL.md
   - §6.2 (aggregate summary): in execute-bolts SKILL.md
   - §6.3 (propose-and-confirm): in execute-bolts SKILL.md + propose-and-confirm-prompt.md
   - §6.4 (hybrid drift gate): in orchestrate-flow SKILL.md + detect-drift SKILL.md auto-trigger section
   - §6.5 (drift handoff): in detect-drift SKILL.md Suggested next actions section
   - §6.6 (shared snapshot): in shared-snapshot-schema.md + detect-drift SKILL.md snapshot reuse section
   - §6.7 (convergence bridge): in orchestrate-flow SKILL.md bolt halt convergence bridge section
   - §6.10 (tiered context enrichment): in execute-bolts SKILL.md Step 4.5 + bolt-dispatch-prompt.md

2. **Type consistency check**:
   - All halt type names spelled identically across files (e.g., `bolt_repeated_partial_failure` not variants)
   - `bolt_self_report` YAML field names match across bolt-dispatch-prompt.md + execute-bolts SKILL.md + propose-and-confirm-prompt.md
   - Snapshot schema field names match across shared-snapshot-schema.md + execute-bolts + detect-drift

3. **Cross-references**:
   - execute-bolts SKILL.md Step 4.5 cites bolt-dispatch-prompt.md ✓
   - execute-bolts SKILL.md halt UX cites propose-and-confirm-prompt.md ✓
   - detect-drift SKILL.md cites shared-snapshot-schema.md ✓
   - orchestrate-flow SKILL.md drift gate cites detect-drift sections ✓

4. **Placeholder scan**: search for "TBD", "TODO", "implement later", "fill in details" — no results expected.

---

**End of plan.**

Total tasks: 10
Estimated execution time: 4-6 hours (markdown-heavy, low cognitive load per task)
Risk areas: Task 4-7 (execute-bolts SKILL.md modifications need careful insertion — file already 470+ lines with many sections), Task 8 (orchestrate-flow already has convergence section from Iter 19 — careful not to duplicate)
