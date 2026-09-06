# Scenario 6 — Recovery from Halt

**Time**: ~15 minutes
**Goal**: Pipeline halted mid-chain. Understand the halt, fix the underlying issue, and resume cleanly. No data loss; no partial commits.

Halts are mega-sdd's safety net — they fire when anti-hallucination rails detect real issues. Knowing how to interpret + recover is essential for production use.

> **Command forms in this catalog** — `/mega-sdd` and `/mega-sdd --resume` are the registered front door. Bare skill invocations shown in recovery steps (e.g. `execute-bolts U-001`, `resolve-oq --binding`) are typed as plain text in the session — they phrase-route to their skill (the typed `/mega-sdd:<skill>` command forms were removed at 6.0.0).

## Common halt types you'll encounter

| Halt | What it means | When |
|---|---|---|
| `bind_conflict` | Vault claim contradicts existing code | bind-codebase phase |
| `oq_recommend_underspecified` | Recommendation missing citation/rationale | bind-codebase phase |
| `dedup_ambiguous` | `create` unit targets existing files | generate-units phase |
| `hard_rule_violated` | Bolt modified locked code | execute-bolts post-flight |
| `hard_rule_unparseable` | Bolt's Hard Rule has bad syntax | execute-bolts pre-flight |
| `cross_squad_interface_draft` | Consumer waiting for producer to lock interface | execute-bolts --per-squad |
| `module_blocked_by` | Prerequisite module not complete | execute-bolts --module=X |
| `oq_business_p1_unresolved` | P1 business OQ blocking downstream | bind-codebase (strict mode) |
| `quality_gate_failed` | a module's per-module quality gate failed twice | extract-intelligence |

Each halt provides a YAML `blocker` artifact with `next_action` field telling you exactly what to do.

## Recovery pattern (universal)

For any halt:

1. Read the blocker YAML in chat
2. Understand what triggered it
3. Resolve the underlying issue
4. Run `/mega-sdd --resume`

Mega-sdd's `--resume` is CWD-driven + checkpoint-aware. It detects where you stopped + continues forward.

## Scenario walkthrough — `hard_rule_violated`

Most common halt for bolt phase. Concrete walkthrough.

### Setup — induce a Hard Rule violation

Use the project from [Scenario 3](scenario-3-field-extension.md). Modify the unit's Hard Rule to be intentionally strict:

```bash
cat .mega-sdd/vaults/login-extension/units/U-001.md
```

Find the `## Hard rules` section. Add a too-strict rule:

```yaml
id: response-shape-strict
language: php
rule:
  pattern: |
    return response()->json($$$);
fix: forbidden-when-modified
message: ALL response() calls are locked  # ← intentionally over-strict
```

This will cause the bolt to fail because it adds the new error response. Re-run:

```
execute-bolts U-001
```

### The halt fires

```
▶ Invoking U-001 via superpowers...
  Pre-flight: 2 Hard Rules parsed, snapshots taken
  Bolt: implementing nama field validation...
  Acceptance test: passing
  Post-flight: validating Hard Rules...
    ✓ do-not-modify-token-generation: PASS
    ✗ response-shape-strict: VIOLATED (response()->json([...], 401) added)
  
⛔ HALT — hard_rule_violated

blocker:
  type: hard_rule_violated
  emitted_at: 2026-05-21T15:32:18Z
  emitted_by: execute-bolts
  details:
    unit_id: U-001
    violated_rule: "response-shape-strict — ALL response() calls are locked"
    evidence: "Pattern `return response()->json($$$)` added at line 21"
    files_modified:
      - app/Http/Controllers/Api/LoginController.php
  next_action: "Review the flagged bolt commit; `git revert` it OR
                edit unit's Hard rules + re-run execute-bolts U-001"
```

Detect-after: the bolt commit already landed; the post-flight scan halted the run and the B1 gate blocks every further `execute-bolts` until the flagged commit is fixed-forward or `git revert`ed. User reviews + decides.

## Recovery options

### Option A: Adjust the Hard Rule (most common)

Hard Rule was too strict. Edit unit:

```bash
nano .mega-sdd/vaults/login-extension/units/U-001.md
```

