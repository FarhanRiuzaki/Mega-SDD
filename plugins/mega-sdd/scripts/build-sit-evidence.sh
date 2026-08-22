#!/usr/bin/env bash
# build-sit-evidence.sh — deterministic builder of the SIT evidence fragment (P5,
# spec docs/superpowers/specs/2026-07-19-v5-execution-spec.md P5 row + decisions
# 5/9/10; research §4 "emit-sit").
#
# THE UNFAKEABLE COLUMN: SIT §4 (Bukti eksekusi) must never be model-authored —
# a hand-typed "pass" in a bank test document is a fabricated record. This script
# is the ONLY sanctioned producer of the SIT evidence tables: it READS the
# hook-guarded evidence artifacts (<vault>/bolts/U-*/acceptance.json written by
# run-acceptance-tests.sh [B4], <vault>/bolts/U-*/postflight.json written by
# run-postflight-scan.sh [B1], <vault>/bolts/_batch-suite.json written by
# run-full-suite.sh [B2]) and emits ready-to-include markdown. The model includes
# the fragment VERBATIM and writes only the surrounding Indonesian narrative.
#
# What it emits (one fragment file, default <vault>/sit/.sit-evidence.md):
#   §1  Ruang lingkup uji — flows-in-scope table (TS ↔ F-id ↔ judul ↔ DoD count)
#       + module DoD from <vault>/_meta/modules.yaml when present
#   §2  Skenario uji scaffold — one TS block per F-* flow carrying the flow's
#       Mermaid diagram VERBATIM + its DoD items VERBATIM as expected outcomes
#       (the Mermaid-flows hard rule extends to SIT; a flow without a Mermaid
#       body surfaces a [Pending] marker, never a redrawn diagram)
#   §3  Matriks test case — one TC row per unit acceptance_test[] entry with
#       full traceability TC ↔ TS ↔ F-id ↔ unit id (structured authority = the
#       unit frontmatter, parsed with the SAME region extraction
#       run-acceptance-tests.sh / validate-unit-spec.sh use)
#   §4  Bukti eksekusi — per-entry acceptance rows (status/rc/retried/output_head
#       raw — decision 9: unknown runner output recorded raw as evidence, counts
#       never fabricated), pending_manual rows surfaced as manual tests awaiting
#       execution, per-unit B1 postflight verdicts, the vault-level B2 batch-suite
#       line. ABSENT evidence → the literal row
#       `[Pending — bolt U-XXX belum dieksekusi]` — NEVER invented.
#   §5  Sign-off — bank-style table(s) whose BODY ROWS are placeholder LITERALS
#       (nama/tanggal/tanda tangan = `__________`, status = unchecked boxes).
#       Paper-out per decision 5: a model-filled row is a FABRICATED RECORD.
#   MATURITY verdict (script-computable ladder, decision on evidence coverage):
#       planned  — no unit has acceptance evidence
#       executed — every unit has acceptance.json with status "pass"
#       partial  — anything in between (incl. pending_manual_only / fails)
#
# MULTI-SCOPE (decision 10, locked): --vault= is repeatable → ONE merged fragment;
# ids carry the scope (TS-<SCOPE>-NNN / TC-<SCOPE>-NNN) when the vault's
# vault.json has scope_metadata.id; sign-off table per scope. Single unscoped
# vault → plain TS-NNN / TC-NNN.
#
# SIGN-OFF SLOT-GRAMMAR GUARD (decision 5 — the chosen zero-risk wiring, per
# references/emission-engine.md §P5 seams: validate-fsd-slots.sh stays FSD-scoped
# because its PostToolUse path contract must not widen; the SIT guard lives HERE
# as a sibling check): when <vault>/sit/SIT.md exists (default mode) or with
# --check-signoff (check-only mode), §5 body rows are scanned — ANY
# non-placeholder text in the Nama / Tanggal / Tanda tangan / Status cells is a
# deterministic FAIL (exit 1) with Indonesian keterangan framing it as a
# fabricated record.
#
# Usage:
#   build-sit-evidence.sh --vault=<vault-dir> [--vault=<dir2> ...] \
#       --cwd=<project-root> [--out=<fragment-path>] [--quiet]
#   build-sit-evidence.sh --check-signoff --vault=<vault-dir> [--cwd=<root>]
# Exit: 0 = fragment written (and sign-off clean when SIT.md exists)
#       1 = sign-off violation (fabricated record) — keterangan printed;
#           in default mode the fragment is still written (audit-trail precedent:
#           build-citation-map.sh writes the map on exit 1)
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
    --check-signoff) CHECK_ONLY=1 ;;
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

