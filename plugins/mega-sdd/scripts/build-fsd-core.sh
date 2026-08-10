#!/usr/bin/env bash
# build-fsd-core.sh — deterministic builder of the FSD document body (tranche 5e,
# spec docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md §5e).
#
# THE SEAM (stronger than the SIT/UAT fragment precedent): this script executes
# emit-fsd/references/section-mapping.md §1–§10 deterministically and writes
# <vault>/fsd/FSD.md with EVERY slot pre-filled — the mapping was always written
# as extraction rules, and every FSD slot is mechanical. The model runs this
# script and reviews; mechanical bytes never transit model output (model_slots=0
# for the FSD lane). Downstream is byte-unchanged: the unfilled-slot scan,
# build-citation-map.sh stamping, md2pdf render, and refresh-doc-stamps.sh all
# operate on the written FSD.md exactly as before.
#
# Discipline carried from the mapping (grammar-identical to the model-authored era):
#   - every citation stamp is the LITERAL `(sha256: pending)` — never a hash
#   - absent source → `[Pending — <source> not yet generated]`, never fabrication
#   - drift callouts are inserted HERE (this script runs check-citation-drift.sh
#     and splices the block quotes with old12/new12 VERBATIM — hash prefixes are
#     exactly the value class a model mistypes) and the drift lines are printed
#     so the SKILL change-note derivation consumes them without a second run
#   - templates are the single source of truth: the fenced skeletons are PARSED
#     from fsd-template.md at run time (no hand-duplicated doc constants)
#   - §6 NFR: when BOTH 02-functional §NFR and constitution LOCKED clauses carry
#     a category, BOTH are emitted under labeled sub-blocks (the old "de-dup,
#     prefer constitution" was model judgment; over-complete + labeled is
#     deterministic and a duplicate is not fabrication — mapping amended)
#
# Usage:
#   build-fsd-core.sh --vault=<vault-dir> --cwd=<project-root> \
#       [--mode=pre-dev|post-dev|auto] [--sections=1,2,5] [--quiet]
# Exit: 0 = FSD.md written; prints ONE summary line
#         `fsd-core: mode=<m> sections=<n>/<10> pending=<k> drift=<d> model_slots=0`
#         plus the drift lines (DRIFT/GONE/NO_PRIOR/...) verbatim after it
#       2 = cannot run (usage / vault or template missing)
set -uo pipefail

VAULT=""; CWD=""; MODE="auto"; SECTIONS="all"; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT="${arg#*=}" ;;
    --cwd=*) CWD="${arg#*=}" ;;
    --mode=*) MODE="${arg#*=}" ;;
    --sections=*) SECTIONS="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { echo "ERROR: --vault=<vault-dir> required" >&2; exit 2; }
[ -n "$CWD" ] && [ -d "$CWD" ] || { echo "ERROR: --cwd=<project-root> required" >&2; exit 2; }
case "$MODE" in auto|pre-dev|post-dev) ;; *) echo "ERROR: --mode must be pre-dev|post-dev|auto" >&2; exit 2 ;; esac
TPL="${SCRIPT_DIR}/../skills/emit-fsd/references/fsd-template.md"
STYD="${SCRIPT_DIR}/../skills/emit-fsd/references/styling-config.yaml"
[ -f "$TPL" ] || { echo "ERROR: fsd-template.md missing at $TPL" >&2; exit 2; }
PLUGIN_VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${SCRIPT_DIR}/../.claude-plugin/plugin.json" 2>/dev/null | head -1)

# Drift lines from the sanctioned reader (first emit → NO_PRIOR); consumed below
# for callout insertion, then re-printed for the SKILL change-note derivation.
DRIFT_OUT=$(bash "${SCRIPT_DIR}/check-citation-drift.sh" --vault="$VAULT" --cwd="$CWD" 2>/dev/null || true)

VAULT="$VAULT" CWD="$CWD" MODE="$MODE" SECTIONS="$SECTIONS" QUIET="$QUIET" \
TPL="$TPL" STYD="$STYD" PLUGIN_VER="${PLUGIN_VER:-unknown}" DRIFT_OUT="$DRIFT_OUT" python3 <<'PYEOF'
import glob, json, os, re, sys
from datetime import datetime, timezone

vault = os.path.abspath(os.environ["VAULT"])
cwd = os.path.abspath(os.environ["CWD"])
mode_arg = os.environ["MODE"]
sections_arg = os.environ["SECTIONS"]
quiet = os.environ.get("QUIET", "0") == "1"
tpl_path = os.environ["TPL"]
drift_out = os.environ.get("DRIFT_OUT", "")
plugin_ver = os.environ["PLUGIN_VER"]

def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return None

# ── Template skeletons: parse the ```markdown fences per `## <heading>` — the
# template file is the single source of truth (never duplicated here).
tpl = read(tpl_path) or ""
# The fenced skeletons CONTAIN `## <n>. <title>` document headings, so a naive
# "until the next ^## " terminator dies inside the first fence. Template-level
# section boundaries are exactly the `## Section N` headings (plus the trailing
# `## Slot semantics` block) — split on those.
def fences_under(n):
    m = re.search(r"(?ms)^## Section %d\b[^\n]*\n(.*?)(?=^## Section \d|^## Slot semantics|\Z)" % n, tpl)
    if not m:
        return []
    return re.findall(r"(?ms)^```markdown\n(.*?)^```", m.group(1))

