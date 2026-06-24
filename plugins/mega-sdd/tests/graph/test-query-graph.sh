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

# 5c-mixed: downstream is per-relation directional, NOT one direction for all.
# A --downstream query from a code file must reach not just claims+units (via
# REVERSE of the dependency relations implements/honors/depends_on) but ALSO the
# STRUCTURAL nodes those reached nodes attach to (via FORWARD in_module/covers/
# kb_source/blocks/domain_dep). The buggy single-direction traversal can NEVER
# reach these. Assert the exact enriched nodes appear:
#   U-001 -[in_module]-> M-auth                 (module, forward from reached unit)
#   M-auth -[blocks]-> M-orders                 (module, forward from reached module)
#   C-001 -[covers]-> sample-vault:F-U-001       (flow, forward from reached claim)
#   F-U-001 -[kb_source]-> cif-customer          (kb_domain, forward from reached flow)
#   cif-customer -[domain_dep]-> account-base    (kb_domain, forward chain)
echo "$OUT" | grep -q "## module" || { echo "FAIL 5c-mixed: no module section downstream"; rc=1; }
echo "$OUT" | grep -q "M-auth" || { echo "FAIL 5c-mixed: module M-auth not surfaced downstream (in_module not followed forward)"; rc=1; }
echo "$OUT" | grep -q "M-orders" || { echo "FAIL 5c-mixed: module M-orders not surfaced downstream (blocks not followed forward)"; rc=1; }
echo "$OUT" | grep -q "## flow" || { echo "FAIL 5c-mixed: no flow section downstream"; rc=1; }
echo "$OUT" | grep -q "sample-vault:F-U-001" || { echo "FAIL 5c-mixed: flow F-U-001 not surfaced downstream (covers not followed forward)"; rc=1; }
echo "$OUT" | grep -q "## kb_domain" || { echo "FAIL 5c-mixed: no kb_domain section downstream"; rc=1; }
echo "$OUT" | grep -q "cif-customer" || { echo "FAIL 5c-mixed: kb_domain cif-customer not surfaced downstream (kb_source not followed forward)"; rc=1; }
echo "$OUT" | grep -q "account-base" || { echo "FAIL 5c-mixed: kb_domain account-base not surfaced downstream (domain_dep not followed forward)"; rc=1; }

# 5c-freshness: a SECOND query with nothing changed must NOT rebuild graph.json.
# The fixture includes knowledge-base/00-overview/system-purpose.md, a globbed KB
# file with NO `domain:` key (contributes no node). The builder must still hash it
# so the query's freshness pre-check (which hashes EVERY globbed file) finds
# set(cur)==set(old). The buggy builder hashed only node-contributing files ->
# set mismatch -> forced rebuild every query (built_at changes). Capture built_at
# now (graph.json exists from 5a/5b/5c), query again, assert built_at UNCHANGED.
# Done BEFORE 5d mutates binding.json (which legitimately forces a rebuild).
BUILT_AT_1="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['_meta']['built_at'])" "$TMP/.mega-sdd/graph.json")"
MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$Q" --root "$TMP" --impact "UserController.php" --downstream >/dev/null 2>&1
BUILT_AT_2="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['_meta']['built_at'])" "$TMP/.mega-sdd/graph.json")"
[ "$BUILT_AT_1" = "$BUILT_AT_2" ] || { echo "FAIL 5c-freshness: unchanged second query rebuilt graph.json (built_at $BUILT_AT_1 -> $BUILT_AT_2); cache defeated by domain-less KB file"; rc=1; }

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
