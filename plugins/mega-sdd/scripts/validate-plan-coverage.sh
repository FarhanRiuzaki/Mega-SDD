#!/usr/bin/env bash
# validate-plan-coverage.sh — v8 P1.d (spec 2026-09-10 Appendix F5): the ONLY
# mechanical rail for the PRD→units prose gap. Census of the PRD's requirement
# anchors vs the union of every unit's `prd_source` (+ OQs that cite the heading,
# + headings under an explicit out-of-scope section) → `plan_coverage_gap`.
#
#   validate-plan-coverage.sh --cwd=<root> (--prd=<prd.md> | --kb=<kb-dir>) --vault=<vault-dir> [--quiet]
#
# Requirement anchors (deterministic, document structure only — same class as
# derive-project-scale.sh): every H2/H3 heading EXCEPT meta sections (background,
# goals, scope, sources, data model, NFR, open questions, glossary, changelog,
# version) and everything under an out-of-scope section; plus every `F-<X>-<NNN>`
# id found in a heading. Covered when some unit's prd_source names the heading
# slug (or a :line inside that heading's range), or a vault OQ (vault.json
# open_questions[].text) quotes the heading text.
# --kb (plan --kb, an extract-intelligence KB is the source): the same census over
# EVERY <kb>/modules/*.prd.md — the PRD-kontrak meta sections `1. Purpose` and
# `6. Open Questions` excluded (a leading section number is ignored when matching
# meta names). A unit covers a module heading when its prd_source names that
# module file + the heading slug (<kb>/modules/<m>.prd.md#<slug>) or a :line in
# its range; an OQ covers it only when it quotes the heading AND names the module
# file (<m>.prd.md) — every module carries the same section names. Each gap
# names its module file. A legacy numbered-tree KB (no modules/) is censused over
# its <kb>/10-domains/**/*.md instead (meta: `1. Purpose`, `10. Open Questions`,
# `11. Source References`).
# Output: <root>/.mega-sdd/.plan-coverage-state.json {status, prd, sources[], anchors, covered, gaps[], next_action}
# Exit 0 PASS · 1 FAIL (≥1 gap) · 2 usage/unreadable.
set -u
CWD="."; PRD=""; KB=""; VAULT=""; QUIET=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --prd=*) PRD="${arg#*=}" ;; --kb=*) KB="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --quiet) QUIET=1 ;;
  *) echo "usage: validate-plan-coverage.sh --cwd=<root> (--prd=<prd.md> | --kb=<kb-dir>) --vault=<vault> [--quiet]" >&2; exit 2 ;;
esac; done
if [ -n "$KB" ]; then
  [ -z "$PRD" ] && [ -f "$KB/README.md" ] && [ -d "$VAULT" ] \
    || { echo "usage: --kb=<dir with README.md> (not with --prd) --vault=<existing dir> required" >&2; exit 2; }
else
  [ -f "$PRD" ] && [ -d "$VAULT" ] || { echo "usage: --prd=<existing file> --vault=<existing dir> required" >&2; exit 2; }
fi
V_CWD="$CWD" V_PRD="$PRD" V_KB="$KB" V_VAULT="$VAULT" V_QUIET="$QUIET" python3 <<'PYEOF'
import glob, json, os, re, sys
from datetime import datetime, timezone
E = os.environ; cwd = os.path.realpath(E["V_CWD"]); prd = E["V_PRD"]; kb = E["V_KB"]; vault = E["V_VAULT"]
META = re.compile(r"(?i)^(latar|background|tujuan|goal|ruang lingkup|scope|sumber|source|data model|model data|dbml|non.?functional|nfr|open question|pertanyaan terbuka|glossary|glosarium|changelog|riwayat|versi|version|out of scope|di luar lingkup|tidak termasuk)")
KB_META = re.compile(r"(?i)^(purpose|open question|source reference)")  # PRD-kontrak §1/§6; numbered tree §1/§10/§11
SECNUM = re.compile(r"^\d+(?:\.\d+)*\.?[ \t]+")
OOS = re.compile(r"(?i)^(out of scope|di luar lingkup|tidak termasuk)")
def slug(s): return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.strip().lower())).strip("-")
def rel(p):  # directories resolved (a symlinked tmp/home dir), the file itself not followed
    p = os.path.abspath(p)
    return os.path.relpath(os.path.join(os.path.realpath(os.path.dirname(p)), os.path.basename(p)), cwd).replace("\\", "/")

def census(path):
    """Requirement anchors of one source file (H2/H3 minus meta + out-of-scope)."""
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    heads = []  # (level, text, line_no)
    for i, ln in enumerate(lines, 1):
        m = re.match(r"^(#{2,3})[ \t]+(.+?)\s*$", ln)
        if m: heads.append((len(m.group(1)), m.group(2), i))
    out = []; in_oos = False; oos_level = 9
    for k, (lvl, text, ln) in enumerate(heads):
        name = SECNUM.sub("", text) if kb else text
        if in_oos and lvl > oos_level: continue
        in_oos = False
        if OOS.match(name): in_oos, oos_level = True, lvl; continue
        if (KB_META if kb else META).match(name): continue
        end = heads[k + 1][2] - 1 if k + 1 < len(heads) else len(lines)
        out.append({"heading": text, "slug": slug(text), "line": ln, "end": end, "file": rel(path),
                    "f_id": (re.search(r"\b(F-[A-Z]+-\d+)\b", text) or [None, None])[1]})
    return out