Remove the over-strict rule OR scope it more narrowly:

```yaml
id: response-shape-strict-success
language: php
rule:
  pattern: |
    return response()->json(['token' => $$$]);
fix: forbidden-when-modified
message: 200-success response shape (with token key) is locked
```

Now the rule only locks the success path; new 401 error is allowed.

Resume bolt:

```bash
execute-bolts U-001
# Re-runs pre/post-flight; rule passes; commits
```

### Option B: Revert the bolt's code change (rare)

If bolt actually went wrong + rule was correct:

```bash
git checkout app/Http/Controllers/Api/LoginController.php
# Or just the offending hunks via git checkout -p

# Re-think the unit's task — maybe Migration notes were wrong
# Edit unit body, then:
execute-bolts U-001
```

### Option C: Force commit + accept risk (last resort)

If you know the rule was wrong but don't want to edit it:

```bash
execute-bolts U-001 --force-skip-postflight
```

⚠️ Warning logged to memory. Use sparingly — bypasses the safety rail.

### Option D: Skip this unit + continue chain

If unit isn't critical:

```bash
git checkout app/Http/Controllers/Api/LoginController.php   # revert
/mega-sdd --resume    # continues from next unit
```

`/mega-sdd --resume` skips a reverted unit on its own.

## Scenario walkthrough — `bind_conflict`

Equally common. Different recovery pattern.

### The halt

```
⛔ HALT — bind_conflict

blocker:
  type: bind_conflict
  emitted_at: 2026-05-21T15:35:00Z
  emitted_by: bind-codebase
  details:
    conflict_count: 1
    conflicts:
      - id: C-007
        vault_claim: "Auth uses Bearer tokens"
        codebase_reality: "Auth uses session cookies (Laravel default)"
        suggested_resolutions:
          - KEEP_VAULT — migrate code to Bearer auth (high effort)
          - KEEP_CODE — preserve session auth; update vault
          - DEFER — flag as future work; mark this claim deferred
          - SPLIT — Sanctum for /api/*; sessions for web
  next_action: "Run resolve-oq --binding"
```

### Recovery

```
resolve-oq --binding
```

(A converging `--deep` chain — the default — enters resolve-oq itself on `bind_conflict`; the manual walk below applies under `--no-converge`.)

Interactive walker:

```
CONFLICT C-007:
  Vault: "Auth uses Bearer tokens"
  Code:  "Auth uses session cookies"
  
  Recommendation: SPLIT — Sanctum for /api/*; sessions for web (recommended)
  Rationale: Laravel best practice (framework pack §auth) + minimal churn
  Source: scan citation routes/api.php:12 + config/sanctum.php:1 (KB/vault/codebase-grounded)
  Fallback-if-wrong: If client requires single-auth uniformity, revisit
  Confidence: HIGH
  
  Options:
    1. SPLIT (recommended) — Sanctum API + session web
    2. KEEP_VAULT — migrate all to Bearer (high effort)
    3. KEEP_CODE — preserve session auth; update vault
    4. DEFER — handle later
```

Pick (1). The resolution lands in the vault (binding annotation + `constraints.md ## Open Questions`). Resume:

```
/mega-sdd --resume
```

Chain continues from `bind-codebase` (re-runs with conflict resolved).

## Scenario walkthrough — `quality_gate_failed` (extract-intelligence)

Heavy phase; halt rare but real. Fires when the SAME module's per-module quality gate (frontmatter contract / 6-section presence / gotcha floor / Mermaid flow / citation discipline) fails twice. The registry files this under subtype `module_quality_threshold_unmet` — the extract default emits with `subtype` absent; the label is the registry's documentation name.

### The halt

```
⛔ HALT — quality_gate_failed

blocker:
  type: quality_gate_failed
  emitted_at: 2026-05-21T13:42:00Z
  emitted_by: extract-intelligence
  details:
    module: import-lc
    module_prd: modules/import-lc.prd.md
    failed_check: "§5 Edge Cases & Gotchas < 3 entries (workflow-module minimum)"
    retries_attempted: 2
```

The halt surfaces the gate output VERBATIM and asks with keterangan per option:

- **Re-scope module** — pecah/gabung ulang module ini, lalu re-dispatch
- **Re-prompt** — re-dispatch sekali lagi dengan arahan tambahan lo
- **Abort** — berhenti; KB partial disimpan (module PRD yang sudah lolos gate tetap di disk)

### Recovery options

Option A: Answer the halt menu (most common) — **Re-prompt** when the extractor just missed depth; **Re-scope** when the module split was wrong (too broad or too thin for one PRD).

Option B: Manually inspect the partial output first, then decide:

```bash
cat .mega-sdd/knowledge-base/modules/import-lc.prd.md
# The failing PRD — is the gap real, or is the module mis-scoped?
cat .mega-sdd/knowledge-base/census.json
# What the census enumerated + the module proposal (which source_files this module claims)
cat .mega-sdd/knowledge-base/.extract-census-state.json
# Completeness-gate state (present once validate-extract-census.sh has run)
```

If the PRD is actually good enough: accept with QA notes recorded (loses some rigor). If not: check whether the module's `source_files` actually carry the logic — a mis-split census proposal means **Re-scope**, not another re-prompt.

There is NO auto-resume after Abort: the next `extract-intelligence` run starts again from the census (idempotent — module PRDs that already passed stay on disk, and the completeness gate recomputes coverage from the artifacts, never from the conversation).

## Universal `--resume` rules

`/mega-sdd --resume` does the right thing:

1. Re-inspects CWD state (artifact presence)
2. Reads checkpoints if any
3. Identifies the latest incomplete phase
4. Re-runs that phase if needed (idempotent for clean states)
5. Continues forward per the handoff YAML protocol

It's safe to run `--resume` multiple times. If issue still exists, same halt fires.

## Inspecting bolt-report after a halt

```bash
cat .mega-sdd/vaults/<slug>/bolts/U-XXX/bolt-report.md
```

Includes:
- Pre-flight Hard Rule snapshots (sha256, signatures, manifest state)
- Acceptance test results (passed/failed/retries)
- Post-flight Hard Rule diff results
- Files modified
- Halt reason if applicable

```bash
cat .mega-sdd/vaults/<slug>/bolts/U-XXX/preflight.json
cat .mega-sdd/vaults/<slug>/bolts/U-XXX/postflight.json
```

JSON detail of Hard Rule state before/after.

## Common pitfalls during recovery

### Lost checkpoint after manual git checkout

If you `git checkout .` to discard ALL bolt changes, you also discarded `.mega-sdd/vaults/<slug>/.internal/checkpoints/*.jsonl`. Recovery cursor lost.

Fix: re-run with `/mega-sdd --resume` (CWD-driven cursor will rebuild from artifact presence; just slower than checkpoint-driven).

### Recovery loop

Same halt fires after `--resume`. You haven't fixed the underlying issue. Read the blocker YAML AGAIN; the `next_action` is specific. If unclear, check:

- For `hard_rule_violated`: did you actually adjust the rule OR revert the code?
- For `bind_conflict`: did `resolve-oq --binding` actually save the resolution? Check vault.json changelog.
- For `dedup_ambiguous`: did you actually update target_files in the unit?

### Force-commit after `hard_rule_violated`

```bash
execute-bolts U-XXX --force-skip-postflight
```

⚠️ Bypasses safety rail. Use ONLY when you've manually verified the code change is intentional + acceptable. Logged to memory for audit.

---

# Additional halt walkthroughs

