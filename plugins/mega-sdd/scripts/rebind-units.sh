#!/usr/bin/env bash
# rebind-units.sh — the lane-lite / layout-3 re-bind hop of the sync + delta lanes
# (v8 P3, spec 2026-09-10 §4 row "re-bind": `bind --paths=@` → `bolts --rebind=@paths`).
#
# A plan-born (layout-3) vault has no whole-vault binding.md/binding.json — its
# verdicts live per unit in <vault>/bolts/U-XXX/binding.json (JIT bind at dispatch).
# When the code moved (sync) or the vault moved (delta), the units that TOUCH the
# changed paths must be re-verdicted; nothing else. This script is the deterministic
# scope + the same sanctioned writers the JIT step uses — never a second grammar:
#
#   affected = units whose target_files[].path ∪ `## Anchors` paths ∪
#              existing_interfaces[].file ∪ bolts/U-XXX/binding.json claims[].anchor
#              intersect the changed paths (exact or ancestor-dir, both directions —
#              the sync-intersect.sh rule)             [--units=all = every unit]
#   then:      derive-unit-claims.sh --units=<affected>   (wave claim set)
#              write-unit-binding.sh per affected unit     (fs/symbol verdicts by script;
#                                                           `text` claims stay OQ until the
#                                                           controller runs ladder E3 and
#                                                           re-runs the writer --verdicts)
#              validate-handoff-binding-units.sh --units=<affected>  (the CONFLICT gate,
#                                                           .validation-blockers.json)
#
#   rebind-units.sh --cwd=<root> --vault=<vault> (--paths=@<file>|<p1,p2,…> | --units=all) [--quiet]
#
# stdout: ONE JSON line {schema, lane, changed, affected[], rebound, conflicts, oq,
#         text_pending, gate} — pointers for the controller (it dispatches nothing).
# Exit 0 = nothing affected (in_sync for this hop) · 4 = re-bound (read `gate`) ·
#      2 = usage / unreadable input · 3 = a writer or the validator failed (fail-closed:
#          treat as "full JIT re-bind required", never as in-sync).
set -u
CWD="."; VAULT=""; PATHS=""; UNITS=""; QUIET=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --paths=*) PATHS="${arg#*=}" ;;
  --units=*) UNITS="${arg#*=}" ;; --quiet) QUIET=1 ;;
  *) echo "usage: rebind-units.sh --cwd=<root> --vault=<vault> (--paths=@<file>|<list> | --units=all) [--quiet]" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT/units" ] || { echo "usage: --vault=<dir with units/> required" >&2; exit 2; }
[ -n "$PATHS" ] || [ "$UNITS" = "all" ] || { echo "usage: --paths=@<file>|<list> or --units=all required" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

AFFECTED="$(V_CWD="$CWD" V_VAULT="$VAULT" V_PATHS="$PATHS" V_UNITS="$UNITS" python3 <<'PYEOF'
import glob, json, os, re, sys
cwd = os.path.abspath(os.environ["V_CWD"]); vault = os.environ["V_VAULT"]
raw = os.environ["V_PATHS"]; all_units = os.environ["V_UNITS"] == "all"

def norm(p):
    p = str(p).strip().strip("'\"").replace("\\", "/")
    if not p: return None
    if os.path.isabs(p):
        rel = os.path.relpath(p, cwd).replace("\\", "/")
        if rel == ".." or rel.startswith("../"): return None
        p = rel
    while p.startswith("./"): p = p[2:]
    return p.rstrip("/") or None

changed = set()
if raw:
    if raw.startswith("@"):
        try:
            with open(raw[1:], encoding="utf-8") as f: entries = f.read().splitlines()
        except OSError as e:
            print("cannot read paths file %s (%s)" % (raw[1:], e), file=sys.stderr); sys.exit(2)
    else:
        entries = raw.split(",")
    changed = {q for q in (norm(e) for e in entries) if q}

ANCHOR_RE = re.compile(r'(?<![\w:/])((?:(?:[\w.\-]+|\([\w.\-]+\)|\[[\w.\-]+\]|@[\w.\-]+)/)*[\w.\-]+\.[A-Za-z]\w{0,7})(?::\d+(?:-\d+)?)?\b')

def intersects(p, changed):
    if p in changed: return True
    for c in changed:
        if c.startswith(p + "/") or p.startswith(c + "/"): return True
    return False

units = {}
for uf in sorted(glob.glob(os.path.join(vault, "units", "U-*.md")) + glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))):
    uid = os.path.basename(uf)[:-3] if os.path.basename(uf).startswith("U-") else os.path.basename(os.path.dirname(uf))
    try: txt = open(uf, encoding="utf-8", errors="replace").read()
    except OSError: continue
    paths = set()
    m = re.match(r"\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\Z)", txt, re.S)
    fm = m.group(1) if m else ""
    for pm in re.finditer(r"(?m)^\s+-?\s*(?:path|file)\s*:\s*(.+?)\s*$", fm):
        p = norm(pm.group(1))
        if p: paths.add(p)
    sec = re.search(r"(?ims)^##[ \t]+Anchors\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", txt)
    if sec:
        for am in ANCHOR_RE.finditer(sec.group(1)):
            p = norm(am.group(1))
            if p: paths.add(p)
    bj = os.path.join(vault, "bolts", uid, "binding.json")
    if os.path.isfile(bj):
        try:
            for c in json.load(open(bj, encoding="utf-8")).get("claims", []):
                anc = c.get("anchor")
                if not anc or anc in ("—", "n/a"): continue
                for piece in re.split(r"\s*\+\s*", str(anc)):
                    piece = piece.strip()
                    if "/" in piece or ":" in piece or re.search(r"\.[A-Za-z0-9]+$", piece):
                        p = norm(re.sub(r":\d+(-\d+)?$", "", piece))
                        if p and "/" in p: paths.add(p)
        except (OSError, ValueError):
            print("unreadable bolts/%s/binding.json — fail-closed" % uid, file=sys.stderr); sys.exit(2)
    units[uid] = paths

