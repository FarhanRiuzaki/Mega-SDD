#!/usr/bin/env bash
# write-unit-binding.sh — SOLE writer of <vault>/bolts/U-XXX/binding.json (v8 P1,
# spec 2026-09-10 Appendix F3). The file is hook-guarded evidence (evidence-deny
# regex, like postflight/acceptance/findings): Write/Edit/Bash writes are denied,
# only this script produces or amends it — so a verdict can never be typed in.
#
#   write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --claims=<wave claims.json> [--verdicts=<json>]
#   write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --resolve=C-U005-01=KEEP_VAULT|KEEP_CODE|SPLIT --by=<who>
#
# Verdicts (fail-closed, never CONFIRMED-by-absence):
#   fs_must_exist      path exists (and line range fits when `:N[-M]`) → CONFIRMED/IMPLEMENTED · else CONFLICT
#   fs_must_not_exist  path absent → CONFIRMED/NEW · else CONFLICT (already exists)
#   symbol             symbol-index lookup: in the expected file → CONFIRMED/IMPLEMENTED (anchor file:line);
#                      only elsewhere → CONFLICT (collision; anchors listed); nowhere → OQ; index absent → OQ (reason)
#   text               OQ until `--verdicts` supplies the model ladder's verdict (express-bind.md §E3);
#                      a supplied CONFIRMED MUST carry an anchor, else the writer REFUSES (exit 3)
# Exit 0 written · 2 usage/input · 3 refused (illegal verdict, CONFIRMED without anchor, resolve on non-CONFLICT).
set -u
CWD="."; VAULT=""; UNIT=""; CLAIMS=""; VERDICTS=""; RESOLVE=""; BY=""
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --unit=*) UNIT="${arg#*=}" ;;
  --claims=*) CLAIMS="${arg#*=}" ;; --verdicts=*) VERDICTS="${arg#*=}" ;; --resolve=*) RESOLVE="${arg#*=}" ;; --by=*) BY="${arg#*=}" ;;
  *) echo "usage: write-unit-binding.sh --cwd --vault --unit=U-XXX (--claims=<json> [--verdicts=<json>] | --resolve=C-id=ACTION --by=<who>)" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT" ] && [ -n "$UNIT" ] || { echo "usage: --vault=<dir> --unit=U-XXX required" >&2; exit 2; }
if [ -z "$RESOLVE" ]; then [ -n "$CLAIMS" ] && [ -f "$CLAIMS" ] || { echo "usage: --claims=<wave claims.json> required (or --resolve)" >&2; exit 2; }; fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEAD8="$(git -C "$CWD" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)"
V_CWD="$CWD" V_VAULT="$VAULT" V_UNIT="$UNIT" V_CLAIMS="$CLAIMS" V_VERDICTS="$VERDICTS" V_RESOLVE="$RESOLVE" V_BY="$BY" V_HEAD="$HEAD8" V_LIB="$SCRIPT_DIR/_lib" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone
E = os.environ; cwd = os.path.abspath(E["V_CWD"]); vault = E["V_VAULT"]; unit = E["V_UNIT"]
sys.path.insert(0, E["V_LIB"])
try:
    from plugin_meta import plugin_version as _pv
    GEN = "write-unit-binding.sh@%s" % _pv()
except Exception:
    GEN = "write-unit-binding.sh"
ENUM = ("CONFIRMED", "CONFLICT", "OQ")
out_dir = os.path.join(vault, "bolts", unit); out = os.path.join(out_dir, "binding.json")

def refuse(msg):
    print("REFUSE: %s" % msg, file=sys.stderr); sys.exit(3)

def write(doc):
    os.makedirs(out_dir, exist_ok=True)
    tmp = out + ".tmp.%d" % os.getpid()
    with open(tmp, "w", encoding="utf-8") as f: json.dump(doc, f, indent=1, ensure_ascii=False)
    os.replace(tmp, out)

