#!/usr/bin/env bash
# derive-unit-claims.sh — JIT bind step 1 (v8 P1, spec 2026-09-10 Appendix F2):
# the claim set of ONE WAVE of units, derived deterministically from the unit
# files themselves — never from the vault, never from a model.
#
#   derive-unit-claims.sh --cwd=<root> --vault=<vault-dir> --units=U-001,U-002[,…] | --units=all
#   (`all` = every unit under <vault>/units — the `sync --full-bind` sweep, 7.34.0)
#
# Per unit, claims are minted from:
#   target_files          create        → fs_must_not_exist (the path must be absent)
#                         modify|delete → fs_must_exist
#   ## Anchors            `path:line[-line]`   → fs_must_exist (+ line range check)
#   existing_interfaces   file + symbol → symbol (symbol index lookup, P1.b writer)
#   ## Claims             `- C-U<NNN>-<NN> "<text>" — expect: <path>[:<sym>] | <path> — must-exist | <path> — must-not-exist`
#                         → fs_* / symbol / text (text = ladder E3, express-bind.md — model)
# Output: <vault>/bolts/_wave-claims.json (one stable file, overwritten per wave; head inside)
#   {schema:"unit-claims/1", head, generated_by, units[], claims[{id, unit, kind, expect, source, text?}]}
# stdout: ONE JSON line {"jit_bind":{"units":N,"fs_claims":F,"symbol_claims":S,"text_claims":T,"out":path}}
#   — greenfield / create-only ⇒ symbol_claims=text_claims=0 ⇒ the wave needs ZERO model tokens.
# Exit 0 written · 2 usage / unit file not found (nothing written).
set -u
CWD="."; VAULT=""; UNITS=""
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --units=*) UNITS="${arg#*=}" ;;
  *) echo "usage: derive-unit-claims.sh --cwd=<root> --vault=<vault> --units=U-001,…" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT" ] && [ -n "$UNITS" ] || { echo "usage: --vault=<existing dir> --units=U-001,… required" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEAD8="$(git -C "$CWD" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)"
V_CWD="$CWD" V_VAULT="$VAULT" V_UNITS="$UNITS" V_HEAD="$HEAD8" V_LIB="$SCRIPT_DIR/_lib" python3 <<'PYEOF'
import glob, json, os, re, sys
from datetime import datetime, timezone
cwd = os.path.abspath(os.environ["V_CWD"]); vault = os.environ["V_VAULT"]
units = [u.strip() for u in os.environ["V_UNITS"].split(",") if u.strip()]
if units == ["all"]:  # sync --full-bind (7.34.0): the whole vault, sorted, both unit layouts
    units = sorted({os.path.basename(p)[:-3] for p in glob.glob(os.path.join(vault, "units", "U-*.md"))}
                   | {os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))})
    if not units:
        print("FAIL: --units=all but no units under %s/units" % vault, file=sys.stderr); sys.exit(2)
head = os.environ["V_HEAD"]
sys.path.insert(0, os.environ["V_LIB"])
try:
    from plugin_meta import plugin_version as _pv
    GEN = "derive-unit-claims.sh@%s" % _pv()
except Exception:
    GEN = "derive-unit-claims.sh"

CLAIM_RE = re.compile(r'^-\s+(C-U[\w-]+)\s+"(.+?)"\s+—\s+expect:\s+(.+?)\s*$')
ANCHOR_RE = re.compile(r'((?:[\w.\-]+/)*[\w.\-]+\.[A-Za-z]\w{0,7}):(\d+)(?:-(\d+))?\b')

def unit_file(uid):
    for pat in (os.path.join(vault, "units", uid + ".md"), os.path.join(vault, "units", uid, "unit.md")):
        g = sorted(glob.glob(pat))
        if g: return g[0]
    return None

def section(body, name):
    m = re.search(r"(?ms)^##\s+%s\b[^\n]*\n(.*?)(?=^##\s|\Z)" % re.escape(name), body)
    return m.group(1) if m else ""

def fm_block(text):
    m = re.match(r"^---\n(.*?)\n---\n?", text, re.S)
    return (m.group(1), text[m.end():]) if m else ("", text)

