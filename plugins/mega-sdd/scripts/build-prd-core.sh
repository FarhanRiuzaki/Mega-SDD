#!/usr/bin/env bash
# build-prd-core.sh — deterministic builder of the PRD mechanical body (tranche 5e,
# spec docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md §5e).
#
# Same seam as build-fsd-core.sh, with one honest difference: the PRD carries
# genuinely-synthetic slots (Indonesian narrative weaving; reverse-mode actor
# identification from prose; new Mermaid for a KB workflow that has NO diagram)
# — those are LEFT as {{...}} markers the model fills via targeted Edits, and
# this script prints `model_slots=<n> (<names>)` so the controller knows exactly
# what remains. Everything mechanical is pre-filled:
#   forward: §2 actor rows from squads.yaml; §3 FR id/title + FIRST paragraph
#            VERBATIM (extraction, not model summarization) + flow inventory;
#            §4 vault 04-flows Mermaid VERBATIM; §5 NFR categories +
#            constitution [LOCKED] clauses; §6 unresolved-OQ table
#   reverse: §3 per-domain MARKER-CARRYING claim harvest (over-complete BY
#            DESIGN — the model's authority over harvested rows is DELETE/
#            REFORMAT-only; adding an uncited row is fabrication and stays
#            policed by build-citation-map.sh + check-prd-markers.sh); §4 KB
#            workflow Mermaid VERBATIM (diagram-less workflows become model
#            slots carrying the recorded steps as quoted material); §5 keyword-
#            filtered NFR-ish claims WITH markers; §6 every [OPEN] claim
# Grammar identical to the model-authored era: `(sha256: pending)` literals,
# `[Pending — …]` markers, markers VERBATIM. Downstream (slot scan, citation
# map --doc=prd, check-prd-markers.sh, md2pdf, refresh-doc-stamps.sh) unchanged.
#
# Usage:
#   build-prd-core.sh --out-root=<dir> --cwd=<project-root> \
#       --mode=forward|reverse [--vault=<vault-dir>] [--kb=<kb-root>] [--quiet]
# Exit: 0 = PRD.md written; ONE summary line
#         `prd-core: mode=<m> pending=<k> markers=<v>/<i>/<o> model_slots=<n> (<names>)`
#         plus drift lines verbatim
#       2 = cannot run (usage / sources or template missing)
set -uo pipefail

OUTROOT=""; CWD=""; MODE=""; VAULT=""; KB=""; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --out-root=*) OUTROOT="${arg#*=}" ;;
    --cwd=*) CWD="${arg#*=}" ;;
    --mode=*) MODE="${arg#*=}" ;;
    --vault=*) VAULT="${arg#*=}" ;;
    --kb=*) KB="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
[ -n "$OUTROOT" ] || { echo "ERROR: --out-root=<dir> required" >&2; exit 2; }
[ -n "$CWD" ] && [ -d "$CWD" ] || { echo "ERROR: --cwd=<project-root> required" >&2; exit 2; }
case "$MODE" in forward|reverse) ;; *) echo "ERROR: --mode=forward|reverse required" >&2; exit 2 ;; esac
[ "$MODE" = "forward" ] && [ -z "$VAULT" ] && VAULT="$OUTROOT"
TPL="${SCRIPT_DIR}/../skills/emit-prd/references/prd-template.md"
[ -f "$TPL" ] || { echo "ERROR: prd-template.md missing at $TPL" >&2; exit 2; }
PLUGIN_VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${SCRIPT_DIR}/../.claude-plugin/plugin.json" 2>/dev/null | head -1)
DRIFT_OUT=$(bash "${SCRIPT_DIR}/check-citation-drift.sh" --vault="$OUTROOT" --cwd="$CWD" --doc=prd 2>/dev/null || true)

