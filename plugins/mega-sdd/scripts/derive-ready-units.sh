#!/usr/bin/env bash
# derive-ready-units.sh — W2 fast lane (v8 P2, lane lite; spec 2026-09-10 §7 W2 +
# research/2026-09-11-v8-p2-report.md §1): unit-level readiness instead of the
# wave barrier. MEASURED on the clinic baseline: 8 sequential waves, 17–45 min
# each, a 1-unit tail wave still 21–25 min because U-020 waited for U-019's
# whole panel + gates, not for U-019's evidence.
#
#   derive-ready-units.sh --cwd=<root> --vault=<vault> [--quiet]
#
# Reads every unit's `depends_on`, the staleness statuses (compute-unit-staleness.sh:
# implemented / stale / quarantined / pending) and the per-unit evidence files
# (bolts/U-XXX/acceptance.json + postflight.json with status pass). A unit is
#   ready     = not started, and EVERY dependency is `implemented` with acceptance
#               pass AND postflight pass (evidence written — the panel may still run);
#   blocked   = a dependency is missing evidence, red, stale, or quarantined
#               (quarantine of a dependency blocks the dependent, W1 rule);
#   done      = implemented with pass evidence;   quarantined = as recorded.
# Output: ONE JSON line {ready[], blocked[{unit,waiting_on[]}], done[], quarantined[],
# in_progress[], dispatch_plan{}} — pointers for the controller; it never dispatches
# anything, and every gate the dispatch itself meets (F-09, B1–B4, whitelist, CONFLICT)
# is untouched.
#
# dispatch_plan (8.3.0 L1, spec 2026-09-16-clinic-levers-design.md — MEASUREMENT PENDING):
# MEASURED on clinic lite 7.38.0 (research §2f): the controller topped up per BURST
# (7 bursts 17–22 min apart), ready units waited ≈117 unit-min, = the 25 % idle. The
# plan makes the top-up deterministic: cap = vault_layouts.parallel_max, in_flight =
# vault_layouts.inflight_units (the ONE definition the gate + wave rail read),
# slots = cap - in_flight, dispatch_now = the first `slots` ready units ordered by
# direct-dependent count DESC (critical path first) then id; the rest = deferred.
# The controller dispatches dispatch_now VERBATIM after every implementer return.
# Exit 0 · 2 usage.
set -u
CWD="."; VAULT=""; QUIET=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --quiet) QUIET=1 ;;
  *) echo "usage: derive-ready-units.sh --cwd=<root> --vault=<vault> [--quiet]" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT/units" ] || { echo "usage: --vault=<dir with units/> required" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STALE="$(bash "$SCRIPT_DIR/compute-unit-staleness.sh" --project="$CWD" --vault="$VAULT" 2>/dev/null || echo '{"units":[]}')"
V_CWD="$CWD" V_LIB="$SCRIPT_DIR/_lib" V_VAULT="$VAULT" V_STALE="$STALE" V_QUIET="$QUIET" python3 <<'PYEOF'
import glob, json, os, re, sys
vault = os.environ["V_VAULT"]
cwd = os.environ["V_CWD"]
sys.path.insert(0, os.environ["V_LIB"])
try:
    import vault_layouts as _vl
except Exception:
    _vl = None
try:
    stale = {u["unit"]: u for u in (json.loads(os.environ["V_STALE"]).get("units") or [])}
except Exception:
    stale = {}
units = {}
for p in sorted(glob.glob(os.path.join(vault, "units", "U-*.md")) + glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))):
    uid = os.path.basename(p)[:-3] if p.endswith(".md") and os.path.basename(p).startswith("U-") else os.path.basename(os.path.dirname(p))
    txt = open(p, encoding="utf-8", errors="replace").read()
    fm = txt.split("\n---", 1)[0] if txt.startswith("---") else ""
    deps = []
    m = re.search(r"(?m)^depends_on:[ \t]*(\[[^\]]*\])?[ \t]*\n((?:[ \t]+-[^\n]*\n?)*)", fm)
    if m:
        if m.group(1): deps = [d.strip().strip("'\"") for d in m.group(1)[1:-1].split(",") if d.strip()]
        else: deps = [re.sub(r"^[ \t]+-[ \t]*", "", ln).strip().strip("'\"") for ln in m.group(2).splitlines() if ln.strip()]
    units[uid] = [d for d in deps if re.match(r"^U-", d)]

def evidence(uid):
    b = os.path.join(vault, "bolts", uid)
    def ok(name):
        try: return str(json.load(open(os.path.join(b, name))).get("status") or "").lower() == "pass"
        except Exception: return False
    return ok("acceptance.json") and ok("postflight.json")

done, quarantined, in_progress, ready, blocked = [], [], [], [], []
for uid in sorted(units):
    st = (stale.get(uid) or {}).get("status", "pending")
    if st == "quarantined": quarantined.append(uid); continue
    if st == "implemented" and evidence(uid): done.append(uid); continue
    if st == "implemented" or os.path.isdir(os.path.join(vault, "bolts", uid)) and os.path.isfile(os.path.join(vault, "bolts", uid, "dispatch-prompt.md")):
        in_progress.append(uid); continue
    waiting = [d for d in units[uid] if not (d in stale and stale[d].get("status") == "implemented" and evidence(d))]
    (ready if not waiting else blocked).append(uid if not waiting else {"unit": uid, "waiting_on": waiting})
# dispatch_plan (L1): deterministic top-up — ONE in-flight definition, ONE cap.
dependents = {u: 0 for u in units}
for u, deps in units.items():
    for d in deps:
        if d in dependents: dependents[d] += 1
if _vl is not None:
    try:
        in_flight = list(_vl.inflight_units(cwd)); cap = int(_vl.parallel_max(cwd))
    except Exception:
        in_flight = list(in_progress); cap = 4
else:
    in_flight = list(in_progress); cap = 4
slots = max(0, cap - len(in_flight))
ordered = sorted(ready, key=lambda u: (-dependents.get(u, 0), u))
plan = {"cap": cap, "in_flight": in_flight, "slots": slots,
        "dispatch_now": ordered[:slots], "deferred": ordered[slots:],
        "order_rule": "direct-dependent count desc (critical path first), then unit id",
        "reason": ("dispatch these NOW, in this order — one Agent call each, this message"
                   if ordered[:slots] else
                   ("no free slot (in_flight == cap) — wait for the next implementer return, never a timer/burst"
                    if ready else "nothing ready — wait for the next implementer return"))}
out = {"schema": "ready-units/2", "lane": "lite", "ready": ready, "blocked": blocked, "done": done, "quarantined": quarantined, "in_progress": in_progress,
       "dispatch_plan": plan,
       "rule": "ready = every depends_on unit implemented with acceptance+postflight pass (panel may still run); quarantined/red/stale dependency blocks; dispatch_plan = cap - in_flight slots filled critical-path-first (L1, spec 2026-09-16-clinic-levers-design.md)"}
print(json.dumps(out))
PYEOF
