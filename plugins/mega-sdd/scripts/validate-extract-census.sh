#!/usr/bin/env bash
# validate-extract-census.sh — the extraction completeness gate for the
# PRD-kontrak lane (spec 2026-08-26-extract-revamp-contract-design.md).
#
# "Done" is contracted to the census, not to a wave count: extraction is
# complete when EVERY file row in census.json is (a) claimed by exactly one
# module PRD (frontmatter `source_files:`), (b) that PRD exists under
# <kb-dir>/modules/*.prd.md with sane frontmatter, (c) the file is cited
# (path:line) at least once in its PRD body, (d) every PRD carries all 6
# template sections incl. `## Open Questions` (explicit absence beats silent
# omission), and (e) every substantive Flow section carries a Mermaid fence
# that passes the shared _lib/mermaid_syntax tokenizer (user-mandated rule).
# Everything is recomputed from census.json + the PRD artifacts on every run
# (B1-recompute pattern) — there is no trusted intermediate state.
#
# Usage:
#   validate-extract-census.sh --kb-dir=<dir> [--quiet]
# Exit: 0 PASS or SKIP (no census.json — pre-PRD-kontrak KB, nothing to
#       gate) · 1 FAIL (findings listed; state file carries them) · 2 usage.
# State: <kb-dir>/.extract-census-state.json (re-derived every run).

set -u
KB_DIR=""; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --kb-dir=*) KB_DIR="${arg#--kb-dir=}" ;;
    --quiet)    QUIET=1 ;;
    *) echo "usage: validate-extract-census.sh --kb-dir=<dir> [--quiet]" >&2; exit 2 ;;
  esac
done
[ -n "$KB_DIR" ] && [ -d "$KB_DIR" ] || { echo "validate-extract-census.sh: --kb-dir missing or not a directory: '$KB_DIR'" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

KB_DIR="$KB_DIR" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import mermaid_syntax              # noqa: E402  the ONE Mermaid Rule 0-3 tokenizer (never fork per surface)

kb_dir = os.environ["KB_DIR"]
quiet = os.environ["QUIET"] == "1"
state_path = os.path.join(kb_dir, ".extract-census-state.json")

advisories = {"oq_answerable_from_disk": [], "notes": []}

def write_state(status, findings):
    doc = {"status": status,
           "generated_by": "mega-sdd:validate-extract-census",
           "checked_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "findings": findings,
           "advisories": advisories}
    tmp = state_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, state_path)

census_path = os.path.join(kb_dir, "census.json")
if not os.path.isfile(census_path):
    # pre-PRD-kontrak KB (numbered tree) — nothing to gate here; the legacy
    # validators own that grammar. SKIP is an answer, never a silent pass.
    write_state("SKIP", {"note": "no census.json — pre-PRD-kontrak knowledge base"})
    if not quiet:
        print("extract-census: SKIP (no census.json)")
    sys.exit(0)

try:
    with open(census_path, encoding="utf-8") as fh:
        census = json.load(fh)
    census_files = [r["path"] for r in census.get("files", [])]
except (ValueError, OSError, KeyError, TypeError) as e:
    write_state("FAIL", {"census_unreadable": str(e)})
    print("extract-census: FAIL — census.json unreadable: %s" % e, file=sys.stderr)
    sys.exit(1)

modules_dir = os.path.join(kb_dir, "modules")
prd_paths = []
if os.path.isdir(modules_dir):
    prd_paths = sorted(os.path.join(modules_dir, n)
                       for n in os.listdir(modules_dir) if n.endswith(".prd.md"))

findings = {"unclaimed": [], "double_claimed": [], "phantom_claims": [],
            "uncited": [], "bad_frontmatter": [], "missing_oq_section": [],
            "missing_sections": [], "flow_not_mermaid": [], "mermaid_syntax": [],
            "claim_verify_missing": [], "claim_verify_failed": [],
            "claim_verify_incomplete": [],
            "rollup_mismatch": [], "site_uncovered": []}

all_bodies = []          # (rel, body) — consumed by the Fase-4 passes below
tier_totals = {"locked": 0, "intent": 0, "artifact": 0}
oq_split = {"P1": 0, "P2": 0, "P3": 0}
oq_total = 0

