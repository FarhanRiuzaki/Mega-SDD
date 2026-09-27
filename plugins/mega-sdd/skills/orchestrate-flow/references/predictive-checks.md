# Predictive Checks Catalog

> Per-skill preflight checks consulted by `mega-sdd:orchestrate-flow` Step 5.

**Consumed by:** `mega-sdd:orchestrate-flow` Step 5 predictive preflight

---

## Contents

- [Purpose](#purpose)
- [Check entry format](#check-entry-format)
- [plan preflight checks](#plan-preflight-checks)
- [execute-bolts preflight checks](#execute-bolts-preflight-checks)
- [detect-drift preflight checks](#detect-drift-preflight-checks)
- [diff-vault preflight checks](#diff-vault-preflight-checks)
- [resolve-oq preflight checks](#resolve-oq-preflight-checks)
- [extract-intelligence preflight checks](#extract-intelligence-preflight-checks)
- [emit-agents-md preflight checks](#emit-agents-md-preflight-checks)
- [Cold-halt anticipation checks](#cold-halt-anticipation-checks)
- [install-deps preflight checks](#install-deps-preflight-checks)
- [emit-fsd preflight checks](#emit-fsd-preflight-checks)
- [Removed skills (9.0)](#removed-skills-90)
- [Read protocol (Step 5)](#read-protocol-step-5)
- [Anti-halu rails](#anti-halu-rails)
- [Adding new checks](#adding-new-checks)
- [See also](#see-also)

## Purpose

Catalog of lightweight checks that detect known halt preconditions BEFORE invoking the skill. Instead of execute-bolts halting `dep_missing` on a v2 Hard Rule mid-run, the user sees before chain start: "ast-grep not installed, so GROUND built no symbol index; run `/mega-sdd:install-deps`".

---

## Check entry format

```markdown
### <skill-name> preflight checks

- **check_id: `<unique-snake-case-id>`**
  command: `<bash command to run>`
  expected: <exit 0 | non-empty output | file exists>
  on_fail: <user-facing warning message>
  fatal: <yes | no>
  predicts_halt: <halt-type that would fire if check ignored>
```

- `command:` MUST be lightweight (no full file scans; bash probes + file existence checks only)
- `fatal: yes` → halt chain with `predictive_check_failed` envelope
- `fatal: no` → log warning + continue (most checks)
- `predicts_halt:` is informational (documents which downstream halt this check anticipates)

---

## plan preflight checks

- **check_id: `prd_or_kb_input_present`**
  command: plan hop with a POSITIONAL input (a PRD path) → `test -f <positional-input>` (a positional that resolves to a file IS the input; the root probe below applies only when no positional exists). With `--kb=<kb-dir>` → `test -f <kb-dir>/README.md && ls <kb-dir>/modules/*.prd.md`. Otherwise: `test -f <project>/prd.md` OR the derive-state digest's `probes.prd.present` (which scans root + one level inside dirs whose name case-insensitively matches `PRD`/`docs`/`documents`/`requirements`).
  expected: at least one input
  on_fail: "plan requires an input — a positional PRD, root prd.md, a PRD candidate in PRD/ or docs/, or --kb=<kb-dir> (extract-intelligence output). For a free-text brief: write it to a file or use the direct/assisted lane. Or run extract-intelligence first."
  fatal: yes
  predicts_halt: (chain order error)
  note: model-run — the positional and `--kb` are invisible to `validate-preflight.sh --chain`, so the script skips this check. A root-only probe against an explicitly-supplied positional PRD is a FALSE FAIL predicting a halt plan would never raise (field finding, training-nextjs 2026-08-03).

- **check_id: `ast_engine_present`**
  command: `command -v ast-grep` (a repo with no source files passes: there is no symbol index to build)
  expected: exit 0
  on_fail: "ast-grep not installed; GROUND builds no symbol index, so plan types brownfield units greenfield (+WARN), JIT bind leaves symbol claims OQ, v2 Hard Rules halt dep_missing. Install ast-grep (brew install ast-grep / scoop install ast-grep) OR run `/mega-sdd:install-deps`."
  fatal: no
  predicts_halt: dep_missing (execute-bolts: a v2 Hard Rule with ast-grep absent, `hard-rule-scan.md` exit 6)

- **check_id: `plan_layout2_vault`** (dispatch-time only)
  command: resolve the dispatch's TARGET vault (`--vault=<name|dir>`, else `.mega-sdd/vaults/<slug>` from the `<prd>` positional; unresolvable under `--kb` / `--reconcile` → pass), then `test -f <target>/context.md || ! { test -f <target>/vault.md || ls <target>/0[0-6]-*.md; }`
  expected: the target is layout-3 (`context.md` present; a migrated vault has one), not yet written, or unresolvable
  on_fail: "plan writes layout-3 only and the target vault <dir> is layout-2 (no context.md) — run /mega-sdd:migrate-paths --vault-layout=3 --vault=<dir> first (a legacy 7-file vault takes --vault-layout first; then the mandatory full JIT re-bind), or pass --vault=<new-dir> for a separate plan-born vault."
  fatal: yes
  predicts_halt: (dispatch refusal — plan writes layout-3 only; the layout-2 migration rung is spec 2026-09-27 §4)
  note: run by the PreToolUse preflight on a `plan` dispatch (`validate-preflight.sh --skill=mega-sdd:plan --args-b64=…`, no `--predictive`). `--chain` cannot see `--vault=` or the positional, so the predictive run skips it (same reason as `prd_or_kb_input_present`). Only the dispatch's own target is probed, never every vault dir: a layout-2 vault next to a new PRD must not block that PRD.

No framework-pack check: GROUND's pack matcher and the bolt dispatch (`scripts/_lib/resolve-framework-pack.sh`) always fall back to `_universal.md`, so a missing pack never halts. The pre-9.0 `framework_pack_present` probe (a scan-codebase check) could only test that the fallback file exists, and was retired with scan-codebase.

## execute-bolts preflight checks

- **check_id: `units_directory_present`**
  command: `test -d <vault-path>/units && ls <vault-path>/units/U-*.md | head -1`
  expected: at least 1 unit file exists
  on_fail: "execute-bolts requires generated units. Run plan <prd> first (plan writes units/U-*.md)."
  fatal: yes
  predicts_halt: (chain order error — invokes plan instead)

- **check_id: `ast_engine_present`**
  command: `command -v ast-grep` (a repo with no source files passes)
  expected: exit 0
  on_fail: "ast-grep not installed; a unit carrying v2 (ast-grep YAML) Hard Rules halts dep_missing at pre-flight, and the JIT bind leaves symbol claims OQ. Install ast-grep (brew install ast-grep / scoop install ast-grep) OR run `/mega-sdd:install-deps`."
  fatal: no
  predicts_halt: dep_missing (`hard-rule-scan.md` exit 6 — v2 grammar, ast-grep absent)
  note: the same probe as the plan entry, repeated here because the halt it predicts fires at execute-bolts: a chain that starts at execute-bolts (`units_pending_bolts`) has no plan hop to carry the warning. A `plan,execute-bolts` chain reports it once per hop. Not fatal: a unit without v2 Hard Rules runs fine without ast-grep.

- **check_id: `lite_plan_coverage_pass`**
  command: `python3 -c "import json,sys; sys.exit(0 if json.load(open('<project>/.mega-sdd/.plan-coverage-state.json')).get('status') == 'PASS' else 1)"`
  expected: exit 0 (the census `validate-plan-coverage.sh` writes at plan Step 5 is PASS)
  on_fail: ".mega-sdd/.plan-coverage-state.json is missing or FAIL (plan_coverage_gap): every PRD requirement heading must be owned by a unit's prd_source or quoted by an open question BEFORE execute-bolts. Run validate-plan-coverage.sh --cwd --prd --vault (plan Step 5; legacy KB: --kb=<kb-dir>) and close the listed gaps; a missing state is a skipped census, not a pass. A layout-2 vault: /mega-sdd:migrate-paths --vault-layout=3 first (a migrated vault is exempt)."
  fatal: yes
  predicts_halt: plan_coverage_gap
  note: ALWAYS ON. 9.0 has one pipeline, so no lane or config key (`lane:`, `--lite`) switches the rail off. The only exemption is a MIGRATED layout-2 vault (`<vault>/_meta/archive/layout2/` present; its classic-born units carry no `prd_source`, spec 2026-09-27 §7 #12): the check is then not run at all, unless an un-migrated plan-born vault (`context.md`) in the same project carries units. A missing or unreadable state is fatal, except when a `plan` hop earlier in the same chain writes it (chain-aware, see §Read protocol). The PreToolUse hook enforces the rail at dispatch for plan-born vaults (§Dispatch-time mode below), so a direct `execute-bolts` call or a hand `bolt-implementer` dispatch that skipped this predictive run is still refused.

## detect-drift preflight checks

- **check_id: `vault_present_for_drift`**
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "detect-drift requires a vault. Run plan <prd> first."
  fatal: yes
  predicts_halt: (chain order error)

- **check_id: `binding_present_for_drift`**
  command: layout-3 (`<vault-path>/context.md` present) → `ls <vault-path>/bolts/U-*/binding.json | head -1`; otherwise (readable layout-2) → `test -f <vault-path>/binding.md && grep -q "^## Confirmed Claims" <vault-path>/binding.md`
  expected: layout-3: at least one per-unit `binding.json`; layout-2: binding.md with a Confirmed Claims section
  on_fail: "detect-drift needs binding verdicts: run execute-bolts --all --lite (JIT bind → bolts/U-*/binding.json) or scripts/rebind-units.sh --units=all; a layout-2 vault with no binding.md needs /mega-sdd:migrate-paths --vault-layout=3 first."
  fatal: yes
  predicts_halt: (chain order error — drift has no anchor points)

- **check_id: `clean_working_tree_for_drift`**
  command: `git status --porcelain | head -1`
  expected: empty output (no uncommitted changes)
  on_fail: "detect-drift may conflate uncommitted user edits with actual drift. Commit or stash local changes first for clean drift report."
  fatal: no
  predicts_halt: (no halt; degraded drift signal)

## diff-vault preflight checks

- **check_id: `current_vault_present_for_diff`**
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "diff-vault requires a current vault to compare the new source against. Run plan <prd> first."
  fatal: yes
  predicts_halt: (chain order error)

- **check_id: `new_source_resolves_for_diff`**
  command: `test -f <new-source-path>`
  expected: file exists
  on_fail: "diff-vault second argument must resolve to existing PRD/source file."
  fatal: yes
  predicts_halt: prd_path_missing

- **check_id: `vault_version_parseable`**
  command: `python3 -c "import json; print(json.load(open('<vault-path>/vault.json'))['vault_version'])" 2>&1`
  expected: outputs valid version string (no exception)
  on_fail: "current vault.json malformed OR missing vault_version field. diff-vault cannot determine version bump target."
  fatal: yes
  predicts_halt: invalid_handoff

## resolve-oq preflight checks

- **check_id: `vault_present_for_oq`**
  command: `test -f <vault-path>/vault.json && { test -f <vault-path>/context.md || test -f <vault-path>/constraints.md || test -f <vault-path>/06-constraints.md; }`
  expected: vault.json + the OQ doc of the vault's layout exist (layout-3 `context.md`; layout-2 `constraints.md`; legacy `06-constraints.md` — no layout ever had `03-open-questions.md`)
  on_fail: "resolve-oq requires a vault with vault.json + the OQ doc (context.md on layout-3; constraints.md / 06-constraints.md on readable layout-2/legacy vaults). Run plan <prd> (or plan --kb=<kb-dir>) first."
  fatal: yes
  predicts_halt: (chain order error)

- **check_id: `oq_status_field_present`**
  command: `python3 -c "import json; v=json.load(open('<vault-path>/vault.json')); exit(0 if any('status' in oq for oq in v.get('open_questions', [])) else 1)"`
  expected: at least one OQ entry has status field (schema)
  on_fail: "vault.json open_questions[] entries lack 'status' field (old schema). resolve-oq cannot track Resolve/Out-of-Scope/Defer outcomes without status field. Re-derive with scripts/derive-vault-json.sh --vault=<dir>; a plan-born vault can be rebuilt with plan <prd> --regenerate (layout-2: /mega-sdd:migrate-paths --vault-layout=3 first)."
  fatal: no
  predicts_halt: (no halt; degraded interactive walk)

- **check_id: `unresolved_oqs_exist`**
  command: `python3 -c "import json; v=json.load(open('<vault-path>/vault.json')); print(sum(1 for oq in v.get('open_questions', []) if oq.get('status') != 'resolved'))"`
  expected: non-zero count
  on_fail: "All OQs in vault are already resolved. resolve-oq is a no-op."
  fatal: no
  predicts_halt: (no halt; no-op invocation)

## extract-intelligence preflight checks

- **check_id: `legacy_codebase_path_present`**
  command: `test -d <legacy-path> && [ "$(ls -A <legacy-path>)" ]`
  expected: directory exists AND non-empty
  on_fail: "extract-intelligence requires a non-empty legacy codebase path."
  fatal: yes
  predicts_halt: dep_missing

- **check_id: `kb_target_writable`**
  command: `mkdir -p <kb-output-dir>/.test-write && rmdir <kb-output-dir>/.test-write`
  expected: exit 0 (directory creatable)
  on_fail: "extract-intelligence cannot write to <kb-output-dir>. Check permissions OR change --out=."
  fatal: yes
  predicts_halt: dep_missing

- **check_id: `subagent_capacity_reasonable`**
  command: `[ "<max-parallel-flag-value>" -le 5 ]`
  expected: exit 0 (max-parallel ≤ 5)
  on_fail: "extract-intelligence --max-parallel=<N> exceeds the advisory threshold (5, the default). Above it, coordination overhead tends to outrun the gain. Soft warn at >5; hard cap at 8 still enforced by extract-intelligence."
  fatal: no
  predicts_halt: (no halt; degraded throughput)

## emit-agents-md preflight checks

- **check_id: `vault_present_for_agents_md`**
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "emit-agents-md requires a vault. Run plan <prd> first."
  fatal: yes
  predicts_halt: (chain order error)

- **check_id: `units_present_for_agents_md`**
  command: `test -d <vault-path>/units && ls <vault-path>/units/U-*.md | head -1`
  expected: at least 1 unit file exists
  on_fail: "emit-agents-md is unit-aware (lists units in AGENTS.md). Run plan <prd> first (plan writes the units) OR pass --no-units for a vault-only AGENTS.md."
  fatal: no
  predicts_halt: (no halt; degraded AGENTS.md)

## Cold-halt anticipation checks

Most halts are runtime-only (cannot statically predict). These 4 feasible static checks cover the ones that would otherwise fire cold (no anticipating predictive-check):

- **check_id: `units_depends_on_dag_acyclic`** (anticipates `cycle_detected`)
  command: `python3 -c "import json, glob; from collections import defaultdict; g=defaultdict(list); [g[d.get('id','')].extend(d.get('depends_on',[])) for f in glob.glob('<vault-path>/units/U-*.md') for d in [{}]]; print('ok')"` (skeleton — actual implementation parses YAML frontmatter from each unit's depends_on and runs DAG cycle detection)
  expected: exit 0 + 'ok' output
  on_fail: "Cycle detected in unit depends_on graph. Inspect <vault>/units/U-*.md frontmatter; resolve cycle BEFORE running execute-bolts."
  fatal: yes
  predicts_halt: cycle_detected

- **check_id: `partial_state_loads_cleanly`** (anticipates `partial_state_corrupt`)
  command: `for f in <vault-path>/bolts/U-*/partial-state.json; do [ -f "$f" ] || continue; python3 -c "import json; json.load(open('$f'))" 2>&1 || { echo "corrupt: $f"; exit 1; }; done`
  expected: exit 0 (all partial-state.json files parse cleanly OR none exist)
  on_fail: "One or more partial-state.json files have JSON parse errors. execute-bolts --resume will halt partial_state_corrupt. Rename .corrupt-<timestamp> and re-run without --resume OR fix the JSON manually."
  fatal: no
  predicts_halt: partial_state_corrupt

- **check_id: `units_have_acceptance_tests`** (anticipates `unit_underspecified`)
  command: `for f in <vault-path>/units/U-*.md; do grep -q "^acceptance_test:" "$f" || { echo "no acceptance_test: $f"; exit 1; }; done`
  expected: exit 0 (every unit has acceptance_test field)
  on_fail: "One or more units lack acceptance_test field. execute-bolts will halt unit_underspecified. Edit affected units (≥1 acceptance_test per the unit contract) OR re-run plan <prd> --regenerate."
  fatal: yes
  predicts_halt: unit_underspecified

- **check_id: `verify_units_have_no_target_files`** (anticipates `verify_unit_writable`)
  command: `for f in <vault-path>/units/U-*.md; do grep -A1 "^task_type: verify" "$f" | grep -q "target_files: \[\]" || { grep -q "^task_type: verify" "$f" && [ -n "$(grep -E '^target_files:\s*\[?[^]]' $f)" ] && echo "verify-unit with target_files: $f" && exit 1; }; done; echo ok`
  expected: exit 0
  on_fail: "One or more task_type: verify units have non-empty target_files. execute-bolts will halt verify_unit_writable. Edit affected units to remove target_files (verify units only run acceptance tests, don't author code)."
  fatal: yes
  predicts_halt: verify_unit_writable

**Documented as RUNTIME-ONLY (no feasible static check):**

- `handoff_missing`, `handoff_type_mismatch`, `artifact_missing` — orchestrate-flow self-emits on chain envelope state corruption; the corruption IS the runtime event
- `predictive_check_failed`, `model_tier_unknown` — orchestrate-flow self-checks during runtime
- `test_fail`, `hard_rule_violated`, `provenance_missing` — emitted during execute-bolts execution, not anticipatable pre-flight
- `cross_squad_interface_draft` — depends on producer skill state at runtime (interface lock status)

These halts rely on `chat_tail_excerpt` + `next_action.hint` + scenario-6 walkthroughs for recovery (no static preflight feasible).

## install-deps preflight checks

- **check_id: `pkg_mgr_detected`**
  command: `command -v brew || command -v apt || command -v dnf || command -v pacman || command -v apk || command -v winget || command -v scoop || command -v cargo || command -v npm || command -v go`
  expected: exit 0
  on_fail: "install-deps requires a compatible package manager (brew/apt/dnf/pacman/apk/winget/scoop) or cross-platform fallback (cargo/npm/go). None detected on PATH. macOS: install brew via https://brew.sh. Linux: verify apt/dnf is on PATH. Windows native: install WSL Ubuntu + re-run."
  fatal: yes
  predicts_halt: pkg_mgr_not_found

- **check_id: `network_reachable`**
  command: `curl -fsS --max-time 5 https://github.com >/dev/null 2>&1 || ping -c 1 -W 2 github.com >/dev/null 2>&1`
  expected: exit 0
  on_fail: "Network unreachable; package manager install will fail. Check connectivity OR set --manual to skip install (print commands only)."
  fatal: no
  predicts_halt: install_failed (network failure subtype)

## emit-fsd preflight checks

- **check_id: `vault_present_for_fsd`**
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "emit-fsd requires a vault. Run plan <prd> first."
  fatal: yes
  predicts_halt: dep_missing (chain order error)

- **check_id: `pandoc_installed`**
  command: `command -v pandoc`
  expected: exit 0
  on_fail: "pandoc not installed; emit-fsd will produce FSD.md only (no PDF render). Install: brew install pandoc (macOS) / apt install pandoc (Debian/Ubuntu) / dnf install pandoc (Fedora) — OR run `/mega-sdd:install-deps` for auto-install."
  fatal: no
  predicts_halt: (no halt; degraded output — markdown-only)

- **check_id: `chrome_mmdc_present`**
  command: `md2pdf.sh probes Chrome/Chromium (PDF printer) + command -v mmdc (mermaid)`
  expected: exit 0
  on_fail: "Chrome absent -> md2pdf emits GitHub-styled HTML (print-to-PDF from a browser) instead of PDF; mmdc absent -> mermaid stays code. Install Chrome (detect-only) + run /mega-sdd:install-deps --tools=mmdc. PDF is NEVER LaTeX."
  fatal: no
  predicts_halt: (no halt; degraded — HTML fallback)

## Removed skills (9.0)

- **check_id: `skill_removed_in_9`**
  command: the hop's skill is one of `generate-intent`, `bind-codebase`, `generate-units`, `scan-codebase` (`scripts/_lib/state_probes.py` `REMOVED_SKILLS`, the single list)
  expected: no hop names a removed skill
  on_fail: the skill's one-line replacement from `REMOVED_SKILLS`, e.g. "bind-codebase was removed in 9.0 — use plan → `execute-bolts --all --lite`, which binds each unit at dispatch (full audit: `scripts/rebind-units.sh --units=all`)."
  fatal: yes
  predicts_halt: (chain order error — a stale 8.x chain, e.g. a paused `--resume`)
  note: both modes emit it: the predictive run (`--chain=…`) and the dispatch mode (`--skill=mega-sdd:<name>`), including in a directory with no `.mega-sdd/` (never the no-project PASS; nothing is written there). It never depends on lane, config or vault layout, and none of the removed skill's pre-9.0 probes run. The removed skills are not coming back: the fix is the replacement hop the message names.

---

## Read protocol (Step 5)

> **IMPLEMENTED by `scripts/validate-preflight.sh --predictive`** — the orchestrator runs the script (`--predictive --cwd --chain`), never this loop by hand; the loop below is the maintainer's spec of what the script does, and this catalog is the script's declared source of truth.

```
For each skill in proposed chain:
  If skill is in §Removed skills (9.0) → fatal skill_removed_in_9; next skill (none of its probes run)
  Read this catalog's §<skill> section
    (execute-bolts also runs §Cold-halt anticipation checks; its lite_plan_coverage_pass
     is skipped only on a migrated layout-2 vault)
  Skip entries marked model-run or dispatch-time only
  For each check entry:
    Run command
    If expected condition met → pass; continue to next check
    If condition not met:
      If fatal: yes AND an earlier hop of this chain produces the missing input
        (plan → units, plan coverage) → pass (chain-aware; the PreToolUse dispatch
        gate re-checks both at that hop: bolts_units_missing, and lite_plan_coverage_pass
        on the plan-born vault plan writes — see Dispatch-time mode)
      If fatal: yes → emit halt predictive_check_failed; STOP chain
      If fatal: no → accumulate warning; log to user; continue chain
```

**Dispatch-time mode.** Separately from Step 5, the PreToolUse hook runs `validate-preflight.sh --skill=<skill> --args-b64=<dispatch args>` (no `--predictive`) on every `plan` and `execute-bolts` dispatch and blocks the dispatch on a fatal. It reads the dispatch args, so it owns the checks a `--chain` run cannot see: `plan_layout2_vault` (plan) and the execute-bolts units check (`bolts_units_missing`, the dispatch twin of `units_directory_present`). For `execute-bolts` it also enforces `lite_plan_coverage_pass` by READING `.mega-sdd/.plan-coverage-state.json` (no extra process in the hook): anything but `status: PASS` (missing, FAIL, unreadable) is fatal while any plan-born vault carries units: layout-3 (`context.md`) and not migrated (`_meta/archive/layout2/` absent). No dispatch arg narrows that set: `execute-bolts` has no `--vault` flag, the in-run `bolt-implementer` dispatch carries no args, and the census is one project-wide file. The gate cannot re-derive that file (no PRD path at dispatch, no spawn budget), so it is anti-self-bypass guarded like the other gate states: a Write/Edit or shell forge of it is denied, and its only writer is `validate-plan-coverage.sh`. Exempt: a migrated vault (spec §7 #12), and a layout-2 or legacy vault (no `context.md`). Such a vault was never plan-born, so no census can exist for it; migrating it (`/mega-sdd:migrate-paths --vault-layout=3`) makes it a migrated vault, exempt as well. The predictive run is stricter here: it also refuses an un-migrated layout-2 vault, with the migrate hint. The hook runs this mode on both the `mega-sdd:execute-bolts` Skill entry and every in-run `bolt-implementer` Agent dispatch. Called for a removed skill name, it returns `skill_removed_in_9` as well, even with no `.mega-sdd/`.

---

## Anti-halu rails

1. Check `command:` MUST be deterministic + lightweight (no LLM dispatches, no file reads >1KB)
2. `on_fail:` message MUST be actionable (concrete fix the user can apply)
3. `fatal: yes` MUST be reserved for cases where chain CANNOT succeed without fix
4. NEVER auto-fix preconditions on user's behalf — user does the fix; checks re-run on next invocation
5. Empty/missing predictive-checks.md → orchestrate-flow Step 5 logs "no checks defined; skipping preflight" + chain proceeds (no halt)

---

## Adding new checks

Future iters that touch a skill MUST update this catalog if introducing new preconditions:

1. Add new `### <skill> preflight checks` section if skill not present
2. Add new `- **check_id:**` entry with all 5 fields
3. Use canonical halt type names from `plugins/mega-sdd/references/halt-protocol.md` `§halt-protocol type enum`
4. Verify check command is portable (works on macOS + Linux; if not, document platform)
5. Cite in skill's SKILL.md halt section: "Step 5 preflight check `<check_id>` anticipates this halt"

---

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 5 (consumer)
- `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol (canonical halt envelope for `predictive_check_failed`)
