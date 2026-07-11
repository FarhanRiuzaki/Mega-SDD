# L0 Code Gates — the deterministic floor under the review panel

Machine checks the controller runs on a bolt's `<base>..<head>` diff BEFORE dispatching the review panel. Commit topology (detect-after, per SKILL.md): the implementer's commit has already landed when these gates run — a BLOCKING finding halts the run and gates further bolts; it does not (cannot) prevent the commit that carries it. Deterministic first, LLM second: an LLM lens must never burn context on what a linter, SAST rule, or registry lookup decides for free. Design: `docs/superpowers/specs/2026-06-12-review-panel-design.md` (Phase 2).

## Contents

- The gates and their order
- Toolchain detection (detect, never impose)
- Blocking vs advisory
- Halt YAMLs
- Feeding results into the panel
- Config + opt-out

## The gates and their order

Run after the implementer reports DONE, in this order (cheap → expensive), each scoped to the bolt's `<base>..<head>` diff:

| # | Gate | Script | Tool | Absent tool → |
|---|---|---|---|---|
| 1 | Format check | per `detect-toolchain.sh` output (`check_cmd`; run `fix_cmd` then re-check when only formatting fails) | the repo's own formatter | SKIP (note) |
| 2 | Lint + typecheck | per `detect-toolchain.sh` output | the repo's own linter/typechecker | SKIP (note) |
| 3 | Secrets in code | `scripts/scan-secrets-code.sh --base= --head=` | gitleaks → plugin regex fallback | fallback regex set (never unscanned) |
| 4 | SAST | `scripts/run-code-scan.sh --base= --head=` | semgrep | SKIP (note) |
| 5 | New-dep existence | `scripts/validate-new-deps.sh --base= --head=` | curl to the official registry | offline → `unverified` WARNING |

Scripts live at `$PLUGIN_ROOT/scripts/`, where `$PLUGIN_ROOT` resolves to the **LATEST cached version** (not whatever version path is in context — that may be stale). Resolve it once with one Bash call, then prefix every `scripts/<name>.sh` above with `$PLUGIN_ROOT/` (full rationale: `plugins/mega-sdd/references/plugin-root-resolution.md`):

```bash
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
```

All emit JSON; a tool failure is a visible SKIP with a reason, never silently reported as "clean". For the secret gate specifically (the always-on gate), a gitleaks RUNTIME failure (exit ≥ 2 — crash, incompatible CLI, bad log-opts) does not merely SKIP: it WARNs to stderr and falls back to the plugin's regex scan, and the emitted JSON `note` discloses the fallback — same degradation path as gitleaks-absent. gitleaks exit 1 with an unreadable report is a BLOCKING `report-unreadable` finding (leaks were detected; never reported clean).

## Toolchain detection (detect, never impose)

`scripts/detect-toolchain.sh --cwd=<project>` probes for the repo's OWN formatter/linter/typechecker config (prettier/biome/eslint/tsc, ruff/black/mypy, gofmt/golangci-lint/go-vet, rustfmt/clippy, pint/php-cs-fixer/phpstan/psalm, rubocop, EditorConfig) and emits the commands with their config-file evidence. **No config evidence → no command** — the bolt loop NEVER introduces a formatter or linter the project doesn't already use (that is a unit-level decision, not a gate side-effect). A project framework pack MAY override detection via an optional `## Toolchain` section (see `framework-conventions/_template.md`); pack override > detection.

Formatting failures are auto-fixed (`fix_cmd`) and re-checked — formatting is machine territory, not a finding. Lint/typecheck failures are findings.

## Blocking vs advisory

Per the gates-doctrine (blocking only for critical + un-promptable):

- **BLOCKING (halt before the panel dispatches — the bolt commit already landed):**
  - a secret in the diff (`scan-secrets-code.sh` exit 1) → halt `secret_in_code`
  - an ERROR-severity SAST finding (`run-code-scan.sh` exit 2) → halt `sast_critical_finding`
  - a new dependency the registry definitively 404s (`validate-new-deps.sh` exit 2) → halt `dep_not_found` (hallucinated/slopsquat package — never install)
- **FINDINGS (non-blocking, fed to the panel + bolt-report):** lint/typecheck failures, WARNING/INFO SAST findings, `unverified` new deps (offline).
- **SKIPs** are recorded in the bolt-report `## Review panel` section so a "clean" run that scanned nothing is never mistaken for a clean scan.

These halts follow the same shape and discipline as `hard_rule_violated` (detect-after): blocker YAML + `bolt-report.md` with the findings; the flagged code sits in an already-landed commit, and the remediation acts on that commit. There is no `--force` path around the secret gate; `--no-code-gates` (below) skips gates 1–2 and 4 only — secrets and dep-existence always run.

## Halt YAMLs

```yaml
halt:
  type: secret_in_code
  unit: U-XXX
  details: {engine: gitleaks|fallback-regex, findings: [{rule, file, line}], commit: <bolt sha>}   # values never echoed
  next_action: "The secret is in COMMITTED history (detect-after): rotate it NOW (assume compromised), remove it from the code, and purge it from history BEFORE any push (git revert is not enough — rewrite with e.g. git reset/rebase or git-filter-repo while the branch is local). Secrets never ship — no override."
```

```yaml
halt:
  type: sast_critical_finding
  unit: U-XXX
  details: {findings: [{severity: ERROR, rule, file, line, message}]}
  next_action: "Fix the flagged code or, for a verified false positive, add a scoped ignore with a justification comment and re-run."
```

```yaml
halt:
  type: dep_not_found
  unit: U-XXX
  details: {new_deps: [{package, registry, status: NOT_FOUND}]}
  next_action: "The package does not exist on its official registry — likely a hallucinated name (slopsquat risk). Find the canonical package or drop the dependency. Never install around this halt."
```

## Feeding results into the panel

The merged L0 JSON (gate results + skips) is appended to each review-panel lens prompt as a `## Deterministic scan results` block. Lenses do NOT re-report machine-caught findings; the security lens verifies blockers were addressed and hunts what scanners can't see (authz semantics, architectural drift). This keeps the blind protocol intact — L0 output is machine fact, not another lens's opinion.

## Config + opt-out

- `.mega-sdd/config.yaml` → `code_gates: true` (default). `false` disables gates 1–2 and 4 (toolchain + SAST) for the project; **secrets (gate 3) and dep-existence (gate 5) always run** — they are the critical + un-promptable pair.
- CLI `--no-code-gates` — same scope as `code_gates: false`, one run only; logged in the bolt-report.
- Tool installation: semgrep + gitleaks (+ osv-scanner) ship in the `/mega-sdd:install-deps` matrix; every gate degrades gracefully without them per the table above.
