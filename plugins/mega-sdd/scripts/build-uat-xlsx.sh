#!/usr/bin/env bash
# build-uat-xlsx.sh — deterministic render of the assembled UAT doc-pack into a
# real .xlsx (spec docs/superpowers/specs/2026-07-23-uat-docpack-and-doc-
# versioning-design.md). The workbook is the tester's fill-in surface — a DERIVED
# artifact; the markdown <vault>/uat/UAT.md stays canonical.
#
# ZERO EXTRA DEPS: python3 STDLIB ONLY (zipfile + XML strings). No openpyxl, no
# pip — an .xlsx is a ZIP of OOXML XML parts, and we hand-write the minimal set
# (Content_Types + rels + workbook + styles + one worksheet per scenario).
#
# What it renders from the assembled UAT.md:
#   Rekap  — one row per §2 scenario (id · judul · flow · #langkah · status/
#            pelaksana/tanggal columns left BLANK for the tester)
#   RTM    — the §3 traceability matrix verbatim (Status UAT column blank)
#   UAT-NNN — one sheet per §2 scenario: title + metadata + the step table.
#            Execution columns (Actual Result / Status / Defect / Bukti) are
#            written as EMPTY cells — the `__________` / `[ ] Pass · …` markdown
#            placeholders are a MARKDOWN convention; the workbook gives the tester
#            blank cells to fill. Bold, frozen headers.
#
# NEVER OVERWRITE: an existing <vault>/uat/UAT-v<version>.xlsx is REFUSED (exit 3)
# — a tester may already have filled it. The version comes from
# <vault>/uat/.doc-history.json (written by refresh-doc-stamps.sh --bump); default
# `0.1` when the sidecar is absent. Regenerate by renaming/removing the file.
#
# Usage:
#   build-uat-xlsx.sh --vault=<vault-dir>
# Exit: 0 = workbook written
#       1 = parse failure (no §2 '### UAT-' scenario block found)
#       2 = usage error / vault missing / UAT.md missing
#       3 = target UAT-v<version>.xlsx already exists — REFUSED (never overwrite)
set -uo pipefail

VAULT=""
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT="${arg#*=}" ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$VAULT" ] || { echo "ERROR: --vault=<vault-dir> required" >&2; exit 2; }
[ -d "$VAULT" ] || { echo "ERROR: vault dir not found: $VAULT" >&2; exit 2; }

VAULT="$VAULT" python3 <<'PYEOF'
import json, os, re, sys, zipfile
from xml.sax.saxutils import escape

vault = os.path.abspath(os.environ["VAULT"])
uat_md = os.path.join(vault, "uat", "UAT.md")
hist_path = os.path.join(vault, "uat", ".doc-history.json")
if not os.path.isfile(uat_md):
    print(f"ERROR: {uat_md} not found — emit UAT.md first", file=sys.stderr); sys.exit(2)
version = "0.1"
if os.path.isfile(hist_path):
    try:
        version = json.load(open(hist_path)).get("version") or "0.1"
    except (OSError, ValueError):
        pass
out_path = os.path.join(vault, "uat", f"UAT-v{version}.xlsx")
if os.path.exists(out_path):
    print(f"REFUSE: {out_path} sudah ada — tidak menimpa workbook yang mungkin sudah diisi tester (rename/hapus manual untuk regenerate)")
    sys.exit(3)

text = open(uat_md, encoding="utf-8", errors="surrogateescape").read()
lines = text.split("\n")

def md_row(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]

def unesc(s):
    # undo markdown-cell escapes for spreadsheet cells
    return s.replace("\\|", "|").replace("`", "")

PLACEHOLDER = "__________"
EXEC_STATUS = "[ ] Pass · [ ] Fail · [ ] Blocked"
def blank_exec(v):   # workbook gives testers EMPTY cells, not markdown placeholders
    return "" if v in (PLACEHOLDER, EXEC_STATUS, "—") else v

# ── parse §2 scenarios ──────────────────────────────────────────────────────
scen_re = re.compile(r"^### (UAT-[A-Z0-9-]+) — (.*?) \((F-[A-Z0-9-]+)\)\s*$")
scenarios = []   # {id,title,fid,meta:[(k,v)],steps:[[7 cells]]}
cur = None; in2 = False
for ln in lines:
    if re.match(r"^## 2\.", ln): in2 = True; continue
    if in2 and re.match(r"^## \d+\.", ln): in2 = False
    if not in2: continue
    m = scen_re.match(ln)
    if m:
        cur = {"id": m.group(1), "title": m.group(2), "fid": m.group(3), "meta": [], "steps": []}
        scenarios.append(cur); continue
    if cur is None or not ln.strip().startswith("|"): continue
    cells = md_row(ln)
    if all(re.fullmatch(r":?-{3,}:?", c) for c in cells if c): continue
    if len(cells) == 2 and cells[0] != "Field":
        cur["meta"].append((cells[0], unesc(cells[1])))
    elif len(cells) == 7 and cells[0] != "No":
        cur["steps"].append([unesc(c) for c in cells])
if not scenarios:
    print("ERROR: no '### UAT-' scenario block found in §2 — nothing to render", file=sys.stderr); sys.exit(1)