def _flpath(root):
    # v7 Fase 3 dual-layout read (one minor cycle): layout-2 flows.md first.
    return vault_md.resolve_doc(root, "04-flows.md")

def _flname(root):
    return os.path.basename(_flpath(root))

vaults = [os.path.abspath(v) for v in os.environ["VAULTS_JOINED"].splitlines() if v.strip()]
cwd = os.path.abspath(os.environ["CWD"]) if os.environ.get("CWD") else None
out_override = os.environ.get("OUT") or None
quiet = os.environ.get("QUIET", "0") == "1"
check_only = os.environ.get("CHECK_ONLY", "0") == "1"
ts_now = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")

PLACEHOLDER = "__________"
STATUS_PLACEHOLDER = "[ ] Diterima · [ ] Ditolak"
SIGNOFF_ROLES = ("QA Lead", "Dev Lead", "Product Owner")

# ── Sign-off slot-grammar check (decision 5) ─────────────────────────────────
def check_signoff(sit_path):
    """Scan §5 body rows of an emitted SIT.md. Returns list of violation lines."""
    try:
        lines = open(sit_path, encoding="utf-8", errors="surrogateescape").read().split("\n")
    except OSError:
        return ["SIGNOFF_UNREADABLE %s" % sit_path]
    in5 = False
    seen5 = False
    violations = []
    body_rows = 0
    for i, line in enumerate(lines, 1):
        if re.match(r"^## 5\.", line):
            in5, seen5 = True, True
            continue
        if in5 and re.match(r"^## \d+\.", line):
            in5 = False
        if not in5 or not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not cells:
            continue
        if cells[0] == "Peran":
            continue  # header row
        if all(re.fullmatch(r":?-{3,}:?", c) for c in cells if c):
            continue  # separator row
        if len(cells) != 5:
            violations.append("SIGNOFF_SHAPE %d %s" % (i, cells[0] if cells else "?"))
            continue
        body_rows += 1
        peran, nama, tanggal, ttd, status = cells
        for label, got in (("Nama", nama), ("Tanggal", tanggal), ("Tanda tangan", ttd)):
            if got != PLACEHOLDER:
                violations.append("SIGNOFF_FILLED %d %s %s" % (i, peran, label))
        if status != STATUS_PLACEHOLDER:
            violations.append("SIGNOFF_FILLED %d %s Status" % (i, peran))
    if not seen5:
        violations.insert(0, "SIGNOFF_SECTION_MISSING")
    elif body_rows == 0:
        violations.insert(0, "SIGNOFF_TABLE_MISSING")
    return violations

def print_signoff_keterangan(violations):
    for v in violations:
        print(v)
    print("KETERANGAN: baris sign-off SIT yang terisi terdeteksi — sign-off adalah")
    print("persetujuan MANUSIA (paper-out). Baris yang diisi model/AI adalah FABRICATED")
    print("RECORD dan diblokir deterministik (decision 5, v5 spec). Kembalikan sel")
    print("Nama/Tanggal/Tanda tangan ke literal `%s` dan Status ke" % PLACEHOLDER)
    print("`%s`; persetujuan asli ditandatangani di dokumen cetak." % STATUS_PLACEHOLDER)

if check_only:
    sit_path = os.path.join(vaults[0], "sit", "SIT.md")
    if not os.path.isfile(sit_path):
        print("ERROR: %s not found — nothing to check" % sit_path, file=sys.stderr)
        sys.exit(2)
    v = check_signoff(sit_path)
    if v:
        print_signoff_keterangan(v)
        sys.exit(1)
    print("sit-signoff: clean (semua baris sign-off masih placeholder literal)")
    sys.exit(0)

# ── Per-vault parsing ────────────────────────────────────────────────────────
FM_KEY_RE = re.compile(r"^([A-Za-z_]+)\s*:\s*(.*)$")
F_ID_RE = re.compile(r"\bF-(?:[A-Z]-)?\d+\b")

def frontmatter_region(text):
    if not text.startswith("---"):
        return ""
    end = text.find("\n---", 3)
    return text[3:end] if end != -1 else ""

