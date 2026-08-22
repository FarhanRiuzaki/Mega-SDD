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

Run after the implementer reports DONE, in this order (cheap → expensive), each scoped to the bolt's `<base>..<head>` diff. `<base>` is the bolt's ORIGINAL base on EVERY pass — a panel re-dispatch re-enters here (review-panel.md §Merge) and the gates re-scan `original-base..new-head`, never fix-commit-only. **Under `--parallel` the same rule is expressed per commit** (wave commits interleave, so a contiguous range would sweep siblings): the re-entry scan covers the unit's own commit SET — the original bolt commit AND each fix commit (`<sha>^..<sha>` per commit, results merged) — which keeps attempt-1's findings in the record (this rule's purpose) without attributing sibling commits to this unit (`batch-and-fanout.md §--all`):

| # | Gate | Script | Tool | Absent tool → |
|---|---|---|---|---|
| 1 | Format check | per `detect-toolchain.sh` output (`check_cmd`; run `fix_cmd` then re-check when only formatting fails) | the repo's own formatter | SKIP (note) |
| 2 | Lint + typecheck | per `detect-toolchain.sh` output | the repo's own linter/typechecker | SKIP (note) |
| 3 | Secrets in code | `scripts/secret-scan.sh --code --base= --head=` | gitleaks → plugin regex fallback | fallback regex set (never unscanned) |
| 4 | SAST | `scripts/run-code-scan.sh --base= --head=` | semgrep | SKIP (note) |
| 5 | New-dep existence | `scripts/validate-new-deps.sh --base= --head=` | python3 urllib → official registry | offline → `unverified` WARNING |
| 6 | Dep authorization (ADVISORY) | `scripts/validate-new-deps.sh --unit= --base= --head=` (rides gate 5 — one manifest-diff pass, `authorization` JSON section) | shared `_lib/dep_manifest.py` diff | unit lacks `allowed_new_deps:` → `enforced:false` no-op |

**Run the floor as ONE call — `scripts/run-code-gates.sh` (`docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md` §2c).** The controller no longer runs the table row-by-row across 9–13 Bash turns: the wrapper sequences toolchain detection + gates 1–6 in the order above, **short-circuits at the first BLOCKING result** (later gates land in `not_run[]` and their subprocesses are never spawned — on a blocking run it does strictly less work than the per-turn flow it replaced), and emits ONE merged JSON on stdout — the payload the controller Writes to `<vault>/lens-inputs/U-XXX/l0-results.json` for the panel (spec D5). It resolves the gate scripts as siblings of its own path, so no plugin-root resolution happens here (the runnable form lives in SKILL.md Procedure step 3 — `${CLAUDE_PLUGIN_ROOT}` is NOT substituted in reference files):

```
bash <plugin-root>/scripts/run-code-gates.sh \
  --cwd=<project-root> --base=<bolt-base-sha> --head=<new-head-sha> \
  --unit=<vault>/units/U-XXX.md [--pack=<active-pack.md>] [--no-code-gates]
```

- **Exit 0** — gates ran, no blocking finding; non-blocking findings + SKIPs ride in the JSON for the panel.
- **Exit 1** — a BLOCKING finding; the JSON `halt` object carries the type (`secret_in_code` / `sast_critical_finding` / `dep_not_found`) and IS the blocker payload.
- **Exit 2** — usage/environment error (bad args, unresolvable base/head, an always-run gate could not complete): NOTHING was certified — never treat as clean; fix and re-run.
- `--unit=` feeds gate 6 (absent → a visible SKIP, never silent). `--pack=` applies a pack `## Toolchain` override to gates 1–2 (pack override > detection, per the section below). `--no-code-gates` and the `code_gates: false` config key (read by the wrapper itself) skip gates 1–2, 4 and 6 — **gates 3 and 5 always run**.
- Timeouts are bounded per command (120s toolchain / 300s gate script): a toolchain timeout is a per-tool failure note, a SAST timeout is a visible SKIP ("scan NOT performed"), a secrets/dep-existence timeout is exit 2 — the always-run pair is never silently skipped.
- The individual scripts stay invocable directly for debugging; the wrapper is the shipped path, and a panel re-dispatch re-enters at the same one call over `original-base..new-head`.

All emit JSON; a tool failure is a visible SKIP with a reason, never silently reported as "clean". For the secret gate specifically (the always-on gate), a gitleaks RUNTIME failure (exit ≥ 2 — crash, incompatible CLI, bad log-opts) does not merely SKIP: it WARNs to stderr and falls back to the plugin's regex scan, and the emitted JSON `note` discloses the fallback — same degradation path as gitleaks-absent. gitleaks exit 1 with an unreadable report is a BLOCKING `report-unreadable` finding (leaks were detected; never reported clean).

## Toolchain detection (detect, never impose)

`scripts/detect-toolchain.sh --cwd=<project>` probes for the repo's OWN formatter/linter/typechecker config (prettier/biome/eslint/tsc, ruff/black/mypy, gofmt/golangci-lint/go-vet, rustfmt/clippy, pint/php-cs-fixer/phpstan/psalm, rubocop, EditorConfig) and emits the commands with their config-file evidence. **No config evidence → no command** — the bolt loop NEVER introduces a formatter or linter the project doesn't already use (that is a unit-level decision, not a gate side-effect). A project framework pack MAY override detection via an optional `## Toolchain` section (see `framework-conventions/_template.md`); pack override > detection.

Formatting failures are auto-fixed (`fix_cmd`) and re-checked — formatting is machine territory, not a finding. Lint/typecheck failures are findings. **A fix lands AFTER the bolt commit and dirties the working tree** — the JSON discloses it (`format.fix_applied: true`, per-tool `fix_rc`): the controller commits the formatting fix under the unit's canonical identity (a follow-up commit in the unit's commit set, `bolt-contract.md §Commit message format`) before proceeding — pre-flight 3 (clean tree) makes silently carrying the dirt into the next unit impossible.