doc_head = (re.findall(r"(?ms)^```markdown\n(.*?)^```", tpl.split("## Section 1")[0]) or [""])[0]
SEC = {}
for n in range(1, 11):
    f = fences_under(n)
    if f:
        SEC[n] = f  # [skeleton] or [skeleton, sub-template] ([pre-dev, post-dev] for §9)
if len(SEC) != 10 or not doc_head:
    print("ERROR: fsd-template.md fenced skeletons not parseable (found %d/10 sections)" % len(SEC), file=sys.stderr)
    sys.exit(2)
# Sub-templates are keyed by their prose LABEL, never by fence position — an
# added illustrative fence must not silently swap a skeleton (ADV-019).
def labeled_fence(n, label):
    m = re.search(r"(?ms)^## Section %d\b[^\n]*\n(.*?)(?=^## Section \d|^## Slot semantics|\Z)" % n, tpl)
    if not m:
        return ""
    lm = re.search(r"(?ms)%s.*?^```markdown\n(.*?)^```" % re.escape(label), m.group(1))
    return lm.group(1) if lm else (SEC[n][1] if len(SEC[n]) > 1 else "")
US_TPL = labeled_fence(4, "Per-story emit format")
FR_TPL = labeled_fence(5, "Per-FR detail format")
SEC9_PRE = labeled_fence(9, "Pre-development mode emits")
SEC9_POST = labeled_fence(9, "Post-development mode emits")
# The template ToC is a REFERENCE-file navigation aid; if it leaks inside the
# doc-control fence it would ship template-internal headings into every FSD
# (ADV-014) — strip a leading `## Contents` block defensively.
doc_head = re.sub(r"(?ms)^## Contents\n.*?(?=^## |\Z)", "", doc_head)

# ── Mode detection (section-mapping §Mode determination) ──
def detect_mode():
    if glob.glob(os.path.join(vault, "bolts", "U-*", "bolt-report.md")):
        return "post-dev"
    if glob.glob(os.path.join(vault, "units", "U-*.md")) or glob.glob(os.path.join(vault, "units", "U-*", "unit.md")):
        return "pre-dev"
    return "pre-dev"
mode = mode_arg if mode_arg in ("pre-dev", "post-dev") else detect_mode()

# ── Styling / metadata ──
sty = {"classification": "Internal", "include_sections": "all", "include_citation_footnotes": True}
sty_path = os.path.join(vault, "fsd", "FSD.styling.yaml")
if not os.path.isfile(sty_path):
    src = read(os.environ["STYD"])
    if src is not None:
        os.makedirs(os.path.join(vault, "fsd"), exist_ok=True)
        open(sty_path, "w", encoding="utf-8").write(src)
sty_raw = read(sty_path) or ""
for k in ("classification", "project_name", "include_sections"):
    m = re.search(r'(?m)^%s:\s*"?([^"\n#]+)"?\s*(?:#.*)?$' % k, sty_raw)
    if m and m.group(1).strip() and m.group(1).strip() != "null":
        sty[k] = m.group(1).strip()
if re.search(r"(?m)^include_citation_footnotes:\s*false", sty_raw):
    sty["include_citation_footnotes"] = False

vj = {}
try:
    vj = json.load(open(os.path.join(vault, "vault.json")))
except Exception:
    pass
project = sty.get("project_name") or vj.get("project_name") or os.path.basename(vault)
vver = str(vj.get("vault_version", "0.1"))
author = str(vj.get("author", "(unspecified)"))
now = datetime.now(timezone.utc)
iso = now.isoformat().replace("+00:00", "Z")
human = now.strftime("%d %B %Y")

# section filter
if sections_arg and sections_arg != "all":
    want = {int(x) for x in re.findall(r"\d+", sections_arg)}
elif str(sty.get("include_sections", "all")) != "all":
    want = {int(x) for x in re.findall(r"\d+", str(sty["include_sections"]))}
else:
    want = set(range(1, 11))

pending_count = 0
def pend(src):
    global pending_count
    pending_count += 1
    return "[Pending — %s not yet generated]" % src

# ── Source loaders ──
ov = read(os.path.join(vault, "01-overview.md"))
fn = read(os.path.join(vault, "02-functional.md"))
binding_rel = "binding.md"
binding = read(os.path.join(vault, "binding.md"))
if binding is None:
    binding = read(os.path.join(vault, "bound", "binding.md"))
    if binding is not None:
        binding_rel = "bound/binding.md"
const = read(os.path.join(vault, "_meta", "constitution.md"))
cbmap_p = None
for c in (os.path.join(cwd, ".mega-sdd", "codebase", "codebase-map.md"), os.path.join(cwd, "codebase-map.md")):
    if os.path.isfile(c):
        cbmap_p = c
        break
cbmap = read(cbmap_p) if cbmap_p else None
cb_rel = os.path.relpath(cbmap_p, cwd).replace(os.sep, "/") if cbmap_p else "codebase-map.md"