def parse_acceptance_entries(full_text):
    """SAME region extraction run-acceptance-tests.sh / validate-unit-spec.sh
    use (^acceptance_test\\s*: up to the next top-level key) — REUSE, no new
    YAML dep. Kept byte-compatible with run-acceptance-tests.sh."""
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
    data = {"root": vroot, "scope": None, "flows": [], "units": [], "modules": []}
    vjson_path = os.path.join(vroot, "vault.json")
    if os.path.isfile(vjson_path):
        try:
            vj = json.load(open(vjson_path))
            sm = vj.get("scope_metadata") or {}
            sid = str(sm.get("id") or "").strip()
            if sid:
                data["scope"] = sid.upper()
        except (OSError, ValueError):
            pass
    flows_path = _flpath(vroot)
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

# TS id derivation: 1:1 from F-*-NNN — the flow's numeric part when unique
# within the vault, ordinal fallback on numeric collision. Scope rides the id
# (decision 10): TS-<SCOPE>-NNN when the vault is scoped.
for p in parsed:
    nums = [re.search(r"(\d+)$", f["id"]).group(1) for f in p["flows"]]
    unique = len(set(nums)) == len(nums)
    for idx, f in enumerate(p["flows"], 1):
        n = nums[idx - 1] if unique else "%03d" % idx
        n = n.zfill(3)
        f["ts_id"] = "TS-%s-%s" % (p["scope"], n) if p["scope"] else "TS-%s" % n

ts_by_flow = {}
for p in parsed:
    for f in p["flows"]:
        ts_by_flow[(p["root"], f["id"])] = f["ts_id"]

# ── Evidence read (B4/B1/B2 artifacts — hook-guarded writers own them) ───────
def read_json(path):
    if not os.path.isfile(path):
        return None
    try:
        return json.load(open(path))
    except (OSError, ValueError):
        return {"_unreadable": True}

for p in parsed:
    for u in p["units"]:
        bdir = os.path.join(p["root"], "bolts", u["id"])
        u["acc_json"] = read_json(os.path.join(bdir, "acceptance.json"))
        u["pf_json"] = read_json(os.path.join(bdir, "postflight.json"))
    p["batch"] = read_json(os.path.join(p["root"], "bolts", "_batch-suite.json"))

# ── Maturity (script-computable ladder — evidence coverage over B4) ──────────
def vault_maturity(p):
    units = p["units"]
    if not units:
        return "planned"
    with_ev = [u for u in units if u["acc_json"] and not u["acc_json"].get("_unreadable")]
    if not with_ev:
        return "planned"
    if len(with_ev) == len(units) and all(u["acc_json"].get("status") == "pass" for u in with_ev):
        return "executed"
    return "partial"

RANK = {"planned": 0, "partial": 1, "executed": 2}
maturities = [vault_maturity(p) for p in parsed]
maturity = min(maturities, key=lambda m: RANK[m]) if maturities else "planned"
# merged doc: any evidence at all lifts planned→partial even if one scope is empty
if maturity == "planned" and any(RANK[m] > 0 for m in maturities):
    maturity = "partial"

def cell(s, limit=160):
    """Sanitize raw evidence for a table cell — content preserved raw except
    markdown-breaking bytes (decision 9: raw output IS the evidence)."""
    s = (s or "").replace("\r", "").replace("\n", " ⏎ ").replace("|", "\\|").strip()
    return (s[: limit - 1] + "…") if len(s) > limit else s

def scope_label(p):
    return p["scope"] or "-"

# ── Fragment emission ────────────────────────────────────────────────────────
L = []
L.append("<!-- mega-sdd:sit-evidence")
L.append("generated_by: build-sit-evidence.sh")
L.append("generated_at: %s" % ts_now)
L.append("maturity: %s" % maturity)
L.append("scopes: %s" % ",".join(scope_label(p) for p in parsed))
L.append("Blok §1–§5 di bawah disertakan VERBATIM ke SIT.md — model tidak mengedit sel.")
L.append("-->")
L.append("")

# §1 — Ruang lingkup uji
L.append("<!-- sit-evidence:§1 -->")
if any(p["flows"] for p in parsed):
    hdr = "| TS | Flow | Judul | Tipe | DoD items |"
    sep = "|---|---|---|---|---|"
    if multi_scope:
        hdr = "| Scope " + hdr
        sep = "|---" + sep
    L.append(hdr)
    L.append(sep)
    for p in parsed:
        for f in p["flows"]:
            row = "| %s | %s | %s | %s | %d |" % (f["ts_id"], f["id"], cell(f["title"], 80), f["type"], len(f["dod"]))
            if multi_scope:
                row = "| %s %s" % (scope_label(p), row)
            L.append(row)