if not prd_paths:
    findings["no_module_prds"] = ("census present (%d files) but no modules/*.prd.md — extraction not started or wrote elsewhere"
                                  % len(census_files))
    write_state("FAIL", findings)
    print("extract-census: FAIL — %s" % findings["no_module_prds"], file=sys.stderr)
    sys.exit(1)

def parse_frontmatter(text):
    """Minimal hand parser (no yaml dep): top --- block; scalar keys +
    the source_files '- item' list. Returns (dict, body)."""
    if not text.startswith("---"):
        return None, text
    end = text.find("\n---", 3)
    if end < 0:
        return None, text
    fm_text, body = text[3:end], text[end + 4:]
    fm, cur_list = {}, None
    for line in fm_text.splitlines():
        if not line.strip():
            continue
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if val == "" or val == "|":
                fm[key] = []
                cur_list = key
            else:
                fm[key] = val.strip("'\"")
                cur_list = None
        elif cur_list is not None:
            lm = re.match(r"^\s*-\s*(.+?)\s*$", line)
            if lm:
                fm[cur_list].append(lm.group(1).strip("'\""))
    return fm, body

claims = {}   # census path -> [prd relnames]
for p in prd_paths:
    rel = os.path.relpath(p, kb_dir).replace(os.sep, "/")
    try:
        text = open(p, encoding="utf-8", errors="replace").read()
    except OSError as e:
        findings["bad_frontmatter"].append({"prd": rel, "issue": "unreadable: %s" % e})
        continue
    fm, body = parse_frontmatter(text)
    if fm is None:
        findings["bad_frontmatter"].append({"prd": rel, "issue": "no YAML frontmatter"})
        continue
    for key in ("generated_by", "domain", "source_files"):
        if key not in fm:
            findings["bad_frontmatter"].append({"prd": rel, "issue": "missing frontmatter key: %s" % key})
    src = fm.get("source_files")
    src_list = src if isinstance(src, list) else []
    for f in src_list:
        claims.setdefault(f, []).append(rel)
        if f not in census_files:
            findings["phantom_claims"].append({"prd": rel, "path": f})
        else:
            # cited at least once in the body as path:line
            if not re.search(re.escape(f) + r":\d", body):
                findings["uncited"].append({"prd": rel, "path": f})
    if not re.search(r"^##+\s+.*Open Questions", body, re.MULTILINE):
        findings["missing_oq_section"].append(rel)

    # Mermaid hard rule (user-mandated) on the new grammar: §3 Flow must carry
    # a mermaid fence when it describes transitions, and every mermaid block
    # must pass the shared Rule 0-3 tokenizer (same rules as KB/vault flows).
    for n in ("1", "2", "3", "4", "5", "6"):
        if not re.search(r"^##\s*%s\." % n, body, re.MULTILINE):
            findings["missing_sections"].append({"prd": rel, "section": n})
    m3 = re.search(r"^##\s*3\..*$", body, re.MULTILINE)
    if m3:
        nxt = re.search(r"^##\s*4\.", body[m3.end():], re.MULTILINE)
        sec3 = body[m3.end(): m3.end() + nxt.start()] if nxt else body[m3.end():]
        substantive = sec3.strip() and "_Tidak terdeteksi._" not in sec3
        if substantive and "```mermaid" not in sec3:
            findings["flow_not_mermaid"].append(rel)
    blocks = mermaid_syntax.extract_mermaid_blocks(body)
    for issue in (mermaid_syntax.check_diagram_type(blocks, rel)
                  + mermaid_syntax.check_mermaid_syntax(blocks, rel)):
        issue["prd"] = rel
        findings["mermaid_syntax"].append(issue)

    # Claim-verify lane gate (7.25.0, spec 2026-09-05-kb-verify-lane-design.md
    # Fase 3): every module PRD must carry a passing .verify/<domain>.json
    # written by write-verify-state.sh from the claim-verifier's VERIFY REPORT.
    # LOCKED coverage + the sample floor are RECOMPUTED from the PRD artifact
    # here (B1-recompute pattern) — the state supplies the verdict, never the
    # coverage ground truth, so an under-scoped or forged report cannot pass.
    all_bodies.append((rel, body))
    tier_totals["locked"] += len(re.findall(r"\[LOCKED\]", body))
    tier_totals["intent"] += len(re.findall(r"\[INTENT\]", body))
    tier_totals["artifact"] += len(re.findall(r"\[ARTIFACT\]", body))
    m6 = re.search(r"^##\s*6\.", body, re.MULTILINE)
    if m6:
        for oq_line in re.findall(r"^\s*-\s*(?:\[[ xX]\]\s*)?OQ-.*$", body[m6.start():], re.MULTILINE):
            oq_total += 1
            pm = re.search(r"\[(P[123])\]", oq_line)
            if pm:
                oq_split[pm.group(1)] += 1
            # OQ evidence probe (Fase 4): "(probe-glob: <pattern>)" — evidence
            # arriving on disk answers the OQ; surface it, never fail on it.
            gm = re.search(r"\(probe-glob:\s*([^)]+)\)", oq_line)
            if gm:
                import glob as _glob
                pat = gm.group(1).strip().strip("`")
                roots = [os.path.abspath(os.path.join(kb_dir, "..", ".."))]
                lr = census.get("legacy_root", "")
                if lr and os.path.isdir(lr):
                    roots.append(lr)
                hits = []
                for root in roots:
                    hits.extend(_glob.glob(os.path.join(root, pat)))
                if hits:
                    advisories["oq_answerable_from_disk"].append(
                        {"prd": rel, "oq": oq_line.strip()[:120], "probe": pat,
                         "hits": sorted(os.path.relpath(h, roots[0]) for h in hits[:5])})

    domain = fm.get("domain") if isinstance(fm.get("domain"), str) else None
    locked_in_prd = len(re.findall(r"\[LOCKED\]", body))
    cite_count = len(re.findall(r"[\w./#-]+:\d+", body))
    sample_floor = min(8, cite_count)
    vpath = os.path.join(kb_dir, ".verify", (domain or "") + ".json")
    if not domain or not os.path.isfile(vpath):
        findings["claim_verify_missing"].append(
            {"prd": rel, "expected": ".verify/%s.json" % (domain or "<domain>"),
             "fix": "dispatch mega-sdd:claim-verifier for this module, then write-verify-state.sh"})
    else:
        vdoc = None
        try:
            with open(vpath, encoding="utf-8") as vf:
                vdoc = json.load(vf)
        except (ValueError, OSError) as e:
            findings["claim_verify_failed"].append({"prd": rel, "issue": "verify state unreadable: %s" % e})
        if vdoc is not None:
            try:
                wlb = int(vdoc.get("wrong_load_bearing", 1))
                locked_checked = int(vdoc.get("locked_checked", 0))
                checked_total = (locked_checked + int(vdoc.get("money_checked", 0))
                                 + int(vdoc.get("sampled", 0)))
            except (TypeError, ValueError):
                findings["claim_verify_failed"].append({"prd": rel, "issue": "verify state fields non-integer"})
                wlb, locked_checked, checked_total = 1, 0, 0
            if vdoc.get("status") != "PASS" or wlb > 0:
                findings["claim_verify_failed"].append(
                    {"prd": rel, "status": vdoc.get("status"),
                     "wrong_load_bearing": vdoc.get("wrong_load_bearing"),
                     "findings": (vdoc.get("findings") or [])[:5]})
            if locked_checked < locked_in_prd:
                findings["claim_verify_incomplete"].append(
                    {"prd": rel, "locked_in_prd": locked_in_prd,
                     "locked_checked": locked_checked,
                     "issue": "LOCKED coverage short (recomputed from the PRD body)"})
            if checked_total < sample_floor:
                findings["claim_verify_incomplete"].append(
                    {"prd": rel, "checked_total": checked_total, "sample_floor": sample_floor,
                     "issue": "checked fewer claims than the recomputed sample floor"})