sources = [prd]
if kb:
    sources = sorted(glob.glob(os.path.join(kb, "modules", "*.prd.md"))) \
        or sorted(glob.glob(os.path.join(kb, "10-domains", "**", "*.md"), recursive=True))
    if not sources:
        print("usage: --kb=%s has no modules/*.prd.md (PRD-kontrak) and no 10-domains/*.md (numbered tree)" % kb, file=sys.stderr)
        sys.exit(2)
anchors = [a for src in sources for a in census(src)]
prd_rel = rel(os.path.join(kb, "README.md")) if kb else rel(prd)

# unit prd_source refs (scalar / flow list / block list)
refs = []
for uf in sorted(glob.glob(os.path.join(vault, "units", "U-*.md")) + glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))):
    t = open(uf, encoding="utf-8", errors="replace").read()
    fm = re.match(r"^---\n(.*?)\n---", t, re.S)
    if not fm: continue
    fm = fm.group(1)
    m = re.search(r"^prd_source:[ \t]*(.*)$", fm, re.M)
    if not m: continue
    head = m.group(1).strip()
    if head.startswith("["): refs += [x.strip().strip("'\"") for x in head.strip("[]").split(",") if x.strip()]
    elif head: refs.append(head.strip("'\""))
    else:
        for ln in fm[m.end():].splitlines():
            if re.match(r"^\s*-\s+", ln): refs.append(re.sub(r"^\s*-\s+", "", ln).strip().strip("'\""))
            elif ln.strip(): break
oq_texts = []
try:
    vj = json.load(open(os.path.join(vault, "vault.json"), encoding="utf-8"))
    # an OQ the AI already DECIDED (`resolved_by: ai`) is closed when this gate
    # runs — a PRD heading with no unit and only that decision citing it is a
    # gap, not coverage (a human answer keeps counting: no retro-effect)
    oq_texts = [str(o.get("text", "")).lower() for o in vj.get("open_questions", [])
                if isinstance(o, dict) and str(o.get("resolved_by") or "").lower() != "ai"]
except Exception:
    pass

covered, gaps = [], []
for a in anchors:
    by = None; src = a["file"]
    for r in refs:
        m = re.match(r"^(.+?\.md)(?:#([^\s]+)|:(\d+))$", r)
        if not m: continue
        f = m.group(1).replace("\\", "/").lstrip("./")
        if not (src.endswith(f) or f.endswith(src) or os.path.basename(f) == os.path.basename(src)): continue
        if m.group(2) and slug(m.group(2)) == a["slug"]: by = "unit prd_source %s" % r; break
        if m.group(3) and a["line"] <= int(m.group(3)) <= a["end"]: by = "unit prd_source %s" % r; break
    if not by and a["f_id"]:
        if any(a["f_id"].lower() in r.lower() for r in refs): by = "unit prd_source (F-id)"
    if not by and any(a["heading"].lower() in t and (not kb or os.path.basename(src).lower() in t) for t in oq_texts):
        by = "open question cites heading"
    (covered if by else gaps).append({**a, "covered_by": by} if by else a)

status = "PASS" if not gaps else "FAIL"
state = {"ts": datetime.now(timezone.utc).isoformat(timespec="seconds"), "validator": "validate-plan-coverage.sh",
         "status": status, "prd": prd_rel, "sources": [rel(x) for x in sources], "anchors": len(anchors), "covered": len(covered), "units_prd_refs": len(refs),
         "gaps": [{"heading": g["heading"], "slug": g["slug"], "line": g["line"], "file": g["file"], "halt_type": "plan_coverage_gap"} for g in gaps],
         "covered_detail": covered,
         "next_action": ("Every PRD requirement anchor has an owning unit or an open question." if not gaps else
                         "%d PRD requirement heading(s) have NO unit prd_source and NO open question citing them (plan_coverage_gap) — a requirement no unit will ever verify: %s. Add a unit with prd_source, raise an OQ quoting the heading, or move it under an explicit 'Out of scope' section." % (len(gaps), "; ".join("%s#%s" % (g["file"], g["slug"]) for g in gaps)))}
md = os.path.join(cwd, ".mega-sdd"); os.makedirs(md, exist_ok=True)
out = os.path.join(md, ".plan-coverage-state.json"); tmp = out + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as f: json.dump(state, f, indent=1, ensure_ascii=False)
os.replace(tmp, out)
if E["V_QUIET"] != "1": print(json.dumps(state, indent=1, ensure_ascii=False))
sys.exit(0 if status == "PASS" else 1)
PYEOF