else:
    L.append("[Pending — flows doc vault (flows.md / 04-flows.md) belum berisi flow F-* — jalankan generate-intent dulu]")
L.append("")
L.append("**Module DoD:**")
L.append("")
any_mod = False
for p in parsed:
    for m in p["modules"]:
        any_mod = True
        label = m["name"] or m["id"]
        L.append("- **%s** (%s%s):" % (label, m["id"], " · scope %s" % p["scope"] if p["scope"] else ""))
        for d in m["dod"]:
            L.append("  - %s" % d)
        if not m["dod"]:
            L.append("  - [Pending — DoD module %s belum diisi di _meta/modules.yaml]" % m["id"])
if not any_mod:
    L.append("_Module DoD: `_meta/modules.yaml` tidak ada — module tunggal implisit (M-default), tanpa DoD level module._")
L.append("")
L.append("**Sources for this section:**")
for p in parsed:
    if os.path.isfile(_flpath(p["root"])):
        L.append("- [¹] `vault/%s` (sha256: `pending`)" % _flname(p["root"]))
    if p["modules"]:
        L.append("- [²] `_meta/modules.yaml` (sha256: `pending`)")
L.append("<!-- /sit-evidence:§1 -->")
L.append("")

# §2 — Skenario uji (TS scaffold: Mermaid + DoD verbatim)
L.append("<!-- sit-evidence:§2 -->")
if not any(p["flows"] for p in parsed):
    L.append("[Pending — belum ada flow F-* untuk diturunkan menjadi skenario uji]")
for p in parsed:
    for f in p["flows"]:
        L.append("### %s — %s (%s)" % (f["ts_id"], f["title"], f["id"]))
        L.append("")
        if f["mermaid"]:
            L.append("**Flow (Mermaid — verbatim dari vault):**")
            L.append("")
            for mm in f["mermaid"]:
                L.append(mm)
                L.append("")
        else:
            L.append("[Pending — diagram Mermaid untuk %s belum ada di flows doc vault]" % f["id"])
            L.append("")
        L.append("**Expected outcome (DoD — verbatim dari vault):**")
        L.append("")
        if f["dod"]:
            L.extend(f["dod"])
        else:
            L.append("- [Pending — Definition of Done untuk %s belum ada di flows doc vault]" % f["id"])
        L.append("")
L.append("**Sources for this section:**")
cited2 = False
for p in parsed:
    if os.path.isfile(_flpath(p["root"])):
        L.append("- [¹] `vault/%s` (sha256: `pending`)" % _flname(p["root"]))
        cited2 = True
if not cited2:
    L.append("_(no source artifacts cited — see [Pending] markers above for missing sources)_")
L.append("<!-- /sit-evidence:§2 -->")
L.append("")

# §3 — Matriks test case (TC ↔ TS ↔ F-id ↔ unit)
L.append("<!-- sit-evidence:§3 -->")
tc_rows = []
for p in parsed:
    seq = 0
    for u in sorted(p["units"], key=lambda x: x["id"]):
        ts = ts_by_flow.get((p["root"], u["flow_id"])) if u["flow_id"] else None
        ts_cell = ts or "[Pending — flow untuk %s tidak teridentifikasi dari vault_source]" % u["id"]
        f_cell = u["flow_id"] or "—"
        if not u["acceptance"]:
            seq += 1
            tcid = "TC-%s-%03d" % (p["scope"], seq) if p["scope"] else "TC-%03d" % seq
            tc_rows.append((p, tcid, ts_cell, f_cell, u["id"], "—",
                            "[Pending — %s tanpa acceptance_test terstruktur]" % u["id"], "—"))
            continue
        for e in u["acceptance"]:
            seq += 1
            tcid = "TC-%s-%03d" % (p["scope"], seq) if p["scope"] else "TC-%03d" % seq
            etype = (e.get("type") or "test").lower()
            cmd = "`%s`" % cell(e.get("command"), 80) if e.get("command") else "(manual) %s" % cell(e.get("desc"), 80)
            tc_rows.append((p, tcid, ts_cell, f_cell, u["id"], etype, cmd, cell(e.get("expects"), 60) or "—"))
