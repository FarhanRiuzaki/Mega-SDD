# Iter 77 — Generalize range-shorthand expansion (`...` / `through` / `to` / `thru` / `…`)

Fixture for logic-proving `validate-handoff-yaml.sh` `expand_range_shorthand` (renamed from Iter 75 `expand_ellipsis_range`).

## Bug

Iter 75 caught ellipsis (`U-001/ ... U-016/`). Post-ship, execute-bolts emitted a NEW shorthand variant:

```yaml
artifacts:
  - .mega-sdd/vaults/tradefinance-rebuild-phase-2/bolts/U-017/ through U-025/
```

Iter 75 regex only recognized `...` — `through` slipped past defense → `artifact_missing` halt even though all 9 dirs (U-017..U-025) existed on disk. Class-bug shape: model invents new natural-language range condensations.

## Fix

Generalized regex to match `(?:\.\.\.|…|through|thru|to)` (case-insensitive for word separators).

## Logic-proof scenarios (run with validator):

```bash
VALIDATOR=plugins/mega-sdd/scripts/validate-handoff-yaml.sh
CWD=tests/fixtures/iter77-range-shorthand/project
for f in farhan-through-bug scenario-D-through scenario-E-to scenario-F-uppercase scenario-G-genuine-miss scenario-H-iter75-regression; do
  bash $VALIDATOR --cwd=$CWD --response-file=tests/fixtures/iter77-range-shorthand/$f.md --skill-name=mega-sdd:execute-bolts
done
```

| Scenario | Description | Expected |
|---|---|---|
| `farhan-through-bug` | Farhan's exact production input — U-001 enumerated + `U-017/ through U-025/` shorthand, all dirs on disk | **PASS** ✓ |
| `scenario-D-through` | Lowercase `through` only | **PASS** ✓ |
| `scenario-E-to` | Lowercase `to` separator | **PASS** ✓ |
| `scenario-F-uppercase` | Uppercase `THROUGH` (case-insensitive coverage) | **PASS** ✓ |
| `scenario-G-genuine-miss` | `through U-030/` with only U-017..U-025 on disk (U-026..U-030 genuinely missing) | **FAIL** ✓ (false-negative preserved) |
| `scenario-H-iter75-regression` | Original `...` ellipsis (Iter 75 regression check) | **PASS** ✓ |

## Layout

```
project/.mega-sdd/vaults/test-vault/bolts/
  U-001/  U-017/  U-018/  ...  U-025/   # 10 dirs total; U-026..U-030 INTENTIONALLY missing for G
*.md                                    # handoff inputs per scenario
```
