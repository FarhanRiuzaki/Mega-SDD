#!/usr/bin/env bash
# validate-plan-coverage.sh — the plan's spec-completeness gate (plan Step 5, halt `plan_coverage_gap`;
# validate-preflight.sh refuses execute-bolts until each plan-born vault has a fresh PASS here). DECLARED coverage:
# the gate never guesses what a heading means, it checks that a DECISION exists for every anchor.
#
#   validate-plan-coverage.sh --cwd=<root> (--prd=<file.md> [--prd=…] | --kb=<kb-dir>) --vault=<vault-dir> [--quiet]
#
# CENSUS (_lib/prd_headings.py census(), parser shared with validate-unit-spec.sh) of every --prd (--kb: every
# <kb>/modules/*.prd.md; a numbered-tree KB: <kb>/10-domains/**/*.md), parsed as CommonMark does. ANCHORS = every
# non-empty H1-H3 except a CONTAINER (no text of its own + sub-headings: its sub-headings, H4-H6 too, are censused in its
# place), plus "(text before the first heading)" when text precedes every heading. Unique slugs (x, x-1 …).
# An anchor is DECIDED by one of:
#  (a) a unit's prd_source `<file>#<slug | {#id} | html id | whole F-<X>-<NNN> id>` or `<file>:<line>` inside it (an H4+
#      heading inside it too); <file> relative to --cwd, exact case. A superseded unit covers nothing.
#  (b) an OQ of <vault>/context.md ## Open Questions carrying `[covers: <file>#<slug> | <file>:<line>, …]` (the anchor
#      waits on its answer) that is open, deferred, or [~] with `→ Out of Scope v<X>: <reason>`. Resolved (also a [ ]
#      line carrying → Resolved), fenced / commented, or merely quoting / §-citing the heading = no decision.
#  (c) a `- ` item of <vault>/context.md `## Coverage exclusions`, one per anchor:
#        - "<exact heading text>" — <reason>      ("…" “…” `…` '…'; separator — – - : →)
#        - <slug> — <reason>                      (separator — – → or ' - ')
#      optional `<file>#` prefix (REQUIRED under --kb; a basename unique among the sources suffices). Whole heading,
#      never a substring (case, quotes, dashes, markup, emoji, escapes, a trailing ?:!. folded). Per anchor: an H2 line
#      covers no H3. INVALID = FAIL naming the line: unparseable or ordered; a name two anchors share, a section number
#      aside ("Users" / "1. Users": use the slug); an empty / placeholder reason; a pending decision (that is an OQ).
#      Stale, redundant and near-miss lines are notes.
#  (d) --kb only: the module template's own meta sections — PRD-kontrak `## 1. Purpose|Tujuan`, `## 6. Open
#      Questions|Pertanyaan Terbuka`; numbered tree §1 / §10 / §11 (the extractor's grammar, not a guess).
# Everything else is a gap; zero anchors = FAIL. Exit 2 (usage): a --prd that is not markdown (plan writes a .md
# rendition of a .pdf/.docx/.txt PRD first), not in vault.json source_documents, or a run missing a source the vault
# pins (prd_headings.expected_sources: its PRD + delta seed-PRDs, or every KB module).
# KNOWN LIMITS: H4-H6 and bold pseudo-headings inside an anchor that has text belong to it; frontmatter at the top of a
# file is hidden. PARSER REFUSALS (notes; they hide nothing): a fence / comment that looks forgotten.
# Output: <root>/.mega-sdd/.plan-coverage-state.json — this run {run_status, anchors, covered, gaps[], excluded[],
#   oq_only[], notes[], next_action, paste[], summary, …} + vaults{<vault>: {status, digest, sources, …}}; `status` =
#   PASS only when every entry is a PASS. Exit 0 PASS · 1 FAIL · 2 usage. Replaced a heuristic classifier (9.0).
set -u
export PYTHONUTF8=1
CWD="."; PRD=""; KB=""; VAULT=""; QUIET=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --prd=*) PRD="$PRD${arg#*=}"$'\n' ;; --kb=*) KB="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --quiet) QUIET=1 ;;
  *) echo "usage: validate-plan-coverage.sh --cwd=<root> (--prd=<prd.md> … | --kb=<kb-dir>) --vault=<vault> [--quiet]" >&2; exit 2 ;;