def parse_targets(fm):
    out = []
    m = re.search(r"(?ms)^target_files:\s*\n((?:[ \t]+.*\n?)*)", fm)
    if not m: return out
    cur = None
    for ln in m.group(1).splitlines():
        pm = re.match(r"\s*-\s*path:\s*(\S+)", ln); om = re.match(r"\s*operation:\s*(\w+)", ln)
        if pm: cur = {"path": pm.group(1).strip("'\""), "operation": "create"}; out.append(cur)
        elif om and cur: cur["operation"] = om.group(1).lower()
    return out

def parse_interfaces(fm):
    out = []
    m = re.search(r"(?ms)^existing_interfaces:\s*\n((?:[ \t]+.*\n?)*)", fm)
    if not m: return out
    cur = None
    for ln in m.group(1).splitlines():
        fmx = re.match(r"\s*-\s*file:\s*(\S+)", ln); sm = re.match(r"\s*symbol:\s*(\S+)", ln)
        if fmx: cur = {"file": fmx.group(1).strip("'\""), "symbol": None}; out.append(cur)
        elif sm and cur: cur["symbol"] = sm.group(1).strip("'\"")
    return out

claims = []; counts = {"fs": 0, "symbol": 0, "text": 0}
def add(uid, kind, expect, source, cid=None, text=None):
    n = sum(1 for c in claims if c["unit"] == uid) + 1
    c = {"id": cid or "%s-A%02d" % (uid.replace("U-", "C-U"), n), "unit": uid, "kind": kind,
         "expect": expect, "source": source}
    if text: c["text"] = text
    claims.append(c)
    counts["fs" if kind.startswith("fs_") else ("symbol" if kind == "symbol" else "text")] += 1

for uid in units:
    uf = unit_file(uid)
    if not uf:
        print("FAIL: unit %s not found under %s/units" % (uid, vault), file=sys.stderr); sys.exit(2)
    text = open(uf, encoding="utf-8", errors="replace").read()
    fm, body = fm_block(text)
    rel = os.path.relpath(uf, cwd)
    for t in parse_targets(fm):
        kind = "fs_must_not_exist" if t["operation"] == "create" else ("fs_must_exist" if t["operation"] in ("modify", "delete") else None)
        if kind: add(uid, kind, t["path"], "%s:target_files" % rel)
    for a in ANCHOR_RE.finditer(section(body, "Anchors")):
        add(uid, "fs_must_exist", "%s:%s%s" % (a.group(1), a.group(2), ("-" + a.group(3)) if a.group(3) else ""), "%s:## Anchors" % rel)
    for i in parse_interfaces(fm):
        if i["symbol"]: add(uid, "symbol", "%s:%s" % (i["file"], i["symbol"]), "%s:existing_interfaces" % rel)
        else: add(uid, "fs_must_exist", i["file"], "%s:existing_interfaces" % rel)
    for ln in section(body, "Claims").splitlines():
        m = CLAIM_RE.match(ln.strip())
        if not m: continue
        cid, ctext, exp = m.group(1), m.group(2), m.group(3).strip()
        if exp.endswith("must-not-exist"): add(uid, "fs_must_not_exist", exp.split("—")[0].strip(), "%s:## Claims" % rel, cid, ctext)
        elif exp.endswith("must-exist"): add(uid, "fs_must_exist", exp.split("—")[0].strip(), "%s:## Claims" % rel, cid, ctext)
        elif re.match(r"^[^\s:]+:[A-Za-z_]\w*$", exp): add(uid, "symbol", exp, "%s:## Claims" % rel, cid, ctext)
        else: add(uid, "text", exp, "%s:## Claims" % rel, cid, ctext)

# ONE stable file per vault, overwritten per wave (v8 P1 debt #5, 2026-09-10): the
# head is recorded INSIDE the doc; a per-head directory accumulated one
# claims.json per commit and was never cleaned. Convention = bolts/_batch-suite.json.
out_dir = os.path.join(vault, "bolts"); os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, "_wave-claims.json")
doc = {"schema": "unit-claims/1", "head": head, "generated_by": GEN,
       "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"), "units": units, "claims": claims}
tmp = out + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as f: json.dump(doc, f, indent=1, ensure_ascii=False)
os.replace(tmp, out)
print(json.dumps({"jit_bind": {"units": len(units), "fs_claims": counts["fs"], "symbol_claims": counts["symbol"],
                               "text_claims": counts["text"], "out": os.path.relpath(out, cwd)}}))
PYEOF