affected = sorted(u for u, ps in units.items() if all_units or any(intersects(p, changed) for p in ps))
print(json.dumps({"changed": sorted(changed), "affected": affected}))
PYEOF
)" || exit 2
AFF_LIST="$(printf '%s' "$AFFECTED" | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["affected"]))')"
if [ -z "$AFF_LIST" ]; then
  printf '%s' "$AFFECTED" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({"schema":"rebind-units/1","lane":"lite","changed":len(d["changed"]),"affected":[],"rebound":0,"conflicts":0,"oq":0,"text_pending":0,"gate":"in_sync"}))'
  exit 0
fi
bash "$SCRIPT_DIR/derive-unit-claims.sh" --cwd="$CWD" --vault="$VAULT" --units="$AFF_LIST" >/dev/null 2>&1 || { echo "rebind-units: derive-unit-claims failed for $AFF_LIST — full JIT re-bind required" >&2; exit 3; }
CLAIMS="$VAULT/bolts/_wave-claims.json"
IFS=',' read -r -a UARR <<< "$AFF_LIST"
for u in "${UARR[@]}"; do
  bash "$SCRIPT_DIR/write-unit-binding.sh" --cwd="$CWD" --vault="$VAULT" --unit="$u" --claims="$CLAIMS" >/dev/null 2>&1 \
    || { echo "rebind-units: write-unit-binding failed for $u — full JIT re-bind required" >&2; exit 3; }
done
bash "$SCRIPT_DIR/validate-handoff-binding-units.sh" --cwd="$CWD" --units="$AFF_LIST" --quiet >/dev/null 2>&1; VRC=$?
V_VAULT="$VAULT" V_AFF="$AFF_LIST" V_CWD="$CWD" V_VRC="$VRC" V_CH="$AFFECTED" python3 <<'PYEOF'
import json, os
vault = os.environ["V_VAULT"]; aff = os.environ["V_AFF"].split(","); cwd = os.path.abspath(os.environ["V_CWD"])
conf = oq = txt = 0
for u in aff:
    try: d = json.load(open(os.path.join(vault, "bolts", u, "binding.json"), encoding="utf-8"))
    except (OSError, ValueError): continue
    for c in d.get("claims", []):
        if c.get("verdict") == "CONFLICT" and not c.get("resolution"): conf += 1
        if c.get("verdict") == "OQ":
            oq += 1
            if c.get("kind") == "text": txt += 1
gate = "unknown"
try:
    s = json.load(open(os.path.join(cwd, ".mega-sdd", ".validation-blockers.json"), encoding="utf-8"))
    gate = s.get("status", "unknown")
except (OSError, ValueError):
    gate = "unknown"
changed = json.loads(os.environ["V_CH"])["changed"]
print(json.dumps({"schema": "rebind-units/1", "lane": "lite", "changed": len(changed), "affected": aff,
                  "rebound": len(aff), "conflicts": conf, "oq": oq, "text_pending": txt, "gate": gate,
                  "validator_rc": int(os.environ["V_VRC"]),
                  "next": ("run ladder E3 for %d text claim(s) and re-run write-unit-binding --verdicts" % txt) if txt else
                          ("resolve %d CONFLICT(s) via resolve-oq --binding" % conf if conf else "dependents of the affected units are re-verdicted; proceed")}))
PYEOF
exit 4