esac; done
[ -d "$VAULT" ] || { echo "usage: --vault=<existing dir> required" >&2; exit 2; }
V_LIB="$(cd "$(dirname "$0")" && pwd)/_lib" V_CWD="$CWD" V_PRD="$PRD" V_KB="$KB" V_VAULT="$VAULT" V_QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone
E = os.environ; sys.path.insert(0, E["V_LIB"]); import prd_headings as ph
cwd = os.path.realpath(E["V_CWD"]); prds = [p for p in E["V_PRD"].split("\n") if p]; kb = E["V_KB"]; vault = E["V_VAULT"]
def rel(p): return ph.rel_path(os.path.abspath(p), cwd)
def usage(msg): print("usage: " + msg, file=sys.stderr); sys.exit(2)

# ── (d) --kb: the module template's own meta sections (whole heading, numbered H2) ──
_OQ = ("open questions", "open question", "pertanyaan terbuka")
KB_META = {"prd-kontrak": {"1": ("purpose", "tujuan"), "6": _OQ}, "numbered-tree": {"1": ("purpose", "tujuan"), "10": _OQ,
           "11": ("source references", "source reference", "referensi sumber", "sumber referensi")}}
def kb_template(text, grammar):  # '## 1. Purpose', '## 6. Pertanyaan Terbuka (Open Questions)' → True
    t = re.sub(r"[ \t]+#+[ \t]*$", "", text); m = re.match(r"^(\d+)\.?[ \t]+(.*)$", t)
    if not m: return False
    name = re.sub(r"\s+", " ", m.group(2)).strip().rstrip(":").strip().lower(); names = KB_META[grammar].get(str(int(m.group(1))), ())
    parts = [p for p in re.split(r"\s*[/()]\s*", name) if p]  # a bilingual pair of two names of that section
    return name in names or (len(parts) == 2 and all(p in names for p in parts))

grammar = None
if kb:
    if prds or not os.path.isfile(os.path.join(kb, "README.md")): usage("--kb=<dir with README.md> (not with --prd) required")
    sources, grammar = ph.kb_sources(kb)
    if not sources: usage("--kb=%s has no modules/*.prd.md (PRD-kontrak) and no 10-domains/*.md (numbered tree)" % kb)
else:
    if not prds or not all(os.path.isfile(p) for p in prds): usage("--prd=<existing file> required (repeat it per source)")
    for p in prds:
        if not p.lower().endswith(".md"):
            usage("--prd=%s is not markdown: write its .md rendition first (plan Step 0, .mega-sdd/sources/<name>.md) and pass that" % p)
    sources = prds
srcs = [rel(x) for x in sources]; prd_rel = rel(os.path.join(kb, "README.md")) if kb else srcs[0]
if not kb:  # a PASS for another document proves nothing about this vault
    try: sd = json.load(open(os.path.join(vault, "vault.json"), encoding="utf-8")).get("source_documents") or []
    except Exception: sd = []
    sd = [ph.rel_path(d["path"], cwd) for d in sd if isinstance(d, dict) and str(d.get("path", "")).lower().endswith(".md")]
    for s in srcs:
        if sd and s not in sd: usage("--prd=%s is not a source document of %s (vault.json source_documents: %s)" % (s, rel(vault), ", ".join(sd)))
miss = [x for x in ph.expected_sources(cwd, vault) or [] if x not in srcs]
if miss: usage("%s pins %s — the run must census every source it pins (--prd=<file> per source; a KB-born vault: --kb=<kb-dir>)" % (rel(vault), ", ".join(miss)))

# ── census ──
docs, anchors, template, containers, empties, refusal_notes, shadows = {}, [], [], [], [], [], []
for src in sources:
    d = ph.parse(src, rel(src)); docs[d["file"]] = d; an, cn = ph.census(d)
    refusal_notes += ["%s:%d (%s)" % (d["file"], x + 1, why) for x, why in d["refusals"]]
    shadows += ["%s:%d" % (d["file"], x + 1) for x in d["shadows"]]
    empties += ["%s:%d" % (d["file"], h["line"]) for h in d["heads"] if not h["heading"] and h["level"] <= 3]
    for h in an + cn: h["file"] = d["file"]
    containers += cn
    for h in an: (template if grammar and h["level"] == 2 and kb_template(h["heading"], grammar) else anchors).append(h)
AID, CID = {id(a) for a in anchors}, {id(c) for c in containers}

