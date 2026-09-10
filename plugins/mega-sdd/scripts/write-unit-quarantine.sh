#!/usr/bin/env bash
# write-unit-quarantine.sh — W1 zero-idle (v8 P1.e, spec 2026-09-10 Appendix F6c):
# record that ONE unit was set aside by a DEFER-class halt so the wave can continue
# and the question reaches the human ONCE, in the final report — instead of the
# chain parking mid-run.
#
#   write-unit-quarantine.sh --cwd=<root> --vault=<vault> --unit=U-XXX --halt=<halt_type> --reason="<why>" [--envelope=<file>] [--dependents=U-005,U-007]
#   write-unit-quarantine.sh --cwd=<root> --vault=<vault> --unit=U-XXX --release --by=<who>
#
# Writes <vault>/bolts/U-XXX/quarantine.json (NOT evidence of passing — no hook
# guard needed; it only ever records a failure + the open question). Readers:
# compute-unit-staleness.sh (status: quarantined), execute-bolts (skip unit +
# dependents with the reason; _summary.md karantina table). --release removes the
# file (the human answered: retry / fixed by hand / dropped) and stamps who.
# Exit 0 written/released · 2 usage.
set -u
CWD="."; VAULT=""; UNIT=""; HALT=""; REASON=""; ENV_FILE=""; DEPS=""; RELEASE=0; BY=""
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --unit=*) UNIT="${arg#*=}" ;; --halt=*) HALT="${arg#*=}" ;;
  --reason=*) REASON="${arg#*=}" ;; --envelope=*) ENV_FILE="${arg#*=}" ;; --dependents=*) DEPS="${arg#*=}" ;; --release) RELEASE=1 ;; --by=*) BY="${arg#*=}" ;;
  *) echo "usage: write-unit-quarantine.sh --cwd --vault --unit=U-XXX (--halt=<type> --reason=<why> [--envelope=<file>] [--dependents=U-..] | --release --by=<who>)" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT" ] && [ -n "$UNIT" ] || { echo "usage: --vault=<dir> --unit=U-XXX required" >&2; exit 2; }
DIR="$VAULT/bolts/$UNIT"; OUT="$DIR/quarantine.json"
if [ "$RELEASE" -eq 1 ]; then
  [ -n "$BY" ] || { echo "usage: --release needs --by=<who>" >&2; exit 2; }
  [ -f "$OUT" ] || { echo "nothing to release: $OUT absent" >&2; exit 2; }
  mkdir -p "$DIR"; mv "$OUT" "$DIR/quarantine.released.$(date -u +%Y%m%dT%H%M%SZ).json"
  printf '{"unit":"%s","released_by":"%s","out":"%s"}\n' "$UNIT" "$BY" "$OUT"; exit 0
fi
[ -n "$HALT" ] && [ -n "$REASON" ] || { echo "usage: --halt=<halt_type> --reason=<why> required" >&2; exit 2; }
mkdir -p "$DIR"
V_UNIT="$UNIT" V_HALT="$HALT" V_REASON="$REASON" V_ENV="$ENV_FILE" V_DEPS="$DEPS" V_OUT="$OUT" V_CWD="$CWD" python3 <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone
E = os.environ
env = None
if E["V_ENV"]:
    try: env = open(E["V_ENV"], encoding="utf-8", errors="replace").read()[:4000]
    except OSError: env = None
doc = {"schema": "unit-quarantine/1", "unit": E["V_UNIT"], "halt_type": E["V_HALT"], "reason": E["V_REASON"],
       "dependents_skipped": [d.strip() for d in E["V_DEPS"].split(",") if d.strip()],
       "envelope": env, "quarantined_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
       "question": "Retry the unit after a fix, fix it by hand, or drop it? (one answer per quarantined unit, in the final report)"}
tmp = E["V_OUT"] + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as f: json.dump(doc, f, indent=1, ensure_ascii=False)
os.replace(tmp, E["V_OUT"])
print(json.dumps({"unit": doc["unit"], "halt_type": doc["halt_type"], "dependents_skipped": doc["dependents_skipped"],
                  "out": os.path.relpath(E["V_OUT"], os.path.abspath(E["V_CWD"]))}))
PYEOF