def md_section(text, name):
    """Body of `## <name>`/`### <name>` (numbered headings tolerated) until the
    next same-or-higher heading. `name` may be an alternation of synonyms —
    the real vault producer emits §Product/§Problem/§Success criteria/§Out of
    Scope (generate-intent templates), and the real codebase-map numbers its
    headings (`## 2. Public interfaces`) — ADV-007/ADV-008."""
    if not text:
        return None
    alts = "|".join(re.escape(a.strip()) for a in name.split("|"))
    m = re.search(r"(?ims)^(#{2,3})[ \t]+(?:\d+\.\s*)?(?:%s)\b[^\n]*\n(.*?)(?=^\1[ \t]|^#{1,2}[ \t]|\Z)" % alts, text)
    return m.group(2).strip() if m else None

def line_range(text, body):
    if not text or not body:
        return None
    idx = text.find(body[:80])
    if idx < 0:
        return None
    start = text[:idx].count("\n") + 1
    return (start, start + body.count("\n"))

# units
unit_files = sorted(glob.glob(os.path.join(vault, "units", "U-*.md")) +
                    glob.glob(os.path.join(vault, "units", "U-*", "unit.md")))
units = []
for uf in unit_files:
    t = read(uf) or ""
    fm = t.split("---", 2)
    front = fm[1] if len(fm) >= 3 else ""
    def fv(key, src=front):
        m = re.search(r"(?m)^\s*%s:\s*(.+)$" % key, src)
        return m.group(1).strip().strip('"\'') if m else ""
    uid = fv("unit_id")
    if not uid:
        m_id = re.search(r"U-[A-Za-z0-9_-]+", os.path.basename(os.path.dirname(uf) if uf.endswith("unit.md") else uf))
        uid = m_id.group(0) if m_id else ""
    if not uid:
        continue  # not a unit file (U-.md / non-conforming name) — skip, never crash
    title_m = re.search(r"(?m)^#\s+(?:U-\S+\s*[—-]\s*)?(.+)$", t)
    at = md_section(t, "Acceptance") or ""
    cmd_m = re.search(r"(?m)^\s*-?\s*command:\s*(.+)$", t)
    exp_m = re.search(r"(?m)^\s*-?\s*expected:\s*(.+)$", t)
    rel_u = os.path.relpath(uf, vault).replace(os.sep, "/")
    units.append({
        "id": uid, "file": uf, "rel": rel_u, "front": front, "text": t,
        "title": fv("title") or (title_m.group(1).strip() if title_m else uid),
        "scope": fv("scope"),
        "as_a": fv("as_a"), "i_want": fv("i_want"), "so_that": fv("so_that"),
        "business_value": fv("business_value"),
        "cmd": cmd_m.group(1).strip() if cmd_m else "",
        "expected": exp_m.group(1).strip() if exp_m else "",
        "implements": fv("implements_claim") or fv("vault_source"),
    })

# bolt reports (post-dev)
bolts = {}
for br in glob.glob(os.path.join(vault, "bolts", "U-*", "bolt-report.md")):
    uid = os.path.basename(os.path.dirname(br))
    t = read(br) or ""
    st = re.search(r"(?m)^\s*bolt_status:\s*(\S+)", t)
    # ADV-012: only a line-anchored commit field / provenance trailer — a loose
    # first-hex match can steal a base/parent/quoted sha into a signed doc
    ci = re.search(r"(?mi)^\s*(?:bolt_)?commit:\s*([0-9a-f]{7,40})\b", t) or \
         re.search(r"(?mi)SDD-PROVENANCE:.*?\b([0-9a-f]{7,40})\b", t)
    cc = re.search(r"(?m)^\s*acceptance_test_concern:\s*(.+)$", t)
    ag = re.search(r"(?m)^\s*bolt_subagent_id:\s*(\S+)", t)
    bolts[uid] = {"status": st.group(1) if st else "unknown",  # absent evidence is NEVER success (ADV-004)
                  "commit": (ci.group(1)[:8] if ci else ""),
                  "concern": cc.group(1).strip() if cc else "",
                  "agent": ag.group(1) if ag else "bolt-implementer"}

cites = {n: [] for n in range(1, 11)}
def cite(n, path, lr=None):
    entry = (path, lr)
    if all(e[0] != path for e in cites[n]):
        cites[n].append(entry)

slots = {}

# ── §1 Overview ──
purpose = md_section(ov, "Purpose|Product") if ov else None
scope_b = md_section(ov, "Scope|Target users / personas") if ov else None
if ov and (purpose or scope_b):
    body = "\n\n".join(x for x in (purpose, scope_b) if x)
    slots["section-1-content"] = body
    lr1 = line_range(ov, purpose) if purpose else None
    lr2 = line_range(ov, scope_b) if scope_b else None
    span = (min(x[0] for x in (lr1, lr2) if x), max(x[1] for x in (lr1, lr2) if x)) if (lr1 or lr2) else None
    cite(1, "vault/01-overview.md", span)
else:
    slots["section-1-content"] = pend("vault/01-overview.md")

# ── §2 Goals / Non-Goals ──
goals = md_section(ov, "Goals|Success criteria") if ov else None
nongoals = md_section(ov, "Non-Goals|Out of Scope") if ov else None
slots["section-2-goals-content"] = goals or "[Pending — vault/01-overview.md §Goals not yet generated]"
slots["section-2-non-goals-content"] = nongoals or "[Pending — vault/01-overview.md §Non-Goals not yet generated]"
if goals is None and nongoals is None:
    pending_count += 1
