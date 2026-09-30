#!/usr/bin/env bash
# derive-ready-units.sh — the done / quarantined source of derive-exec-plan.sh (the inline execute-bolts run).
#
#   derive-ready-units.sh --cwd=<root> --vault=<vault> [--quiet]
#
# done = implemented (compute-unit-staleness.sh) with acceptance.json + postflight.json status pass;
# quarantined = as recorded (write-unit-quarantine.sh). Output: ONE JSON line. Exit 0 · 2 usage.
set -u
export PYTHONUTF8=1
CWD="."; VAULT=""; QUIET=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --quiet) QUIET=1 ;;
  *) echo "usage: derive-ready-units.sh --cwd=<root> --vault=<vault> [--quiet]" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT/units" ] || { echo "usage: --vault=<dir with units/> required" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STALE="$(bash "$SCRIPT_DIR/compute-unit-staleness.sh" --project="$CWD" --vault="$VAULT" 2>/dev/null || echo '{"units":[]}')"
V_VAULT="$VAULT" V_STALE="$STALE" python3 <<'PYEOF'
import glob, json, os
vault = os.environ["V_VAULT"]
try:
    stale = {u["unit"]: u for u in (json.loads(os.environ["V_STALE"]).get("units") or [])}
except Exception:
    stale = {}
units = sorted({os.path.basename(p)[:-3] if p.endswith(".md") and os.path.basename(p).startswith("U-") else os.path.basename(os.path.dirname(p))
                for p in glob.glob(os.path.join(vault, "units", "U-*.md")) + glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))})


def evidence(uid):
    b = os.path.join(vault, "bolts", uid)
    def ok(name):
        try: return str(json.load(open(os.path.join(b, name), encoding="utf-8")).get("status") or "").lower() == "pass"
        except Exception: return False
    return ok("acceptance.json") and ok("postflight.json")


st = {u: (stale.get(u) or {}).get("status", "pending") for u in units}
print(json.dumps({"schema": "ready-units/3", "done": [u for u in units if st[u] == "implemented" and evidence(u)],
                  "quarantined": [u for u in units if st[u] == "quarantined"]}))
PYEOF