OUTROOT="$OUTROOT" CWD="$CWD" MODE="$MODE" VAULT="$VAULT" KB="$KB" QUIET="$QUIET" \
TPL="$TPL" PLUGIN_VER="${PLUGIN_VER:-unknown}" DRIFT_OUT="$DRIFT_OUT" python3 <<'PYEOF'
import glob, json, os, re, sys
from datetime import datetime, timezone

outroot = os.path.abspath(os.environ["OUTROOT"])
cwd = os.path.abspath(os.environ["CWD"])
mode = os.environ["MODE"]
vault = os.path.abspath(os.environ["VAULT"]) if os.environ.get("VAULT") else None
kb = os.environ.get("KB") or ""
tpl_path = os.environ["TPL"]
drift_out = os.environ.get("DRIFT_OUT", "")
plugin_ver = os.environ["PLUGIN_VER"]

def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return None

def rel(p):
    return os.path.relpath(p, cwd).replace(os.sep, "/")

# KB root resolution (canonical → legacy)
if mode == "reverse":
    # canonical four, IDENTICAL to check-prd-markers.sh — a divergent probe
    # either kills reverse mode on a legacy layout or harvests a KB the marker
    # rail cannot see (ADV-006)
    cands = [kb] if kb else [os.path.join(cwd, ".mega-sdd", "knowledge-base"),
                             os.path.join(cwd, "docs", "knowledge-base"),
                             os.path.join(cwd, "docs", "mega-sdd", "knowledge-base"),
                             os.path.join(cwd, "old-reference", "knowledge-base")]
    kb_root = next((c for c in cands if c and os.path.isdir(c)), None)
    if not kb_root:
        print("ERROR: reverse mode but no knowledge-base root found", file=sys.stderr)
        sys.exit(2)
else:
    kb_root = None
    if not vault or not os.path.isdir(vault):
        print("ERROR: forward mode requires --vault (or --out-root pointing at the vault)", file=sys.stderr)
        sys.exit(2)

tpl = read(tpl_path) or ""
def fences_under(n):
    m = re.search(r"(?ms)^## Section %d\b[^\n]*\n(.*?)(?=^## Section \d|^## Slot semantics|\Z)" % n, tpl)
    return re.findall(r"(?ms)^```markdown\n(.*?)^```", m.group(1)) if m else []
doc_head = (re.findall(r"(?ms)^```markdown\n(.*?)^```", tpl.split("## Section 1")[0]) or [""])[0]
legend = ""
lm = re.search(r"(?ms)\*\*Marker legend.*?```markdown\n(.*?)^```", tpl.split("## Section 1")[0])
if lm:
    legend = lm.group(1).strip()
SEC = {n: fences_under(n) for n in range(1, 7)}
if not doc_head or any(not SEC[n] for n in range(1, 7)):
    print("ERROR: prd-template.md fenced skeletons not parseable", file=sys.stderr)
    sys.exit(2)

MARKER = re.compile(r"\[(VERIFIED|INFERRED|OPEN)\]")
mcount = {"VERIFIED": 0, "INFERRED": 0, "OPEN": 0}

def claim_lines(text):
    """(lineno, line) for every BULLET line carrying a marker, OUTSIDE code
    fences (F4: a fence-quoted example must never become a PRD requirement —
    no downstream rail catches it, the KB line really carries the marker)."""
    in_fence = False
    for i, ln in enumerate((text or "").split("\n"), 1):
        if ln.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if MARKER.search(ln) and ln.strip().startswith(("-", "*")):
            yield i, ln
pending_count = 0
model_slots = []
cites = {n: [] for n in range(1, 7)}
def cite(n, path):
    if path not in cites[n]:
        cites[n].append(path)
slots = {}

def md_section(text, name):
    if not text:
        return None
    m = re.search(r"(?ims)^(#{2,3})[ \t]+%s\b[^\n]*\n(.*?)(?=^\1[ \t]|^#{1,2}[ \t]|\Z)" % re.escape(name), text)
    return m.group(2).strip() if m else None

