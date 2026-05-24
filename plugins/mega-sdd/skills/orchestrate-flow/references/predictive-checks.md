# Predictive Checks Catalog

> Per-skill preflight checks consulted by `mega-sdd:orchestrate-flow` v3.0.0+ Step 3.5.

**Introduced:** v3.24.0 (Iter 33)
**Consumed by:** `mega-sdd:orchestrate-flow` Step 3.5 predictive preflight

---

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

- **check_id: `tree_sitter_present`**
  command: `command -v tree-sitter || command -v tree-sitter-cli`
  expected: exit 0
  on_fail: "tree-sitter not installed; scan-codebase will fall back to regex engine (lower precision). Install: brew install tree-sitter / cargo install tree-sitter-cli / npm install -g tree-sitter-cli"
  fatal: no
  predicts_halt: dep_missing (avoided if user OK with regex fallback OR installs binary)

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
  command: `test -f <project>/prd.md || test -d <project>/.mega-sdd/knowledge-base/`
  expected: at least one input
  on_fail: "generate-intent requires PRD (prd.md) OR knowledge-base (extract-intelligence output). Provide one OR run extract-intelligence first."
  fatal: yes
  predicts_halt: (chain order error)

---

## Read protocol (Step 3.5)

```
For each skill in proposed chain:
  Read references/predictive-checks.md §<skill> section
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
3. Use canonical halt type names from vault-contract.md `§halt-protocol type enum`
4. Verify check command is portable (works on macOS + Linux; if not, document platform)
5. Cite in skill's SKILL.md halt section: "Step 3.5 preflight check `<check_id>` anticipates this halt"

---

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 3.5 (consumer)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` §halt-protocol (canonical halt envelope for `predictive_check_failed`)