def source_of(f, decl=False):  # a ref's file → its parsed source (cwd-relative, exact case; a declaration: or a unique basename)
    f = f.strip().replace("\\", "/")
    if decl and "/" not in f:
        hit = [d for d in docs.values() if os.path.basename(d["file"]) == f]
        if len(hit) == 1: return hit[0]
    d = docs.get(ph.rel_path(f, cwd))
    return d if d and ph.exact_case(cwd, f) else None
def in_range(d, n): return [a for a in anchors if a["file"] == d["file"] and a["line"] <= n <= a["end"]]
def ref_targets(r):  # → (anchors decided, the heads when the fragment names 2+ headings, the source) of a <file>#… / :line ref
    m = ph.REF_RE.match(r.strip()); d = m and source_of(m.group(1))
    if not d: return [], None, None
    if m.group(3): return in_range(d, int(m.group(3))), None, d
    heads = ph.resolve_frag(d, m.group(2))
    if len(heads) > 1: return [], heads, d
    return [a for h in heads for a in ([h] if id(h) in AID else [] if id(h) in CID else in_range(d, h["line"]))], None, d
def aref(a): return "%s#%s" % (a["file"], a["slug"]) if a["slug"] else "%s:%d" % (a["file"], a["line"])

# ── (c) declaration grammar + reasons ──
DECL_Q = re.compile(r'^(?:"(.+?)"|“(.+?)”|`(.+?)`|\'(.+?)\'|‘(.+?)’)[ \t]*(?:—|–|:|-|→)[ \t]*(.*)$')  # a closer pairs with its opener
DECL_S = re.compile(r'^([^\s"“”`\'‘]+?)(?:[ \t]*[—–→][ \t]*|[ \t]+-[ \t]+)(.*)$')
PLACEHOLDER = re.compile(r"(?i)^(?:n/?a|none|nil|null|nothing|reason|alasan|x+|later|nanti|belum|belum ada|tidak ada|kosong|"
                         r"same|idem|ditto|see above|lihat atas|-+|\.+|…|\?+)$")
PLACEHOLDER_HEAD = re.compile(r"(?i)^(?:tbd|tbc|tba|todo|to do|pending|wip|placeholder|xxx|lorem)\b|^fill(?: in)?(?=\s*$|\s*[:—–(\[])")
PENDING = re.compile(r"(?i)\b(?:await(?:s|ing)?|menunggu|to be (?:confirmed|decided|defined|clarified|determined)|needs? (?:a )?"
                     r"(?:confirmation|decision|clarification)|perlu (?:di)?(?:konfirmasi|keputusan|putuskan|klarifikasi)|belum "
                     r"(?:diputuskan|dikonfirmasi|jelas|pasti|final)|unclear|undecided|not (?:yet )?(?:decided|confirmed)|ask (?:the )?"
                     r"(?:po|pm|business|stakeholders?|client)|tanya(?:kan)? (?:ke )?(?:po|pm|bisnis)|confirm with|konfirmasi "
                     r"(?:ke|dengan)|pending (?:review|decision|confirmation|approval|sign-?off))\b")
def bad_reason(r):  # → why a reason is none, else None
    r = re.sub(r"^[\s*_`()\[\]{}]+|[\s*_`()\[\]{}.]+$", "", r)
    if not re.search(r"\w", r): return "empty or placeholder reason (empty)"
    m = PLACEHOLDER.match(r) or PLACEHOLDER_HEAD.match(r) or re.search(r"<[A-Za-z][^<>\d=]{0,40}>|\{\{.*?\}\}", r)
    if m: return "empty or placeholder reason ('%s')" % (m.group(0).strip() or r)
    m = PENDING.search(r)
    return m and "a pending decision ('%s') is a [business] OQ carrying [covers: …], not an exclusion" % m.group(0)
def parse_decl(t):  # a list item's text → (file | None, quoted?, key, reason), else None
    fp = re.match(r"^([^\s\"“”`'‘#]+\.md)#", t); body = t[fp.end():] if fp else t
    m = DECL_Q.match(re.sub(r"^(\*\*|__|\*|_)([\"“`'‘].*?[\"”`'’])\1", r"\2", body))  # a bold / italic quoted key too
    if m: return (fp.group(1) if fp else None, True, next(g for g in m.groups()[:5] if g is not None), m.group(6))
    m = DECL_S.match(body)
    if m and m.group(1) == ph.slug(m.group(1)): return (fp.group(1) if fp else None, False, m.group(1), m.group(2))
    return None