These 10 high-frequency halt walkthroughs cover the gap between the original 3 walkthroughs above and the halt families in `references/halt-families/` (per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`). These complement the universal recovery patterns documented above — each walkthrough shows the trigger, halt envelope, and recovery options.

## Scenario walkthrough — `handoff_missing`

**When you'll see it.** A sub-skill in an `--auto` chain exits without emitting a `handoff:` YAML block in its chat output. Orchestrator can't decide auto-continue / pause / stop without that block. The check looks at the sub-skill's chat output (last assistant message), NOT a file on disk.

**Example halt envelope:**

```yaml
type: handoff_missing
source_skill: orchestrate-flow
details:
  failing_skill: bind-codebase
  last_known_step: "Step 7 (binding entries written)"
  chat_tail_excerpt: "... write to file failed: ENOSPC: no space left on device\nProcess exited with code 1"
next_action:
  type: inspect_subskill_logs
  hint: "Sub-skill `bind-codebase` exited without emitting handoff YAML in chat. Inspect chat_tail_excerpt for crash logs / OS-level failures."
```

**Recovery:** read `chat_tail_excerpt` for the crash signal. Re-run sub-skill standalone to reproduce (`bind-codebase <vault-path>`). If reproducible → file a skill-author bug. If transient (disk full, OOM) → fix the environmental issue and retry.

Cross-refs: `plugins/mega-sdd/references/halt-protocol.md §halt-protocol §handoff_missing`; `orchestrate-flow/references/handoff-contract.md §Pre-validation`.

## Scenario walkthrough — `artifact_missing`

**When you'll see it.** A sub-skill emits a handoff YAML with `artifacts: [paths]` listing files that don't exist on disk (because the producer crashed mid-write OR fabricated paths). Orchestrator's step `b.vii` existence-checks every path BEFORE consuming.

**Example halt envelope:**

```yaml
type: artifact_missing
source_skill: orchestrate-flow
details:
  failing_skill: generate-units
  missing_paths: ["<vault>/units/U-007.md", "<vault>/units/U-008.md"]
  present_paths: ["<vault>/units/U-001.md", ..., "<vault>/units/U-006.md"]
  handoff_file: "<vault>/.internal/checkpoints/2026-05-25-generate-units.handoff.yaml"  # optional replay copy; the orchestrator reads chat output
next_action:
  type: re_run_producer
  hint: "Producer declared 8 unit files but only wrote 6. Re-run generate-units standalone to reproduce. Likely cause: crash mid-loop."
```

**Recovery:** re-run the producer skill standalone; inspect chat for mid-write crash signals. If reproducible → file bug. If transient → re-run + retry chain.

## Scenario walkthrough — `partial_state_corrupt` + saga rollback

**When you'll see it.** `execute-bolts --resume` reads `<vault>/bolts/U-XXX/partial-state.json` and JSON parse fails. Previously silent overwrite; now ALWAYS-STOP with forensics path suggestion.

**Recovery option 1 (forensics + restart):**

```bash
mv <vault>/bolts/U-007/partial-state.json <vault>/bolts/U-007/partial-state.json.corrupt-$(date -u +%Y-%m-%dT%H:%M:%SZ)
execute-bolts U-007 --resume   # starts fresh now that corrupt file is moved aside
```

**Recovery option 2 (saga rollback — v2.0 partial-state):** if the corrupt file is actually v2.0 with intact `rollback_hints[]` despite parse failure (rare — JSON header valid but `rollback_hints` array malformed), use `--rollback` to undo prior non-idempotent steps before re-attempting:

```bash
execute-bolts U-007 --rollback   # applies rollback_hints[] in reverse order
execute-bolts U-007              # fresh re-run from clean slate
```

Cross-refs: `plugins/mega-sdd/references/halt-protocol.md §halt-protocol §partial_state_corrupt`; `execute-bolts/SKILL.md §Saga compensating actions`.

## Scenario walkthrough — `oq_blocker`

**When you'll see it.** Generate-intent or any AI consumer reading the vault non-interactively encounters an unresolved P1 Open Question that blocks downstream work.

**Recovery:**

```bash
resolve-oq <vault-path>       # interactive Q&A walk through unresolved OQs
# OR
# Edit constraints.md ## Open Questions directly + add "status: resolved" + answer; then re-run upstream skill
```

If the OQ is `category: tech` and can be auto-resolved via codebase scan: re-run `bind-codebase` (it auto-resolves tech OQs with HIGH classification_confidence).

## Scenario walkthrough — `diff_conflict`

**When you'll see it.** `diff-vault` detects that a new PRD revision conflicts with a vault Resolved-OQ or ADR Decision. Needs stakeholder input — never auto-overrides existing decisions.

**Example envelope:**

```yaml
type: diff_conflict
source_skill: diff-vault
tag: OQ-AR-12
priority: n/a
conflict_old: "vault says: payment provider = Stripe"
conflict_new: "new PRD says: payment provider = Adyen"
options: ["supersede", "keep_vault", "capture_both"]
```

**Recovery:** review the conflict context, pick one of the 3 options, then edit the vault markdown directly and re-run `diff-vault`.

## Scenario walkthrough — `dispatch_prompt_too_large`

**When you'll see it.** Current semantics: fires ONLY when constitution_clauses alone exceeds 10KB after all disposable T2 sections truncated to drop floor. Real config issue, not bolt-fixable.

**Recovery:** the halt envelope shows `warnings: [{section, rule_applied, bytes_saved}, ...]` — review which sections truncated. If constitution_clauses is the bulk, consider:
1. Splitting the unit (smaller scope = fewer constitution clauses referenced)
2. Reducing the unit's `vault_source` array to fewer sections
3. (Last resort) editing the constitution to merge or shorten clauses

Cross-refs: `execute-bolts/SKILL.md §Step 4.5.a.5 T2 Section Priority + Truncation`.

## Scenario walkthrough — `provenance_missing`

**When you'll see it.** Bolt subagent committed code without the provenance trailer (`# mega-sdd: unit=U-XXX bolt=<sha>`). Post-flight scan catches this.

**Recovery:** edit each modified file to add the trailer; amend the bolt commit:

```bash
# In your editor, add trailer to top of each modified file
git add <modified-files>
git commit --amend --no-edit
execute-bolts U-007 --resume   # post-flight will pass now
```

Cross-refs: `bolt-dispatch-prompt.md §Provenance trailer`.

## Scenario walkthrough — `bind_conflict_constitution_violation`

**When you'll see it.** A claim being bound conflicts with a security/compliance clause in `<vault>/constitution.md` §B or §F. Constitution is non-negotiable — overrides binding gate.

**Example envelope:**

```yaml
type: bind_conflict_constitution_violation
source_skill: bind-codebase
details:
  claim_id: C-042
  claim_text: "POST /api/login endpoint uses session cookies"
  conflict: "Constitution §B-002 requires JWT for all auth endpoints"
  constitution_clause: "B-002"
```

**Recovery:**
1. Review constitution §B-002. Is it still valid? If outdated, edit constitution.md + re-run binding.
2. If constitution is correct, the claim is wrong — fix the PRD/vault and re-run binding.
3. Never bypass — constitution violations are blocking by design.

## Scenario walkthrough — `cross_squad_dep_invalid`

**When you'll see it.** A unit declares `consumes_interface: <ref>` from a different squad, but the producer squad hasn't locked that interface yet OR the ref points to a non-existent interface.

**Recovery:**

```bash
# Option A: producer squad locks the interface
execute-bolts U-<producer-unit> --squad=producer-squad

# Option B: consumer waits (orchestrate-flow auto-handles via convergence loop with backoff)
/mega-sdd --converge --max-cycles=3

# Option C: fix the ref if it points to wrong interface
# Edit unit's consumes_interface field; re-run generate-units --refresh
```

Cross-refs: `generate-units/references/cross-squad-interfaces.md`.

---

## Scenario walkthrough — `install_failed` + `pkg_mgr_not_found`

**When you'll see it.** `/mega-sdd:install-deps` ran but either (a) detected no compatible package manager (`pkg_mgr_not_found`) or (b) install command exited non-zero / post-install `verify_cmd` failed (`install_failed`).

### Recovery — `pkg_mgr_not_found`

```yaml
blocker:
  type: pkg_mgr_not_found
  source_skill: install-deps
  details:
    os: linux
    distro: ubuntu
    attempted_pkg_mgrs: [apt]
    fallbacks_attempted: [cargo, npm, go]
  next_action:
    hint: "No compatible package manager. Install brew (macOS) / verify apt is on PATH (Linux) / install WSL Ubuntu (Windows native), then re-run."
```

Recovery paths:

```bash
# macOS without brew:
# Open https://brew.sh + run their official installer (one-line curl|bash — done manually by user; install-deps does NOT auto-execute curl|bash per safety rail).
# After brew installed: re-run /mega-sdd:install-deps

# Ubuntu/Debian missing apt on PATH (rare; chroot/container envs):
which apt   # if empty, your environment has no apt — install via your distro tools

# Windows native without WSL:
# Install WSL Ubuntu via: wsl --install -d Ubuntu
# Re-run /mega-sdd:install-deps inside WSL terminal
```

### Recovery — `install_failed`

```yaml
blocker:
  type: install_failed
  source_skill: install-deps
  details:
    tool: mmdc
    install_cmd: "npm install -g @mermaid-js/mermaid-cli"
    verify_cmd: "command -v mmdc"
    exit_code: 1
    stderr_tail: "Error: Failed to download from formula cask: connection timed out"
    subtype: install_command_failed
  next_action:
    hint: "Inspect stderr_tail; fix root cause (network / repo signing / PATH); retry single tool via /mega-sdd:install-deps --tools=mmdc"
```

Recovery options:

```bash
# Option 1: Retry single failed tool (most common; transient network issue):
/mega-sdd:install-deps --tools=mmdc

# Option 2: Force a specific package manager (for a tool with multiple sources):
/mega-sdd:install-deps --tools=<tool> --pkg-mgr=<mgr>

# Option 3: Skip + use fallback (if tool optional for current workflow):
# e.g., mmdc missing → emit PDF renders mermaid as code (not a diagram); Chrome missing → GitHub-styled HTML fallback
# Just continue; the emit lane degrades gracefully (md2pdf, never LaTeX). Install later.

# Option 4: Manual install + verify:
/mega-sdd:install-deps --manual                          # prints install commands but doesn't execute
# Run the printed command yourself, then:
/mega-sdd:install-deps --tools=mmdc  # every run re-probes (no cache to skip)
```

If `subtype: verify_after_install_failed`: install ran but tool not on PATH. Common fix:

```bash
hash -r                       # clear shell command cache
which <tool>                  # verify path
# Or restart shell session and re-run /mega-sdd:install-deps --tools=<tool>
```

---

## Scenario walkthrough — `quality_gate_failed` subtypes

The `quality_gate_failed` halt carries a `subtype:` discriminator. Recovery forks on subtype.

### `type: pdf_render_failed` (emit-fsd)

```yaml
blocker:
  type: pdf_render_failed
  source_skill: emit-fsd
  details:
    md2pdf_stderr_tail: "md2pdf: pandoc HTML render failed"
```

The emit lanes render PDFs via `scripts/md2pdf.sh` (pandoc HTML + Chrome print, GitHub/VS Code style — NEVER LaTeX). `pdf_render_failed` fires ONLY on a real render error (exit 1); a **Chrome-absent** run is NOT a halt — md2pdf writes GitHub-styled `FSD.html` (exit 3) and the lane proceeds. Recovery for a genuine failure:

```bash
/mega-sdd:install-deps --tools=pandoc,mmdc   # pandoc = the renderer; mmdc = mermaid diagrams
# Chrome is detect-only (a GUI app, never auto-installed) — install it for direct PDF, else FSD.html.
/mega-sdd:emit fsd <vault-path>              # retry the render
```

### `subtype: template_slot_unfilled` (emit-fsd)

Internal bug — fsd-template.md has a slot marker that section-mapping.md has no extraction rule for. File plugin bug. Meanwhile:

```bash
# Skip affected section per styling override:
/mega-sdd:emit fsd --sections=1,2,3,4,5,6,7,8,10  # skip section 9 (or whichever is failing)
```

### `type: starterkit_metrics_inconsistent` (orchestrate-flow / generate-units)

generate-units emitted `units_with_starterkit_rules > 0` BUT scan-codebase's starterkit-context.yaml flags `partial: true`. Rules may cite incomplete framework conventions.

Recovery:

```bash
# Force-deep re-scan to complete starterkit slices:
scan-codebase --force-deep

# Regenerate units against complete starterkit:
generate-units --regenerate
```

### `module_quality_threshold_unmet` or omitted (extract-intelligence)

The extract default — the envelope emits with `subtype` absent; `module_quality_threshold_unmet` is the registry's documentation label for it. Existing walkthrough above at §`quality_gate_failed` (extract-intelligence) covers this case.

---

## Scenario walkthrough — PRD-scope halts

PRD multi-scope handling carries 3 halts; all 3 get explicit recovery walkthroughs.

### `scope_not_declared_in_prd`

```yaml
blocker:
  type: scope_not_declared_in_prd
  source_skill: generate-intent
  details:
    requested_scope: "BE"
    declared_scopes: ["FE", "MW"]
    prd_path: "<project>/prd.md"
  next_action:
    hint: "Requested --scope=BE not in PRD's declared scopes [FE, MW]. Pick valid scope OR retrofit PRD to add BE."
```

Recovery:

```bash
# Option 1: pick valid scope from declared list
generate-intent ./prd.md --scope=FE

# Option 2: edit PRD frontmatter to add missing scope
# Add to PRD frontmatter:
#   scopes:
#     - id: BE
#       name: Backend
# Then re-run
generate-intent ./prd.md --scope=BE
```

### `prd_no_scopes_block_user_rejected_retrofit`

```yaml
blocker:
  type: prd_no_scopes_block_user_rejected_retrofit
  source_skill: generate-intent
  details:
    prd_path: "<project>/prd.md"
    retrofit_attempted: true
    user_action: rejected
```

Recovery: user explicitly rejected the AI retrofit (auto-add scopes block). 3 paths:

```bash
# Option 1: manually edit PRD frontmatter to add scopes block
# Then re-run
generate-intent ./prd.md

# Option 2: opt-out of multi-scope; run with all scopes as one
generate-intent ./prd.md --scope=all

# Option 3: accept retrofit (changed mind) — re-run plainly; the retrofit bridge re-offers
generate-intent ./prd.md
```

### `prd_retrofit_low_confidence`

```yaml
blocker:
  type: prd_retrofit_low_confidence
  source_skill: generate-intent
  details:
    overall_confidence: LOW
    retrofit_preview_path: "<project>/.mega-sdd/retrofit-preview.md"
```

Recovery: AI retrofit subagent unsure about scope inference. User reviews:

```bash
# Inspect what retrofit proposes
cat <project>/.mega-sdd/retrofit-preview.md

# Then choose:
# (a) Accept anyway despite LOW confidence — re-run and accept at the interactive prompt:
generate-intent ./prd.md
# (b) Fall back to all scopes as one:
generate-intent ./prd.md --scope=all
# (c) Cancel + manually retrofit PRD frontmatter:
# Edit PRD; re-run
```

---

## Scenario walkthrough — `drift_framework_mismatch` + `constitution_drift_detected`

Both halts fire from `detect-drift` on real production drift scenarios.

### `drift_framework_mismatch`

Vault says one framework; codebase is now another (e.g., vault PRD says Laravel; code is now Spring after a rebuild).

```yaml
blocker:
  type: drift_framework_mismatch
  source_skill: detect-drift
  details:
    detected_framework: "Java/Spring"
    expected_framework: "PHP/Laravel"
```

Recovery options:

```bash
# Option 1: code-supersede (codebase reality is correct; update vault)
diff-vault ./new-prd-spring.md   # if new PRD reflects Spring
# OR re-extract intelligence + regenerate vault:
extract-intelligence ./
generate-intent --kb=<kb>

# Option 2: vault-supersede (codebase regressed; revert to Laravel)
git revert <commit-range>   # roll back framework migration
# OR
git checkout <pre-migration-tag>

# Option 3: split — keep both as separate vault scopes
# Manually retrofit PRD scopes block: scopes: [legacy-laravel, new-spring]
generate-intent ./prd.md --scope=new-spring
```

### `constitution_drift_detected`

§B (security) or §F (compliance) constitution clause drift detected in code.

```yaml
blocker:
  type: constitution_drift_detected
  source_skill: detect-drift
  details:
    clause_id: "§B-007"
    clause_text: "All session tokens MUST be encrypted at rest"
    code_evidence: "src/auth/SessionStore.kt:45 — stores raw token without encryption"
```

Recovery (mandatory — security/compliance is non-negotiable):

```bash
# Step 1: inspect drift evidence
cat <vault>/DRIFT-REPORT.md

# Step 2: fix the code (preferred — code violates constitution)
# Edit src/auth/SessionStore.kt:45 to encrypt token before persist
# Commit fix

# Step 3: re-run drift detection
detect-drift

# OPTION: if constitution clause itself is wrong (rare), update it:
# Edit <vault>/_meta/constitution.md §B-007
# Re-run: detect-drift
# (Constitution edits require sign-off per CLAUDE.md governance)
```

---

## Scenario walkthrough — execute-bolts halts

Three more execute-bolts halts:

### `bolt_repeated_partial_failure`

A bolt failed 3 partial-state recovery cycles.

```yaml
blocker:
  type: bolt_repeated_partial_failure
  source_skill: execute-bolts
  details:
    unit_id: U-012
    cycle_count: 3
    last_failure: "test: assertion 'user.id present' failed; retry budget exhausted"
```

Recovery (unit spec is likely wrong):

```bash
# Step 1: inspect bolt-report + partial-state across cycles
cat <vault>/bolts/U-012/bolt-report.md
cat <vault>/bolts/U-012/partial-state.json

# Step 2: review unit spec — is acceptance_test under-specified? target_files wrong scope?
cat <vault>/units/U-012.md

# Step 3: edit unit OR escalate
# If acceptance_test wrong: edit acceptance_test field; re-run
# If target_files too broad: tighten scope; re-run
# If genuinely blocked: author the OQ into `constraints.md ## Open Questions`
# for human review (e.g. "U-012 cannot pass acceptance test as specified")
```

### `bolt_introduces_locked_drift`

Bolt drift hit a LOCKED entity (constitution/security-protected).

```yaml
blocker:
  type: bolt_introduces_locked_drift
  source_skill: execute-bolts
  details:
    unit_id: U-007
    locked_entity: "src/auth/User.php"
    drift_evidence: "added field `last_login_ip` without locking constitution amendment"
```

Recovery (propose-and-confirm override path):

```bash
# Option 1: revert bolt changes (locked entity protected by design)
git diff HEAD <vault>/bolts/U-007/preflight.json   # see what bolt wrote
git checkout <pre-bolt-state>

# Option 2: amend constitution to allow drift (requires explicit user approval)
# Edit <vault>/_meta/constitution.md — explicitly mark src/auth/User.php as UNLOCKED for this field
# Re-run bolt:
execute-bolts U-007 --force   # audit-logged
```

### `self_assessment_missing`

bolt-report.md lacks self-assessment YAML block.

```yaml
blocker:
  type: self_assessment_missing
  source_skill: execute-bolts
  details:
    unit_id: U-009
    expected_block: "bolt_self_report"
```

Recovery (bolt subagent skipped mandatory output):

```bash
# Inspect what bolt-report.md actually contains
cat <vault>/bolts/U-009/bolt-report.md

# Re-run the bolt:
execute-bolts U-009

# If repeat failure: likely bolt subagent prompt drift; file plugin bug
```

---

## What you learned

- Halts are SAFETY NET, not bugs — they fire on real issues mega-sdd's rails caught
- Each halt's `next_action` field tells you exactly what to do
- `--resume` is universal recovery (CWD-driven + checkpoint-aware)
- A failed bolt's commit already landed (detect-after); the gate blocks further bolts until the user fixes forward or `git revert`s it
- Multiple recovery paths per halt type; choose based on context

## Wrap-up

For the full scenario catalog, see the [chooser table in the scenarios README](README.md#quick-chooser--which-scenario-fits-you).

Mega-sdd is now your friend for spec-driven AI development. The pipeline is opinionated, anti-hallucinating, and atomic. `/mega-sdd` is THE command; everything else exists for power users.

For deeper architecture details: see [`../../README.md`](../../README.md) advanced sections + [`docs/superpowers/specs/`](../../docs/superpowers/specs/) design docs.

For contributing: see [`../../plugins/mega-sdd/CLAUDE.md`](../../plugins/mega-sdd/CLAUDE.md).
