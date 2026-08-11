#!/usr/bin/env bash
# Quality gate for one arm: run BOTH test trees (tests/ + plugins/mega-sdd/tests/).
# Usage: quality-gate.sh <arm-root> <arm-name> <out-json>
# The 3 long pack suites are excluded IDENTICALLY in both arms (CI runs them
# separately); everything else must exit 0. QUALITY_PASS = 0 failures.
# Evidence class: MEASURED.
set -u
ROOT="${1:?arm-root}"; ARM="${2:?arm-name}"; OUT="${3:?out-json}"
cd "$ROOT" || exit 2
fails=0; total=0; failed_list=""
while IFS= read -r t; do
  case "$t" in *validate-pack*|*test-pack-lint*|*test-packs-golden*) continue ;; esac
  total=$((total+1))
  bash "$t" </dev/null >/dev/null 2>&1 || { fails=$((fails+1)); failed_list="$failed_list\"$t\","; }
done < <(find tests plugins/mega-sdd/tests -name 'test-*.sh' 2>/dev/null | sort)
pass=$((total-fails))
verdict="PASS"; [ "$fails" -gt 0 ] && verdict="FAIL"
printf '{"arm":"%s","suites_total":%d,"suites_passed":%d,"suites_failed":%d,"failed":[%s],"quality_pass":"%s"}\n' \
  "$ARM" "$total" "$pass" "$fails" "${failed_list%,}" "$verdict" > "$OUT"
echo "$ARM: $pass/$total suites pass — QUALITY_$verdict"
[ "$fails" -eq 0 ]
