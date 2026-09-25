#!/usr/bin/env bash
# State anchor — scope parity (spec docs/superpowers/specs/2026-09-25-state-anchor-design.md §4).
# vault_scope.py is the ONE scope grammar; the sync lane still computes its own path
# set (sync-intersect.sh, rebind-units.sh — rewired in Slice 3). Until then this pins
# vault_scope ⊇ sync-intersect: every path the sync gate would call "touched" is also
# inside the state-anchor scope, so the view never calls FRESH what sync calls moved.
# Plus the shapes only vault_scope covers: `units/U-*/unit.md`, root `vaults/*`,
# root-escaping `../` paths, the basename lane.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

P="$WORK/p"; V="$P/.mega-sdd/vaults/web"; mkdir -p "$V/units/U-003" "$V/bolts/U-001" "$P/src/lib"
cat > "$V/units/U-001.md" <<'U'
---
id: U-001
target_files:
  - path: src/Login.tsx
    operation: modify
  - path: src/lib
    operation: modify
existing_interfaces:
  - file: src/api/client.ts
    symbol: login
---
## Anchors
- `src/pages/Home.tsx:10-20` home
- `Widget.tsx:3` basename lane
## Claims
- C-U001-01 "config dir" — expect: src/config — must-exist
- C-U001-02 "token helper" — expect: src/auth/token.ts:refresh
U
cat > "$V/units/U-002.md" <<'U'
---
id: U-002
target_files: [src/New.tsx, ../shared/lib.ts]
---
U
cat > "$V/units/U-003/unit.md" <<'U'
---
id: U-003
target_files:
  - path: src/deep/Only.tsx
    operation: create
---
U
printf '{"schema":"unit-binding/1","head":"deadbeef","claims":[{"id":"C-1","anchor":"src/models/User.ts:4 + src/models/Role.ts:9"}]}\n' > "$V/bolts/U-001/binding.json"
mkdir -p "$P/vaults/legacy/units"
printf -- '---\nid: U-100\ntarget_files:\n  - path: legacy/app.php\n    operation: modify\n---\n' > "$P/vaults/legacy/units/U-100.md"

CANDS="src/Login.tsx,src/lib/x.ts,src/api/client.ts,src/pages/Home.tsx,src/config/a.ts,src/auth/token.ts,src/New.tsx,src/models/User.ts,src/models/Role.ts,src/other/Widget.tsx,README.md,src/unrelated.ts"
SI=$(bash "$PLUGIN/scripts/sync-intersect.sh" --cwd="$P" --vault="$V" --paths="$CANDS" 2>/dev/null)
python3 - "$P" "$V" "$SI" "$PLUGIN/scripts/_lib" <<'PY' && ok "vault_scope ⊇ every path sync-intersect calls touched" || bad "parity (see above)"
import json, sys
root, vault, si, lib = sys.argv[1:5]
sys.path.insert(0, lib)
import vault_scope as vs
sc = vs.vault_scope(root, vault)
specs = sc["paths"] | sc["globs"]
def m(q, s):
    if s.startswith(vs.GLOB_PREFIX):
        n = s[len(vs.GLOB_PREFIX):]
        return q == n or q.endswith("/" + n)
    return q == s or q.startswith(s + "/") or s.startswith(q + "/")
hits = json.loads(si)["intersect_paths"]
missing = [h for h in hits if not any(m(h, s) for s in specs)]
for h in missing:
    print("   not in vault_scope:", h)
assert hits, "sync-intersect found nothing — fixture broken"
sys.exit(1 if missing else 0)
PY

python3 - "$P" "$V" "$PLUGIN/scripts/_lib" <<'PY' && ok "vault_scope covers unit.md shape, ../ paths, basename lane, root vaults/*, binding anchors" || bad "vault_scope widenings"
import sys
root, vault, lib = sys.argv[1:4]
sys.path.insert(0, lib)
import vault_scope as vs
sc = vs.vault_scope(root, vault)
need = ["src/deep/Only.tsx", "../shared/lib.ts", "src/models/Role.ts", "src/config", "src/auth/token.ts"]
miss = [n for n in need if n not in sc["paths"]]
if ":(glob)**/Widget.tsx" not in sc["globs"]:
    miss.append(":(glob)**/Widget.tsx")
vnames = [vs.vault_name(root, v) for v in vs.vaults(root)]
if "legacy" not in vnames:
    miss.append("root vaults/legacy not enumerated")
if any(p.startswith(".mega-sdd") for p in sc["paths"]):
    miss.append(".mega-sdd path leaked into scope")
for x in miss:
    print("   missing:", x)
sys.exit(1 if miss else 0)
PY

[ "$fail" -eq 0 ] && { echo "PASS state-anchor vault-scope parity"; exit 0; }
echo "state-anchor vault-scope parity FAILED"; exit 1
