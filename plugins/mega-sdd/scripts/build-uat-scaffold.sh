#!/usr/bin/env bash
# build-uat-scaffold.sh — deterministic builder of the UAT scaffold fragment
# (spec docs/superpowers/specs/2026-07-23-uat-docpack-and-doc-versioning-design.md
# §3 "Design A — the emit-uat doc-pack" + decisions 1/3; SEOJK 21/2017 §2.3.1.5).
#
# THE UNFAKEABLE RECORD: the UAT document is business-facing — every scenario id,
# traceability row, criteria checkbox, and berita-acara cell is SCRIPT-computed;
# the model writes ONLY §2 narrative + the numbered step rows (replacing each
# `<!-- uat-steps:UAT-NNN -->` marker). A hand-typed execution result (Actual
# Result / Status / Defect / Bukti), tester footer, or sign-off cell in a bank
# UAT document is a FABRICATED test record. This script is the sibling of
# build-sit-evidence.sh: it READS the vault artifacts and emits ready-to-include
# markdown; the model includes the fragment VERBATIM.
#
# What it emits (one fragment file, default <vault>/uat/.uat-scaffold.md):
#   §1  Ruang lingkup & kriteria — flows-in-scope table (UAT ↔ TS ↔ F-id ↔ judul
#       ↔ tipe) + entry-criteria table (incl. the SEOJK berita-acara-SIT gate row
#       + the probed SIT maturity) + exit-criteria table
#   §2  Skenario UAT scaffold — one UAT block per F-* flow carrying the flow's
#       Mermaid diagram VERBATIM + its DoD items VERBATIM as expected outcomes +
#       an empty step-table skeleton (header/separator + the sole model-owned
#       `<!-- uat-steps:UAT-NNN -->` marker line) + a placeholder tester footer
#   §3  Matriks ketertelusuran (RTM) — one row per flow joining F-id ↔ UAT ↔ TS
#       (SIT) ↔ unit terkait, Status UAT cell a placeholder LITERAL
#   §4  Berita Acara UAT — info table + outstanding-defects skeleton + the
#       Go/No-Go decision line + per-scope sign-off table(s) whose BODY ROWS are
#       placeholder LITERALS (paper-out, mirrors SIT §5 / SEOJK §2.3.1.5).
#   MATURITY: always `draft` — the model never self-promotes a UAT approval state
#       (spec §3.4; PRD precedent — self-promotion would fabricate approval).
#
# SIT ENTRY-GATE PROBE (SEOJK §2.3.1.5 — UAT may start only after the developer's
# berita acara SIT): read <vault>/sit/SIT.md's doc-control maturity. When it is
# absent or ≠ `executed`, a WARN_SIT line is printed (warn-only — preparing UAT
# scripts early is legitimate; NEVER a failure exit).
#
# MULTI-SCOPE (spec §3.5, mirrors SIT decision 10): --vault= is repeatable → ONE
# merged fragment; ids carry the scope (UAT-<SCOPE>-NNN / TS-<SCOPE>-NNN) when the
# vault's vault.json has scope_metadata.id; Scope column in §1/§3; sign-off table
# per scope. Single unscoped vault → plain UAT-NNN / TS-NNN. UAT-NNN numbering is
# IDENTICAL to SIT's TS-NNN derivation so the ids pair 1:1.
#
# EXECUTION-FABRICATION GATE (spec §3.3 --check-execution): with --check-execution
# (or, in default mode, when <vault>/uat/UAT.md already exists) the assembled
# UAT.md is scanned — any filled §2 execution cell / tester footer, any filled §3
# RTM status, any altered §4 keputusan / info / defects / sign-off cell is a
# deterministic FAIL (exit 1) with Indonesian keterangan framing it as a
# fabricated record.
#
# Usage:
#   build-uat-scaffold.sh --vault=<vault-dir> [--vault=<dir2> ...] \
#       --cwd=<project-root> [--out=<fragment-path>] [--quiet]
#   build-uat-scaffold.sh --check-execution --vault=<vault-dir> [--cwd=<root>]
# Exit: 0 = fragment written (and execution clean when UAT.md exists)
#       1 = execution violation (fabricated record) — keterangan printed;
#           in default mode the fragment is still written (audit-trail precedent)
#       2 = usage error / vault missing
set -uo pipefail

VAULTS=()
CWD=""
OUT=""
QUIET=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULTS+=("${arg#*=}") ;;
    --cwd=*)   CWD="${arg#*=}" ;;
    --out=*)   OUT="${arg#*=}" ;;
    --quiet)   QUIET=1 ;;
    --check-execution) CHECK_ONLY=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ "${#VAULTS[@]}" -ge 1 ] || { echo "ERROR: --vault=<vault-dir> required (repeatable)" >&2; exit 2; }