else:
    cite(2, "vault/01-overview.md", line_range(ov, goals or nongoals))

# ── §3 Stakeholders ──
rows3 = []
squads_p = os.path.join(vault, "_meta", "squads.yaml")
sq = read(squads_p)
if sq:
    # split on entry boundaries FIRST — a lazy multiline regex bled fields
    # across entries (F5: a lead-less entry stole the NEXT entry name)
    for entry in re.split(r"(?m)^-\s+", sq)[1:]:
        rm = re.match(r"(?:squad|role):\s*(.+)", entry)
        if not rm:
            continue
        lm = re.search(r"(?m)^\s*lead_name:\s*(.+)$", entry)
        pm2 = re.search(r"(?m)^\s*responsibility:\s*(.+)$", entry)
        rows3.append("| %s | %s | %s |" % (rm.group(1).strip(), (lm.group(1).strip() if lm else "(unspecified)"), (pm2.group(1).strip() if pm2 else "")))
    cite(3, "vault/_meta/squads.yaml")
elif isinstance(vj.get("stakeholders"), list) and vj["stakeholders"]:
    for s in vj["stakeholders"]:
        rows3.append("| %s | %s | %s |" % (s.get("role", ""), s.get("name", ""), s.get("responsibility", "")))
    cite(3, "vault.json")
elif vj.get("author"):
    rows3.append("| Author | %s | Project owner |" % vj["author"])
    cite(3, "vault.json")
else:
    rows3.append("| Author | (unspecified — vault.json.author missing) | Project owner |")
    rows3.insert(0, "")  # placeholder; replaced by the warning below
if rows3 and rows3[0] == "":
    rows3 = rows3[1:]
    slots["section-3-stakeholders-table"] = ("> ⚠ Pemilik tidak teridentifikasi di sumber (vault.json.author kosong) — lengkapi sebelum sign-off.\n\n" + "\n".join(rows3))
else:
    slots["section-3-stakeholders-table"] = "\n".join(rows3)

# ── §4 User stories ──
SCOPE_AS_A = {"BE": "API consumer", "FE": "End user", "API": "API consumer", "UI": "End user"}
if units:
    blocks = []
    for u in units:
        as_a = u["as_a"] or SCOPE_AS_A.get(u["scope"].upper(), "User of %s" % (u["scope"] or "the system"))
        i_want = u["i_want"] or u["title"]
        so_that = u["so_that"] or u["business_value"] or "(unspecified)"
        # empty expects = exit-code criterion; never fabricate a "pass" token the unit doesn't carry
        ats = (("`%s` (expects: %s)" % (u["cmd"], u["expected"])) if u["expected"] else ("`%s` (exit-code criterion)" % u["cmd"])) if u["cmd"] else "(no acceptance_test declared)"
        b = US_TPL
        for k, v in (("unit_id_short", u["id"].replace("U-", "")), ("unit_title", u["title"]),
                     ("as_a", as_a), ("i_want", i_want), ("so_that", so_that),
                     ("acceptance_test_summary", ats), ("unit_id", u["id"])):
            b = b.replace("{{%s}}" % k, v)
        b = b.replace("[Source: units/%s.md" % u["id"], "[Source: %s" % u["rel"])
        blocks.append(b.strip())
        cite(4, u["rel"])
    slots["section-4-user-stories-content"] = "\n\n".join(blocks)
else:
    slots["section-4-user-stories-content"] = "[Pending — units/ directory not yet generated. Run generate-units after vault stabilizes.]"
    pending_count += 1

# ── §5 Functional requirements ──
fr_rows, fr_details = [], []
if fn:
    heads = list(re.finditer(r"(?m)^(#{2,4})\s+(FR-\d+)\s*[—:-]?\s*(.*)$", fn))
    for i, h in enumerate(heads):
        frid, title = h.group(2), h.group(3).strip() or "(untitled)"
        body_start = h.end()
        body_end = heads[i + 1].start() if i + 1 < len(heads) else len(fn)
        body = fn[body_start:body_end].strip()
        pm = re.search(r"\*\*Priority:\*\*\s*(\S+)", body)
        prio = pm.group(1) if pm else "MEDIUM"
        frid_rx = re.compile(r"\b%s(?!\d)" % re.escape(frid))
        # mapping rule: reference = implements_claim / vault_source ONLY — a
        # prose mention ("not FR-001") must never promote a unit to implementer
        refs = [u for u in units if frid_rx.search(u["implements"] or "")]
        if mode == "pre-dev":
            status, ev = "Specified", "pre-dev"
        elif not refs:
            status, ev = "Specified (no unit)", "no referencing unit"
        else:
            sts = [bolts.get(u["id"], {}).get("status") for u in refs]
            if any(s and s.startswith("halted") for s in sts):
                status, ev = "In Progress (halted)", "a bolt halted"
            elif sts and all(s == "completed" for s in sts):
                status, ev = "Implemented", "all referenced bolts completed"
            else:
                status, ev = "In Progress", "bolts pending"
        verdict, claim_id = "(not bound)", "(none)"
        if binding:
            # per-LINE scan, prefix-immune (F1: FR-001 inside an FR-0010 line
            # masked a real CONFLICT as CONFIRMED) — the verdict must come from
            # a line that references THIS fr id as a whole token
            for bline in binding.splitlines():
                if frid_rx.search(bline):
                    vm = re.search(r"\b(CONFIRMED|CONFLICT|OQ)\b", bline)
                    if vm:
                        verdict = vm.group(1)
                        cm = re.search(r"\[?(C-\d+)\]?", bline)
                        claim_id = cm.group(1) if cm else "(unlabelled)"
                        break
        ln1 = fn[:h.start()].count("\n") + 1
        ln2 = fn[:body_end].count("\n") + 1
        fr_rows.append("| %s | %s | %s | %s |" % (frid, title, prio, status))
        d = FR_TPL
        for k, v in (("fr_id", frid.replace("FR-", "")), ("fr_title", title),
                     ("fr_description", body.split("\n\n")[0] if body else "(no description)"),
                     ("fr_priority", prio), ("fr_status", status), ("status_evidence", ev),
                     ("binding_verdict", verdict), ("claim_id", claim_id),
                     ("unit_ids_csv", ", ".join(u["id"] for u in refs) or "(none)"),
                     ("bolt_status_summary", ", ".join(sorted({bolts.get(u["id"], {}).get("status", "pending") for u in refs})) or "n/a"),
                     ("fr_line_start", str(ln1)), ("fr_line_end", str(ln2))):
            d = d.replace("{{%s}}" % k, v)
        fr_details.append(d.strip())
    cite(5, "vault/02-functional.md")