# §1 — narrative weaving: ALWAYS model slots (both modes)
slots["section-1-background"] = "{{section-1-background}}"
slots["section-1-purpose"] = "{{section-1-purpose}}"
model_slots += ["section-1-background", "section-1-purpose"]
if mode == "forward":
    ov = read(os.path.join(vault, "01-overview.md"))
    if ov:
        cite(1, "vault/01-overview.md")
else:
    for c in ("README.md",):
        if os.path.isfile(os.path.join(kb_root, c)):
            cite(1, rel(os.path.join(kb_root, c)))

# §2 — actors
if mode == "forward":
    rows2 = []
    sq = read(os.path.join(vault, "_meta", "squads.yaml"))
    if sq:
        # entry-split first — a lazy multiline regex bled fields across entries (F5)
        for entry in re.split(r"(?m)^-\s+", sq)[1:]:
            rm = re.match(r"(?:squad|role):\s*(.+)", entry)
            if not rm:
                continue
            dm = re.search(r"(?m)^\s*responsibility:\s*(.+)$", entry) or re.search(r"(?m)^\s*lead_name:\s*(.+)$", entry)
            rows2.append("| %s | %s | `_meta/squads.yaml` |" % (rm.group(1).strip(), (dm.group(1).strip() if dm else "")))
        cite(2, "vault/_meta/squads.yaml")
    if rows2:
        slots["section-2-actors-table"] = "\n".join(rows2)
    else:
        slots["section-2-actors-table"] = "{{section-2-actors-table}}"
        model_slots.append("section-2-actors-table")
else:
    slots["section-2-actors-table"] = "{{section-2-actors-table}}"
    model_slots.append("section-2-actors-table")

# §3 — functional requirements
if mode == "forward":
    fn = read(os.path.join(vault, "02-functional.md"))
    fl = read(os.path.join(vault, "04-flows.md"))
    parts = []
    if fn:
        heads = list(re.finditer(r"(?m)^(#{2,3})\s+(FR-\d+)\s*[—:-]?\s*(.*)$", fn))
        for i, h in enumerate(heads):
            body = fn[h.end():heads[i + 1].start() if i + 1 < len(heads) else len(fn)].strip()
            first_para = body.split("\n\n")[0].strip() if body else "(tanpa deskripsi)"
            first_para = re.sub(r"(?m)^\*\*Priority:\*\*.*$", "", first_para).strip() or "(tanpa deskripsi)"
            ln = fn[:h.start()].count("\n") + 1
            parts.append("- **%s — %s**: %s [Source: vault/02-functional.md:L%d (sha256: pending)]"
                         % (h.group(2), h.group(3).strip() or "(untitled)", first_para, ln))
        cite(3, "vault/02-functional.md")
    if fl:
        finv = ["- %s — %s" % (m.group(1), m.group(2).strip())
                for m in re.finditer(r"(?m)^#{2,3}\s+(F-[\w-]+)\s*[—:-]?\s*(.*)$", fl)]
        if finv:
            parts.append("\n**Inventori flow (diagram di §4):**\n" + "\n".join(finv))
            cite(3, "vault/04-flows.md")
    slots["section-3-fr-content"] = "\n".join(parts) if parts else "[Pending — vault/02-functional.md not yet generated]"
    if not parts:
        pending_count += 1
else:
    groups = []
    dom_files = sorted(glob.glob(os.path.join(kb_root, "10-domains", "*.md")) +
                       glob.glob(os.path.join(kb_root, "40-business-rules", "*.md")))
    for df in dom_files:
        t = read(df) or ""
        lines = []
        for i, ln in claim_lines(t):
            claim = ln.strip().lstrip("-* ").strip()
            for mk in MARKER.findall(ln):
                mcount[mk] += 1
            lines.append("- %s [Source: %s:L%d (sha256: pending)]" % (claim, rel(df), i))
        if lines:
            groups.append("### %s\n\n%s" % (os.path.splitext(os.path.basename(df))[0], "\n".join(lines)))
            cite(3, rel(df))
    slots["section-3-fr-content"] = "\n\n".join(groups) if groups else "[Pending — KB domain files belum ada]"
    if not groups:
        pending_count += 1

