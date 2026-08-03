# Predictive Checks Catalog

> Per-skill preflight checks consulted by `mega-sdd:orchestrate-flow` Step 3.5.

**Consumed by:** `mega-sdd:orchestrate-flow` Step 3.5 predictive preflight

---

## Contents

- [Purpose](#purpose)
- [Check entry format](#check-entry-format)
- [scan-codebase preflight checks](#scan-codebase-preflight-checks)
- [bind-codebase preflight checks](#bind-codebase-preflight-checks)
- [execute-bolts preflight checks](#execute-bolts-preflight-checks)
- [generate-intent preflight checks](#generate-intent-preflight-checks)
- [detect-drift preflight checks](#detect-drift-preflight-checks)
- [diff-vault preflight checks](#diff-vault-preflight-checks)
- [resolve-oq preflight checks](#resolve-oq-preflight-checks)
- [extract-intelligence preflight checks](#extract-intelligence-preflight-checks)
- [emit-agents-md preflight checks](#emit-agents-md-preflight-checks)
- [Cold-halt anticipation checks](#cold-halt-anticipation-checks)
- [install-deps preflight checks](#install-deps-preflight-checks)
- [emit-fsd preflight checks](#emit-fsd-preflight-checks)
- [memory preflight checks](#memory-preflight-checks)
- [Read protocol (Step 3.5)](#read-protocol-step-35)
- [Anti-halu rails](#anti-halu-rails)
- [Adding new checks](#adding-new-checks)
- [See also](#see-also)

## Purpose

Catalog of lightweight checks that detect known halt preconditions BEFORE invoking the skill. Per spec §4.2: "Instead of 'scan-codebase halted on dep_missing 8 minutes in', user sees 'before chain starts: tree-sitter not installed; install or use --engine=regex'."

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

## scan-codebase preflight checks

- **check_id: `ast_engine_present`**
  command: `command -v tree-sitter || command -v tree-sitter-cli || command -v ast-grep`
  expected: exit 0
  on_fail: "no AST engine installed (tree-sitter AND ast-grep both absent); scan-codebase will fall back to the regex engine (lower precision). Install: brew install ast-grep (zero-compilation tier) / brew install tree-sitter-cli — OR run `/mega-sdd:install-deps` for auto-install. tree-sitter absent with ast-grep present is the NORMAL D2 state (no warning): auto extraction runs at the ast-grep tier, precision stays ast; tree-sitter is an explicit --engine opt-in."
  fatal: no
  predicts_halt: dep_missing (only under a forced `--engine=`; avoided if user OK with the fallback tier OR installs a binary)

- **check_id: `framework_pack_present`**
  command: `test -f plugins/mega-sdd/references/framework-conventions/<detected-framework>.md`
  expected: file exists
  on_fail: "no framework pack for <framework>; scan-codebase will use _universal.md fallback patterns (lower starterkit detection precision)"
  fatal: no
  predicts_halt: framework_pack_missing (avoided — fallback always exists)

## bind-codebase preflight checks

- **check_id: `binding_input_complete`**
  command: `test -f <vault-path>/vault.json && test -f <codebase-map-path>`
  expected: both files exist
  on_fail: "bind-codebase requires both vault.json AND codebase-map.md. Run scan-codebase first if codebase-map.md absent; run generate-intent first if vault.json absent."
  fatal: yes
  predicts_halt: bind_conflict (vault.json absent) OR dep_missing (codebase-map absent)
  express_carve_out: when the bind hop carries `--express` OR the express spine is active with no `--no-express`/`--classic` on the hop (derive-state `derived.spine` — the deterministic validator applies the same flag-or-config rule), run ONLY the vault.json arm (`test -f <vault-path>/vault.json`, still fatal) — the express lane reads NO codebase-map (`bind-codebase/references/express-bind.md`), so the map arm would falsely halt a valid express chain.

- **check_id: `constitution_file_check`**
  command: `test -f <vault-path>/constitution.md`
  expected: file exists (only relevant if --strict-constitution flag passed)
  on_fail: "--strict-constitution requires constitution.md in vault; not found"
  fatal: yes (only when --strict-constitution explicitly set)
  predicts_halt: bind_conflict_constitution_violation

## execute-bolts preflight checks

- **check_id: `units_directory_present`**
  command: `test -d <vault-path>/units && ls <vault-path>/units/U-*.md | head -1`
  expected: at least 1 unit file exists
  on_fail: "execute-bolts requires generated units. Run generate-units first."
  fatal: yes
  predicts_halt: (chain order error — invokes generate-units instead)

- **check_id: `superpowers_available`**
  command: check superpowers plugin presence (existing check from current Step 4)
  expected: superpowers plugin loadable OR vendored fallback present
  on_fail: "execute-bolts dispatches via superpowers.executing-plans; superpowers plugin not available"
  fatal: no (vendored fallback exists)
  predicts_halt: (no specific halt; degraded operation)

## generate-intent preflight checks

- **check_id: `prd_or_kb_input_present`**
  command: when the chain's generate-intent hop carries a POSITIONAL input → `test -f <positional-input>` (generate-intent Rule 2 — a positional that resolves to a file IS the input; the root probe below is Rule-7 territory and only applies when no positional exists). Otherwise: `test -f <project>/prd.md || test -d <project>/.mega-sdd/knowledge-base/` OR the derive-state digest's `probes.prd.present` (which scans root + one level inside dirs whose name case-insensitively matches `PRD`/`docs`/`documents`/`requirements`).
  expected: at least one input
  on_fail: "generate-intent requires an input — a positional PRD path, root prd.md, a PRD candidate in PRD//docs/, OR a knowledge-base (extract-intelligence output). Provide one OR run extract-intelligence first."
  fatal: yes
  predicts_halt: (chain order error)
  note: a root-only probe against an explicitly-supplied positional PRD is a FALSE FAIL predicting a halt generate-intent would never raise (field finding, training-nextjs 2026-08-03).

## detect-drift preflight checks

- **check_id: `vault_present_for_drift`**
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "detect-drift requires a vault. Run generate-intent first."
  fatal: yes
  predicts_halt: (chain order error)

- **check_id: `binding_present_for_drift`**
  command: `test -f <vault-path>/binding.md && grep -q "^## Confirmed Claims" <vault-path>/binding.md`
  expected: binding.md exists with at least one Confirmed Claims section
  on_fail: "detect-drift compares against bound vault state. Run bind-codebase first to establish binding."
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
  on_fail: "diff-vault requires current vault to compare new source against. Run generate-intent first."
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
  command: `test -f <vault-path>/vault.json && test -f <vault-path>/03-open-questions.md`
  expected: both files exist
  on_fail: "resolve-oq requires a vault with 03-open-questions.md. Run generate-intent first."
  fatal: yes
  predicts_halt: (chain order error)

- **check_id: `oq_status_field_present`**
  command: `python3 -c "import json; v=json.load(open('<vault-path>/vault.json')); exit(0 if any('status' in oq for oq in v.get('open_questions', [])) else 1)"`
  expected: at least one OQ entry has status field (schema)
  on_fail: "vault.json open_questions[] entries lack 'status' field (pre-v1.1 schema). resolve-oq cannot track Resolve/Out-of-Scope/Defer outcomes without status field. Regenerate vault via generate-intent --refresh."
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
  on_fail: "extract-intelligence cannot write to <kb-output-dir>. Check permissions OR change --output."
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
  on_fail: "emit-agents-md requires a vault. Run generate-intent first."
  fatal: yes
  predicts_halt: (chain order error)

- **check_id: `units_present_for_agents_md`**
  command: `test -d <vault-path>/units && ls <vault-path>/units/U-*.md | head -1`
  expected: at least 1 unit file exists
  on_fail: "emit-agents-md is unit-aware (lists units in AGENTS.md). Run generate-units first OR pass --no-units for vault-only AGENTS.md."
  fatal: no
  predicts_halt: (no halt; degraded AGENTS.md)

## Cold-halt anticipation checks

An earlier audit flagged ~33 halts firing cold (no anticipating predictive-check). Most are runtime-only (cannot statically predict). These 4 feasible static checks cover the previously-uncovered halts:

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
  on_fail: "One or more units lack acceptance_test field. execute-bolts will halt unit_underspecified. Edit affected units OR re-run generate-units --strict."
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
- `predictive_check_failed`, `model_tier_unknown`, `routing_outcome_corrupt` — orchestrate-flow self-checks during runtime
- `test_fail`, `hard_rule_violated`, `provenance_missing` — emitted during execute-bolts execution, not anticipatable pre-flight
- `cross_squad_interface_draft` — depends on producer skill state at runtime (interface lock status)
- `deep_scan_subagent_failed/_all_failed/cache_corrupt` — depends on subagent runtime outcomes

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

- **check_id: `memory_writable_for_install_outcomes`**
  command: `mkdir -p <project>/.mega-sdd/memory/.test-write && rmdir <project>/.mega-sdd/memory/.test-write`
  expected: exit 0
  on_fail: "install-deps writes install-outcomes.md to <project>/.mega-sdd/memory/. Directory not writable. Check permissions."
  fatal: no
  predicts_halt: memory_in_use (memory write would fail)

## emit-fsd preflight checks

- **check_id: `vault_present_for_fsd`**
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "emit-fsd requires a vault. Run generate-intent first."
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

## memory preflight checks

- **check_id: `memory_dir_writable`**
  command: `mkdir -p ~/.mega-sdd/.test-write && rmdir ~/.mega-sdd/.test-write && mkdir -p <project>/.mega-sdd/.test-write && rmdir <project>/.mega-sdd/.test-write`
  expected: exit 0 for BOTH user-scope + project-scope dirs
  on_fail: "memory subsystem cannot write to ~/.mega-sdd/ OR <project>/.mega-sdd/. Check permissions."
  fatal: yes
  predicts_halt: memory_in_use (lock acquisition would fail)

- **check_id: `schema_version_match`**
  command: `python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('~/.mega-sdd/memory/*.json') + glob.glob('<project>/.mega-sdd/memory/*.json')]" 2>&1`
  expected: all memory files parse cleanly
  on_fail: "One or more memory files have schema_version drift OR JSON parse failure. Run `/mega-sdd:memory migrate` to repair."
  fatal: no
  predicts_halt: memory_schema_mismatch

- **check_id: `concurrent_writer_check`**
  command: `find ~/.mega-sdd <project>/.mega-sdd -name "*.lock" -mtime -1`
  expected: empty output (no recent lock files)
  on_fail: "Active or orphaned lock files detected. If no other mega-sdd skill is running, rm the stale .lock files manually."
  fatal: no
  predicts_halt: memory_in_use (lock collision)

---

## Read protocol (Step 3.5)

```
For each skill in proposed chain:
  Read this catalog's §<skill> section
  For each check entry:
    Run command
    If expected condition met → pass; continue to next check
    If condition not met:
      If fatal: yes → emit halt predictive_check_failed; STOP chain
      If fatal: no → accumulate warning; log to user; continue chain
```

---

## Anti-halu rails

1. Check `command:` MUST be deterministic + lightweight (no LLM dispatches, no file reads >1KB)
2. `on_fail:` message MUST be actionable (concrete fix the user can apply)
3. `fatal: yes` MUST be reserved for cases where chain CANNOT succeed without fix
4. NEVER auto-fix preconditions on user's behalf — user does the fix; checks re-run on next invocation
5. Empty/missing predictive-checks.md → orchestrate-flow Step 3.5 logs "no checks defined; skipping preflight" + chain proceeds (no halt)

---

## Adding new checks

Future iters that touch a skill MUST update this catalog if introducing new preconditions:

1. Add new `### <skill> preflight checks` section if skill not present
2. Add new `- **check_id:**` entry with all 5 fields
3. Use canonical halt type names from `plugins/mega-sdd/references/halt-protocol.md` `§halt-protocol type enum`
4. Verify check command is portable (works on macOS + Linux; if not, document platform)
5. Cite in skill's SKILL.md halt section: "Step 3.5 preflight check `<check_id>` anticipates this halt"

---

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 3.5 (consumer)
- `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol (canonical halt envelope for `predictive_check_failed`)
