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
# EVERY <kb>/modules/*.prd.md (numbered-tree KB, no modules/: <kb>/10-domains/**/*.md).
# A unit covers a module heading when its prd_source names that file + the heading
# slug (<kb>/modules/<m>.prd.md#<slug>) or a :line in its range; an OQ covers it only
# when it quotes the heading AND names the file (<m>.prd.md) — every module carries
# the same section names. Each gap names its file. The --kb census is FAIL-CLOSED:
# whole-heading matches, never a prefix (V7: prefixes dropped [LOCKED] headings such
# as 'Purpose code validation', 'Source reference number format', 'Tidak termasuk
# biaya admin …' and every heading nested under the last one).
#  * meta = an H2 that IS a template meta section: its template number + a known
#    EN/ID name, or a bilingual 'EN (ID)' / 'EN / ID' pair (prd-kontrak-template.md:
#    `1. Purpose|Tujuan`, `6. Open Questions|Pertanyaan Terbuka`; numbered tree: `1.`,
#    `10.` and `11. Source References|Referensi Sumber`). H3s/other numbers: censused.
#  * out of scope = a heading whose WHOLE name (number optional) is Out of scope /
#    Out-of-scope / Di luar lingkup / Tidak termasuk; it + deeper headings skipped.
#  * fenced code is skipped; a fence with no closer, holding another info-string
#    opener (a forgotten closer) or spanning a numbered H2 (a section boundary — a
#    quoted '## 1. …' banner is then censused) is not a fence: no section is hidden.
# PRD mode (--prd) keeps its META/OOS prefix census unchanged.
# KNOWN LIMIT (both modes): coverage is per HEADING, not per rule — one unit citing
# `<m>.prd.md#2-business-rules` covers every BR row there, [LOCKED] ones included,
# and identical headings in one file share a slug. Per-rule needs a BR-id census.
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
# PRD mode (--prd) — prefix census, unchanged
META = re.compile(r"(?i)^(latar|background|tujuan|goal|ruang lingkup|scope|sumber|source|data model|model data|dbml|non.?functional|nfr|open question|pertanyaan terbuka|glossary|glosarium|changelog|riwayat|versi|version|out of scope|di luar lingkup|tidak termasuk)")
OOS = re.compile(r"(?i)^(out of scope|di luar lingkup|tidak termasuk)")
# --kb mode — whole-heading matches against the template (see header)
_OQ = ("open questions", "open question", "pertanyaan terbuka")
KB_META = {"prd-kontrak": {"1": ("purpose", "tujuan"), "6": _OQ}, "numbered-tree": {"1": ("purpose", "tujuan"), "10": _OQ,
           "11": ("source references", "source reference", "referensi sumber", "sumber referensi")}}
KB_OOS = ("out of scope", "out-of-scope", "di luar lingkup", "tidak termasuk")
KB_SECNAME = re.compile(r"^(\d+(?:\.\d+)*)\.?[ \t]+(.*)$")
FENCE_OPEN = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
def slug(s): return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s.strip().lower())).strip("-")
def rel(p):  # directories resolved (a symlinked tmp/home dir), the file itself not followed
    p = os.path.abspath(p)
    return os.path.relpath(os.path.join(os.path.realpath(os.path.dirname(p)), os.path.basename(p)), cwd).replace("\\", "/")

def kb_split(text):  # → (section number or None, normalised whole name)
    t = re.sub(r"[ \t]+#+[ \t]*$", "", text); m = KB_SECNAME.match(t)  # closing '#' run dropped
    num = m and (str(int(m.group(1))) if m.group(1).isdigit() else m.group(1))
    return num, re.sub(r"\s+", " ", m.group(2) if m else t).strip().rstrip(":").strip().lower()

def kb_name_is(name, names):  # the whole name, or a bilingual pair of two names of that section
    parts = [p for p in re.split(r"\s*[/()]\s*", name) if p]
    return name in names or (len(parts) == 2 and all(p in names for p in parts))

def fenced_lines(lines):
    """1-based numbers of the lines of CLOSED fences (opener..closer); fail-closed —
    no closer, another same-char info-string opener first, or a numbered H2 (a template
    section boundary; the census gate greps '## N.' fence-blind) inside = not a fence."""
    skip, i = set(), 0
    while i < len(lines):
        m = FENCE_OPEN.match(lines[i])
        if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):  # a ``` info string holds no backtick
            c, w = re.escape(m.group(1)[0]), len(m.group(1))
            for j in range(i + 1, len(lines)):
                if re.match(r" {0,3}%s{%d,}[ \t]*$" % (c, w), lines[j]): skip.update(range(i + 1, j + 2)); i = j; break
                if re.match(r" {0,3}%s{%d,}[ \t]*[^ \t%s]" % (c, w, c), lines[j]) or re.match(r"##[ \t]*\d+\.", lines[j]): break
        i += 1
    return skip

def census(path, grammar=None):
    """Requirement anchors of one source file (H2/H3 minus meta + out-of-scope)."""
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    fenced = fenced_lines(lines) if kb else set()  # PRD mode: unchanged (fences not skipped)
    heads = []  # (level, text, line_no)
    for i, ln in enumerate(lines, 1):
        if i in fenced: continue
        m = re.match(r"^(#{2,3})[ \t]+(.+?)\s*$", ln)
        if m: heads.append((len(m.group(1)), m.group(2), i))
    out = []; in_oos = False; oos_level = 9
    for k, (lvl, text, ln) in enumerate(heads):
        if in_oos and lvl > oos_level: continue
        in_oos = False; num, name = kb_split(text) if kb else (None, text)
        if (kb_name_is(name, KB_OOS) if kb else OOS.match(text)): in_oos, oos_level = True, lvl; continue
        if (lvl == 2 and kb_name_is(name, KB_META[grammar].get(num, ())) if kb else META.match(text)): continue
        end = heads[k + 1][2] - 1 if k + 1 < len(heads) else len(lines)
        out.append({"heading": text, "slug": slug(text), "line": ln, "end": end, "file": rel(path),
                    "f_id": (re.search(r"\b(F-[A-Z]+-\d+)\b", text) or [None, None])[1]})
    return out

sources = [prd]; grammar = None
if kb:
    sources = sorted(glob.glob(os.path.join(kb, "modules", "*.prd.md"))); grammar = "prd-kontrak"
    if not sources:
        sources = sorted(glob.glob(os.path.join(kb, "10-domains", "**", "*.md"), recursive=True)); grammar = "numbered-tree"
    if not sources:
        print("usage: --kb=%s has no modules/*.prd.md (PRD-kontrak) and no 10-domains/*.md (numbered tree)" % kb, file=sys.stderr)
        sys.exit(2)
anchors = [a for src in sources for a in census(src, grammar)]
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
