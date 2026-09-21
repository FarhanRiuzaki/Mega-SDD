#!/usr/bin/env bash
# test-gitignore-guidance.sh — references/paths.md §Recommended .gitignore entries.
#
# Field evidence (2026-09-21): a team repo TRACKED `.validation-blockers.json` and
# `.locked-files-index.json` — dirty tree at every session start, whole-file merge
# conflicts, and the anti-self-bypass guard refusing to let Claude fix them. The
# guidance did not list them. The same block also offered `vaults/*/bolts/` as
# "regenerable" — but bolts/ carries READ gate evidence (bolt-report.md,
# acceptance.json, _batch-suite.json, attempts.json); a clone that ignores it closes
# the execute-bolts gate on the first run.
#
# This suite reads the patterns OUT OF the document and runs them through real
# `git check-ignore`, so the prose and its effect cannot drift:
#   G1  the always-block ignores every derived / per-machine state file
#   G2  it does NOT ignore gate evidence, the ledger, or the source of truth
#       (incl. the near-miss names `state.json` / `vault.json` vs `.*-state.json`)
#   G3  the doc never again offers bolts/ for gitignore, and names it under NEVER
#   G4  every always-entry is really derived: named in the Stop hook's derived-OUTPUT
#       prune list, or a cache/journal path the doc itself classifies
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
DOC="$P/references/paths.md"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
command -v git >/dev/null 2>&1 || { echo "gitignore-guidance: git not found"; exit 1; }

# ── extract the always-block (between the two marker comments inside the fence) ──
ALWAYS="$W/always.gitignore"
awk '/^# --- always:/{on=1;next} /^# --- per-project decision/{on=0} on && NF && $0 !~ /^#/' "$DOC" > "$ALWAYS"
N_ALWAYS=$(wc -l < "$ALWAYS" | tr -d ' ')
[ "$N_ALWAYS" -ge 8 ] && ok "always-block extracted from paths.md ($N_ALWAYS patterns)" \
  || fail "always-block missing or too short ($N_ALWAYS) — markers '# --- always:' / '# --- per-project decision' must stay"

REPO="$W/repo"; mkdir -p "$REPO" && ( cd "$REPO" && git init -q . ) >/dev/null 2>&1
cp "$ALWAYS" "$REPO/.gitignore"
ignored() { ( cd "$REPO" && git check-ignore -q "$1" ); }

echo "── G1: derived / per-machine state IS ignored ──"
for f in .mega-sdd/.validation-blockers.json .mega-sdd/.ui-quality-blockers.json \
         .mega-sdd/.unit-spec-state.json .mega-sdd/.flow-coverage-state.json \
         .mega-sdd/.sibling-consistency-state.json .mega-sdd/.handoff-validation-state.json \
         .mega-sdd/.analyze-state.json .mega-sdd/.publish-state.json \
         .mega-sdd/.analyze-freshness.json .mega-sdd/.locked-files-index.json \
         .mega-sdd/.stop-scan-stamp .mega-sdd/.ptu-scan-stamp \
         .mega-sdd/.cache/pack-resolver/x .mega-sdd/codebase/.dirty-paths.jsonl; do
  ignored "$f" && ok "G1 ignored: $f" || fail "G1 NOT ignored: $f"
done

echo "── G2: gate evidence + source of truth is NOT ignored ──"
for f in .mega-sdd/vaults/app/bolts/U-001/bolt-report.md .mega-sdd/vaults/app/bolts/U-001/acceptance.json \
         .mega-sdd/vaults/app/bolts/U-001/attempts.json .mega-sdd/vaults/app/bolts/U-001/postflight.json \
         .mega-sdd/vaults/app/bolts/_batch-suite.json .mega-sdd/factory-ledger.json \
         .mega-sdd/state.json .mega-sdd/graph.json .mega-sdd/config.yaml \
         .mega-sdd/vaults/app/vault.json .mega-sdd/vaults/app/vault.md .mega-sdd/vaults/app/context.md \
         .mega-sdd/vaults/app/binding.md .mega-sdd/vaults/app/units/U-001.md \
         .mega-sdd/vaults/app/constitution.md .mega-sdd/codebase/codebase-map.md; do
  ignored "$f" && fail "G2 WRONGLY ignored: $f" || ok "G2 kept: $f"
done

echo "── G3: bolts/ is never offered for gitignore; it is named under NEVER ──"
awk '/^```/{f=!f} f' "$DOC" | grep -qE '^#? *\.mega-sdd/vaults/\*/bolts/' \
  && fail "G3 a .gitignore block in paths.md offers vaults/*/bolts/ (gate evidence — lockout on a fresh clone)" \
  || ok "G3 no .gitignore block offers bolts/"
NEVER="$(awk '/^\*\*NEVER gitignore/{on=1} on && /^Mega-sdd does NOT modify/{on=0} on' "$DOC")"
printf '%s' "$NEVER" | grep -q 'bolts/' && printf '%s' "$NEVER" | grep -q 'factory-ledger.json' \
  && printf '%s' "$NEVER" | grep -q 'acceptance.json' && printf '%s' "$NEVER" | grep -q 'attempts.json' \
  && ok "G3b NEVER list names bolts/ evidence + the ledger" || fail "G3b NEVER list incomplete"

echo "── G4: every always-entry is classified derived by the MECHANISM, not just by the doc ──"
STOP="$P/hooks/stop"
G4_BAD=0
while IFS= read -r pat; do
  base="${pat##*/}"; [ -n "$base" ] || base="$(basename "${pat%/}")"
  case "$pat" in
    */.cache/) grep -q -- '-name .cache' "$STOP" || { G4_BAD=1; echo "    not pruned as derived in hooks/stop: $pat"; } ;;
    *) grep -qF -- "-name $base" "$STOP" || grep -qF -- "-name '$base'" "$STOP" \
         || { G4_BAD=1; echo "    not in the Stop hook's derived-OUTPUT prune list: $pat"; } ;;
  esac
done < "$ALWAYS"
[ "$G4_BAD" -eq 0 ] && ok "G4 all $N_ALWAYS always-entries appear in hooks/stop's derived-output prune list" \
  || fail "G4 the doc calls something derived that the Stop hook does not"

echo "gitignore-guidance: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