def decl_targets(f, quoted, key):  # a quoted name also hits an anchor that bears it after a section number (ambiguity)
    fs = {d["file"] for d in ([source_of(f, True)] if f else docs.values()) if d}
    if not quoted: return [h for x in fs for h in ph.resolve_frag(docs[x], key) if id(h) in AID]
    k = ph.norm(key); exact = [a for a in anchors if a["file"] in fs and a["name"] == k]
    loose = [a for a in anchors if a["file"] in fs and a not in exact and ph.unnumbered(a["heading"]) == k]
    return exact + loose if exact and loose else exact

cov, amb_rows, unanchored, offsrc, oq_notes = {}, [], [], [], []
# (a) unit prd_source refs
units = ph.unit_refs(vault); refs = [(u, r) for u, rs, sup in units if not sup for r in rs]
for u, r in refs:
    hit, amb, d = ref_targets(r)
    if amb: amb_rows.append((u, r, amb))
    elif not d: offsrc.append("%s → %s" % (u, r))
    elif not hit: unanchored.append("%s → %s" % (u, r))
    for a in hit: cov.setdefault(id(a), ("unit", "unit prd_source %s" % r))
# (b) OQs carrying [covers: …]
for o in ph.read_oqs(vault):
    tag, st = str(o.get("tag") or "OQ"), str(o.get("status") or "open").lower()
    if not o.get("covers"): continue
    why = ("is resolved — its answer needs a unit or a declaration" if st not in ("open", "deferred", "out_of_scope") or o.get("resolved_by") == "ai"
           else "carries → Resolved but its box is not [x] (read as resolved)" if st != "out_of_scope" and o.get("resolution")
           else "is [~] with no real '→ Out of Scope v<X>: <reason>'" if st == "out_of_scope" and bad_reason(o.get("out_of_scope_reason") or "") else None)
    if why: oq_notes.append("%s %s" % (tag, why)); continue
    for r in o["covers"]:
        hit, amb, d = ref_targets(r)
        if not hit: oq_notes.append("%s [covers: %s] names %s" % (tag, r, "%d headings" % len(amb) if amb else "no anchor of this run")); continue
        for a in hit: cov.setdefault(id(a), ("oq", "open question %s" % tag, st))
# (c) declarations: <vault>/context.md `## Coverage exclusions`
ctx = os.path.join(vault, "context.md"); ctx_rel = rel(ctx)
try: ctx_text = open(ctx, encoding="utf-8", errors="replace").read()
except OSError: ctx_text = ""
sec_lines, near = ph.exclusion_lines(ctx_text)
decls, invalid, loose = [], [], []
for n, ln in sec_lines:
    if not ln.strip() or re.match(r"^ {0,3}(?:#{1,6}[ \t]|>)", ln): continue  # blank · H3+ · a quote
    lm, om = re.match(r"^( {0,3})[-*+][ \t]+(.*)$", ln), re.match(r"^ {0,3}\d{1,9}[.)][ \t]+(.*)$", ln)
    p = parse_decl((lm or om).group(lm.lastindex if lm else 1).strip()) if lm or om else None
    if not lm or (len(lm.group(1)) > 1 and not p):  # a wrapped line, prose or an indented sub-bullet: a note
        if om and p: invalid.append((n, ln, "an ordered item — use a '- ' bullet"))
        elif not re.match(r"^\s{2,}\S", ln) or lm: loose.append("%s:%d" % (ctx_rel, n))
        continue
    why = ("not a declaration (want: - \"<heading>\" — <reason>, or - <slug> — <reason>)" if not p else bad_reason(p[3])
           or ("--kb: name the module file (- <module>.prd.md#\"<heading>\" — <reason>)" if kb and not p[0] else None))
    tg = decl_targets(*p[:3]) if not why else []
    if len(tg) > 1: why = "ambiguous: %d headings named %s — use its unique slug (%s)" % (len(tg), p[2], ", ".join(aref(a) for a in tg))
    if why: invalid.append((n, ln, why)); continue
    decls.append({"line": n, "key": p[2], "reason": p[3].strip(), "hits": tg,
                  "hint": [a["heading"] for a in anchors if p[1] and not tg and ph.unnumbered(a["heading"]) == ph.norm(p[2])]})

covered, excluded, gaps, redundant, oq_only, decided = [], [], [], [], [], {}
for dl in decls:
    for a in dl["hits"]: decided.setdefault(id(a), dl)