for f in census_files:
    owners = claims.get(f, [])
    if not owners:
        findings["unclaimed"].append(f)
    elif len(owners) > 1:
        findings["double_claimed"].append({"path": f, "prds": owners})

# ── Fase 4 (7.26.0): README roll-up recount ──────────────────────────────────
# Field lesson: the Host README claimed LOCKED=5 (real: 4) and an OQ split of
# 9/20/11 (real: 12/18/10) — hand-computed roll-ups drift. Recount the two
# machine-parseable claims: the Mutability Tier Distribution Total row and the
# OQ split. Unparseable README (custom format) → advisory note, never a guess.
readme_path = os.path.join(kb_dir, "README.md")
if os.path.isfile(readme_path):
    rd = open(readme_path, encoding="utf-8", errors="replace").read()
    tm = re.search(r"^\|\s*\**Total\**\s*\|\s*\**(\d+)\**\s*\|\s*\**(\d+)\**\s*\|\s*\**(\d+)\**\s*\|",
                   rd, re.MULTILINE)
    if tm:
        got = tuple(int(x) for x in tm.groups())
        want = (tier_totals["locked"], tier_totals["intent"], tier_totals["artifact"])
        if got != want:
            findings["rollup_mismatch"].append(
                {"claim": "mutability Total row", "readme": list(got), "recomputed": list(want),
                 "note": "explicit body markers only (untagged claims are default tiers)"})
    elif re.search(r"Mutability Tier Distribution", rd):
        advisories["notes"].append("README has a Mutability section but no parseable Total row — recount skipped")
    sm = re.search(r"P1:\s*(\d+)\s*[,;]\s*P2:\s*(\d+)\s*[,;]\s*P3:\s*(\d+)", rd)
    if sm:
        got = tuple(int(x) for x in sm.groups())
        want = (oq_split["P1"], oq_split["P2"], oq_split["P3"])
        if got != want:
            findings["rollup_mismatch"].append(
                {"claim": "OQ priority split", "readme": list(got), "recomputed": list(want)})
    om = re.search(r"Open questions[:*\s]+\**(\d+)\**", rd, re.IGNORECASE)
    if om and int(om.group(1)) != oq_total:
        findings["rollup_mismatch"].append(
            {"claim": "OQ total", "readme": int(om.group(1)), "recomputed": oq_total})

