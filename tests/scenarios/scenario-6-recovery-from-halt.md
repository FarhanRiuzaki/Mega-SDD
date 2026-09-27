# Scenario 6 — Recovery from Halt

**Time**: ~15 minutes
**Goal**: Pipeline halted mid-chain. Understand the halt, fix the underlying issue, and resume cleanly. No data loss; no partial commits.

Halts are mega-sdd's safety net — they fire when a rail meets something it must not decide on its own. Knowing how to interpret + recover is essential for production use. A halt is a finding to read, not automatically a defect in your code: check the evidence it cites before you act (see the `binding_conflict` walkthrough).

Halts belong to the guarded pipeline (`plan` → `execute-bolts`) and to the extract, sync, emit and install-deps lanes. The direct and assisted lanes carry no halt envelope: when the work turns out to need the pipeline they stop and offer `/mega-sdd <input> --guarded` (`plugins/mega-sdd/references/direct-lane.md` §Escalating to guarded).

> **Command forms in this catalog** — `/mega-sdd` and `/mega-sdd --resume` are the registered front door. Bare skill invocations shown in recovery steps (e.g. `execute-bolts U-001`, `resolve-oq --binding`) are typed as plain text in the session — they phrase-route to their skill (the typed `/mega-sdd:<skill>` command forms were removed at 6.0.0).

## Common halt types you'll encounter