for a in anchors:
    row = {k: a[k] for k in ("heading", "slug", "line", "end", "file")}; dl = decided.get(id(a)); c = cov.get(id(a))
    if c:
        covered.append(dict(row, covered_by=c[1]))
        if c[0] == "oq": oq_only.append(dict(row, oq=c[1].split()[-1], oq_status=c[2]))
        if dl: redundant.append("%s (%s:%d)" % (aref(a), ctx_rel, dl["line"]))
    elif dl: excluded.append(dict(row, by="declared", reason=dl["reason"], declared_at="%s:%d" % (ctx_rel, dl["line"])))
    else: gaps.append(row)
excluded += [dict({k: a[k] for k in ("heading", "slug", "line", "file")}, by="kb_template",
                  reason="KB module template section (meta by construction)") for a in template]

notes = []
for items, what in ((refusal_notes, "fence/comment block(s) NOT treated as code/comment — a forgotten closer is assumed, so their headings are censused (fix the markdown if the block was meant)"),
                    (shadows, "hidden fence/comment block(s) hold a heading + text — not censused; if that is a section, fix the markdown"),
                    (empties, "empty heading(s) skipped (CommonMark renders them empty)"),
                    (["%s#%s" % (c["file"], c["slug"]) for c in containers], "container heading(s) (no text of their own) — their sub-headings are censused instead"),
                    (["units/%s" % u.split("units/", 1)[-1] for u, rs, sup in units if sup], "superseded unit(s) cover nothing (execute-bolts skips them)"),
                    (unanchored, "unit prd_source ref(s) name no anchor (a container, a KB template section, a line outside every anchor)"),
                    (offsrc, "unit prd_source ref(s) name no source of this run (another document, a path whose case differs, not <file>.md#…)"),
                    (oq_notes, "open question(s) with [covers: …] decide nothing"),
                    (["%s:%d %s%s" % (ctx_rel, dl["line"], dl["key"], " (did you mean %s?)" % " / ".join('"%s"' % x for x in dl["hint"]) if dl["hint"] else "")
                      for dl in decls if not dl["hits"]], "coverage exclusion(s) match no anchor (stale — delete or fix the text; a container or an H4 is no anchor)"),
                    (redundant, "heading(s) both covered (unit / OQ) and declared excluded — the declaration is redundant"),
                    (["%s:%d %s" % (ctx_rel, x, t) for x, t in near], "near-miss section heading(s) — only an H2 named exactly '## Coverage exclusions' is read"),
                    (loose, "line(s) in ## Coverage exclusions are not '- ' declarations and were ignored")):
    if items: notes.append("%d %s: %s" % (len(items), what, "; ".join(items)))
notes.append("census = every H1-H3 except containers (their sub-headings instead) + text before the first heading; H4+ and bold pseudo-headings inside an anchor belong to it")
gap_rows = [dict({k: g[k] for k in ("heading", "slug", "line", "file")}, halt_type="plan_coverage_gap") for g in gaps]
gap_rows += [{"heading": "(invalid coverage exclusion) %s" % ln.strip()[:120], "slug": "", "line": n, "file": ctx_rel,
              "halt_type": "plan_coverage_gap", "why": why} for n, ln, why in invalid]
gap_rows += [{"heading": "(ambiguous prd_source) %s" % r, "slug": "", "line": 0, "file": "%s/%s" % (rel(vault), u), "halt_type": "plan_coverage_gap",
              "why": "ambiguous: %d headings match — cite <file>#<unique slug> (%s) or <file>:<line>" % (len(amb), ", ".join(h["slug"] for h in amb))}
             for u, r, amb in amb_rows]
if not anchors:
    gap_rows.insert(0, {"heading": "(no requirement headings found)", "slug": "", "line": 0, "file": prd_rel, "halt_type": "plan_coverage_gap"})
status = "PASS" if not gap_rows else "FAIL"

def decl_line(a):  # the paste-ready line — quoted text, or the unique slug when the text would not parse back to it
    pre = ""
    if len(docs) > 1:
        b = os.path.basename(a["file"]); pre = (b if sum(os.path.basename(x) == b for x in docs) == 1 else a["file"]) + "#"
    p = parse_decl('%s"%s" — r' % (pre, a["heading"]))
    ok = p and p[1] and [(x["file"], x["line"]) for x in decl_targets(*p[:3])] == [(a["file"], a["line"])]
    return "- %s — <reason>" % ('%s"%s"' % (pre, a["heading"]) if ok or not a["slug"] else pre + a["slug"])
paste = [decl_line(g) for g in gaps]