if not fr_rows:
    # Modern-vault fallback (P4 repair): today's generate-intent emits no
    # 02-functional.md — the functional enumeration of a modern vault is its
    # flows (04-flows.md `### F-*` + per-flow DoD; SIT already builds from
    # exactly this). Legacy FR-heading vaults keep the branch above.
    fl = read(os.path.join(vault, "04-flows.md"))
    if fl:
        # id must END at the match (round: `F-U_002` half-matched as id "F-U";
        # a heading the grammar cannot parse whole is DROPPED, never truncated)
        fheads = list(re.finditer(r"(?m)^(#{2,4})\s+(F-[A-Z0-9]+(?:-[A-Z0-9]+)*)(?!\w)\s*[—:-]?\s*(.*)$", fl))
        for i, h in enumerate(fheads):
            fid, title = h.group(2), h.group(3).strip() or "(untitled)"
            body_start = h.end()
            body_end = fheads[i + 1].start() if i + 1 < len(fheads) else len(fl)
            body = fl[body_start:body_end]
            # suffix guard covers ALPHANUMERIC-AND-DASH ids (round: the numeric
            # `(?!\d)` guard let F-U-001 match inside F-U-001-B — false
            # "Implemented" status from another flow's unit)
            fid_rx = re.compile(r"\b%s(?![\w-])" % re.escape(fid))
            refs = [u for u in units if fid_rx.search(u["implements"] or "")]
            if mode == "pre-dev":
                status, ev = "Specified", "pre-dev"
            elif not refs:
                status, ev = "Specified (no unit)", "no referencing unit"
            else:
                sts = [bolts.get(u["id"], {}).get("status") for u in refs]
                if any(s and s.startswith("halted") for s in sts):
                    status, ev = "In Progress (halted)", "a bolt halted"
                elif sts and all(s == "completed" for s in sts):
                    status, ev = "Implemented", "all referenced bolts completed"
                else:
                    status, ev = "In Progress", "bolts pending"
            verdict, claim_id = "(not bound)", "(none)"
            if binding:
                # a verdict is accepted ONLY from a line that also carries a
                # word-bounded claim id (round: prose "unresolved OQ tracking"
                # promoted to a verdict; `SEC-12` yielded claim C-12) — no
                # claim id on the line ⇒ not a verdict row ⇒ keep (not bound)
                for bline in binding.splitlines():
                    if fid_rx.search(bline):
                        vm = re.search(r"\b(CONFIRMED|CONFLICT|OQ)\b", bline)
                        cm = re.search(r"(?<![A-Za-z0-9])(C-\d+)\b", bline)
                        if vm and cm:
                            verdict, claim_id = vm.group(1), cm.group(1)
                            break
            # no DOTALL: the bullet group must stop at the first non-bullet
            # line (round: `(?s)` swallowed the whole flow body incl. mermaid)
            dod = re.search(r"(?m)^\*\*Definition of Done\*\*[^\n]*\n((?:[ \t]*[-*] .*\n)+)", body + "\n")
            desc = (dod.group(1).strip() if dod
                    else "(flow spec — see vault/04-flows.md)")
            ln1 = fl[:h.start()].count("\n") + 1
            ln2 = fl[:body_end].count("\n") + 1
            # priority stays honest: flows carry no Priority field — never default one
            fr_rows.append("| %s | %s | — | %s |" % (fid, title, status))
            d = FR_TPL
            for k, v in (("fr_id", fid), ("fr_title", title),
                         ("fr_description", desc),
                         ("fr_priority", "— (flows carry no priority field)"),
                         ("fr_status", status), ("status_evidence", ev),
                         ("binding_verdict", verdict), ("claim_id", claim_id),
                         ("unit_ids_csv", ", ".join(u["id"] for u in refs) or "(none)"),
                         ("bolt_status_summary", ", ".join(sorted({bolts.get(u["id"], {}).get("status", "pending") for u in refs})) or "n/a"),
                         ("fr_line_start", str(ln1)), ("fr_line_end", str(ln2))):
                d = d.replace("{{%s}}" % k, v)
            # the template hardcodes the legacy source path + an FR- id prefix;
            # the flows branch MUST rewrite both (round blocker: every modern
            # FSD stamped [Source: vault/02-functional.md:<04-flows line>] — a
            # fabricated citation the citation gate then failed on)
            d = d.replace("vault/02-functional.md", "vault/04-flows.md")
            d = d.replace("FR-%s" % fid, fid)
            fr_details.append(d.strip())
        if fr_rows:
            cite(5, "vault/04-flows.md")