# §4 — user journeys (Mermaid mandate: existing diagrams VERBATIM, never redrawn)
def mermaid_blocks(text):
    return re.findall(r"(?ms)^```mermaid\n.*?^```", text or "")
journeys = []
jn = 0
if mode == "forward":
    fl = read(os.path.join(vault, "04-flows.md"))
    if fl:
        flows = list(re.finditer(r"(?ms)^#{2,3}\s+(F-[\w-]+)\s*[—:-]?\s*(.*?)$(.*?)(?=^#{2,3}\s+F-|\Z)", fl))
        flows.sort(key=lambda m: (0 if m.group(1).startswith("F-U-") else 1))
        for m in flows:
            blocks = mermaid_blocks(m.group(3))
            jn += 1
            if blocks:
                journeys.append("### UJ-%d — %s\n\nAlur berikut dibawa VERBATIM dari `vault/04-flows.md` (%s).\n\n%s\n\n[Source: vault/04-flows.md (sha256: pending)]"
                                % (jn, m.group(2).strip() or m.group(1), m.group(1), blocks[0]))
            else:
                journeys.append("### UJ-%d — %s\n\n[Pending — flow %s belum punya diagram Mermaid di 04-flows.md]"
                                % (jn, m.group(2).strip() or m.group(1), m.group(1)))
                pending_count += 1
        cite(4, "vault/04-flows.md")
else:
    for wf in sorted(glob.glob(os.path.join(kb_root, "20-workflows", "*.md"))):
        t = read(wf) or ""
        title = (re.search(r"(?m)^#\s+(.+)$", t) or [None, os.path.basename(wf)])[1]
        blocks = mermaid_blocks(t)
        jn += 1
        if blocks:
            bl_ln = t[:t.find(blocks[0])].count("\n") + 1
            journeys.append("### UJ-%d — %s\n\nAlur berikut dibawa VERBATIM dari `%s`.\n\n%s\n\n[Source: %s:L%d (sha256: pending)]"
                            % (jn, title.strip(), rel(wf), blocks[0], rel(wf), bl_ln))
        else:
            slug = re.sub(r"[^a-z0-9-]+", "-", os.path.splitext(os.path.basename(wf))[0].lower()).strip("-")
            base_slug, k = slug, 2
            while ("journey-%s" % slug) in model_slots:
                slug = "%s-%d" % (base_slug, k)  # F6: same-basename workflows must not collide
                k += 1
            steps = md_section(t, "Steps") or md_section(t, "Stages") or "(langkah tidak tercatat terstruktur — baca file sumber)"
            journeys.append("### UJ-%d — %s\n\n_Workflow ini TIDAK punya diagram di KB — gambar Mermaid BARU secara ketat dari langkah tercatat di bawah (langkah di luar KB tidak boleh muncul):_\n\n> %s\n\n{{journey-%s}}\n\n[Source: %s:L1 (sha256: pending)]"
                            % (jn, title.strip(), steps.replace("\n", "\n> "), slug, rel(wf)))
            model_slots.append("journey-%s" % slug)
        cite(4, rel(wf))
slots["section-4-journeys"] = "\n\n".join(journeys) if journeys else "[Pending — belum ada flow/workflow di sumber]"
if not journeys:
    pending_count += 1

# §5 — NFR
CATS = (("section-5-performance", ("performance", "latency", "throughput", "p95", "p99")),
        ("section-5-security", ("security", "auth", "encrypt", "tls", "audit trail")),
        ("section-5-availability", ("availability", "uptime", "sla", "failover")),
        ("section-5-other", ("compliance", "regulat", "audit", "ojk", "bi-")))