for v in "${VAULTS[@]}"; do
  [ -d "$v" ] || { echo "ERROR: vault dir not found: $v" >&2; exit 2; }
done
if [ "$CHECK_ONLY" -eq 0 ]; then
  [ -n "$CWD" ] && [ -d "$CWD" ] || { echo "ERROR: --cwd=<project-root> required (dir must exist)" >&2; exit 2; }
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

VAULTS_JOINED=$(printf '%s\n' "${VAULTS[@]}")
VAULTS_JOINED="$VAULTS_JOINED" CWD="$CWD" OUT="$OUT" QUIET="$QUIET" CHECK_ONLY="$CHECK_ONLY" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_md  # FLOW_HEADING_RE / DOD_ITEM_RE / FLOW_DOD_LABEL_RE — one grammar

vaults = [os.path.abspath(v) for v in os.environ["VAULTS_JOINED"].splitlines() if v.strip()]
cwd = os.path.abspath(os.environ["CWD"]) if os.environ.get("CWD") else None
out_override = os.environ.get("OUT") or None
quiet = os.environ.get("QUIET", "0") == "1"
check_only = os.environ.get("CHECK_ONLY", "0") == "1"
ts_now = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")

PLACEHOLDER = "__________"
EXEC_STATUS = "[ ] Pass · [ ] Fail · [ ] Blocked"
BA_STATUS = "[ ] Diterima · [ ] Ditolak"
DECISION = "**Keputusan:** [ ] Go · [ ] No-Go"
STEP_HDR = "| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |"
STEP_SEP = "|---|---|---|---|---|---|---|"
UAT_SIGNOFF_ROLES = ("UAT Lead", "Business Owner", "Product Owner")
PERIODE_VALUE = "%s s.d. %s" % (PLACEHOLDER, PLACEHOLDER)
REF_SIT_VALUE = "sit/SIT.md — berita acara SIT: %s" % PLACEHOLDER
STEP_COLS = {4: "Actual Result", 6: "Defect", 7: "Bukti"}  # 1-indexed cells

# ── Execution-fabrication gate (spec §3.3) ───────────────────────────────────
def _cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]

def _is_sep(cells):
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c) for c in cells if c)

