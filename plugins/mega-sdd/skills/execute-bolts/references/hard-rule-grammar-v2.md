# Hard Rule Grammar v2 (ast-grep YAML)

Replaces the bespoke 5-type v1 grammar. Each Hard Rule in a unit's `## Hard rules` body section is now an ast-grep YAML rule. Pre/post-flight `execute-bolts` invokes `ast-grep scan --rule <rule-file>`.

## Contents

- Why v2
- Detection
- Installation guidance
- v2 rule file format
- Hard rules
- Mapping v1 → v2 (the 5 original types)
- Pre/post-flight validation flow
- Migration command (per ITER6-OQ-2 resolved explicit)
- Backward compatibility
- ast-grep limitation: syntax-only
- References

## Why v2

- v1 was 5 fixed types; v2 is expressive within ast-grep's pattern grammar
- v2 ships with fix templates (rule can suggest auto-fix)
- v2 single Rust binary (single install for users)
- v2 covers 100+ languages via tree-sitter grammars (shared with Swap #1)

## Detection

At skill startup, probe for ast-grep:

```bash
command -v ast-grep
```

- Found → use ast-grep engine (Hard Rule v2 grammar)
- Not found AND unit has v2 rules → halt `dep_missing` with install commands
- Not found AND unit has v1 rules → fall back to v1 parser (preserved unchanged)

## Installation guidance

```yaml
blocker:
  type: dep_missing
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    required_binary: ast-grep
    install_commands:
      macos: "brew install ast-grep"
      linux: "cargo install ast-grep"
      windows: "scoop install ast-grep"
      universal: "npm install -g @ast-grep/cli"
  next_action: "Install ast-grep (see install_commands) then re-run, OR author this unit's Hard Rules in v1 (bulleted) grammar by hand — reverse migration via --to=v1 is NOT implemented (v1 grammar is still executed natively at pre/post-flight)"
```

## v2 rule file format

Each Hard Rule in unit body is now a YAML block. Multiple rules can appear in one `## Hard rules` section.

```markdown
## Hard rules

\`\`\`yaml
id: no-raw-db-in-controllers
language: php
severity: error
rule:
  pattern: $DB->query($$$ARGS)
files: ["**/app/Http/Controllers/**"]
message: "Controllers must not run raw DB queries (binding C-007) — use the repository layer"
\`\`\`

> **`files:` globs MUST be `**/`-prefixed** when relative (`files: ["**/src/Models/User.php"]`,
> never `["src/Models/User.php"]`): `ast-grep scan --rule` matches a bare relative glob against
> NOTHING — the rule silently scans zero files and "passes". The engine normalizes relative
> globs to `**/` defensively, but author them correctly. And note what ast-grep CAN express:
> content-presence rules (a forbidden pattern in scoped files). It is STATELESS — it cannot
> detect "file was modified" or "dependency was added"; those stay v1 productions (below).

\`\`\`yaml
id: preserve-authenticate-user-sig
language: typescript
severity: error
rule:
  pattern: |
    function authenticateUser($EMAIL: string, $PASSWORD: string): Promise<User> {
      $$$
    }
constraints:
  EMAIL: { kind: identifier }
  PASSWORD: { kind: identifier }
fix: |
  // Signature drift detected. Required: (email: string, password: string) => Promise<User>
message: "Function authenticateUser signature is locked by Hard Rule"
\`\`\`
```

## Mapping v1 → v2 (the 5 original types)

| v1 type | v2 equivalent |
|---|---|
| `DO NOT modify <path>` | **NONE — stays v1.** ast-grep is stateless (it cannot know "changed"); the v1 production checks git touched-set + sha256 vs preflight. Do NOT migrate. |
| `DO NOT add new <manifest> dependencies` | **NONE — stays v1.** "New" requires a before/after diff ast-grep cannot express; the v1 production diffs the unit's own commit range. Do NOT migrate. |
| `<path-glob> MUST follow <case-style> naming` | **NONE — stays v1.** ast-grep matches AST nodes, not file names; a files-only rule with no positive matcher is invalid. |
| `function <name> MUST preserve signature: <sig>` | Pattern with `$EMAIL: string, $PASSWORD: string` shape; constraint on params (content-expressible — a decl NOT matching the locked shape is findable) |
| `file <path> MUST exist after bolt` | Post-flight file existence check (no AST rule; simple `test -f`) |

## Pre/post-flight validation flow

### Pre-flight (per `execute-bolts/SKILL.md` pre-flight)

For each rule in unit's `## Hard rules`:

1. Parse YAML block
2. Validate via ast-grep parse (`ast-grep test --validate` flag does not exist in the CLI; use parse-via-scan instead):
   ```bash
   # Parse the rule by running scan with --dry-run against /dev/null (or empty input)
   echo "" | ast-grep scan --rule <rule-yaml-tempfile> --json /dev/stdin 2>&1
   ```
   - Exit 0 → rule parses cleanly (zero matches on empty input is the expected baseline)
   - Exit non-zero with parse error in stderr → halt `hard_rule_unparseable` with stderr verbatim
3. Snapshot relevant files (sha256 for `files:` paths) — an AUDIT record of the
   pre-bolt state, NOT a lock check: a v2 rule is a pattern scan, and the bolt is
   allowed (often required) to edit matched files to fix a pre-existing violation.
   Lock semantics (DO_NOT_MODIFY) stay v1 per the mapping table.
4. Persist to `<vault>/bolts/U-XXX/preflight.json`:
   ```json
   {
     "rule_id": "no-raw-db-in-controllers",
     "rule_yaml": "...",
     "snapshot_paths": ["app/Http/Controllers/UserController.php"],
     "snapshot_sha256": {"app/Http/Controllers/UserController.php": "abc123..."},
     "snapshot_at": "2026-05-21T10:00:00Z"
   }
   ```

### Post-flight (per `execute-bolts/SKILL.md` Post-flight validation)

For each rule:

1. Run: `ast-grep scan --rule <rule-yaml-tempfile> --json <repo-root>` (or use `files:` filter)
2. Parse JSON output
3. Apply violation logic:
   - Any matches → VIOLATED (with file:line + matched text as evidence)
   - Zero matches → PASSED
   (No sha256-vs-snapshot compare: a v2 rule is a pattern scan, not a file lock —
   fixing a pre-bolt violation necessarily changes the file, so a sha check would
   make honest remediation unreachable. Lock semantics stay v1.)
4. Write `<vault>/bolts/U-XXX/postflight.json` with per-rule status

### Halt on violation

Same as grammar v1 — `hard_rule_violated` blocker; detect-after (the bolt commit already landed): remediation is fix-forward or `git revert` of the flagged commit, and the B1 gate blocks every further `execute-bolts` until a passing `postflight.json` is recorded.

## Migration command (per ITER6-OQ-2 resolved explicit)

`/mega-sdd:migrate-rules --vault=<path>` walks the vault's units and offers to migrate v1 → v2:

```
Walking ./vault/units/...

U-001: 1 v1 rule found
  v1: "DO NOT modify src/Models/User.php"
  → KEEP AS v1 (no v2 equivalent — DO_NOT_MODIFY needs git/sha state ast-grep
    cannot express; see the mapping table). Nothing proposed.

U-001b: 1 migratable v1 rule found
  v1: "function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>"
  v2 (proposed):
    id: preserve-authenticate-user-sig
    language: typescript
    files: ["**/src/auth/**"]
    rule: { pattern: "function authenticateUser($EMAIL: string, $PASSWORD: string): Promise<User> { $$$ }" }
    message: "..."

  ACCEPT migration? [Y/n/skip-unit]

U-002: 2 v1 rules found
  ...
```

User confirms per unit. v1 rules preserved as `<!-- v1: ... -->` HTML comments for audit. Migration log written to `<vault>/units/.migration-log.md`.

## Backward compatibility

- v2.1 units with v1 rules → execute-bolts v1.4 parser still works (v1 path preserved)
- Newly-generated units emit v1 productions by default (binding-suggested `DO NOT modify …` etc.); v2 blocks are authored/migrated deliberately for pattern rules only
- Mixed-grammar units → halt `hard_rule_mixed_grammar` (user must migrate first)
- `--hard-rule-grammar=v1|v2` flag forces grammar; default `auto` (detect from rule YAML presence)

## ast-grep limitation: syntax-only

ast-grep matches AST patterns; it does NOT do dataflow analysis, and it is STATELESS — it sees only the current tree, never "changed since X". Of mega-sdd's 5 original rule types only SIGNATURE_RULE is v2-expressible (see the mapping table); the state-dependent types (modify-lock, dep-diff, naming-on-new-files) stay v1. Future needs like dataflow ("function X MUST flow tainted data into sanitizer Y") would need different tooling (CodeQL / Semgrep dataflow rules).

## References

- ast-grep docs: https://ast-grep.github.io/
- Tree-sitter integration (shared): `scan-codebase/references/tree-sitter-integration.md`
- Design spec: `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` §6 (v1 grammar)
- Design spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.2