**L0 syntax floor (the zero-config rung UNDER gate 2).** Even with no repo-own lint/typecheck config, a committed file must at least parse: `scripts/run-acceptance-tests.sh` (the B4 evidence writer, run at post-flight per SKILL.md Procedure step 5) executes `php -l` / `python3 -m py_compile` / `node --check` / `ruby -c` over the bolt's changed files as a pre-rung — only when the interpreter already exists on PATH (detect-never-impose; absent interpreters are recorded in `acceptance.json.syntax_skipped`, never installed). A syntax failure is recorded with NO retry (syntax is deterministic) and halts **`build_broken`**. Deterministic home (documented choice): the rung lives INSIDE the B4 writer — one writer, one hook-guarded artifact — so the syntax evidence is auditable in `acceptance.json` next to the acceptance verdicts instead of a second unguarded artifact.

## Blocking vs advisory

Per the gates-doctrine (blocking only for critical + un-promptable):

- **BLOCKING (halt before the panel dispatches — the bolt commit already landed):**
  - a secret in the diff (`secret-scan.sh --code` exit 1) → halt `secret_in_code`
  - an ERROR-severity SAST finding (`run-code-scan.sh` exit 2) → halt `sast_critical_finding`
  - a new dependency the registry definitively 404s (`validate-new-deps.sh` exit 2) → halt `dep_not_found` (hallucinated/slopsquat package — never install)
- **FINDINGS (non-blocking, fed to the panel + bolt-report):** lint/typecheck failures, WARNING/INFO SAST findings, `unverified` new deps (offline), **`dep_unauthorized`** (gate 6 — the bolt added a dependency the unit's `allowed_new_deps` did not sanction; anti-over-engineering per the WAJIB bar). Gate 6 is **advisory-first by design** (always exit 0): the future blocking escalation is deferred and, when it lands, is commit-keyed like B4 so legacy bolts never retro-block. A unit with no `allowed_new_deps:` key (v4/pre-v5) is `enforced:false` — never a finding.
- **SKIPs** are recorded in the bolt-report `## Review panel` section so a "clean" run that scanned nothing is never mistaken for a clean scan.

These halts follow the same shape and discipline as `hard_rule_violated` (detect-after): blocker YAML + `bolt-report.md` with the findings; the flagged code sits in an already-landed commit, and the remediation acts on that commit. There is no `--force` path around the secret gate; `--no-code-gates` (below) skips gates 1–2, 4, and 6 (the advisory/non-critical set) — secrets and dep-existence always run.

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

The wrapper's stdout JSON — gate results, skips, `not_run[]` — is the merged L0 JSON. The controller Writes it ONCE, verbatim, to `<vault>/lens-inputs/U-XXX/l0-results.json` and puts that PATH in each review-panel lens/verifier prompt (it never re-assembles, summarizes, or pastes the per-gate results per lens; a re-round OVERWRITES the file with the fresh run — `review-panel.md §Blind dispatch`). Lenses do NOT re-report machine-caught findings; the security lens verifies blockers were addressed and hunts what scanners can't see (authz semantics, architectural drift). This keeps the blind protocol intact — L0 output is machine fact, not another lens's opinion.

## Config + opt-out

- `.mega-sdd/config.yaml` → `code_gates: true` (default). `false` disables gates 1–2, 4, and 6 (toolchain + SAST + advisory dep-authorization) for the project; **secrets (gate 3) and dep-existence (gate 5) always run** — they are the critical + un-promptable pair. The key is read by `run-code-gates.sh` itself — the controller does not pre-check it.
- CLI `--no-code-gates` — same scope as `code_gates: false`, one run only; forwarded to `run-code-gates.sh` as its `--no-code-gates` flag; logged in the bolt-report.
- Tool installation: semgrep + gitleaks ship in the `/mega-sdd:install-deps` matrix; every gate degrades gracefully without them per the table above.