if mode == "forward":
    fn = read(os.path.join(vault, "02-functional.md"))
    const = read(os.path.join(vault, "_meta", "constitution.md"))
    nfr = md_section(fn, "NFR") or (md_section(fn, "Non-Functional Requirements") if fn else None)
    for slot, words in CATS:
        parts = []
        if nfr:
            sub = md_section("## X\n" + nfr, slot.split("-")[-1].capitalize())
            if sub:
                parts.append(sub)
        if const:
            cc = [m.group(0).strip() for m in re.finditer(r"(?m)^.*\[LOCKED\].*$", const)
                  if any(w in m.group(0).lower() for w in words)]
            if cc:
                parts.append("_Dari constitution [LOCKED]:_\n\n" + "\n".join(cc))
        slots[slot] = "\n\n".join(parts) if parts else "(belum terspesifikasi di sumber)"
    if nfr:
        cite(5, "vault/02-functional.md")
    if const:
        cite(5, "vault/_meta/constitution.md")
else:
    all_claims = []
    for df in sorted(glob.glob(os.path.join(kb_root, "*", "*.md"))):
        t = read(df) or ""
        for i, ln in claim_lines(t):
            all_claims.append((ln.strip().lstrip("-* ").strip(), rel(df), i))
    for slot, words in CATS:
        hits = ["- %s [Source: %s:L%d (sha256: pending)]" % c for c in all_claims
                if any(w in c[0].lower() for w in words)]
        slots[slot] = "\n".join(hits) if hits else "(belum terspesifikasi di sumber)"
        for h in {c[1] for c in all_claims if any(w in c[0].lower() for w in words)}:
            cite(5, h)

# §6 — open items
rows6 = []
if mode == "forward":
    oq = read(os.path.join(vault, "03-open-questions.md"))
    if oq:
        for m in re.finditer(r"(?ms)^#{2,4}\s+(OQ-[\w-]+)\s*[—:-]?\s*(.*?)$(.*?)(?=^#{2,4}\s|\Z)", oq):
            if re.search(r"(?mi)^\s*\**status\**\s*:\s*\**\s*resolved", m.group(3)):
                continue
            pr = re.search(r"(?mi)^\s*\**priority\**\s*:\s*\**\s*([^*\s]+)", m.group(3))
            rows6.append("| %s | %s | %s | `vault/03-open-questions.md` |"
                         % (m.group(1), m.group(2).strip() or "(untitled)", pr.group(1) if pr else "—"))
        if rows6:
            cite(6, "vault/03-open-questions.md")
    if not rows6:
        # the canonical OQ home is vault.json.open_questions[] (ADV-009 — a
        # real vault has no 03-open-questions.md; "(tidak ada)" would be false)
        vj6 = {}
        try:
            vj6 = json.load(open(os.path.join(vault, "vault.json")))
        except Exception:
            pass
        for q in (vj6.get("open_questions") or []):
            # resolved + out_of_scope are closed; `deferred` stays listed (A6)
            if str(q.get("status", "")) in ("resolved", "out_of_scope"):
                continue
            # both OQ shapes: derive-vault-json emits tag/text; an older authored
            # shape used id/question (P4 repair — tag/text vaults rendered empty);
            # null/absent fields render an honest em-dash
            rows6.append("| %s | %s | %s | `vault.json` |" % (
                q.get("id") or q.get("tag") or "—",
                q.get("question") or q.get("text") or "—",
                q.get("priority") or "—"))
        if rows6:
            cite(6, "vault.json")
else:
    n6 = 0
    for df in sorted(glob.glob(os.path.join(kb_root, "*", "*.md"))):
        t = read(df) or ""
        for i, ln in claim_lines(t):
            if "[OPEN]" in ln:
                n6 += 1
                rows6.append("| KB-OPEN-%d | %s | — | `%s:L%d` |"
                             % (n6, ln.strip().lstrip("-* ").strip(), rel(df), i))
                cite(6, rel(df))
slots["section-6-open-items"] = "\n".join(rows6) if rows6 else "| — | _(tidak ada open item di sumber)_ | — | — |"