# ── Fase 4 (7.26.0): site-census coverage ────────────────────────────────────
# derive-site-census.sh inventories WRITE/CALL sites per stack idiom; every
# site must be cited in SOME PRD (same path namespace as census, exact line ±2
# or inside a cited a-b range). The Host audit's missed-4th-CFTPNT-site class.
site_path = os.path.join(kb_dir, ".site-census.json")
if os.path.isfile(site_path):
    try:
        site_doc = json.load(open(site_path, encoding="utf-8"))
    except (ValueError, OSError) as e:
        advisories["notes"].append("site-census unreadable (%s) — coverage skipped" % e)
        site_doc = {"sites": []}
    cited = {}   # path -> list of (lo, hi)
    cite_re = re.compile(r"([A-Za-z0-9_./#@$-]+):(\d+)(?:-(\d+))?")
    for rel_b, body_b in all_bodies:
        for m in cite_re.finditer(body_b):
            lo = int(m.group(2)); hi = int(m.group(3)) if m.group(3) else lo
            cited.setdefault(m.group(1), []).append((min(lo, hi), max(lo, hi)))
    for s in site_doc.get("sites", []):
        spans = cited.get(s.get("file", ""), [])
        ln = int(s.get("line", 0))
        ok = any(lo - 2 <= ln <= hi + 2 for lo, hi in spans)
        if not ok:
            if len(findings["site_uncovered"]) < 50:
                findings["site_uncovered"].append(
                    {"kind": s.get("kind"), "target": s.get("target"),
                     "site": "%s:%s" % (s.get("file"), s.get("line")),
                     "fix": "cite this site in the owning PRD or record it as [OPEN]"})
            else:
                break
else:
    advisories["notes"].append("no .site-census.json — site coverage not checked (run derive-site-census.sh)")

failed = any(v for v in findings.values())
status = "FAIL" if failed else "PASS"
write_state(status, findings)
for k, v in advisories.items():
    if v:
        print("extract-census: advisory %s: %s" % (k, json.dumps(v, ensure_ascii=False)[:300]))
if failed:
    for k, v in findings.items():
        if v:
            print("extract-census: %s: %s" % (k, json.dumps(v, ensure_ascii=False)[:400]),
                  file=sys.stderr)
    print("extract-census: FAIL", file=sys.stderr)
    sys.exit(1)
if not quiet:
    print("extract-census: PASS — %d census files fully claimed + cited across %d module PRD(s)"
          % (len(census_files), len(prd_paths)))
PYEOF
