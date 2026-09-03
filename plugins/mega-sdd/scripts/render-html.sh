#!/usr/bin/env bash
# render-html.sh — deterministic md → self-contained HTML renderer (template v2
# 7.23.0, spec 2026-09-03-render-html-v2-template.md; lahir 7.16.0, research
# 2026-08-31 + spec of the same date).
#
# The md stays the ONLY ground truth: this script wraps the RAW markdown into
# assets/render-html/template.html (vendored marked.js + mermaid.js render it
# client-side), so the HTML can never drift from its source — re-run any time.
# Zero model tokens. Offline by construction (no external requests, vendored
# woff2 fonts with a system fallback stack, vendored pinned JS).
#
# Usage:
#   render-html.sh <file.md>            → <parent>/html/<stem>.html
#   render-html.sh <dir> --index        → <dir>/html/*.html + index.html
#   flags: --out=<path> (file or dir)   --assets-dir  (shared assets/ folder
#          next to the outputs instead of inlining ~2.7MB per file — for
#          multi-file KB bundles)       --cwd=<project-root>
#
# Standard enforced BY the template, not per-run taste (research §2–§4, §6 +
# v2 spec): per-doc-type lens (badge + audience + summary strip), 3-zone page
# anatomy (bundle nav / content / on-this-page), diagram budget ADVISORY
# (never blocks — md is ground truth), natural mixed ID-EN template strings.
# Exit 0 = rendered; 2 = usage/missing input.
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
import base64, glob, hashlib, html, json, os, re, sys

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

# ── summary strip per lens — hitungan regex sederhana, gagal → tile dihilangkan.
# v2: label open questions / conflict > 0 dapat class warn (angka merah).
WARN_LABELS = {"open questions", "conflict"}
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
        f'<div class="st{" warn" if l in WARN_LABELS else ""}"><span class="st-n">{n}</span><span class="st-l">{html.escape(l)}</span></div>'
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

# ── slug h2/h3 — REPLIKA PERSIS algoritma nav/search di template.html (7.19.0):
# lowercase → non-word jadi '-' → strip → dedup counter. Search deep-link
# lompat ke #anchor yang sama dengan yang template bangun; kalau dua algoritma
# ini berbeda satu karakter saja, semua hasil search nyasar.
def page_headings(display_md):
    seen = {}
    out = []
    for m in re.finditer(r"(?m)^(#{2,3})\s+(.+?)\s*$", display_md):
        text = re.sub(r"[*`_\[\]]", "", m.group(2)).strip()
        base = re.sub(r"[^\wÀ-￿]+", "-", text.lower()).strip("-") or "sec"
        if base in seen:
            seen[base] += 1
            sid = f"{base}-{seen[base]}"
        else:
            seen[base] = 0
            sid = base
        out.append((sid, text))
    return out

