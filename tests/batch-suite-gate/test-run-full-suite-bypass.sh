#!/usr/bin/env bash
# Functional (B2 out-of-band): run-full-suite.sh --base=<sha> is the WRITER of
# bypass_commits[] in _batch-suite.json — every commit in <base>..HEAD that touches a
# path some unit declares in target_files WITHOUT an SDD-PROVENANCE trailer. The run's
# own bolt commits carry the trailer and are excluded by construction; a commit on a
# non-target path is not a bypass. Without --base there is no scan and the key is
# absent (never a fabricated empty list).
#   A  base    : unit U-001 (target src/a.py) + README.md
#   B  bolt    : src/a.py created, SDD-PROVENANCE trailer          -> NOT listed
#   C  hotfix  : src/a.py edited, no trailer                       -> listed
#   D  docs    : README.md edited, no trailer (not a target path)  -> NOT listed
# Run: bash tests/batch-suite-gate/test-run-full-suite-bypass.sh </dev/null
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
S="$P/scripts/run-full-suite.sh"
[ -x "$S" ] || { echo "run-full-suite.sh missing/non-executable"; exit 1; }
err=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; err=1; }

repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
gc() { git -C "$repo" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
( cd "$repo" && git init -q . )
mkdir -p "$repo/.mega-sdd/vaults/app/units" "$repo/src"
cat > "$repo/.mega-sdd/vaults/app/units/U-001.md" <<'EOF'
---
unit_id: U-001
task_type: create
target_files:
  - path: src/a.py
    operation: create
---
# U-001
EOF
printf 'readme\n' > "$repo/README.md"
gc add -A && gc commit -qm "chore: base" || fail "fixture: commit A failed"
A=$(git -C "$repo" rev-parse HEAD)
printf 'print(1)\n' > "$repo/src/a.py"
gc add -A && gc commit -qm "feat: x" -m "SDD-PROVENANCE: mega-sdd U-001" || fail "fixture: commit B failed"
B=$(git -C "$repo" rev-parse HEAD)
printf 'print(2)\n' >> "$repo/src/a.py"
gc add -A && gc commit -qm "hotfix" || fail "fixture: commit C failed"
C=$(git -C "$repo" rev-parse HEAD)
printf 'more\n' >> "$repo/README.md"
gc add -A && gc commit -qm "docs: readme" || fail "fixture: commit D failed"
D=$(git -C "$repo" rev-parse HEAD)
ART="$repo/.mega-sdd/vaults/app/bolts/_batch-suite.json"

# 1. --base=<A>: base_sha recorded; bypass_commits is EXACTLY [C] touching src/a.py
#    (B excluded by its trailer, D excluded because README.md is no unit's target)
out=$(bash "$S" --cwd="$repo" --runner=true --base="$A" --quiet </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] && pass "1: green run with --base exits 0" || fail "1: expected exit 0, got $rc: $out"
[ -f "$ART" ] && pass "1: artifact written by the script at vaults/app/bolts/_batch-suite.json" \
  || fail "1: artifact missing at $ART"
if python3 - "$ART" "$A" "$B" "$C" "$D" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); A, B, C, D = sys.argv[2:6]
assert d.get("base_sha") == A, ("base_sha", d.get("base_sha"), A)
bc = d.get("bypass_commits")
assert isinstance(bc, list), ("bypass_commits", bc)
assert [e.get("sha") for e in bc] == [C], ("shas", [e.get("sha") for e in bc], {"B": B, "C": C, "D": D})
assert bc[0].get("target_files_touched") == ["src/a.py"], bc[0]
assert bc[0].get("subject") == "hotfix", bc[0]
assert d.get("head_sha") == D, ("head_sha", d.get("head_sha"), D)
PY
then pass "1: base_sha == A; bypass_commits == [C] with target_files_touched == [src/a.py] (B trailer-excluded, D non-target)"
else fail "1: bypass scan wrong — artifact: $(tr -d '\n' < "$ART" 2>/dev/null | cut -c1-600)"
fi

# 2. no --base: no scan -> neither bypass_commits nor base_sha in the artifact
out=$(bash "$S" --cwd="$repo" --runner=true --quiet </dev/null 2>&1); rc=$?
[ $rc -eq 0 ] && pass "2: green run without --base exits 0" || fail "2: expected exit 0, got $rc: $out"
if python3 - "$ART" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert "bypass_commits" not in d, d.get("bypass_commits")
assert "base_sha" not in d, d.get("base_sha")
assert d.get("status") == "green", d.get("status")
PY
then pass "2: without --base the artifact carries no bypass_commits / base_sha"
else fail "2: keys leaked without --base — artifact: $(tr -d '\n' < "$ART" 2>/dev/null | cut -c1-400)"
fi

[ $err -eq 0 ] && echo "ALL PASS (test-run-full-suite-bypass)" || echo "FAILED"
exit $err
