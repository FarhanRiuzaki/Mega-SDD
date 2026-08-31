#!/usr/bin/env bash
# render-html.sh — deterministic md → self-contained HTML renderer (7.16.0,
# research/2026-08-31-render-html-standard.md + spec of the same date).
#
# The md stays the ONLY ground truth: this script wraps the RAW markdown into
# assets/render-html/template.html (vendored marked.js + mermaid.js render it
# client-side), so the HTML can never drift from its source — re-run any time.
# Zero model tokens. Offline by construction (no external requests, system
# fonts, vendored pinned JS).
#
# Usage:
#   render-html.sh <file.md>            → <parent>/html/<stem>.html
#   render-html.sh <dir> --index        → <dir>/html/*.html + index.html
#   flags: --out=<path> (file or dir)   --assets-dir  (shared assets/ folder
#          next to the outputs instead of inlining ~2.6MB per file — for
#          multi-file KB bundles)       --cwd=<project-root>
#
# Standard enforced BY the template, not per-run taste (research §2–§4, §6):
# per-doc-type lens (badge + audience + summary strip), fixed page anatomy,
# diagram budget ADVISORY (never blocks — md is ground truth), natural mixed
# ID-EN template strings. Exit 0 = rendered; 2 = usage/missing input.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS="$SCRIPT_DIR/../assets/render-html"
IN=""; OUT=""; INDEX=0; ASSETS_DIR=0; CWD="$PWD"
for arg in "$@"; do case "$arg" in
  --out=*) OUT="${arg#*=}";;
  --index) INDEX=1;;
  --assets-dir) ASSETS_DIR=1;;
  --cwd=*) CWD="${arg#*=}";;
  --*) echo "usage: render-html.sh <file.md|dir> [--index] [--out=<path>] [--assets-dir] [--cwd=<root>]" >&2; exit 2;;
  *) IN="$arg";;
esac; done
[ -n "$IN" ] && [ -e "$IN" ] || { echo "usage: render-html.sh <file.md|dir> [--index] [--out=<path>] [--assets-dir] [--cwd=<root>]" >&2; exit 2; }
[ -f "$ASSETS/template.html" ] && [ -f "$ASSETS/marked.min.js" ] && [ -f "$ASSETS/mermaid.min.js" ] \
  || { echo "render-html: assets/render-html incomplete (template + marked + mermaid) — broken install" >&2; exit 2; }

export MEGA_SDD_LIB_DIR="$SCRIPT_DIR/_lib"
IN="$IN" OUT="$OUT" INDEX="$INDEX" ASSETS_DIR="$ASSETS_DIR" CWD="$CWD" ASSETS="$ASSETS" SCRIPT_DIR="$SCRIPT_DIR" python3 - <<'PYEOF'
import glob, hashlib, html, json, os, re, sys

IN = os.path.abspath(os.environ["IN"]); OUT = os.environ["OUT"]
INDEX = os.environ["INDEX"] == "1"; SHARED = os.environ["ASSETS_DIR"] == "1"
CWD = os.path.abspath(os.environ["CWD"]); A = os.environ["ASSETS"]
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
try:
    import plugin_meta
    STAMP = plugin_meta.stamp(os.environ["SCRIPT_DIR"])
except Exception:
    STAMP = {"plugin_version": "unknown", "written_at": "unknown"}
TEMPLATE = open(os.path.join(A, "template.html"), encoding="utf-8").read()
PROJECT = os.path.basename(CWD) or "proyek"