if tc_rows:
    hdr = "| TC | TS | Flow | Unit | Tipe | Perintah / Deskripsi | Expects |"
    sep = "|---|---|---|---|---|---|---|"
    if multi_scope:
        hdr = "| Scope " + hdr
        sep = "|---" + sep
    L.append(hdr)
    L.append(sep)
    for (p, *cells_) in tc_rows:
        row = "| " + " | ".join(str(c) for c in cells_) + " |"
        if multi_scope:
            row = "| %s %s" % (scope_label(p), row)
        L.append(row)
else:
    L.append("[Pending — units belum digenerate — jalankan generate-units dulu]")
L.append("")
L.append("**Sources for this section:**")
cited3 = False
for p in parsed:
    for u in p["units"]:
        rel = os.path.relpath(u["file"], p["root"])
        L.append("- [¹] `%s` (sha256: `pending`)" % rel)
        cited3 = True
if not cited3:
    L.append("_(no source artifacts cited — see [Pending] markers above for missing sources)_")
L.append("<!-- /sit-evidence:§3 -->")
L.append("")

# §4 — Bukti eksekusi (UNFAKEABLE: read from hook-guarded artifacts only)
L.append("<!-- sit-evidence:§4 -->")
L.append("#### 4.1 Bukti acceptance test (B4 — `acceptance.json`, script-derived)")
L.append("")
hdr = "| Unit | Entry | Perintah | Hasil | rc | Retried | Bukti (output_head, raw) |"
sep = "|---|---|---|---|---|---|---|"
if multi_scope:
    hdr = "| Scope " + hdr
    sep = "|---" + sep
L.append(hdr)
L.append(sep)
manual_rows = []
any_unit = False
for p in parsed:
    for u in sorted(p["units"], key=lambda x: x["id"]):
        any_unit = True
        aj = u["acc_json"]
        if aj is None:
            row = "| %s | — | — | [Pending — bolt %s belum dieksekusi] | — | — | — |" % (u["id"], u["id"])
            if multi_scope:
                row = "| %s %s" % (scope_label(p), row)
            L.append(row)
            continue
        if aj.get("_unreadable"):
            row = "| %s | — | — | [Pending — acceptance.json %s tidak terbaca] | — | — | — |" % (u["id"], u["id"])
            if multi_scope:
                row = "| %s %s" % (scope_label(p), row)
            L.append(row)
            continue
        n = 0
        for e in aj.get("entries", []):
            if e.get("pending_manual"):
                manual_rows.append((p, u["id"], (e.get("type") or "manual"), cell(e.get("desc"), 100)))
                continue
            n += 1
            row = "| %s | %d (%s) | `%s` | %s | %s | %s | `%s` |" % (
                u["id"], n, e.get("type", "test"), cell(e.get("command"), 60),
                "pass" if e.get("pass") else "fail", e.get("rc", "—"),
                "ya" if e.get("retried") else "tidak", cell(e.get("output_head"), 120) or "—")
            if multi_scope:
                row = "| %s %s" % (scope_label(p), row)
            L.append(row)
        if n == 0 and aj.get("status") == "pending_manual_only":
            row = "| %s | — | — | pending_manual_only | — | — | (semua entri manual — lihat 4.2) |" % u["id"]
            if multi_scope:
                row = "| %s %s" % (scope_label(p), row)
            L.append(row)
if not any_unit:
    L.append("| [Pending — units belum digenerate] | — | — | — | — | — | — |" if not multi_scope
             else "| — | [Pending — units belum digenerate] | — | — | — | — | — | — |")
L.append("")
L.append("#### 4.2 Manual test — menunggu eksekusi manusia")
L.append("")
if manual_rows:
    L.append("| Unit | Tipe | Deskripsi | Status |")
    L.append("|---|---|---|---|")
    for (p, uid, mtype, desc) in manual_rows:
        L.append("| %s | %s | %s | MENUNGGU EKSEKUSI MANUAL |" % (uid, mtype, desc or "—"))
else:
    L.append("_(tidak ada entri manual — semua acceptance test executable)_")
L.append("")
L.append("#### 4.3 Hard-rule postflight (B1 — `postflight.json`)")
L.append("")
L.append("| Unit | Status | Rules | head_sha |")
L.append("|---|---|---|---|")
any_pf = False
for p in parsed:
    for u in sorted(p["units"], key=lambda x: x["id"]):
        any_pf = True
        pj = u["pf_json"]
        if pj is None:
            L.append("| %s | [Pending — postflight %s belum ada] | — | — |" % (u["id"], u["id"]))
        elif pj.get("_unreadable"):
            L.append("| %s | [Pending — postflight.json %s tidak terbaca] | — | — |" % (u["id"], u["id"]))
        else:
            L.append("| %s | %s | %d | `%s` |" % (u["id"], pj.get("status", "—"),
                                                  len(pj.get("rules", [])),
                                                  (pj.get("head_sha") or "")[:12] or "—"))