def plain_text(display_md):
    t = re.sub(r"```.*?```", " ", display_md, flags=re.DOTALL)
    t = re.sub(r"<[^>]+>", " ", t)
    t = re.sub(r"[#*`|>\[\]()]", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def open_oq_count(display_md):
    return len(re.findall(r"(?m)^\s*[-*]\s*\[ \]\s*\**OQ-", display_md))

# ── assets & fonts per halaman (v2): inline = data-URI / shared = url relatif.
# v1 bug fixed: halaman nested di mode shared kini pakai prefix rel yang benar.
FONT_FACES = [("Inter", "100 900", "inter-var-latin.woff2"),
              ("JetBrains Mono", "400", "jetbrains-mono-latin.woff2")]
def fonts_css(rel_prefix=None):
    out = []
    for fam, w, fn in FONT_FACES:
        try:
            if rel_prefix is None:
                b64 = base64.b64encode(open(os.path.join(A, "fonts", fn), "rb").read()).decode()
                src = f"data:font/woff2;base64,{b64}"
            else:
                src = f"{rel_prefix}assets/fonts/{fn}"
            out.append(f"@font-face{{font-family:'{fam}';font-style:normal;font-weight:{w};"
                       f"font-display:swap;src:url({src}) format('woff2')}}")
        except Exception:
            pass  # font hilang → fallback system stack, halaman tetap jadi
    return "\n".join(out)

INLINE_ASSETS = None
INLINE_FONTS = None
def page_assets(out_dir, rel_prefix):
    global INLINE_ASSETS, INLINE_FONTS
    if not SHARED:
        if INLINE_ASSETS is None:
            INLINE_ASSETS = ("<script>\n" + open(os.path.join(A, "marked.min.js"), encoding="utf-8").read() +
                             "\n</script>\n<script>\n" + open(os.path.join(A, "mermaid.min.js"), encoding="utf-8").read() +
                             "\n</script>")
            INLINE_FONTS = fonts_css(None)
        return INLINE_ASSETS, INLINE_FONTS
    ad = os.path.join(out_dir, "assets"); os.makedirs(ad, exist_ok=True)
    for f in ("marked.min.js", "mermaid.min.js"):
        dst = os.path.join(ad, f)
        if not os.path.exists(dst):
            with open(os.path.join(A, f), "rb") as s, open(dst, "wb") as d:
                d.write(s.read())
    fd = os.path.join(ad, "fonts")
    for _, _, fn in FONT_FACES:
        srcp = os.path.join(A, "fonts", fn)
        if os.path.exists(srcp):
            os.makedirs(fd, exist_ok=True)
            dst = os.path.join(fd, fn)
            if not os.path.exists(dst):
                with open(srcp, "rb") as s, open(dst, "wb") as d:
                    d.write(s.read())
    ah = (f'<script src="{rel_prefix}assets/marked.min.js"></script>\n'
          f'<script src="{rel_prefix}assets/mermaid.min.js"></script>')
    return ah, fonts_css(rel_prefix)

def render_one(src, out_path, out_dir=None, index_href=None, self_href=None,
               prev_row=None, next_row=None, crumb_html=None):
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
    warn_html = "" if not warns else ('<div class="warnbar"><span>⚠️</span><p style="margin:0"><b>Budget diagram:</b> ' +
                                      " · ".join(html.escape(w) for w in warns) + "</p></div>")
    page_dir = os.path.dirname(out_path)
    rel_prefix = ""
    if out_dir:
        rp = os.path.relpath(out_dir, page_dir).replace(os.sep, "/")
        rel_prefix = "" if rp == "." else rp + "/"
    assets_html, fonts_html = page_assets(out_dir or page_dir, rel_prefix)
    idx_html = ""
    if index_href:
        idx_html = f'<a class="idx-link" href="{html.escape(index_href)}">&larr; index</a>'
    # nav bundle + ⌘K data: hanya di bundle mode (search-index.js ada)
    nav_html = ""
    if self_href is not None:
        nav_html = ("<script>window.MEGA_SELF=" + json.dumps(self_href) +
                    ";window.MEGA_REL=" + json.dumps(rel_prefix) + ";</script>\n"
                    f'<script src="{rel_prefix}search-index.js"></script>')
    # prev / next dari urutan listing bundle
    pn_html = ""
    if prev_row or next_row:
        def pn_a(row, cls, label):
            if not row:
                return f'<a class="{cls} hole" aria-hidden="true"><span class="lbl">{label}</span><span class="ttl">—</span></a>'
            t, _, href = row
            return (f'<a class="{cls}" href="{html.escape(rel_prefix + href)}"><span class="lbl">{label}</span>'
                    f'<span class="ttl">{html.escape(t)}</span></a>')
        pn_html = ('<div class="pn">' + pn_a(prev_row, "prev", "← Sebelumnya") +
                   pn_a(next_row, "next", "Berikutnya →") + "</div>")
    if crumb_html is None:
        crumb_html = f'<span class="here">{html.escape(rel)}</span>'
    page = (TEMPLATE
            .replace("@@FONTS@@", fonts_html)
            .replace("@@INDEXLINK@@", idx_html)
            .replace("@@NAVDATA@@", nav_html)
            .replace("@@PREVNEXT@@", pn_html)
            .replace("@@CRUMB@@", crumb_html)
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

if os.path.isfile(IN):
    out = OUT or os.path.join(os.path.dirname(IN), "html",
                              os.path.splitext(os.path.basename(IN))[0] + ".html")
    title, lens, warns = render_one(IN, out)
    print(json.dumps({"rendered": [os.path.relpath(out, CWD) if out.startswith(CWD) else out],
                      "lens": lens, "budget_warnings": warns, **STAMP}))
else:
    out_dir = OUT or os.path.join(IN, "html")
    files = sorted(p for p in glob.glob(os.path.join(IN, "**", "*.md"), recursive=True)
                   if (os.sep + "html" + os.sep) not in p and not os.path.basename(p).startswith("."))
    if not files:
        print("render-html: tidak ada .md di " + IN, file=sys.stderr); sys.exit(2)
    # pass 1: kumpulkan baris (title, lens, href) supaya prev/next + nav punya urutan penuh
    rows = []
    for p in files:
        raw = open(p, encoding="utf-8", errors="replace").read()
        m = re.search(r"(?m)^#\s+(.+)$", raw)
        t = m.group(1).strip() if m else os.path.splitext(os.path.basename(p))[0]
        href = (os.path.splitext(os.path.relpath(p, IN))[0] + ".html").replace(os.sep, "/")
        rows.append((t, detect_lens(p), href))
    rendered, all_warns, search_entries = [], [], []
    for i, p in enumerate(files):
        t, lens, href = rows[i]
        rel_out = href.replace("/", os.sep)
        idx_href = os.path.relpath(os.path.join(out_dir, "index.html"),
                                   os.path.dirname(os.path.join(out_dir, rel_out))).replace(os.sep, "/") if INDEX else None
        crumb = None
        if INDEX:
            parts = [f'<a href="{html.escape(idx_href)}">{html.escape(PROJECT)}</a>']
            for d in os.path.dirname(href).split("/"):
                if d: parts.append(html.escape(d))
            parts.append(f'<span class="here">{html.escape(t)}</span>')
            crumb = '<span class="sep">/</span>'.join(parts)
        title, lens, warns = render_one(
            p, os.path.join(out_dir, rel_out), out_dir=out_dir, index_href=idx_href,
            self_href=(href if INDEX else None),
            prev_row=(rows[i - 1] if INDEX and i > 0 else None),
            next_row=(rows[i + 1] if INDEX and i + 1 < len(rows) else None),
            crumb_html=crumb)
        rendered.append(href); all_warns += warns
        raw = open(p, encoding="utf-8", errors="replace").read()
        disp = re.sub(r"\A---\n.*?\n---\n", "", raw, count=1, flags=re.DOTALL)
        search_entries.append({"h": href, "t": title, "l": LENSES[lens][0],
                               "hd": page_headings(disp), "x": plain_text(disp),
                               "q": open_oq_count(disp)})
    if INDEX:
        # search-index.js — dibangun render-time, dibaca client-side (offline):
        # data untuk nav bundle kiri + ⌘K search di SEMUA halaman (v2)
        os.makedirs(out_dir, exist_ok=True)
        with open(os.path.join(out_dir, "search-index.js"), "w", encoding="utf-8") as f:
            f.write("window.MEGA_SEARCH=" + json.dumps(search_entries, ensure_ascii=False).replace("</", "<\\/") + ";\n")
        # muka index = README roll-up bila ada (ringkasan grounded yang sudah
        # ditulis emitter — akhirnya tampil), + daftar semua dokumen
        readme = os.path.join(IN, "README.md")
        lines = []
        if os.path.isfile(readme):
            rme = open(readme, encoding="utf-8", errors="replace").read()
            lines.append(re.sub(r"\A---\n.*?\n---\n", "", rme, count=1, flags=re.DOTALL).rstrip())
            lines.append("")
        else:
            lines.append("# " + PROJECT + " — dokumen render")
            lines.append("")
        lines.append("## Semua dokumen")
        lines.append("")
        for t, lens, href in rows:
            lines.append(f"- [{t}]({href}) — `{LENSES[lens][0]}`")
        idx_md = "\n".join(lines) + "\n"
        tmp = os.path.join(out_dir, "index.md")
        open(tmp, "w", encoding="utf-8").write(idx_md)
        render_one(tmp, os.path.join(out_dir, "index.html"), out_dir=out_dir,
                   self_href="index.html",
                   crumb_html=f'<span class="here">{html.escape(PROJECT)}</span>')
        os.remove(tmp); rendered.append("index.html"); rendered.append("search-index.js")
    print(json.dumps({"rendered": rendered, "out_dir": os.path.relpath(out_dir, CWD) if out_dir.startswith(CWD) else out_dir,
                      "budget_warnings": all_warns, **STAMP}))
PYEOF