# citation footers
for n in range(1, 7):
    if cites[n]:
        lines = ["**Sumber bagian ini:**"]
        for i, p in enumerate(cites[n], 1):
            lines.append("- [%d] `%s` (sha256: `pending`)" % (i, p))
        slots["section-%d-citations" % n] = "\n".join(lines)
    else:
        slots["section-%d-citations" % n] = "**Sumber bagian ini:** _(belum ada sumber dikutip — lihat marker [Pending] / slot model di atas)_"

# assemble
vj = {}
if vault:
    try:
        vj = json.load(open(os.path.join(vault, "vault.json")))
    except Exception:
        pass
project = vj.get("project_name") or os.path.basename(cwd)
now = datetime.now(timezone.utc)
head = doc_head
# The doc-control Source stamp must point at a FILE — build-citation-map.sh
# hashes file bytes and its `**Source vault:**` special case does not apply to
# the PRD wording (pre-5e latent gap: the template's dir-valued {{source_root}}
# could never stamp; surfaced by the builder, fixed here at the producer).
if mode == "forward":
    src_root = rel(os.path.join(vault, "vault.json"))
else:
    kb_readme = os.path.join(kb_root, "README.md")
    if not os.path.isfile(kb_readme):
        # a KB dir without README must not mint an unresolvable citation
        others = sorted(glob.glob(os.path.join(kb_root, "*", "*.md"))) or sorted(glob.glob(os.path.join(kb_root, "*.md")))
        kb_readme = others[0] if others else kb_readme
    src_root = rel(kb_readme)
for k, v in (("project_name", project), ("source_version", str(vj.get("vault_version", "0.1"))),
             ("generation_date_iso", now.isoformat().replace("+00:00", "Z")),
             ("generation_date_human", now.strftime("%d %B %Y")),
             ("emit_mode", mode), ("emit_mode_label", "Forward (dari vault)" if mode == "forward" else "Reverse (dari knowledge base)"),
             ("mega_sdd_version", plugin_ver), ("plugin_version", plugin_ver),
             ("source_root", src_root)):
    head = head.replace("{{%s}}" % k, str(v))

out = [head.rstrip(), ""]
if mode == "reverse" and legend:
    out += [legend, ""]

# drift callouts (grammar shared with the FSD lane)
drift_by_sec = {}
for ln in drift_out.splitlines():
    parts = ln.split()
    if len(parts) >= 4 and parts[0] in ("DRIFT", "GONE"):
        sm = re.search(r"(\d+)", parts[1])
        if sm:
            n = int(sm.group(1))
            if parts[0] == "DRIFT" and len(parts) >= 5:
                drift_by_sec.setdefault(n, []).append("> ⚠ **Updated since last emit** — `%s` was sha256 `%s`, now `%s`. Section regenerated." % (parts[2], parts[3], parts[4]))
            else:
                drift_by_sec.setdefault(n, []).append("> ⚠ **Updated since last emit** — `%s` (sha256 `%s`) is GONE. Section regenerated." % (parts[2], parts[3]))

for n in range(1, 7):
    body = re.sub(r"\{\{([a-z0-9_.-]+)\}\}",
                  lambda m: slots.get(m.group(1), m.group(0)), SEC[n][0])
    if n in drift_by_sec:
        fnl = body.find("\n")
        body = body[:fnl + 1] + "\n" + "\n".join(drift_by_sec[n]) + "\n" + body[fnl + 1:]
    out.append(body.strip())
    out.append("")

os.makedirs(os.path.join(outroot, "prd"), exist_ok=True)
target = os.path.join(outroot, "prd", "PRD.md")
tmp = target + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out).rstrip() + "\n")
os.replace(tmp, target)

print("prd-core: mode=%s pending=%d markers=%d/%d/%d model_slots=%d (%s)"
      % (mode, pending_count, mcount["VERIFIED"], mcount["INFERRED"], mcount["OPEN"],
         len(model_slots), ",".join(model_slots) or "-"))
for ln in drift_out.splitlines():
    print(ln)
sys.exit(0)
PYEOF
