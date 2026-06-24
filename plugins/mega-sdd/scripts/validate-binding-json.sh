#!/usr/bin/env bash
# Parity gate: binding.md State Map rows <-> binding.json claims[].
# Exit 0 PASS, 2 FAIL, 3 usage error.
set -u
VAULT=""
while [ $# -gt 0 ]; do case "$1" in --vault) VAULT="$2"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;; *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: validate-binding-json.sh --vault <dir>" >&2; exit 3; }

V_VAULT="$VAULT" python3 <<'PYEOF'
import json, os, sys
vault = os.environ.get("V_VAULT") or ""
md_path = os.path.join(vault, "binding.md")
js_path = os.path.join(vault, "binding.json")
errors = []

def parse_state_map(md):
    rows = {}
    in_tbl = False
    for line in md.splitlines():
        if line.strip().startswith("## Implementation State Map"):
            in_tbl = True; continue
        if in_tbl:
            if line.startswith("## "):
                break
            if not line.strip().startswith("|"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 6 or cells[0] in ("Claim ID", "---") or set(cells[0]) <= {"-"}:
                continue
            rows[cells[0]] = {"id": cells[0], "verdict": cells[1], "state": cells[2]}
    return rows

try:
    md = open(md_path, encoding="utf-8").read()
    js = json.load(open(js_path, encoding="utf-8"))
except Exception as e:
    print(f"FAIL: cannot read binding pair: {e}"); sys.exit(2)

md_rows = parse_state_map(md)
js_rows = {c["id"]: c for c in js.get("claims", [])}

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