| Halt | What it means | When |
|---|---|---|
| `binding_conflict` | A unit's claim contradicts existing code | execute-bolts pre-flight 3.9 (JIT bind, per unit) |
| `plan_coverage_gap` | A PRD/KB requirement heading has no unit and no OQ | plan Step 5 |
| `oq_recommend_underspecified` | Recommendation missing citation/rationale | plan Step 5 (`validate-vault-oqs.sh`) |
| `dedup_ambiguous` | `create` unit targets existing files | plan Step 4 (and `plan --reconcile`) |
| `hard_rule_violated` | Bolt modified locked code | execute-bolts post-flight |
| `hard_rule_unparseable` | Unit's Hard Rule has bad syntax | plan Step 5 / execute-bolts pre-flight |
| `cross_squad_interface_draft` | Consumer waiting for producer to lock interface | execute-bolts --per-squad (migrated multi-squad vaults) |
| `module_blocked_by` | Prerequisite module not complete | execute-bolts --module=X |
| `oq_business_p1_unresolved` | P1 business OQ blocking downstream | orchestrate-flow oq_gate (a P1 business OQ plan's batched ask left open) |
| `quality_gate_failed` | a module's per-module quality gate failed twice | extract-intelligence |

A pre-9.0 layout-2 vault can still show the legacy name `bind_conflict` (its whole-vault `binding.md`). It builds only after `/mega-sdd:migrate-paths --vault-layout=3` and the mandatory full JIT re-bind, which re-raises every live CONFLICT as `binding_conflict`.

Each halt provides a YAML `blocker` artifact with `next_action` field telling you exactly what to do. Above the YAML the displayer prints a plain-language keterangan block — **Apa yang ditanya** / **Kenapa berhenti** / **Pilihan lo** (`plugins/mega-sdd/references/halt-protocol.md` §Canonical `next_action` field shape).

## Recovery pattern (universal)

For any halt:

1. Read the blocker YAML in chat
2. Understand what triggered it
3. Resolve the underlying issue
4. Run `/mega-sdd --resume`

Mega-sdd's `--resume` is CWD-driven: it re-derives state from disk (`derive-state.sh`) and continues from the first incomplete phase.

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
files: ["**/app/Http/Controllers/Api/LoginController.php"]
rule:
  pattern: |
    return response()->json($$$);
message: ALL response() calls are locked  # ← intentionally over-strict
```

This will cause the bolt to fail because it adds the new error response. Re-run:

```
execute-bolts U-001
```

### The halt fires

```
▶ Dispatching bolt-implementer for U-001…
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
files: ["**/app/Http/Controllers/Api/LoginController.php"]
rule:
  pattern: |
    return response()->json(['token' => $$$]);
message: 200-success response shape (with token key) is locked
```

Now the rule only locks the success path; new 401 error is allowed.

Commit the rule edit, re-run the post-flight scan, and the gate opens (the bolt commit already landed — no re-execution needed):

```bash
git commit -am "fix(U-001): correct hard rule"
bash <plugin>/scripts/run-postflight-scan.sh --cwd=. --unit=U-001   # → status: pass
/mega-sdd --resume
```

### Option B: Revert the bolt's code change (rare)

If bolt actually went wrong + rule was correct:

```bash
git revert <bolt-commit>   # or fix forward
bash <plugin>/scripts/run-postflight-scan.sh --cwd=. --unit=U-001

# Re-think the unit's task — maybe Migration notes were wrong
# Edit unit body, then:
execute-bolts U-001
```

### Option C: Skip the scan for THIS run (broken tool / known false positive) — BLOCKING stays blocking

If you know the rule was wrong but don't want to edit it:

```bash
execute-bolts U-001 --force-skip-postflight
```

⚠️ Any use is logged in the handoff YAML + `_summary.md`. Use sparingly — DISCOURAGED; BLOCKING remains BLOCKING.

### Option D: Revert the bolt, then resume

If unit isn't critical:

```bash
git revert <bolt-commit>
bash <plugin>/scripts/run-postflight-scan.sh --cwd=. --unit=U-001
/mega-sdd --resume    # the unit is re-dispatched
```

After the revert + a passing post-flight scan, `/mega-sdd --resume` re-dispatches the unit.

## Scenario walkthrough — `binding_conflict`

Equally common. Different recovery pattern. Binding is per unit: `execute-bolts` binds each unit just in time at dispatch (pre-flight 3.9 → `bolts/U-XXX/binding.json`), so the CONFLICT closes that unit only — the other units proceed and its dependents are skipped with the reason.

### The halt

```
⛔ HALT — binding_conflict

blocker:
  type: binding_conflict
  emitted_at: 2026-05-21T15:35:00Z
  source_skill: execute-bolts
  details:
    unit_id: U-004
    binding: .mega-sdd/vaults/login-extension/bolts/U-004/binding.json
    conflicts:
      - id: C-U004-01
        kind: text
        expect: "API auth uses Bearer tokens"
        anchor: routes/api.php:12
        evidence: "routes/api.php:12 — /api/* sits behind the session-cookie guard (Laravel default)"
        suggested_action: SPLIT
        suggested_action_rationale: "Sanctum tokens for /api/*, sessions for web — least churn"
  next_action: "Run resolve-oq --binding"
```

The four actions at the walk: KEEP_VAULT — code harus diubah mengikuti vault (migrate all auth to Bearer; high effort); KEEP_CODE — vault di-update mengikuti kenyataan code (preserve session auth); DEFER — jadi OQ yang dibawa unit (the gate opens; execute-bolts asks before the final bolt); SPLIT — claim dipecah jadi sub-claim (Sanctum for /api/*, sessions for web).

**Check the anchor before you pick.** A CONFLICT can be the pipeline's own anchor error rather than a spec-vs-code contradiction. In the 9.0 brownfield benchmark the gate fired 3 times in 3 runs and all 3 were false positives — one line range the pipeline mistyped, two anchors moved by a sibling unit's legitimate commit — each resolved `KEEP_CODE` (`research/2026-09-27-brownfield-results.md` §3). The writer repairs a stale line range itself when the content is unchanged; a range it cannot repair stays a CONFLICT, and `KEEP_CODE` + a hand-corrected `## Anchors` line is the human path. Never edit an anchor just to make a claim pass.

### Recovery

```
resolve-oq --binding
```

(A converging `--deep` chain — the default — enters `resolve-oq --binding` itself inside `execute-bolts` on `binding_conflict`; the manual walk below applies under `--no-converge`.)

Interactive walker:

```
CONFLICT C-U004-01 (U-004):
  Unit claims: "API auth uses Bearer tokens"
  Code:        routes/api.php:12 — session-cookie guard
  
  Recommendation: SPLIT — Sanctum for /api/*; sessions for web (recommended)
  Rationale: Laravel best practice (framework pack §Security idioms) + minimal churn
  Source: binding evidence routes/api.php:12 + config/sanctum.php:1
  Fallback-if-wrong: If client requires single-auth uniformity, revisit
  Confidence: HIGH
  
  Options:
    [S] SPLIT (recommended) — Sanctum API + session web
    [K] KEEP_VAULT — migrate all to Bearer (high effort)
    [C] KEEP_CODE — preserve session auth; update vault
    [D] DEFER — handle later (becomes an OQ the unit carries)
```

Pick [S]. resolve-oq records the choice through the sole writer (`write-unit-binding.sh --resolve=C-U004-01=SPLIT --by=user`) in `bolts/U-004/binding.json` — hook-guarded evidence, never edited by hand. SPLIT (like KEEP_CODE) also edits the unit's `## Claims`, so U-004 is re-bound once (`rebind-units.sh --units=U-004`) before it dispatches; KEEP_VAULT / DEFER open the gate with no re-bind. Resume:

```
/mega-sdd --resume
```

`execute-bolts` re-derives the gate; U-004 dispatches, then the dependents it held back.

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

If the PRD is good enough, answer **Re-prompt** with that note as the extra direction — there is no accept-as-is option. If not: check whether the module's `source_files` actually carry the logic — a mis-split census proposal means **Re-scope**, not another re-prompt.

There is NO auto-resume after Abort: the next `extract-intelligence` run starts again from the census (idempotent — module PRDs that already passed stay on disk, and the completeness gate recomputes coverage from the artifacts, never from the conversation).

## Universal `--resume` rules

`/mega-sdd --resume` does the right thing:

1. Re-derives state from disk (`derive-state.sh` — artifact presence; no checkpoint file is read)
2. Identifies the latest incomplete phase
3. Re-runs that phase if needed (idempotent for clean states)
4. Continues forward per the handoff YAML protocol

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

```bash
cat .mega-sdd/vaults/<slug>/bolts/U-XXX/binding.json
```

The unit's JIT-bind verdicts: CONFIRMED / CONFLICT / OQ per claim, with its anchor, the evidence, and any recorded resolution.

## Common pitfalls during recovery

### Recovery loop

Same halt fires after `--resume`. You haven't fixed the underlying issue. Read the blocker YAML AGAIN; the `next_action` is specific. If unclear, check:

- For `hard_rule_violated`: did you actually adjust the rule OR revert the code?
- For `binding_conflict`: did `resolve-oq --binding` actually save the resolution? Check the claim's `resolution` in `bolts/U-XXX/binding.json`.
- For `dedup_ambiguous`: did you actually update target_files in the unit?

### Force-commit after `hard_rule_violated`

```bash
execute-bolts U-XXX --force-skip-postflight
```

⚠️ Bypasses safety rail. Use ONLY when you've manually verified the code change is intentional + acceptable. Logged in the handoff YAML + `_summary.md`; BLOCKING remains BLOCKING.

---

# Additional halt walkthroughs

These walkthroughs cover the high-frequency halts beyond the three above, from the halt families in `references/halt-families/` (per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`). They complement the universal recovery patterns documented above — each walkthrough shows the trigger, halt envelope, and recovery options.

## Scenario walkthrough — `handoff_missing`

**When you'll see it.** A sub-skill in an `--auto` chain exits without emitting a `handoff:` YAML block in its chat output. Orchestrator can't decide auto-continue / pause / stop without that block. The check looks at the sub-skill's chat output (last assistant message), NOT a file on disk. (`plan` emits no handoff by design — the front door re-derives state from disk after it — so this halt never names `plan`.)

**Example halt envelope:**

```yaml
type: handoff_missing
source_skill: orchestrate-flow
details:
  failing_skill: detect-drift
  last_known_step: "Step 4 (DRIFT-REPORT.md being written)"
  chat_tail_excerpt: "... write to file failed: ENOSPC: no space left on device\nProcess exited with code 1"
next_action:
  type: inspect_subskill_logs
  hint: "Sub-skill `detect-drift` exited without emitting handoff YAML in chat. Inspect chat_tail_excerpt for crash logs / OS-level failures."
```

**Recovery:** read `chat_tail_excerpt` for the crash signal. Re-run sub-skill standalone to reproduce (`detect-drift --vault=<vault-dir> --code=<repo-root>`). If reproducible → file a skill-author bug. If transient (disk full, OOM) → fix the environmental issue and retry.

Cross-refs: `plugins/mega-sdd/references/halt-protocol.md §halt-protocol` (flow family: `halt-families/flow.md §handoff_missing`); `orchestrate-flow/references/handoff-contract.md §Pre-validation`.

## Scenario walkthrough — `artifact_missing`

**When you'll see it.** A sub-skill emits a handoff YAML with `artifacts: [paths]` listing files that don't exist on disk (because the producer crashed mid-write OR fabricated paths). The handoff validator (step `b.script`) existence-checks every path BEFORE consuming.

**Example halt envelope:**

```yaml
type: artifact_missing
source_skill: orchestrate-flow
details:
  failing_skill: extract-intelligence
  missing_paths: ["<kb>/modules/swift-messaging.prd.md", "<kb>/modules/reporting.prd.md"]
  present_paths: ["<kb>/modules/reference-data.prd.md", ..., "<kb>/modules/import-lc.prd.md"]
next_action:
  type: re_run_producer
  hint: "Producer declared 6 module PRDs but only wrote 4. Re-run extract-intelligence standalone to reproduce. Likely cause: crash mid-loop."
```

**Recovery:** re-run the producer skill standalone; inspect chat for mid-write crash signals. If reproducible → file bug. If transient → re-run + retry chain.

## Scenario walkthrough — `partial_state_corrupt` + saga rollback

**When you'll see it.** `<vault>/bolts/U-XXX/partial-state.json` (a crashed bolt's resume record) fails JSON parse. At GROUND (`scripts/ground.sh`, which the front door and sync run at entry) this is a C1 self-resolve: the file is renamed aside to `partial-state.json.corrupt-<ISO8601>` (forensics kept), a `[self-resolved]` line is printed, and the next `--resume` restarts the unit fresh from its spec. You only meet a halt when a standalone `execute-bolts --resume` loads the corrupt file before GROUND ran.

**Recovery option 1 (forensics + restart — the same rename by hand):**

```bash
mv <vault>/bolts/U-007/partial-state.json <vault>/bolts/U-007/partial-state.json.corrupt-$(date -u +%Y-%m-%dT%H:%M:%SZ)
execute-bolts U-007 --resume   # starts fresh now that corrupt file is moved aside
```

**Recovery option 2 (saga rollback — v2.0 partial-state):** if the corrupt file is actually v2.0 with intact `rollback_hints[]` despite parse failure (rare — JSON header valid but `rollback_hints` array malformed), use `--rollback` to undo prior non-idempotent steps before re-attempting:

```bash
execute-bolts U-007 --rollback   # applies rollback_hints[] in reverse order
execute-bolts U-007              # fresh re-run from clean slate
```

Cross-refs: `plugins/mega-sdd/references/halt-protocol.md §halt-protocol` (bolts family: `halt-families/bolts.md §partial_state_corrupt`); `execute-bolts/SKILL.md §Partial-state, resume + saga rollback` (+ `references/partial-state-and-saga.md`).

## Scenario walkthrough — `oq_blocker`

**When you'll see it.** An AI consumer reading the vault non-interactively (per `<vault>/_meta/ai-consumer-guide.md`) meets an unresolved P1 Open Question that blocks its work. `plan` never emits it: a P1 business OQ its batched ask left open stays `blocking`, and the units that need it surface at bolts as `oq_business_p1_unresolved`.

**Recovery:**

```bash
resolve-oq <vault-path>       # interactive Q&A walk through unresolved OQs
# OR
# Edit context.md ## Open Questions directly (`[x]` + `→ Resolved v<X.Y>: <answer>`), then re-derive vault.json:
bash <plugin>/scripts/derive-vault-json.sh --vault=<vault-path>
```

Technical OQs are not yours to answer: `plan` decides every `tech` OQ itself (a labelled, cited AI decision). A leftover open `[tech / scan]` OQ on a migrated pre-9.0 vault is decided in the next `resolve-oq` walk.

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

**When you'll see it.** Current semantics: fires ONLY when all three hold — every disposable T2 section is already truncated to its drop floor, the prompt still exceeds the hard cap (`cap_hard`, 12 KB), and a non-empty constitution-clause section (never truncated) is what remains. Real config issue, not bolt-fixable.

**Recovery:** the halt envelope shows `warnings: [{section, rule_applied, bytes_saved}, ...]` — review which sections truncated. If constitution_clauses is the bulk, consider:
1. Splitting the unit (smaller scope = fewer constitution clauses referenced)
2. Citing fewer constitution clause ids in the unit (the builder injects the ids the unit names in prose, frontmatter, `binding_refs` or `## Hard rules`)
3. (Last resort) editing the constitution to merge or shorten clauses

Cross-refs: `execute-bolts/references/context-enrichment.md §T2 section priority + truncation cascade` + §Halt path.

## Scenario walkthrough — `provenance_missing`

**When you'll see it.** Bolt subagent committed code without the provenance trailer (two lines: `Generated by mega-sdd execute-bolts <version>` / `Unit: U-XXX · provenance: <bolts/U-XXX/dispatch-prompt.md>`). Post-flight scan catches this.

**Recovery:** edit each modified file to add the trailer; amend the bolt commit:

```bash
# In your editor, add trailer to top of each modified file
git add <modified-files>
git commit --amend --no-edit
execute-bolts U-007 --resume   # post-flight will pass now
```

Cross-refs: `agents/bolt-implementer.md §Provenance trailer`.

## Scenario walkthrough — `cross_squad_dep_invalid`

**When you'll see it.** Only on a migrated pre-9.0 vault that carries `_meta/squads.yaml` (`plan` never authors squads), when `plan` re-writes its units (`plan --regenerate`): a unit's `depends_on` points at a unit in another squad. Cross-squad coupling must route through `consumes_interfaces`; a not-yet-locked interface is `cross_squad_interface_draft`, a dangling ref is `interface_ref_missing`.

**Recovery:**

```bash
# Option A: re-partition the squads so both units sit in one squad
# Edit <vault>/_meta/squads.yaml, then re-run:
plan <prd> --regenerate

# Option B: replace the cross-squad depends_on with an interface
# Edit the unit: drop the depends_on edge, add the producer's interface id to consumes_interfaces
# (the interface note lives in <vault>/interfaces/), then re-run plan --regenerate

# Option C: the interface exists but is still draft → that is cross_squad_interface_draft:
# the producer squad lands its unit and locks the interface (status: locked in <vault>/interfaces/)
execute-bolts U-<producer-unit> --squad=producer-squad
```

Cross-refs: `plugins/mega-sdd/references/halt-families/units.md §cross_squad_dep_invalid` + `plan/references/decomposition-rails.md §Squad assignment`.

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

### `subtype: pdf_render_failed` (emit-fsd)

```yaml
blocker:
  type: quality_gate_failed
  source_skill: emit-fsd
  details:
    subtype: pdf_render_failed
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

### `module_quality_threshold_unmet` or omitted (extract-intelligence)

The extract default — the envelope emits with `subtype` absent; `module_quality_threshold_unmet` is the registry's documentation label for it. Existing walkthrough above at §`quality_gate_failed` (extract-intelligence) covers this case.

---

## Scenario walkthrough — PRD-scope halt

PRD multi-scope handling carries one halt, raised by `plan` (and by the scope-flag PreToolUse gate `validate-scope-flag.sh`). A PRD without a `scopes:` block is single-scope: no picker, no retrofit prompt, so the old retrofit halts never fire.

### `scope_not_declared_in_prd`

```yaml
blocker:
  type: scope_not_declared_in_prd
  source_skill: plan
  context: "Step 0.9 scope picker"
  requested_scope: "BE"
  declared_scopes: ["FE", "MW"]
  options: ["re-pick-from-declared", "cancel"]
  resolver_route: user
```

Recovery:

```bash
# Option 1: pick valid scope from declared list
plan ./prd.md --scope=FE

# Option 2: edit PRD frontmatter (by hand) to add missing scope
# Add to PRD frontmatter:
#   scopes:
#     BE:
#       name: Backend
# Then re-run
plan ./prd.md --scope=BE
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
# OR re-extract intelligence + plan a new vault from the KB:
extract-intelligence ./ --out=./.mega-sdd/
plan --kb=.mega-sdd/knowledge-base/ --vault=.mega-sdd/vaults/<new-slug>

# Option 2: vault-supersede (codebase regressed; revert to Laravel)
git revert <commit-range>   # roll back framework migration
# OR
git checkout <pre-migration-tag>

# Option 3: split — keep both as separate vault scopes
# Add a scopes block to the PRD frontmatter by hand (one key per scope: legacy-laravel, new-spring — each with a name)
plan ./prd.md --scope=new-spring --vault=.mega-sdd/vaults/<new-slug>
```

### `constitution_drift_detected`

§B (security) or §F (compliance) constitution clause drift detected in code — or `constitution.md`'s hash no longer matches the one pinned in `vault.json`.

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
# Edit <vault>/constitution.md §B-007
# (Constitution edits require sign-off per CLAUDE.md governance)
```

Editing `constitution.md` moves its hash away from the `constitution_hash` pinned in `vault.json`, so every later `detect-drift` run halts on the hash mismatch: `/mega-sdd:sync` does not clear it (no re-bind re-pins the hash). Either revert `constitution.md` to the pinned state, or accept the change — bolts already read the live `constitution.md` at dispatch — and expect the halt to re-fire until a re-pin path exists (`plugins/mega-sdd/references/halt-families/flow.md §constitution_drift_detected`).

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
# If genuinely blocked: author the OQ into `context.md ## Open Questions`
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

Recovery (override-only):

```bash
# Option 1: revert bolt changes (locked entity protected by design)
git diff HEAD <vault>/bolts/U-007/preflight.json   # see what bolt wrote
git checkout <pre-bolt-state>

# Option 2: amend constitution to allow drift (requires explicit user approval)
# Edit <vault>/constitution.md — explicitly mark src/auth/User.php as UNLOCKED for this field
# Re-run bolt:
execute-bolts U-007 --force   # re-executes the completed unit
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

- Halts are the SAFETY NET, not bugs — but a halt is a finding to check, not a verdict: a `binding_conflict` can be the pipeline's own stale anchor
- Each halt's `next_action` field tells you exactly what to do
- `--resume` is universal recovery (CWD-driven: state re-derived from disk)
- A failed bolt's commit already landed (detect-after); the gate blocks further bolts until the user fixes forward or `git revert`s it
- Multiple recovery paths per halt type; choose based on context
- A recovered run is done only when `execute-bolts` ends with the result contract every lane delivers: the acceptance-criterion → test table, `delivery-check.sh` `VERDICT: PASS` on the final commit, and the assumptions and decisions made

## Wrap-up

For the full scenario catalog, see the [chooser table in the scenarios README](README.md#quick-chooser--which-scenario-fits-you).

Mega-sdd is now your friend for spec-driven AI development. The guarded pipeline is opinionated and atomic: its procedure turns an uncertain claim into an Open Question rather than a guess, and every unit and binding verdict is traceable to its source. That is traceability and audit, not a measured accuracy gain over plain Claude Code (the benchmark blocks showed none; see the root README, "Measured against plain Claude Code"). `/mega-sdd` is THE command; everything else exists for power users.

For deeper architecture details: see [`../../README.md`](../../README.md) advanced sections + [`docs/superpowers/specs/`](../../docs/superpowers/specs/) design docs.

For contributing: see [`../../plugins/mega-sdd/CLAUDE.md`](../../plugins/mega-sdd/CLAUDE.md).