if not fr_rows:
    p = pend("vault/02-functional.md (legacy) / vault/04-flows.md")
    fr_rows, fr_details = ["| — | %s | — | — |" % p], [p]
    pending_count -= 1  # counted once, not twice
    pending_count += 1
slots["section-5-fr-table"] = "\n".join(fr_rows)
slots["section-5-fr-details"] = "\n\n".join(fr_details)

# ── §6 NFR (over-complete: both sources labeled; duplicates are not fabrication) ──
nfr = md_section(fn, "NFR") or (md_section(fn, "Non-Functional Requirements") if fn else None)
# Modern-vault fallback (P4 repair): the modern NFR home is
# 06-constraints.md `## Non-functional requirements` (the table vault_md parses)
cons_doc = read(os.path.join(vault, "06-constraints.md"))
nfr_cons = md_section(cons_doc, "Non-functional requirements|Non-Functional Requirements") if cons_doc else None
def const_clauses(cat_words):
    if not const:
        return None
    out = []
    for m in re.finditer(r"(?m)^.*\[LOCKED\].*$", const):
        if any(w in m.group(0).lower() for w in cat_words):
            out.append(m.group(0).strip())
    return "\n".join(out) or None
# the constraints-table rows, keyword-routed per category; a row matching no
# category lands in Other (never dropped — honesty over tidiness)
def _cons_rows_by_cat():
    if not nfr_cons:
        return {}
    rows = [ln for ln in nfr_cons.splitlines()
            if ln.strip().startswith("|") and not re.match(r"^\s*\|[\s:|-]+\|\s*$", ln)]
    body = [r for r in rows[1:]] if rows else []
    cats = {"Performance": [], "Security": [], "Availability": [], "Other": []}
    kw = {"Performance": ("performance", "performa", "latency", "latensi", "throughput", "response", "load"),
          "Security": ("security", "keamanan", "auth", "encrypt", "enkripsi", "audit"),
          "Availability": ("availability", "ketersediaan", "uptime", "sla", "backup", "recovery")}
    for r in body:
        low = r.lower()
        placed = False
        for cat, words in kw.items():
            if any(w in low for w in words):
                cats[cat].append(r)
                placed = True
                break
        if not placed:
            cats["Other"].append(r)
    hdr = rows[0] + "\n" + "|" + "---|" * (rows[0].count("|") - 1) if rows else ""
    return {c: (hdr + "\n" + "\n".join(v)) for c, v in cats.items() if v}
cons_by_cat = _cons_rows_by_cat()
for slot, cat, words in (("section-6-performance-content", "Performance", ("performance", "latency", "throughput")),
                         ("section-6-security-content", "Security", ("security", "auth", "encrypt")),
                         ("section-6-availability-content", "Availability", ("availability", "uptime", "sla")),
                         ("section-6-other-constitution-content", "Other", ("compliance", "audit", "regulat"))):
    parts = []
    if nfr:
        sub = md_section("## X\n" + nfr, cat) or None
        if sub:
            parts.append("_Dari 02-functional §NFR:_\n\n" + sub)
    if cons_by_cat.get(cat):
        parts.append("_Dari 06-constraints §Non-functional requirements:_\n\n" + cons_by_cat[cat])
    cc = const_clauses(words)
    if cc:
        parts.append("_Dari constitution [LOCKED]:_\n\n" + cc)
    slots[slot] = "\n\n".join(parts) if parts else "(not specified)"
if nfr:
    cite(6, "vault/02-functional.md")
if cons_by_cat:
    cite(6, "vault/06-constraints.md")
if const and any("[LOCKED]" in (slots[s] or "") or "constitution" in (slots[s] or "") for s in
                 ("section-6-performance-content", "section-6-security-content",
                  "section-6-availability-content", "section-6-other-constitution-content")):
    cite(6, "vault/_meta/constitution.md")

# ── §7 Design / architecture ──
ents = md_section(cbmap, "Entities|Data models / Schemas|Data models") if cbmap else None
mods = md_section(cbmap, "Modules|Top-level structure") if cbmap else None
conf = md_section(binding, "Confirmed Claims") if binding else None
slots["section-7-entities-content"] = ents or ("[Pending — codebase-map.md not yet generated. Run scan-codebase.]" if not cbmap else "(no entities recorded)")
slots["section-7-modules-content"] = mods or ("[Pending — codebase-map.md not yet generated. Run scan-codebase.]" if not cbmap else "(no modules recorded)")
slots["section-7-binding-confirmed-content"] = conf or "[Pending — binding.md not yet generated. Run bind-codebase.]"
if not cbmap or not binding:
    pending_count += 1
