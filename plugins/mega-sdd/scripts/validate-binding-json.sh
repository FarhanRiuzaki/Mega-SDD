#!/usr/bin/env bash
# Parity gate: binding.md State Map rows <-> binding.json claims[].
# Exit 0 PASS, 2 FAIL, 3 usage error.
set -u
VAULT=""
while [ $# -gt 0 ]; do case "$1" in --vault) VAULT="$2"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;; *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: validate-binding-json.sh --vault <dir>" >&2; exit 3; }
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

V_VAULT="$VAULT" python3 <<'PYEOF'
import json, os, sys
# W2: parse_state_map moved BYTE-IDENTICAL (error strings + control flow) into
# the shared _lib/binding_md.py so the parity validator and the generator
# (derive-binding-json.sh) can never fork on md grammar.
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
from binding_md import parse_state_map

vault = os.environ.get("V_VAULT") or ""
if not vault:
    print("FAIL: V_VAULT not set", file=sys.stderr); sys.exit(3)
md_path = os.path.join(vault, "binding.md")
js_path = os.path.join(vault, "binding.json")
errors = []

try:
    md = open(md_path, encoding="utf-8").read()
    js = json.load(open(js_path, encoding="utf-8"))
except Exception as e:
    print(f"FAIL: cannot read binding pair: {e}"); sys.exit(2)

md_rows = parse_state_map(md, errors)
# S4 BC-PARITY-5COL: a claims[] entry with no "id" used to raise an uncaught
# KeyError (exit 1, outside the documented 0/2/3 contract, stale state file).
js_rows = {}
for c in js.get("claims", []):
    cid = c.get("id") if isinstance(c, dict) else None
    if not cid:
        errors.append(f"binding.json claims[] entry missing 'id': {str(c)[:120]}")
        continue
    js_rows[cid] = c

for cid, mr in md_rows.items():
    jr = js_rows.get(cid)
    if not jr:
        errors.append(f"{cid}: in binding.md, missing from binding.json")
        continue
    for k in ("verdict", "state"):
        if str(mr[k]) != str(jr.get(k)):
            errors.append(f"{cid}: {k} md={mr[k]!r} json={jr.get(k)!r}")
for cid in js_rows:
    if cid not in md_rows:
        errors.append(f"{cid}: in binding.json, missing from binding.md State Map")

state = {"status": "PASS" if not errors else "FAIL",
         "validator": "validate-binding-json.sh",
         "vault": vault, "errors": errors}
internal = os.path.join(vault, ".internal")
os.makedirs(internal, exist_ok=True)
tmp = os.path.join(internal, ".binding-json-parity.tmp")
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, os.path.join(internal, "binding-json-parity.json"))

if errors:
    for e in errors: print("FAIL:", e)
    sys.exit(2)
print("PASS: binding.json parity")
sys.exit(0)
PYEOF