if not any_pf:
    L.append("| [Pending — units belum digenerate] | — | — | — |")
L.append("")
L.append("#### 4.4 Full-suite batch (B2 — `_batch-suite.json`)")
L.append("")
for p in parsed:
    b = p["batch"]
    pref = "Scope %s: " % p["scope"] if multi_scope else ""
    if b is None:
        L.append("- %s[Pending — _batch-suite.json belum ada — jalankan run-full-suite.sh]" % pref)
    elif b.get("_unreadable"):
        L.append("- %s[Pending — _batch-suite.json tidak terbaca]" % pref)
    else:
        L.append("- %ssuite **%s** @ `%s` (runner: `%s`, exit %s, %s)" % (
            pref, b.get("status", "—"), (b.get("head_sha") or "")[:12],
            cell(b.get("runner"), 60), b.get("exit_code", "—"), b.get("ran_at", "—")))
L.append("")
L.append("**Sources for this section:**")
cited4 = False
for p in parsed:
    for u in p["units"]:
        for name, j in (("acceptance.json", u["acc_json"]), ("postflight.json", u["pf_json"])):
            if j is not None and not j.get("_unreadable"):
                L.append("- [¹] `bolts/%s/%s` (sha256: `pending`)" % (u["id"], name))
                cited4 = True
    if p["batch"] is not None and not p["batch"].get("_unreadable"):
        L.append("- [²] `bolts/_batch-suite.json` (sha256: `pending`)")
        cited4 = True
if not cited4:
    L.append("_(no source artifacts cited — see [Pending] markers above for missing sources)_")
L.append("<!-- /sit-evidence:§4 -->")
L.append("")

# §5 — Sign-off (paper-out placeholder LITERALS — decision 5)
L.append("<!-- sit-evidence:§5 -->")
L.append("<!-- sit-signoff: baris tabel di bawah adalah placeholder LITERAL (paper-out).")
L.append("     Model DILARANG mengisinya — baris terisi = fabricated record, diblokir")
L.append("     deterministik oleh build-sit-evidence.sh --check-signoff. -->")
for p in parsed:
    if multi_scope:
        L.append("")
        L.append("### Sign-off — Scope %s" % scope_label(p))
    L.append("")
    L.append("| Peran | Nama | Tanggal | Tanda tangan | Status |")
    L.append("|---|---|---|---|---|")
    for role in SIGNOFF_ROLES:
        L.append("| %s | %s | %s | %s | %s |" % (role, PLACEHOLDER, PLACEHOLDER, PLACEHOLDER, STATUS_PLACEHOLDER))
L.append("")
L.append("**Sources for this section:** _(no source artifacts cited — sign-off adalah catatan persetujuan manusia, paper-out)_")
L.append("<!-- /sit-evidence:§5 -->")
L.append("")

fragment = "\n".join(L)
out_path = out_override or os.path.join(vaults[0], "sit", ".sit-evidence.md")
os.makedirs(os.path.dirname(out_path), exist_ok=True)
tmp = out_path + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as f:
    f.write(fragment)
os.replace(tmp, out_path)

n_flows = sum(len(p["flows"]) for p in parsed)
n_units = sum(len(p["units"]) for p in parsed)
n_exec = sum(1 for p in parsed for u in p["units"]
             if u["acc_json"] and not u["acc_json"].get("_unreadable"))
if not quiet:
    print("sit-evidence: maturity=%s flows=%d ts=%d tc=%d units=%d executed=%d/%d manual=%d -> %s"
          % (maturity, n_flows, n_flows, len(tc_rows), n_units, n_exec, n_units,
             len(manual_rows), out_path))

# Default mode also guards an ALREADY-EMITTED SIT.md (re-emission cannot proceed
# over a forged sign-off; fragment stays written — audit-trail precedent).
sit_path = os.path.join(vaults[0], "sit", "SIT.md")
if os.path.isfile(sit_path):
    v = check_signoff(sit_path)
    if v:
        print_signoff_keterangan(v)
        sys.exit(1)
sys.exit(0)
PYEOF
exit $?