if cbmap:
    cite(7, cb_rel)
if binding:
    cite(7, binding_rel)

# ── §8 API & data contracts ──
api = md_section(cbmap, "Public interfaces|Routes / Endpoints") if cbmap else None
rows8 = []
if api:
    tbl = [[c.strip() for c in row.split("|")] for row in re.findall(r"(?m)^\|(.+)\|\s*$", api)]
    hdr = tbl[0] if tbl else []
    hl = [h.lower() for h in hdr]
    def col(*names):
        for nm in names:
            if nm in hl:
                return hl.index(nm)
        return None
    i_name = col("symbol", "endpoint / function", "endpoint/function", "name")
    i_sig = col("signature")
    i_src = col("file", "source")
    for cells in tbl[1:]:
        if not cells or re.match(r"^[:\- ]*$", cells[0]) or [c.lower() for c in cells] == hl:
            continue
        if i_name is not None and i_sig is not None and len(cells) > max(i_name, i_sig):
            src_c = cells[i_src] if (i_src is not None and len(cells) > i_src) else "—"
            rows8.append("| %s | %s | %s |" % (cells[i_name], cells[i_sig], src_c))
        elif len(cells) >= 3:
            rows8.append("| %s | %s | %s |" % (cells[0], cells[1], cells[2]))
    cite(8, cb_rel)
slots["section-8-api-table"] = "\n".join(rows8) if rows8 else ("| — | %s | — |" % pend(cb_rel))
slots["section-8-entities-content"] = ents or (pend(cb_rel) if not cbmap else "(no entities recorded)")

# ── §9 Test plan ──
if mode == "pre-dev":
    r9 = []
    for u in units:
        r9.append("| %s | `%s`%s | Pending |" % (u["id"], u["cmd"] or "—", (" (expects: %s)" % u["expected"]) if u["expected"] else ""))
        cite(9, u["rel"])
    slots["section-9-pre-dev-table"] = "\n".join(r9) if r9 else "| — | Pending — units/ not yet generated | — |"
else:
    r9, concerns = [], []
    for u in units:
        b = bolts.get(u["id"])
        if b:
            emoji = "✅" if b["status"] == "completed" else "⚠️"
            r9.append("| %s | `%s` | %s %s | %s |" % (u["id"], u["cmd"] or "—", emoji, b["status"], b["commit"] or "—"))
            cite(9, "bolts/%s/bolt-report.md" % u["id"])
            if b["concern"]:
                concerns.append("**%s:** %s (raised by %s)" % (u["id"], b["concern"], b["agent"]))
        else:
            r9.append("| %s | `%s` | Pending — bolt not yet executed for %s | — |" % (u["id"], u["cmd"] or "—", u["id"]))
    slots["section-9-post-dev-table"] = "\n".join(r9) if r9 else "| — | Pending — units/ not yet generated | — | — |"
    slots["section-9-acceptance-concerns-content"] = "\n".join(concerns) if concerns else "(none)"

# ── §10 Risks & open issues ──
oq = read(os.path.join(vault, "03-open-questions.md"))
rows10 = []
if oq:
    for m in re.finditer(r"(?ms)^#{2,4}\s+(OQ-[\w-]+)\s*[—:-]?\s*(.*?)$(.*?)(?=^#{2,4}\s|\Z)", oq):
        blk = m.group(3)
        # field lines arrive as `**Priority:** P1` (colon inside the bold) or bare
        # `Priority: P1` — `\**` on both sides of the colon covers both shapes
        if re.search(r"(?mi)^\s*\**status\**\s*:\s*\**\s*resolved", blk):
            continue
        pr = re.search(r"(?mi)^\s*\**priority\**\s*:\s*\**\s*([^*\s]+)", blk)
        ct = re.search(r"(?mi)^\s*\**category\**\s*:\s*\**\s*([^*\s]+)", blk)
        rows10.append("| %s | %s | %s | %s |" % (m.group(1), m.group(2).strip() or "(untitled)",
                                                 pr.group(1) if pr else "—", ct.group(1) if ct else "—"))
    if rows10:
        cite(10, "vault/03-open-questions.md")
    elif oq.strip():
        # the file EXISTS with content but no `## OQ-...` heading parsed — a
        # sourced "(none)" would hide open risks (F7); surface the format gap
        rows10.append("| — | [Pending — 03-open-questions.md ada tetapi formatnya tidak dikenali (butuh heading `## OQ-NNN`) — tinjau manual] | — | — |")
        pending_count += 1
elif isinstance(vj.get("open_questions"), list):
    for q in vj["open_questions"]:
        # resolved + out_of_scope are closed decisions; `deferred` stays LISTED
        # (A6: a defer that never resurfaces is a silent assumption)
        if str(q.get("status", "")) in ("resolved", "out_of_scope"):
            continue
        # both OQ shapes: the derive-vault-json schema uses tag/text; an older
        # authored shape used id/question (P4 repair — tag/text vaults rendered
        # empty rows here); null/absent fields render an honest em-dash
        rows10.append("| %s | %s | %s | %s |" % (
            q.get("id") or q.get("tag") or "—",
            q.get("question") or q.get("text") or "—",
            q.get("priority") or "—", q.get("category") or "—"))
    cite(10, "vault.json")