def check_execution(uat_path):
    """Scan an assembled UAT.md. Returns a list of violation lines. §-regions are
    the `## 2.` / `## 3.` / `## 4.` numbered headings the emit-uat skill wraps the
    fragments in (mirrors check_signoff's `## 5.` region detection)."""
    try:
        lines = open(uat_path, encoding="utf-8", errors="surrogateescape").read().split("\n")
    except OSError:
        return ["EXECUTION_UNREADABLE %s" % uat_path]
    section = 0          # 0 = none, 2/3/4 = current numbered section (5 = annex)
    seen4 = False
    seen5 = False        # §5 = the script-owned automated-evidence annex (6.10.0)
    annex_heading = None # the doc's ACTUAL §5 heading line (spoof-compared, round M1)
    annex_body = []      # RAW §5 lines (fences included — nothing may hide in one)
    annexish = False     # fail-closed detector: annex-shaped content under a
                         # MALFORMED heading must never silently skip the gate
                         # (round BLOCKER: '## 5 Lampiran' / '##  5.' / '## **5.**'
                         # all escaped the ^## (\d+)\. transition)
    cur_uat = "?"        # current UAT-id within §2
    ba_table = None      # §4 table mode: 'info' | 'defects' | 'signoff' | None
    keputusan_seen = False
    in_fence = False     # ``` fence tracking — mermaid lines may start with '|'
    v = []
    for i, line in enumerate(lines, 1):
        # §5 annex: collect RAW to EOF BEFORE fence logic — the annex is verified
        # by BYTE-COMPARE against the shared renderer (_lib/uat_annex.py), so a
        # fence-wrapped forged row must land in the compared body, not be skipped.
        if section == 5:
            annex_body.append(line)
            continue
        if re.match(r"^\s*```", line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        hm = re.match(r"^## (\d+)\.", line)
        if hm:
            section = int(hm.group(1))
            ba_table = None
            if section == 4:
                seen4 = True
            if section == 5:
                seen5 = True
                annex_heading = line
            continue
        # fail-closed: a MALFORMED annex heading ('## 5 Lampiran', '##  5.',
        # '## **5.**' …) must arm the gate, never exempt it — any heading-ish
        # line naming the annex or numbered 5 counts (backward compat holds:
        # pre-annex docs contain neither token).
        if not seen5 and ("Lampiran — Eksekusi Otomatis" in line
                          or re.match(r"^\s*##\s*\**\s*5\b", line)):
            annexish = True
        # §2 — step tables + tester footer
        if section == 2:
            um = re.match(r"^###\s+(UAT-\S+)\s+—", line)
            if um:
                cur_uat = um.group(1)
                continue
            if line.strip().startswith("**Pelaksana:**"):
                if line.count(PLACEHOLDER) != 3:
                    v.append("EXECUTION_FILLED %d pelaksana" % i)
                continue
            if "<!-- uat-steps:" in line:
                mk = re.search(r"<!-- uat-steps:(\S+)", line)
                v.append("STEPS_MISSING %s" % (mk.group(1) if mk else cur_uat))
                continue
            if not line.strip().startswith("|"):
                continue
            cells = _cells(line)
            if not cells or _is_sep(cells):
                continue
            if len(cells) == 7:
                if cells[0] == "No":
                    continue  # step-table header
                for idx, col in STEP_COLS.items():
                    if cells[idx - 1] != PLACEHOLDER:
                        v.append("EXECUTION_FILLED %d %s %s" % (i, cur_uat, col))
                if cells[4] != EXEC_STATUS:
                    v.append("EXECUTION_FILLED %d %s Status" % (i, cur_uat))
                continue
            if len(cells) != 2:
                # §2 knows exactly two table shapes: 2-cell metadata rows and
                # 7-cell step rows — anything else is a malformed (possibly
                # column-dropped) step row the placeholder checks cannot see.
                v.append("EXECUTION_SHAPE %d %s %d-cell" % (i, cur_uat, len(cells)))
            continue
        # §3 — RTM: last cell (Status UAT) must stay placeholder
        if section == 3:
            if not line.strip().startswith("|"):
                continue
            cells = _cells(line)
            # skip separator + the RTM header (single-scope `Flow (F-id)` first
            # cell OR the multi-scope `Scope`-prefixed header — §3 is the only
            # region whose header carries the Scope column, so the gate stays
            # multi-scope aware per spec §3.3)
            if not cells or _is_sep(cells) or cells[0].startswith("Flow") or cells[0] == "Scope":
                continue
            if cells[-1] != PLACEHOLDER:
                v.append("RTM_FILLED %d" % i)
            continue
        # §4 — berita acara: keputusan + info + defects + sign-off
        if section == 4:
            if line.strip().startswith("**Keputusan:**"):
                keputusan_seen = True
                if line.strip() != DECISION:
                    v.append("BA_FILLED keputusan")
                continue
            if not line.strip().startswith("|"):
                if line.strip():
                    ba_table = None  # a non-table, non-blank line closes a table run
                continue
            cells = _cells(line)
            if _is_sep(cells):
                continue
            head0 = cells[0] if cells else ""
            if head0 == "Field":
                ba_table = "info"; continue
            if head0 == "No":
                ba_table = "defects"; continue
            if head0 == "Peran":
                ba_table = "signoff"; continue
            if ba_table == "info":
                field, val = (cells + [""])[0], (cells + ["", ""])[1]
                expect = {"Periode UAT": PERIODE_VALUE, "Test cycle": PLACEHOLDER,
                          "Referensi SIT": REF_SIT_VALUE}.get(field)
                if expect is not None and val != expect:
                    v.append("BA_FILLED %d %s" % (i, field))
            elif ba_table == "defects":
                for c in cells[1:]:  # cell 1 = row number literal
                    if c != PLACEHOLDER:
                        v.append("BA_FILLED %d defects" % i)
                        break
            elif ba_table == "signoff":
                if len(cells) != 5:
                    v.append("SIGNOFF_SHAPE %d %s" % (i, head0 or "?"))
                    continue
                peran, nama, tanggal, ttd, status = cells
                for label, got in (("Nama", nama), ("Tanggal", tanggal), ("Tanda tangan", ttd)):
                    if got != PLACEHOLDER:
                        v.append("SIGNOFF_FILLED %d %s %s" % (i, peran, label))
                if status != BA_STATUS:
                    v.append("SIGNOFF_FILLED %d %s Status" % (i, peran))
            continue
    if not seen4:
        v.insert(0, "BA_SECTION_MISSING")
    elif not keputusan_seen:
        v.append("BA_FILLED keputusan")
    # §5 annex byte-compare (recompute-at-gate, B1 precedent): the doc's annex
    # must equal _lib/uat_annex.render_annex() recomputed from on-disk evidence —
    # the model can only ever type the placeholder literal; any other content
    # that a recompute does not reproduce is a fabricated automated-evidence
    # record. Pre-annex docs (no `## 5.` heading) are exempt (backward compat).
    if annexish and not seen5:
        v.append("ANNEX_HEADING_MALFORMED — annex content under a heading the parser "
                 "cannot key ('## 5. ' exact form required); fail-closed, never exempt")
    if seen5:
        import uat_annex
        vault_dir = os.path.dirname(os.path.dirname(uat_path))
        expected = uat_annex.render_annex(vault_dir).strip("\n")
        # spoof guard (round M1): compare the doc's ACTUAL heading line, never
        # substitute the canonical constant — a fabricated pass-claim in the
        # heading text must mismatch.
        got = ((annex_heading or "") + "\n" + "\n".join(annex_body)).strip("\n")
        if got != expected:
            g_lines, e_lines = got.split("\n"), expected.split("\n")
            first_diff = next(
                (g for g, e in zip(g_lines, e_lines) if g != e),
                g_lines[len(e_lines)] if len(g_lines) > len(e_lines)
                else (e_lines[len(g_lines)] if len(e_lines) > len(g_lines) else "?"),
            )
            v.append("ANNEX_FORGED %s" % first_diff.strip()[:120])
    return v

def print_execution_keterangan(violations):
    for x in violations:
        print(x)
    print("KETERANGAN: sel eksekusi / sign-off UAT yang terisi terdeteksi — ini adalah")
    print("hasil eksekusi UAT yang DIFABRIKASI. Hasil uji asli diisi MANUSIA di workbook")
    print("xlsx / dokumen cetak saat pelaksanaan, lalu dituangkan ke berita acara — model/AI")
    print("DILARANG mengisinya (fabricated record, diblokir deterministik oleh")
    print("build-uat-scaffold.sh --check-execution). Kembalikan sel Actual Result/Defect/Bukti")
    print("ke `%s`, Status ke `%s`, baris sign-off Nama/Tanggal/Tanda" % (PLACEHOLDER, EXEC_STATUS))
    print("tangan ke `%s` & Status ke `%s`, dan baris keputusan ke `%s`." % (PLACEHOLDER, BA_STATUS, DECISION))
    if any(x.startswith("ANNEX_FORGED") for x in violations):
        print("Khusus ANNEX_FORGED: §5 Lampiran Eksekusi Otomatis adalah wilayah SCRIPT —")
        print("isinya harus byte-identik dengan recompute dari result.json di disk.")
        print("Jalankan `build-uat-e2e.sh --annex` untuk me-render ulang lampiran dari")
        print("bukti nyata; model/AI DILARANG mengetik baris lampiran (hanya placeholder")
        print("literal saat belum ada eksekusi).")

if check_only:
    uat_path = os.path.join(vaults[0], "uat", "UAT.md")
    if not os.path.isfile(uat_path):
        print("ERROR: %s not found — nothing to check" % uat_path, file=sys.stderr)
        sys.exit(2)
    viol = check_execution(uat_path)
    if viol:
        print_execution_keterangan(viol)
        sys.exit(1)
    print("uat-execution: clean (semua sel eksekusi/sign-off masih placeholder literal)")
    sys.exit(0)

# ── SIT entry-gate probe (SEOJK §2.3.1.5) ────────────────────────────────────
def probe_sit(vroot):
    p = os.path.join(vroot, "sit", "SIT.md")
    if not os.path.isfile(p):
        return "absent"
    t = open(p, encoding="utf-8", errors="surrogateescape").read()
    m = re.search(r"<!-- mega-sdd:doc-control\n.*?^maturity: (.*?)$.*?-->", t, re.DOTALL | re.MULTILINE)
    return (m.group(1).strip() if m else "unset")

# ── Per-vault parsing (SAME grammar as build-sit-evidence.sh — vault_md.py) ───
FM_KEY_RE = re.compile(r"^([A-Za-z_]+)\s*:\s*(.*)$")
F_ID_RE = re.compile(r"\bF-(?:[A-Z]-)?\d+\b")

def frontmatter_region(text):
    if not text.startswith("---"):
        return ""
    end = text.find("\n---", 3)
    return text[3:end] if end != -1 else ""

def parse_acceptance_entries(full_text):
    """SAME region extraction run-acceptance-tests.sh / validate-unit-spec.sh use
    (^acceptance_test\\s*: up to the next top-level key) — REUSE, no new YAML dep."""
    at = re.search(r"^acceptance_test\s*:\s*(.*?)(?=^\S|\Z)", full_text, re.DOTALL | re.MULTILINE)
    if not at:
        return []
    entries = []
    cur = None
    for ln in at.group(1).splitlines():
        if re.match(r"^\s*-\s", ln):
            if cur:
                entries.append(cur)
            cur = {}
            ln = re.sub(r"^\s*-\s*", "", ln)
        if cur is None:
            continue
        m = re.match(r"^\s*([A-Za-z_]+)\s*:\s*(.*)$", ln)
        if m:
            k = m.group(1).strip().lower()
            v = m.group(2).strip().strip("'\"")
            if k in ("type", "kind", "command", "expects", "desc", "ears"):
                cur.setdefault("type" if k == "kind" else k, v)
    if cur:
        entries.append(cur)
    return entries

def parse_modules_yaml(path):
    """Minimal reader for the machine-written modules.yaml shape
    (modules: [- id/name/dod list]) — mirrors the --modules rollup fields (query-graph.sh)."""
    mods = []
    cur = None
    in_dod = False
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return mods
    for ln in lines:
        m = re.match(r"^\s*-\s*id\s*:\s*(.+)$", ln)
        if m:
            cur = {"id": m.group(1).strip().strip("'\""), "name": "", "dod": []}
            mods.append(cur)
            in_dod = False
            continue
        if cur is None:
            continue
        m = re.match(r"^\s*name\s*:\s*(.+)$", ln)
        if m:
            cur["name"] = m.group(1).strip().strip("'\"")
            in_dod = False
            continue
        if re.match(r"^\s*dod\s*:\s*$", ln):
            in_dod = True
            continue
        if in_dod:
            m = re.match(r"^\s*-\s*(.+)$", ln)
            if m:
                cur["dod"].append(m.group(1).strip().strip("'\""))
            elif ln.strip() and not ln.startswith((" ", "\t", "-")):
                in_dod = False
    return mods

def parse_vault(vroot):
    data = {"root": vroot, "scope": None, "flows": [], "units": [], "modules": [],
            "project_name": None}
    vjson_path = os.path.join(vroot, "vault.json")
    if os.path.isfile(vjson_path):
        try:
            vj = json.load(open(vjson_path))
            sm = vj.get("scope_metadata") or {}
            sid = str(sm.get("id") or "").strip()
            if sid:
                data["scope"] = sid.upper()
            pn = str(vj.get("project_name") or "").strip()
            if pn:
                data["project_name"] = pn
        except (OSError, ValueError):
            pass
    flows_path = os.path.join(vroot, "04-flows.md")
    if os.path.isfile(flows_path):
        lines = open(flows_path, encoding="utf-8", errors="surrogateescape").read().split("\n")
        heads = []
        for i, line in enumerate(lines):
            m = vault_md.FLOW_HEADING_RE.match(line)
            if m:
                heads.append((i, m.group(1), m.group(2).strip()))
        for n, (i, fid, title) in enumerate(heads):
            j = heads[n + 1][0] if n + 1 < len(heads) else len(lines)
            for k in range(i + 1, j):
                if lines[k].startswith("## ") or lines[k].startswith("### "):
                    j = k
                    break
            block = lines[i + 1:j]
            # Mermaid fences VERBATIM (never redrawn — anti-fabrication)
            mermaid, in_fence, cur = [], False, []
            for ln in block:
                if re.match(r"^\s*```", ln):
                    if not in_fence and re.match(r"^\s*```mermaid", ln):
                        in_fence = True
                        cur = [ln]
                    elif in_fence:
                        cur.append(ln)
                        mermaid.append("\n".join(cur))
                        in_fence, cur = False, []
                    continue
                if in_fence:
                    cur.append(ln)
            # DoD items VERBATIM
            dod, in_dod = [], False
            for ln in block:
                if vault_md.FLOW_DOD_LABEL_RE.match(ln):
                    in_dod = True
                    continue
                if in_dod:
                    if vault_md.DOD_ITEM_RE.match(ln):
                        dod.append(ln)
                        continue
                    if ln.startswith("**") or ln.startswith("#"):
                        in_dod = False
            ftype = "user"
            pm = re.match(r"^F-([A-Z])-", fid)
            if pm:
                ftype = {"U": "user", "S": "system", "C": "cross-cutting",
                         "P": "pipeline", "X": "custom"}.get(pm.group(1), "custom")
            data["flows"].append({"id": fid, "title": title, "type": ftype,
                                  "mermaid": mermaid, "dod": dod})
    # units (both layouts)
    ufiles = sorted(
        [p for p in __import__("glob").glob(os.path.join(vroot, "units", "U-*.md"))]
        + [p for p in __import__("glob").glob(os.path.join(vroot, "units", "U-*", "unit.md"))]
    )
    for uf in ufiles:
        text = open(uf, encoding="utf-8", errors="surrogateescape").read()
        fm = frontmatter_region(text)
        uid = None
        title = ""
        vsource = ""
        for ln in fm.splitlines():
            m = FM_KEY_RE.match(ln)
            if not m:
                continue
            k, v = m.group(1).lower(), m.group(2).strip().strip("'\"")
            if k in ("id", "unit_id") and not uid:
                uid = v
            elif k == "title" and not title:
                title = v
            elif k == "vault_source" and not vsource:
                vsource = v
        if not uid:
            uid = os.path.splitext(os.path.basename(uf))[0]
            if uid == "unit":
                uid = os.path.basename(os.path.dirname(uf))
        fmatch = F_ID_RE.search(vsource or "")
        data["units"].append({
            "id": uid, "title": title, "file": uf,
            "flow_id": fmatch.group(0) if fmatch else None,
            "acceptance": parse_acceptance_entries(text),
        })
    mpath = os.path.join(vroot, "_meta", "modules.yaml")
    if os.path.isfile(mpath):
        data["modules"] = parse_modules_yaml(mpath)
    return data

parsed = [parse_vault(v) for v in vaults]
multi_scope = len(parsed) > 1 or any(p["scope"] for p in parsed)

# UAT/TS id derivation: 1:1 from F-*-NNN — the flow's numeric part when unique
# within the vault, ordinal fallback on numeric collision (IDENTICAL to SIT's TS
# derivation so UAT-NNN ↔ TS-NNN pair 1:1). Scope rides the id when scoped.
for p in parsed:
    nums = [re.search(r"(\d+)$", f["id"]).group(1) for f in p["flows"]]
    unique = len(set(nums)) == len(nums)
    for idx, f in enumerate(p["flows"], 1):
        n = nums[idx - 1] if unique else "%03d" % idx
        n = n.zfill(3)
        f["ts_id"] = "TS-%s-%s" % (p["scope"], n) if p["scope"] else "TS-%s" % n
        f["uat_id"] = "UAT-%s-%s" % (p["scope"], n) if p["scope"] else "UAT-%s" % n

# flow → linked unit ids (via vault_source F-id)
def units_for_flow(p, fid):
    return [u["id"] for u in sorted(p["units"], key=lambda x: x["id"]) if u["flow_id"] == fid]

def cell(s, limit=160):
    """Sanitize a value for a table cell — markdown-breaking bytes escaped."""
    s = (s or "").replace("\r", "").replace("\n", " ⏎ ").replace("|", "\\|").strip()
    return (s[: limit - 1] + "…") if len(s) > limit else s

def scope_label(p):
    return p["scope"] or "-"

sit_probe = probe_sit(vaults[0])
project_name = next((p["project_name"] for p in parsed if p["project_name"]), None)

# ── Fragment emission (mirror the SIT §-loop style) ──────────────────────────
L = []
L.append("<!-- mega-sdd:uat-scaffold")
L.append("generated_by: build-uat-scaffold.sh")
L.append("generated_at: %s" % ts_now)
L.append("maturity: draft")
L.append("scopes: %s" % ",".join(scope_label(p) for p in parsed))
L.append("sit_probe: %s" % sit_probe)
L.append("Blok §1–§4 di bawah disertakan VERBATIM ke UAT.md — model hanya menulis")
L.append("narasi §2 + baris langkah (mengganti marker `<!-- uat-steps:UAT-NNN -->`).")
L.append("-->")
L.append("")

# §1 — Ruang lingkup & kriteria
L.append("<!-- uat-scaffold:§1 -->")
if any(p["flows"] for p in parsed):
    hdr = "| UAT | TS | Flow | Judul | Tipe |"
    sep = "|---|---|---|---|---|"
    if multi_scope:
        hdr = "| Scope " + hdr
        sep = "|---" + sep
    L.append(hdr)
    L.append(sep)
    for p in parsed:
        for f in p["flows"]:
            row = "| %s | %s | %s | %s | %s |" % (f["uat_id"], f["ts_id"], f["id"], cell(f["title"], 80), f["type"])
            if multi_scope:
                row = "| %s %s" % (scope_label(p), row)
            L.append(row)
else:
    L.append("[Pending — vault/04-flows.md belum berisi flow F-* — jalankan generate-intent dulu]")
L.append("")
L.append("**Kriteria masuk (entry):**")
L.append("")
L.append("| Kriteria | Status |")
L.append("|---|---|")
L.append("| Berita acara SIT diterima dari pengembang (SEOJK 21/2017 §2.3.1.5) | [ ] |")
L.append("| SIT maturity saat emisi: %s | (info) |" % sit_probe)
L.append("| Environment UAT siap & data uji tersedia | [ ] |")
L.append("| Tester bisnis ditugaskan & briefing selesai | [ ] |")
L.append("")
L.append("**Kriteria keluar (exit):**")
L.append("")
L.append("| Kriteria | Status |")
L.append("|---|---|")
L.append("| Seluruh skenario UAT dieksekusi | [ ] |")
L.append("| Defect critical/high selesai atau disepakati ditangguhkan | [ ] |")
L.append("| Berita acara UAT ditandatangani (§4) | [ ] |")
L.append("")
L.append("**Sources for this section:**")
cited1 = False
for p in parsed:
    if os.path.isfile(os.path.join(p["root"], "04-flows.md")):
        L.append("- [¹] `vault/04-flows.md` (sha256: `pending`)")
        cited1 = True
if os.path.isfile(os.path.join(vaults[0], "sit", "SIT.md")):
    L.append("- [²] `sit/SIT.md` (sha256: `pending`)")
    cited1 = True
if not cited1:
    L.append("_(no source artifacts cited — see [Pending] markers above for missing sources)_")
L.append("<!-- /uat-scaffold:§1 -->")
L.append("")

# §2 — Skenario UAT (scaffold: Mermaid + DoD verbatim; model writes step rows)
L.append("<!-- uat-scaffold:§2 -->")
if not any(p["flows"] for p in parsed):
    L.append("[Pending — belum ada flow F-* untuk diturunkan menjadi skenario UAT]")
for p in parsed:
    for f in p["flows"]:
        L.append("### %s — %s (%s)" % (f["uat_id"], f["title"], f["id"]))
        L.append("")
        units = units_for_flow(p, f["id"])
        L.append("| Field | Nilai |")
        L.append("|---|---|")
        L.append("| Flow | %s |" % f["id"])
        L.append("| Unit terkait | %s |" % (", ".join(units) if units else "—"))
        L.append("| Prioritas | %s |" % PLACEHOLDER)
        L.append("| Prasyarat | %s |" % PLACEHOLDER)
        L.append("| Data uji | %s |" % PLACEHOLDER)
        L.append("")
        if f["mermaid"]:
            L.append("**Flow (Mermaid — verbatim dari vault):**")
            L.append("")
            for mm in f["mermaid"]:
                L.append(mm)
                L.append("")
        else:
            L.append("[Pending — diagram Mermaid untuk %s belum ada di vault/04-flows.md]" % f["id"])
            L.append("")
        L.append("**Expected outcome (DoD — verbatim dari vault):**")
        L.append("")
        if f["dod"]:
            L.extend(f["dod"])
        else:
            L.append("- [Pending — Definition of Done untuk %s belum ada di vault/04-flows.md]" % f["id"])
        L.append("")
        L.append("**Langkah uji (isi baris di bawah marker — hasil eksekusi diisi MANUSIA):**")
        L.append("")
        L.append(STEP_HDR)
        L.append(STEP_SEP)
        L.append("<!-- uat-steps:%s -->" % f["uat_id"])
        L.append("")
        L.append("**Pelaksana:** %s · **Tanggal eksekusi:** %s · **Tanda tangan:** %s"
                 % (PLACEHOLDER, PLACEHOLDER, PLACEHOLDER))
        L.append("")
L.append("**Sources for this section:**")
cited2 = False
for p in parsed:
    if os.path.isfile(os.path.join(p["root"], "04-flows.md")):
        L.append("- [¹] `vault/04-flows.md` (sha256: `pending`)")
        cited2 = True
if not cited2:
    L.append("_(no source artifacts cited — see [Pending] markers above for missing sources)_")
L.append("<!-- /uat-scaffold:§2 -->")
L.append("")

# §3 — Matriks ketertelusuran (RTM)
L.append("<!-- uat-scaffold:§3 -->")
if any(p["flows"] for p in parsed):
    hdr = "| Flow (F-id) | Judul | UAT | TS (SIT) | Unit terkait | Status UAT |"
    sep = "|---|---|---|---|---|---|"
    if multi_scope:
        hdr = "| Scope " + hdr
        sep = "|---" + sep
    L.append(hdr)
    L.append(sep)
    for p in parsed:
        for f in p["flows"]:
            units = units_for_flow(p, f["id"])
            row = "| %s | %s | %s | %s | %s | %s |" % (
                f["id"], cell(f["title"], 80), f["uat_id"], f["ts_id"],
                ", ".join(units) if units else "—", PLACEHOLDER)
            if multi_scope:
                row = "| %s %s" % (scope_label(p), row)
            L.append(row)
else:
    L.append("[Pending — belum ada flow F-* untuk RTM]")
L.append("")
L.append("**Sources for this section:**")
cited3 = False
for p in parsed:
    if os.path.isfile(os.path.join(p["root"], "04-flows.md")):
        L.append("- [¹] `vault/04-flows.md` (sha256: `pending`)")
        cited3 = True
    for u in p["units"]:
        rel = os.path.relpath(u["file"], p["root"])
        L.append("- [²] `%s` (sha256: `pending`)" % rel)
        cited3 = True
if not cited3:
    L.append("_(no source artifacts cited — see [Pending] markers above for missing sources)_")
L.append("<!-- /uat-scaffold:§3 -->")
L.append("")

# §4 — Berita Acara UAT (paper-out placeholder LITERALS — SEOJK §2.3.1.5)
L.append("<!-- uat-scaffold:§4 -->")
L.append("#### Berita Acara User Acceptance Test")
L.append("")
L.append("| Field | Nilai |")
L.append("|---|---|")
L.append("| Proyek / Sistem | %s |" % (project_name or PLACEHOLDER))
L.append("| Periode UAT | %s |" % PERIODE_VALUE)
L.append("| Test cycle | %s |" % PLACEHOLDER)
L.append("| Referensi SIT | %s |" % REF_SIT_VALUE)
L.append("")
L.append("**Outstanding defects:**")
L.append("")
L.append("| No | Deskripsi | Severity | Kesepakatan |")
L.append("|---|---|---|---|")
L.append("| 1 | %s | %s | %s |" % (PLACEHOLDER, PLACEHOLDER, PLACEHOLDER))
L.append("")
L.append(DECISION)
L.append("")
L.append("<!-- uat-signoff: baris tabel di bawah adalah placeholder LITERAL (paper-out).")
L.append("     Model DILARANG mengisinya — baris terisi = fabricated record, diblokir")
L.append("     deterministik oleh build-uat-scaffold.sh --check-execution. -->")
for p in parsed:
    if multi_scope:
        L.append("")
        L.append("### Sign-off — Scope %s" % scope_label(p))
    L.append("")
    L.append("| Peran | Nama | Tanggal | Tanda tangan | Status |")
    L.append("|---|---|---|---|---|")
    for role in UAT_SIGNOFF_ROLES:
        L.append("| %s | %s | %s | %s | %s |" % (role, PLACEHOLDER, PLACEHOLDER, PLACEHOLDER, BA_STATUS))
L.append("")
L.append("**Sources for this section:** _(no source artifacts cited — berita acara adalah catatan persetujuan manusia, paper-out)_")
L.append("<!-- /uat-scaffold:§4 -->")
L.append("")

fragment = "\n".join(L)
out_path = out_override or os.path.join(vaults[0], "uat", ".uat-scaffold.md")
os.makedirs(os.path.dirname(out_path), exist_ok=True)
tmp = out_path + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as f:
    f.write(fragment)
os.replace(tmp, out_path)

n_flows = sum(len(p["flows"]) for p in parsed)
n_units = sum(len(p["units"]) for p in parsed)
if not quiet:
    print("uat-scaffold: maturity=draft scenarios=%d units=%d sit=%s -> %s"
          % (n_flows, n_units, sit_probe, out_path))
    if sit_probe != "executed":
        print("WARN_SIT sit_maturity=%s — SEOJK 21/2017 §2.3.1.5: UAT hanya boleh mulai setelah berita acara SIT"
              % sit_probe)

# Default mode also guards an ALREADY-EMITTED UAT.md (re-emission cannot proceed
# over a forged execution/sign-off record; fragment stays written — audit-trail
# precedent, build-sit-evidence.sh:690-697).
uat_path = os.path.join(vaults[0], "uat", "UAT.md")
if os.path.isfile(uat_path):
    viol = check_execution(uat_path)
    if viol:
        print_execution_keterangan(viol)
        sys.exit(1)
sys.exit(0)
PYEOF
exit $?