# ── resolve mode (resolve-oq --binding write-back) ────────────────────────────
if E["V_RESOLVE"]:
    m = re.match(r"^(C-[\w-]+)=(KEEP_VAULT|KEEP_CODE|SPLIT)$", E["V_RESOLVE"])
    if not m: refuse("--resolve must be C-id=KEEP_VAULT|KEEP_CODE|SPLIT")
    if not E["V_BY"]: refuse("--by=<who> required for a resolution")
    if not os.path.isfile(out): refuse("no binding.json for %s yet" % unit)
    doc = json.load(open(out, encoding="utf-8"))
    hit = [c for c in doc["claims"] if c["id"] == m.group(1)]
    if not hit: refuse("claim %s not in %s" % (m.group(1), out))
    if hit[0]["verdict"] != "CONFLICT": refuse("claim %s is %s, not CONFLICT — nothing to resolve" % (m.group(1), hit[0]["verdict"]))
    hit[0]["resolution"] = {"action": m.group(2), "by": E["V_BY"], "at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    doc["updated_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    write(doc)
    print(json.dumps({"unit": unit, "resolved": m.group(1), "action": m.group(2), "out": os.path.relpath(out, cwd)})); sys.exit(0)

# ── verdict mode ──────────────────────────────────────────────────────────────
wave = json.load(open(E["V_CLAIMS"], encoding="utf-8"))
mine = [c for c in wave.get("claims", []) if c.get("unit") == unit]
supplied = json.load(open(E["V_VERDICTS"], encoding="utf-8")) if E["V_VERDICTS"] else {}
idx_path = os.path.join(cwd, ".mega-sdd", "codebase", "symbol-index.json")
index = None
if os.path.isfile(idx_path):
    try: index = json.load(open(idx_path, encoding="utf-8")).get("symbols", [])
    except Exception: index = None

def fs_exists(expect):
    m = re.match(r"^(.+?):(\d+)(?:-(\d+))?$", expect)
    path = os.path.join(cwd, m.group(1) if m else expect)
    if not os.path.exists(path): return False, "absent"
    if m and os.path.isfile(path):
        n = sum(1 for _ in open(path, encoding="utf-8", errors="replace"))
        hi = int(m.group(3) or m.group(2))
        if hi > n: return False, "line %d beyond EOF (%d lines)" % (hi, n)
    return True, "present"

def norm(p): return p.replace("\\", "/").lstrip("./")

verdicts = []
for c in mine:
    v = {"id": c["id"], "kind": c["kind"], "expect": c["expect"], "source": c["source"],
         "verdict": None, "state": None, "anchor": None, "confidence": None, "evidence": None}
    if c.get("text"): v["text"] = c["text"]
    k = c["kind"]
    if k == "fs_must_exist":
        ok, why = fs_exists(c["expect"])
        v.update(verdict="CONFIRMED" if ok else "CONFLICT", state="IMPLEMENTED" if ok else "MISSING",
                 anchor=c["expect"] if ok else None, confidence="high", evidence="fs: %s" % why)
    elif k == "fs_must_not_exist":
        ok, why = fs_exists(c["expect"])
        v.update(verdict="CONFLICT" if ok else "CONFIRMED", state="ALREADY_EXISTS" if ok else "NEW",
                 anchor=c["expect"] if ok else None, confidence="high", evidence="fs: %s" % why)
    elif k == "symbol":
        f, sym = c["expect"].rsplit(":", 1)
        if index is None:
            v.update(verdict="OQ", state="UNKNOWN", confidence="low", evidence="symbol-index.json absent — run scripts/build-symbol-index.sh")
        else:
            hits = [s for s in index if s.get("name") == sym]
            here = [s for s in hits if norm(s.get("file", "")).endswith(norm(f))]
            if here:
                v.update(verdict="CONFIRMED", state="IMPLEMENTED", anchor="%s:%s" % (here[0]["file"], here[0].get("line", "?")),
                         confidence="high", evidence="index: %d hit(s) in expected file" % len(here))
            elif hits:
                v.update(verdict="CONFLICT", state="COLLISION", anchor=" + ".join("%s:%s" % (s["file"], s.get("line", "?")) for s in hits[:5]),
                         confidence="high", evidence="index: symbol lives elsewhere (%d hit(s)), not in %s" % (len(hits), f))
            else:
                v.update(verdict="OQ", state="UNKNOWN", confidence="medium", evidence="index: symbol not found anywhere")
    else:  # text — model ladder result, or OQ
        s = supplied.get(c["id"])
        if s:
            if s.get("verdict") not in ENUM: refuse("claim %s: verdict %r not in %s" % (c["id"], s.get("verdict"), ENUM))
            if s["verdict"] == "CONFIRMED" and not s.get("anchor"): refuse("claim %s: CONFIRMED without an anchor is CONFIRMED-by-absence" % c["id"])
            v.update(verdict=s["verdict"], state=s.get("state") or ("IMPLEMENTED" if s["verdict"] == "CONFIRMED" else "UNKNOWN"),
                     anchor=s.get("anchor"), confidence=s.get("confidence") or "medium", evidence=s.get("evidence") or "model ladder (express-bind §E3)")
        else:
            v.update(verdict="OQ", state="UNKNOWN", confidence="low", evidence="text claim: awaiting ladder E3 verdict (--verdicts)")
    verdicts.append(v)

doc = {"schema": "unit-binding/1", "generated_by": GEN, "head": E["V_HEAD"], "unit": unit,
       "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
       "summary": {k: sum(1 for x in verdicts if x["verdict"] == k) for k in ENUM}, "claims": verdicts}
write(doc)
print(json.dumps({"unit": unit, "claims": len(verdicts), **doc["summary"], "out": os.path.relpath(out, cwd)}))
PYEOF
