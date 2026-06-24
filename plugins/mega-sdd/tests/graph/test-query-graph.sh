#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
Q="${PLUGIN_ROOT}/scripts/query-graph.sh"
SRC="${SCRIPT_DIR}/fixtures/project"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp -R "$SRC/." "$TMP/"

# Seed a git repo so build-graph.sh can read a real HEAD.
# This lets the stale_vs_head check in build-graph.sh compare binding.json
# head_at_bind against an actual commit SHA.
git -C "$TMP" init -q
git -C "$TMP" config user.email "test@test"
git -C "$TMP" config user.name "Test"
git -C "$TMP" add -A
git -C "$TMP" commit -q -m "fixture"

rc=0

# 5a: missing graph.json -> lazy rebuild + answer
rm -f "$TMP/.mega-sdd/graph.json"
OUT="$(MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$Q" --root "$TMP" --impact "UserController.php" --downstream 2>&1)"
echo "$OUT" | grep -q "sample-vault:C-001" || { echo "FAIL 5a: anchor->claim not found"; rc=1; }
echo "$OUT" | grep -q "sample-vault:U-001" || { echo "FAIL 5a: claim->unit not found"; rc=1; }
[ -f "$TMP/.mega-sdd/graph.json" ] || { echo "FAIL 5a: lazy rebuild did not write graph.json"; rc=1; }

# 5b: file:line normalizes to same anchor
OUT2="$(MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$Q" --root "$TMP" --impact "UserController.php:45" --downstream 2>&1)"
echo "$OUT2" | grep -q "sample-vault:C-001" || { echo "FAIL 5b: file:line did not resolve"; rc=1; }

# 5c: transitive downstream U-001 -> U-002 (depends_on reverse)
echo "$OUT" | grep -q "sample-vault:U-002" || { echo "FAIL 5c: transitive dependent unit missing"; rc=1; }

# 5d: staleness banner when binding head != current HEAD
# Mutate binding.json so head_at_bind differs from the real git HEAD.
# Because we have a real git repo in TMP, build-graph.sh will detect the mismatch.
python3 - "$TMP/.mega-sdd/vaults/sample-vault/binding.json" <<'PYEOF'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["head"]="DEADBEEF"; json.dump(d,open(p,"w"))
PYEOF
rm -f "$TMP/.mega-sdd/graph.json"
OUT3="$(MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$Q" --root "$TMP" --impact "UserController.php" --downstream 2>&1)"
echo "$OUT3" | grep -qi "stale\|sync" || { echo "FAIL 5d: no staleness banner"; rc=1; }

# 5e: path-set rebuild -- adding a NEW vault's files (new hash keys) forces rebuild
#     even though no existing tracked file changed, and the new vault is visible.
cp -R "$TMP/.mega-sdd/vaults/sample-vault" "$TMP/.mega-sdd/vaults/second-vault"
# graph.json still exists and its source_hashes lack second-vault/* keys -> must rebuild
OUT4="$(MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$Q" --root "$TMP" --impact "second-vault:U-001" --downstream 2>&1)"
echo "$OUT4" | grep -q "second-vault:U-002" || { echo "FAIL 5e: new vault not picked up by path-set rebuild"; rc=1; }

[ $rc -eq 0 ] && echo "PASS: test-query-graph"
exit $rc