if not rows10:
    # honesty backstop (round doc-16): a vault whose OQs live only in the
    # 00-index roll-up (no 03-open-questions.md, no readable vault.json) must
    # never render a sourced-looking "(none)" — surface the gap instead
    idx10 = read(os.path.join(vault, "00-index.md")) or ""
    if re.search(r"\bOQ-(?:[A-Z]+(?:-[A-Z0-9]+)*-)?\d+\b", idx10):
        rows10.append("| — | [Pending — OQ ada di 00-index roll-up tetapi vault.json tidak terbaca — jalankan derive-vault-json.sh lalu re-emit] | — | — |")
        pending_count += 1
slots["section-10-oq-table"] = "\n".join(rows10) if rows10 else "| — | (none) | — | — |"
bc = ["**%s:** %s (raised by %s)" % (uid, b["concern"], b["agent"]) for uid, b in sorted(bolts.items()) if b["concern"]]
slots["section-10-bolt-concerns-content"] = "\n".join(bc) if bc else "(none)"
for uid in sorted(bolts):
    if bolts[uid]["concern"]:
        cite(10, "bolts/%s/bolt-report.md" % uid)
if nongoals:
    slots["section-10-out-of-scope-content"] = ("Item berikut dinyatakan di luar lingkup (dari §Non-Goals) — risiko scope creep bila diminta belakangan:\n\n" + nongoals)
    cite(10, "vault/01-overview.md")
else:
    slots["section-10-out-of-scope-content"] = "(none)"

# ── Citation footers ──
for n in range(1, 11):
    if not sty["include_citation_footnotes"]:
        slots["section-%d-citations" % n] = ""
        continue
    if cites[n]:
        lines = ["**Sources for this section:**"]
        for i, (p, lr) in enumerate(cites[n], 1):
            loc = (":L%d-L%d" % lr) if lr else ""
            lines.append("- [%d] `%s%s` (sha256: `pending`)" % (i, p, loc))
        slots["section-%d-citations" % n] = "\n".join(lines)
    else:
        slots["section-%d-citations" % n] = "**Sources for this section:** _(no source artifacts cited — see [Pending] markers above for missing sources)_"

# ── Assemble ──
head = doc_head
for k, v in (("project_name", project), ("vault_version", vver), ("generation_date_iso", iso),
             ("generation_date_human", human), ("styling.classification", sty["classification"]),
             ("vault_author", author), ("emit_mode", "pre-development" if mode == "pre-dev" else "post-development"),
             ("emit_mode_label", "Pre-development" if mode == "pre-dev" else "Post-development"),
             ("mega_sdd_version", plugin_ver), ("plugin_version", plugin_ver),
             ("vault_path", os.path.relpath(vault, cwd).replace(os.sep, "/"))):
    head = head.replace("{{%s}}" % k, str(v))

# drift callouts: `DRIFT <section> <path> <old12> <new12>` / `GONE <section> <path> <old12>`
drift_by_sec = {}
for ln in drift_out.splitlines():
    parts = ln.split()
    if len(parts) >= 4 and parts[0] in ("DRIFT", "GONE"):
        secm = re.search(r"(\d+)", parts[1])
        if secm:
            n = int(secm.group(1))
            if parts[0] == "DRIFT" and len(parts) >= 5:
                drift_by_sec.setdefault(n, []).append(
                    "> ⚠ **Updated since last emit** — `%s` was sha256 `%s`, now `%s`. Section regenerated." % (parts[2], parts[3], parts[4]))
            else:
                drift_by_sec.setdefault(n, []).append(
                    "> ⚠ **Updated since last emit** — `%s` (sha256 `%s`) is GONE. Section regenerated." % (parts[2], parts[3]))

out = [head.rstrip(), ""]
emitted = 0
for n in range(1, 11):
    if n not in want:
        continue
    skel = SEC[n][0]
    if n == 9:
        skel = (SEC9_PRE or SEC[9][0]) if mode == "pre-dev" else (SEC9_POST or SEC[9][-1])
    body = re.sub(r"\{\{([a-z0-9_.-]+)\}\}",
                  lambda m: slots.get(m.group(1), m.group(0)), skel)
    if n in drift_by_sec:
        first_nl = body.find("\n")
        body = body[:first_nl + 1] + "\n" + "\n".join(drift_by_sec[n]) + "\n" + body[first_nl + 1:]
    out.append(body.strip())
    out.append("")
    emitted += 1

os.makedirs(os.path.join(vault, "fsd"), exist_ok=True)
target = os.path.join(vault, "fsd", "FSD.md")
tmp = target + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out).rstrip() + "\n")
os.replace(tmp, target)

final_text = read(target) or ""
leftover = re.findall(r"\{\{[a-z0-9_.-]+\}\}", final_text)
pending_count = final_text.count("[Pending —")  # single source of truth (ADV-017)
print("fsd-core: mode=%s sections=%d/10 pending=%d drift=%d model_slots=0%s"
      % (mode, emitted, pending_count, sum(len(v) for v in drift_by_sec.values()),
         (" LEFTOVER_SLOTS=" + ",".join(sorted(set(leftover))) if leftover else "")))
for ln in drift_out.splitlines():
    print(ln)
sys.exit(0)
PYEOF