# ── parse §3 RTM ────────────────────────────────────────────────────────────
rtm = []; in3 = False
for ln in lines:
    if re.match(r"^## 3\.", ln): in3 = True; continue
    if in3 and re.match(r"^## \d+\.", ln): in3 = False
    if in3 and ln.strip().startswith("|"):
        cells = md_row(ln)
        if not all(re.fullmatch(r":?-{3,}:?", c) for c in cells if c):
            row = [unesc(c) for c in cells]
            if row:  # trailing cell is the "Status UAT" column — blank it for the tester
                row[-1] = blank_exec(row[-1])
            rtm.append(row)

# ── minimal OOXML ───────────────────────────────────────────────────────────
INVALID_SHEET = str.maketrans({c: " " for c in r':\/?*[]'})
def sheet_name(raw):
    # Excel sheet-name rules: <=31 chars, none of : \ / ? * [ ]
    return (raw.translate(INVALID_SHEET) or "Sheet").strip()[:31]

def col_letter(i):
    s = ""
    while i >= 0:
        s = chr(65 + i % 26) + s; i = i // 26 - 1
    return s

def sheet_xml(rows, widths, n_header_rows=1):
    cols = "".join(f'<col min="{i+1}" max="{i+1}" width="{w}" customWidth="1"/>' for i, w in enumerate(widths))
    body = []
    for r, row in enumerate(rows, 1):
        cells = []
        for c, val in enumerate(row):
            if val == "":            # skip empties; explicit r= keeps positions correct
                continue
            style = ' s="1"' if r <= n_header_rows else ' s="2"'
            cells.append(f'<c r="{col_letter(c)}{r}" t="inlineStr"{style}><is><t xml:space="preserve">{escape(str(val))}</t></is></c>')
        body.append(f'<row r="{r}">' + "".join(cells) + "</row>")
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            f'<sheetViews><sheetView workbookViewId="0"><pane ySplit="{n_header_rows}" topLeftCell="A{n_header_rows+1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
            f'<cols>{cols}</cols><sheetData>' + "".join(body) + "</sheetData></worksheet>")

STYLES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
  '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
  '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
  '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
  '<fill><patternFill patternType="solid"><fgColor rgb="FFEFEFEF"/><bgColor indexed="64"/></patternFill></fill></fills>'
  '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
  '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
  '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>'
  '</cellXfs></styleSheet>')

sheets = []  # (name, xml)
rekap = [["Skenario", "Judul", "Flow", "Jumlah step", "Status keseluruhan", "Pelaksana", "Tanggal"]]
for s in scenarios:
    rekap.append([s["id"], s["title"], s["fid"], str(len(s["steps"])), "", "", ""])
sheets.append(("Rekap", sheet_xml(rekap, [12, 40, 12, 12, 18, 20, 14])))
if rtm:
    sheets.append(("RTM", sheet_xml(rtm, [14, 36, 12, 12, 20, 14])))
for s in scenarios:
    rows = [[f'{s["id"]} — {s["title"]} ({s["fid"]})'], []]
    for k, v in s["meta"]:
        rows.append([k, blank_exec(v) if k in ("Prioritas", "Prasyarat", "Data uji") else v])
    rows.append([])
    rows.append(["No", "Aksi", "Expected Result", "Actual Result", "Status", "Defect", "Bukti"])
    hdr_at = len(rows)
    for st in s["steps"]:
        rows.append([st[0], st[1], st[2], blank_exec(st[3]), blank_exec(st[4]), blank_exec(st[5]), blank_exec(st[6])])
    rows.append([]); rows.append(["Pelaksana", ""]); rows.append(["Tanggal eksekusi", ""]); rows.append(["Tanda tangan", ""])
    sheets.append((sheet_name(s["id"]), sheet_xml(rows, [5, 45, 35, 30, 12, 10, 18], n_header_rows=hdr_at)))

# ── workbook plumbing ───────────────────────────────────────────────────────
def workbook_xml():
    entries = "".join(f'<sheet name="{escape(n)}" sheetId="{i+1}" r:id="rId{i+1}"/>' for i, (n, _) in enumerate(sheets))
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            f'<sheets>{entries}</sheets></workbook>')

def wb_rels():
    rels = "".join(f'<Relationship Id="rId{i+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i+1}.xml"/>' for i in range(len(sheets)))
    rels += f'<Relationship Id="rId{len(sheets)+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    return f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{rels}</Relationships>'

CT = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
     '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
     '<Default Extension="xml" ContentType="application/xml"/>'
     '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
     '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
     + "".join(f'<Override PartName="/xl/worksheets/sheet{i+1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(len(sheets)))
     + '</Types>')

ROOT_RELS = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
     '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
     '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')

os.makedirs(os.path.dirname(out_path), exist_ok=True)
tmp = out_path + ".tmp.%d" % os.getpid()
try:
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", CT)
        z.writestr("_rels/.rels", ROOT_RELS)
        z.writestr("xl/workbook.xml", workbook_xml())
        z.writestr("xl/_rels/workbook.xml.rels", wb_rels())
        z.writestr("xl/styles.xml", STYLES)
        for i, (_, xml) in enumerate(sheets):
            z.writestr(f"xl/worksheets/sheet{i+1}.xml", xml)
    os.replace(tmp, out_path)
except BaseException:
    try:
        os.remove(tmp)
    except OSError:
        pass
    raise
print(f"uat-xlsx: {out_path} (sheets={len(sheets)}, version={version})")
sys.exit(0)
PYEOF
exit $?