# ── lens per jenis dokumen (research §2) — deteksi dari path/nama, fail-open ke generic ──
LENSES = {
    "kb-module": ("PRD-KONTRAK · MODULE", "dev team yang mau paham module ini tanpa baca source legacy-nya"),
    "binding":   ("BINDING · SPEC↔CODE", "reviewer yang mau lihat klaim mana yang kebukti di kode, mana yang bentrok"),
    "units":     ("UNITS · WORK ORDER", "dev yang mau tahu urutan kerja + dependensi antar unit"),
    "drift":     ("DRIFT REPORT", "siapa pun yang mau cek seberapa jauh kode sudah jalan dari vault"),
    "adr":       ("ADR · KEPUTUSAN ARSITEKTUR", "yang mau paham kenapa arsitektur target dipilih (dan apa yang ditolak)"),
    "vault":     ("VAULT · INTENT", "dev team — kontrak intent proyek ini dalam satu halaman"),
    "index":     ("INDEX", "pintu masuk — semua dokumen render dalam satu daftar"),
    "generic":   ("DOKUMEN", "pembaca dokumen ini dalam bentuk web, offline"),
}
def detect_lens(path):
    b = os.path.basename(path); p = path.replace(os.sep, "/")
    if b.endswith(".prd.md") or "/knowledge-base/modules/" in p: return "kb-module"
    if b == "binding.md": return "binding"
    if b == "_index.md" and "/units" in p: return "units"
    if b.startswith("DRIFT-REPORT"): return "drift"
    if re.match(r"ADR-\d+", b): return "adr"
    if b in ("vault.md", "model.md", "flows.md", "constraints.md"): return "vault"
    return "generic"

# ── summary strip per lens — hitungan regex sederhana, gagal → tile dihilangkan ──
def tiles(lens, md):
    out = []
    def tile(n, label):
        if n: out.append((n, label))
    fences = re.findall(r"```mermaid\n(.*?)```", md, re.DOTALL) + \
             re.findall(r"<pre class=\"mermaid\">(.*?)</pre>", md, re.DOTALL)
    if lens == "kb-module":
        tile(md.count("[LOCKED]"), "locked"); tile(md.count("[INTENT]"), "intent")
        tile(md.count("[ARTIFACT]"), "artifact"); tile(len(set(re.findall(r"\bOQ-[\w-]+", md))), "open questions")
    elif lens == "binding":
        tile(len(re.findall(r"\bCONFIRMED\b", md)), "confirmed")
        tile(len(re.findall(r"\bCONFLICT\b", md)), "conflict")
        tile(len(set(re.findall(r"\bOQ-[\w-]+", md))), "oq")
    elif lens == "units":
        tile(len(set(re.findall(r"\bU-\d{3}\b", md))), "unit")
    tile(len(fences), "diagram")
    tile(len(re.findall(r"(?m)^##\s", md)), "bagian")
    return "" if not out else '<div class="strip">' + "".join(
        f'<div class="st"><span class="st-n">{n}</span><span class="st-l">{html.escape(l)}</span></div>'
        for n, l in out) + "</div>"

# ── budget diagram (research §4) — advisory, tidak pernah blok ──
def budget_warnings(md):
    warns = []
    for i, body in enumerate(re.findall(r"```mermaid\n(.*?)```", md, re.DOTALL), 1):
        edges = len(re.findall(r"-->|---(?!-)|-\.->|==>|->>|--\)|<-->", body))
        if edges > 20:
            warns.append(f"diagram #{i}: ±{edges} edge — kegedean buat sekali baca, mending dipecah / pakai subgraph")
        parts = len(re.findall(r"(?m)^\s*participant\s", body))
        if parts > 7:
            warns.append(f"diagram #{i}: {parts} participant di sequence — di atas budget 7, pecah per interaksi")
    return warns

