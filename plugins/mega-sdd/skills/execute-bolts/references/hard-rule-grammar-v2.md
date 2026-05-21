# Hard Rule Grammar v2 (ast-grep YAML — v2.0+, Iter 6)

Replaces bespoke 5-type grammar (Iter 3 v1). Each Hard Rule in a unit's `## Hard rules` body section is now an ast-grep YAML rule. Pre/post-flight `execute-bolts` invokes `ast-grep scan --rule <rule-file>`.

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
  next_action: "Install ast-grep then re-run, OR migrate this unit's Hard Rules to v1 grammar via /mega-sdd:migrate-rules --to=v1"
```

## v2 rule file format

Each Hard Rule in unit body is now a YAML block. Multiple rules can appear in one `## Hard rules` section.

```markdown
## Hard rules

\`\`\`yaml
id: do-not-modify-user-php
language: php
severity: error
rule:
  pattern: $$$
  inside:
    kind: program
    has:
      stopBy: end
files: ["src/Models/User.php"]
message: "src/Models/User.php is locked by binding (KEEP_CODE on C-007)"
\`\`\`

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
| `DO NOT modify <path>` | `files: [<path>]` + rule with `severity: error` triggered by any AST change |
| `DO NOT add new <manifest> dependencies` | Custom rule on manifest file pattern; `severity: error` if new top-level dep entry |
| `<path-glob> MUST follow <case-style> naming` | Rule on file paths; constraint via regex |
| `function <name> MUST preserve signature: <sig>` | Pattern with `$EMAIL: string, $PASSWORD: string` shape; constraint on params |
| `file <path> MUST exist after bolt` | Post-flight file existence check (no AST rule; simple `test -f`) |

## Pre/post-flight validation flow (v2)

### Pre-flight (per `execute-bolts/SKILL.md` Step 4 v2.0+)

For each rule in unit's `## Hard rules`:

1. Parse YAML block
2. Validate via ast-grep parse (v2.1+, Iter 9 Bug 7 fix — `ast-grep test --validate` flag does not exist in CLI; use parse-via-scan instead):
   ```bash
   # Parse the rule by running scan with --dry-run against /dev/null (or empty input)
   echo "" | ast-grep scan --rule <rule-yaml-tempfile> --json /dev/stdin 2>&1
   ```
   - Exit 0 → rule parses cleanly (zero matches on empty input is the expected baseline)
   - Exit non-zero with parse error in stderr → halt `hard_rule_unparseable` with stderr verbatim
3. Snapshot relevant files (sha256 for `files:` paths)
4. Persist to `<vault>/bolts/U-XXX/preflight.json`:
   ```json
   {
     "rule_id": "do-not-modify-user-php",
     "rule_yaml": "...",
     "snapshot_paths": ["src/Models/User.php"],
     "snapshot_sha256": {"src/Models/User.php": "abc123..."},
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
4. For `files:` lock rules (DO_NOT_MODIFY semantic): compare current sha256 to snapshot
5. Write `<vault>/bolts/U-XXX/postflight.json` with per-rule status

### Halt on violation

Same as Iter 3 — `hard_rule_violated` blocker; code stays in working tree; user reviews.

## Migration command (per ITER6-OQ-2 resolved explicit)

`/mega-sdd:migrate-rules --vault=<path>` walks the vault's units and offers to migrate v1 → v2:

```
Walking ./vault/units/...

U-001: 1 v1 rule found
  v1: "DO NOT modify src/Models/User.php"
  v2 (proposed):
    id: do-not-modify-user-php
    language: php
    files: ["src/Models/User.php"]
    rule: { pattern: $$$, inside: { kind: program } }
    message: "..."

  ACCEPT migration? [Y/n/skip-unit]

U-002: 2 v1 rules found
  ...
```

User confirms per unit. v1 rules preserved as `<!-- v1: ... -->` HTML comments for audit. Migration log written to `<vault>/units/.migration-log.md`.

## Backward compatibility

- v2.1 units with v1 rules → execute-bolts v1.4 parser still works (v1 path preserved)
- v3.0 newly-generated units → v2 grammar by default
- Mixed-grammar units → halt `hard_rule_mixed_grammar` (user must migrate first)
- `--hard-rule-grammar=v1|v2` flag forces grammar; default `auto` (detect from rule YAML presence)

## ast-grep limitation: syntax-only

ast-grep matches AST patterns; it does NOT do dataflow analysis. For mega-sdd's 5 original rule types this is sufficient — all 5 are AST-or-simpler. Future iters that need dataflow (e.g., "function X MUST flow tainted data into sanitizer Y") would need different tooling (CodeQL / Semgrep dataflow rules).

## References

- ast-grep docs: https://ast-grep.github.io/
- Tree-sitter integration (shared): `../../scan-codebase/references/tree-sitter-integration.md`
- Iter 3 spec: `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` §6 (v1 grammar)
- Iter 6 spec: `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md` §4.2