# ── the per-vault state (one project slot; the preflight checks every plan-born vault's entry) ──
ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
sp = os.path.join(cwd, ".mega-sdd", ".plan-coverage-state.json"); vkey = ph.vault_key(cwd, vault)
try:
    old = json.load(open(sp, encoding="utf-8")); ents = old.get("vaults") if isinstance(old, dict) and isinstance(old.get("vaults"), dict) else {}
except Exception:
    ents = {}
ents = {k: v for k, v in ents.items() if k != vkey and isinstance(v, dict) and os.path.isdir(os.path.join(cwd, k))}
others = ["%s (%s)" % (k, why.split(" for ")[0]) for k in sorted(ents)
          for ok, why, _ in [ph.coverage_verdict(cwd, [os.path.join(cwd, k)])] if not ok] if ents else []
ents[vkey] = {"status": status, "prd": prd_rel, "sources": srcs, "digest": ph.digest(cwd, vault, srcs), "ts": ts,
              "anchors": len(anchors), "gaps": len(gap_rows), "gap_headings": [g["heading"] for g in gap_rows][:5]}

lines, ndecl = [], sum(1 for x in excluded if x["by"] == "declared")
if not anchors:
    lines.append("0 anchors (plan_coverage_gap): no heading and no text in %s — the structure was not readable. A census with "
                 "nothing to check is never a PASS." % ("the %d KB module file(s)" % len(sources) if kb else ", ".join(srcs)))
if gaps:
    lines.append("%d heading(s) have NO decision (plan_coverage_gap). For each: add a unit whose prd_source names it, raise a "
                 "[business] OQ carrying [covers: <ref>] (the heading waits on its answer), or declare it in %s under "
                 "\"## Coverage exclusions\" — one line per heading with a real reason (an H2 line covers no H3). Refs: %s. "
                 "Paste-ready lines (replace <reason>):" % (len(gaps), ctx_rel, ", ".join(aref(g) for g in gaps)))
    lines += paste
if invalid:
    lines.append("%d invalid coverage exclusion line(s) (plan_coverage_gap): %s." % (len(invalid), "; ".join("%s:%d %s" % (ctx_rel, n, why) for n, ln, why in invalid)))
if amb_rows:
    lines.append("%d ambiguous unit prd_source ref(s) (plan_coverage_gap): %s." % (len(amb_rows), "; ".join(
        "%s %s — %s" % (g["file"], g["heading"][23:], g["why"]) for g in gap_rows if g["heading"].startswith("(ambiguous"))))
if oq_only:
    lines.append("%d heading(s) have no unit, only an open question — nothing is built for them until it is answered: %s. "
                 "Confirm each whole heading waits on it, else add the unit." % (len(oq_only), "; ".join(
                     "%s ← %s (%s)" % (x["heading"], x["oq"], x["oq_status"]) for x in oq_only)))
if status == "PASS":
    lines.append("Every heading has a decision: %d covered by a unit, %d by an open question, %d declared out of unit coverage." % (
        len(covered) - len(oq_only), len(oq_only), ndecl))
if others:
    lines.append("Other vault(s) of this project are not a fresh PASS: %s — re-run this gate for each (execute-bolts is refused "
                 "until every plan-born vault PASSes)." % ", ".join(others))
summary = dict(([("other_vaults_not_pass", others)] if others else []) + [("gaps", len(gaps)), ("anchors", len(anchors)), ("covered", len(covered)),
               ("declared", ndecl), ("invalid", len(invalid) + len(amb_rows)), ("oq_only", len(oq_only))])
state = {"ts": ts, "validator": "validate-plan-coverage.sh", "status": "PASS" if status == "PASS" and not others else "FAIL",
         "run_status": status, "vault": vkey, "prd": prd_rel, "sources": srcs, "digest": ents[vkey]["digest"], "anchors": len(anchors),
         "covered": len(covered), "units_prd_refs": len(refs), "declarations": len(decls), "summary": summary, "gaps": gap_rows,
         "covered_detail": covered, "excluded": excluded, "oq_only": oq_only, "notes": notes, "next_action": "\n".join(lines),
         "paste": paste, "vaults": ents}
md = os.path.join(cwd, ".mega-sdd"); os.makedirs(md, exist_ok=True); tmp = sp + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as f: json.dump(state, f, indent=1, ensure_ascii=False)
os.replace(tmp, sp)
if E["V_QUIET"] != "1": print(json.dumps(state, indent=1, ensure_ascii=False))
sys.exit(0 if status == "PASS" else 1)
PYEOF
