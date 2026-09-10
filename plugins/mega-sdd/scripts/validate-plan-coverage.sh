#!/usr/bin/env bash
# validate-plan-coverage.sh — v8 P1.d (spec 2026-09-10 Appendix F5): the ONLY
# mechanical rail for the PRD→units prose gap. Census of the PRD's requirement
# anchors vs the union of every unit's `prd_source` (+ OQs that cite the heading,
# + headings under an explicit out-of-scope section) → `plan_coverage_gap`.
#
#   validate-plan-coverage.sh --cwd=<root> --prd=<prd.md> --vault=<vault-dir> [--quiet]
#
# Requirement anchors (deterministic, document structure only — same class as
# derive-project-scale.sh): every H2/H3 heading EXCEPT meta sections (background,
# goals, scope, sources, data model, NFR, open questions, glossary, changelog,
# version) and everything under an out-of-scope section; plus every `F-<X>-<NNN>`
# id found in a heading. Covered when some unit's prd_source names the heading
# slug (or a :line inside that heading's range), or a vault OQ (vault.json
# open_questions[].text) quotes the heading text.
# Output: <root>/.mega-sdd/.plan-coverage-state.json {status, prd, anchors, covered, gaps[], next_action}
# Exit 0 PASS · 1 FAIL (≥1 gap) · 2 usage/unreadable.
set -u
CWD="."; PRD=""; VAULT=""; QUIET=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --prd=*) PRD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --quiet) QUIET=1 ;;
  *) echo "usage: validate-plan-coverage.sh --cwd=<root> --prd=<prd.md> --vault=<vault> [--quiet]" >&2; exit 2 ;;
esac; done
[ -f "$PRD" ] && [ -d "$VAULT" ] || { echo "usage: --prd=<existing file> --vault=<existing dir> required" >&2; exit 2; }
V_CWD="$CWD" V_PRD="$PRD" V_VAULT="$VAULT" V_QUIET="$QUIET" python3 <<'PYEOF'
import glob, json, os, re, sys
from datetime import datetime, timezone
E = os.environ; cwd = os.path.abspath(E["V_CWD"]); prd = E["V_PRD"]; vault = E["V_VAULT"]
META = re.compile(r"(?i)^(latar|background|tujuan|goal|ruang lingkup|scope|sumber|source|data model|model data|dbml|non.?functional|nfr|open question|pertanyaan terbuka|glossary|glosarium|changelog|riwayat|versi|version|out of scope|di luar lingkup|tidak termasuk)")
OOS = re.compile(r"(?i)^(out of scope|di luar lingkup|tidak termasuk)")
def slug(s): return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.strip().lower())).strip("-")

lines = open(prd, encoding="utf-8", errors="replace").read().splitlines()
heads = []  # (level, text, line_no)
for i, ln in enumerate(lines, 1):
    m = re.match(r"^(#{2,3})[ \t]+(.+?)\s*$", ln)
    if m: heads.append((len(m.group(1)), m.group(2), i))
anchors = []; in_oos = False; oos_level = 9
for k, (lvl, text, ln) in enumerate(heads):
    if in_oos and lvl > oos_level: continue
    in_oos = False
    if OOS.match(text): in_oos, oos_level = True, lvl; continue
    if META.match(text): continue
    end = heads[k + 1][2] - 1 if k + 1 < len(heads) else len(lines)
    anchors.append({"heading": text, "slug": slug(text), "line": ln, "end": end,
                    "f_id": (re.search(r"\b(F-[A-Z]+-\d+)\b", text) or [None, None])[1]})
prd_rel = os.path.relpath(os.path.abspath(prd), cwd).replace("\\", "/")

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
    oq_texts = [str(o.get("text", "")).lower() for o in vj.get("open_questions", [])]
except Exception:
    pass

covered, gaps = [], []
for a in anchors:
    by = None
    for r in refs:
        m = re.match(r"^(.+?\.md)(?:#([^\s]+)|:(\d+))$", r)
        if not m: continue
        f = m.group(1).replace("\\", "/").lstrip("./")
        if not (prd_rel.endswith(f) or f.endswith(prd_rel) or os.path.basename(f) == os.path.basename(prd_rel)): continue
        if m.group(2) and slug(m.group(2)) == a["slug"]: by = "unit prd_source %s" % r; break
        if m.group(3) and a["line"] <= int(m.group(3)) <= a["end"]: by = "unit prd_source %s" % r; break
    if not by and a["f_id"]:
        if any(a["f_id"].lower() in r.lower() for r in refs): by = "unit prd_source (F-id)"
    if not by and any(a["heading"].lower() in t for t in oq_texts): by = "open question cites heading"
    (covered if by else gaps).append({**a, "covered_by": by} if by else a)

status = "PASS" if not gaps else "FAIL"
state = {"ts": datetime.now(timezone.utc).isoformat(timespec="seconds"), "validator": "validate-plan-coverage.sh",
         "status": status, "prd": prd_rel, "anchors": len(anchors), "covered": len(covered), "units_prd_refs": len(refs),
         "gaps": [{"heading": g["heading"], "slug": g["slug"], "line": g["line"], "halt_type": "plan_coverage_gap"} for g in gaps],
         "covered_detail": covered,
         "next_action": ("Every PRD requirement anchor has an owning unit or an open question." if not gaps else
                         "%d PRD requirement heading(s) have NO unit prd_source and NO open question citing them (plan_coverage_gap) — a requirement no unit will ever verify. Add a unit with prd_source, raise an OQ quoting the heading, or move it under an explicit 'Out of scope' section." % len(gaps))}
md = os.path.join(cwd, ".mega-sdd"); os.makedirs(md, exist_ok=True)
out = os.path.join(md, ".plan-coverage-state.json"); tmp = out + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as f: json.dump(state, f, indent=1, ensure_ascii=False)
os.replace(tmp, out)
if E["V_QUIET"] != "1": print(json.dumps(state, indent=1, ensure_ascii=False))
sys.exit(0 if status == "PASS" else 1)
PYEOF
