---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "<unit-id | --all> [--parallel] [--worktree] [--max-retries=N] [--dry-run] [--force] [--auto] [--per-squad] [--squad=<id>] [--module=<id>] [--review-panel=minimal|standard|full|auto] [--no-code-gates] [--no-full-suite] [--hard-rule-grammar=v1|v2] [--no-pbt] [--no-empty-commits] [--no-drift-check] [--resume] [--rollback <unit-id>] [--memory-off] [--force-skip-postflight]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:execute-bolts` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke `mega-sdd:execute-bolts` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: unit ID (U-XXX), unit file path, or `--all`.
- Flags:
  - `--parallel` — execute eligible units concurrently (no `depends_on` edge AND pairwise-disjoint `target_files`)
  - `--worktree` — isolate execution in git worktree
  - `--max-retries=N` — retry test-fail before halt (default N=3)
  - `--dry-run` — print plan without committing
  - `--force` — override pre-flight warnings (use sparingly)
  - `--auto` — non-interactive; suppress confirmation prompts (halts still emit blocker YAML)
  - `--per-squad` — execute one squad/module at a time; useful for multi-team coordination
  - `--squad=<id>` — execute only units in the named squad
  - `--module=<id>` — execute only units in the named module
  - `--review-panel=minimal|standard|full|auto` — force the review-panel tier (default auto, risk-based)
  - `--no-code-gates` — skip L0 toolchain + SAST gates for this run (secrets + dep-existence ALWAYS run)
  - `--no-full-suite` — DISCOURAGED: skip the batch-completion full-suite gate this run (logged; the gate still blocks the next run)
  - `--hard-rule-grammar=v1|v2` — force the Hard-rule grammar (default auto)
  - `--no-pbt` — skip Property-Based Testing validation
  - `--no-empty-commits` — skip the bolt-report-only commit for verify units with no changes
  - `--no-drift-check` — opt out of the end-of-chain detect-drift auto-gate
  - `--resume` / `--rollback <unit-id>` — partial-state forward resume / saga rollback
  - `--memory-off` — disable memory reads + writes
  - `--force-skip-postflight` — DISCOURAGED: skip the ast-grep postflight step this run only (logged; anti-bypass policy applies)

Follow `skills/execute-bolts/SKILL.md` procedure. Pre-flight checks MUST pass before any execution.

Hard rails:
- Superpowers detection per superpowers-bridge.md (real install > vendored > halt).
- target_files whitelist enforced at three layers — dispatch-prompt rule + review-panel scope check + the deterministic B3 whitelist observer (`validate-bolt-artifacts.sh --whitelist-scan`; escaped committed paths block the next run with `whitelist_violation`).
- No --no-verify on commits.
- Halt + blocker YAML on test failure after max retries.

On completion: suggest `/mega-sdd:detect-drift`.