def render_one(src, out_path, assets_html):
    md = open(src, encoding="utf-8", errors="replace").read()
    lens = detect_lens(src)
    # frontmatter = metadata mesin, bukan bacaan — jangan ikut render
    # (sha + hitungan strip tetap dari file utuh, ground truth tidak berubah)
    display_md = re.sub(r"\A---\n.*?\n---\n", "", md, count=1, flags=re.DOTALL)
    m = re.search(r"(?m)^#\s+(.+)$", md)
    title = m.group(1).strip() if m else os.path.splitext(os.path.basename(src))[0]
    badge, audience = LENSES[lens]
    sha = hashlib.sha256(md.encode()).hexdigest()[:12]
    rel = os.path.relpath(src, CWD).replace(os.sep, "/") if src.startswith(CWD) else os.path.basename(src)
    warns = budget_warnings(md)
    warn_html = "" if not warns else ('<div class="warnbar"><b>Budget diagram:</b> ' +
                                      " · ".join(html.escape(w) for w in warns) + "</div>")
    page = (TEMPLATE
            .replace("@@TITLE@@", html.escape(title))
            .replace("@@BADGE@@", html.escape(badge))
            .replace("@@AUDIENCE@@", html.escape(audience))
            .replace("@@STRIP@@", tiles(lens, md))
            .replace("@@WARNINGS@@", warn_html)
            .replace("@@SRC_PATH@@", html.escape(rel))
            .replace("@@SRC_SHA@@", sha)
            .replace("@@PLUGIN_VER@@", html.escape(str(STAMP.get("plugin_version"))))
            .replace("@@RENDERED_AT@@", html.escape(str(STAMP.get("written_at"))[:10]))
            .replace("@@PROJECT@@", html.escape(PROJECT))
            .replace("@@ASSETS@@", assets_html)
            # </script> di dalam md tidak boleh menutup tag script pembungkus
            .replace("@@MD_JSON@@", json.dumps(display_md).replace("</", "<\\/")))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(page)
    return title, lens, warns

def assets_for(out_dir):
    if not SHARED:
        return ("<script>\n" + open(os.path.join(A, "marked.min.js"), encoding="utf-8").read() +
                "\n</script>\n<script>\n" + open(os.path.join(A, "mermaid.min.js"), encoding="utf-8").read() +
                "\n</script>")
    ad = os.path.join(out_dir, "assets"); os.makedirs(ad, exist_ok=True)
    for f in ("marked.min.js", "mermaid.min.js"):
        dst = os.path.join(ad, f)
        if not os.path.exists(dst):
            with open(os.path.join(A, f), "rb") as s, open(dst, "wb") as d:
                d.write(s.read())
    return '<script src="assets/marked.min.js"></script>\n<script src="assets/mermaid.min.js"></script>'

if os.path.isfile(IN):
    out = OUT or os.path.join(os.path.dirname(IN), "html",
                              os.path.splitext(os.path.basename(IN))[0] + ".html")
    title, lens, warns = render_one(IN, out, assets_for(os.path.dirname(out)))
    print(json.dumps({"rendered": [os.path.relpath(out, CWD) if out.startswith(CWD) else out],
                      "lens": lens, "budget_warnings": warns, **STAMP}))
else:
    out_dir = OUT or os.path.join(IN, "html")
    files = sorted(p for p in glob.glob(os.path.join(IN, "**", "*.md"), recursive=True)
                   if (os.sep + "html" + os.sep) not in p and not os.path.basename(p).startswith("."))
    if not files:
        print("render-html: tidak ada .md di " + IN, file=sys.stderr); sys.exit(2)
    ah = assets_for(out_dir)
    rows, rendered, all_warns = [], [], []
    for p in files:
        rel_out = os.path.splitext(os.path.relpath(p, IN))[0] + ".html"
        title, lens, warns = render_one(p, os.path.join(out_dir, rel_out), ah)
        rows.append((title, lens, rel_out.replace(os.sep, "/")))
        rendered.append(rel_out.replace(os.sep, "/")); all_warns += warns
    if INDEX:
        lines = ["# " + PROJECT + " — dokumen render", "",
                 "Semua dokumen di bundle ini, satu klik per halaman:", ""]
        for title, lens, href in rows:
            lines.append(f"- [{title}]({href}) — `{LENSES[lens][0]}`")
        idx_md = "\n".join(lines) + "\n"
        tmp = os.path.join(out_dir, ".index-src.md")
        os.makedirs(out_dir, exist_ok=True)
        open(tmp, "w", encoding="utf-8").write(idx_md)
        render_one(tmp, os.path.join(out_dir, "index.html"), ah)
        os.remove(tmp); rendered.append("index.html")
    print(json.dumps({"rendered": rendered, "out_dir": os.path.relpath(out_dir, CWD) if out_dir.startswith(CWD) else out_dir,
                      "budget_warnings": all_warns, **STAMP}))
PYEOF
