#!/usr/bin/env bash
# derive-claims-ledger.sh — deterministic generator (v6 P1): <vault>/claims-ledger.json
# is DERIVED from the vault markdown, never hand-written or model-emitted.
# The ledger is the claim-enumeration input for bind-codebase --express: one terse
# machine-checked file replacing the model's whole-vault read. The markdown stays
# the single grammar (md-authoritative rail) — this script shares its parsers with
# derive-vault-json.sh via _lib/vault_md.py and cross-checks its own line-aware
# extraction against them (grammar can never fork silently).
# Claim id = C-<DOCCODE>-<NN> (MODE for the 00-index lock claim), per-doc ordinal;
# within a doc the § pass streams before the type-specific passes, so ordinals
# order by pass then line — deterministic, not strictly line-ordered. Stability
# across vault edits is the same class as model-minted ids (none guaranteed); the
# --paths "vault regenerated -> full re-bind" fallback covers renumbering.
# `source` is exactly `NN-name.md:LINE` (make-bound.sh SRC_RE form).
# `hints` are ADVISORY retrieval seeds, never a retrieval boundary.
# THE LEDGER IS A SKELETON, NEVER THE CLAIM BOUNDARY: express bind runs a model
# completeness sweep over the vault docs and APPENDS claims this grammar cannot
# see (prose constraints, named-H2 components) — express-bind.md §E2.
# Exit 0 = derived; 2 = grammar mismatch / zero claims (ledger NOT written);
# 3 = usage / unreadable vault.
set -u
VAULT=""
while [ $# -gt 0 ]; do case "$1" in --vault) VAULT="$2"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;; *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: derive-claims-ledger.sh --vault <dir>" >&2; exit 3; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT" >&2; exit 3; }
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

V_VAULT="$VAULT" python3 <<'PYEOF'
import hashlib, json, os, re, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_md

vault = os.environ.get("V_VAULT") or ""
ledger_path = os.path.join(vault, "claims-ledger.json")

DOCS = ["00-index.md", "01-overview.md", "02-architecture.md",
        "03-data-model.md", "04-flows.md", "05-decisions.md",
        "06-constraints.md"]
DOC_CODE = {"01-overview.md": "OV", "02-architecture.md": "AR",
            "03-data-model.md": "DM", "04-flows.md": "FL",
            "05-decisions.md": "DC", "06-constraints.md": "CN"}
SECTION_RE = re.compile(r"^##\s+§([\w-]+)\b\s*(.*)$")   # binding-coverage harvest form
MODE_RE = re.compile(r"^-\s*\*\*Implementation[ _]mode\*\*\s*:", re.IGNORECASE)
NFR_HEAD_RE = re.compile(r"^##\s+Non-functional requirements\b", re.IGNORECASE)

docs, doc_shas = {}, {}
for fn in DOCS:
    p = os.path.join(vault, fn)
    if os.path.isfile(p):
        raw = open(p, "rb").read()
        doc_shas[fn] = hashlib.sha256(raw).hexdigest()
        docs[fn] = raw.decode("utf-8", errors="replace")
if not docs:
    print(f"FAIL: no vault docs (00-06) found in {vault}")
    sys.exit(3)

def name_variants(snake):
    """Deterministic case variants for index queries — advisory hints only."""
    parts = [p for p in snake.split("_") if p]
    out = [snake]
    if parts:
        pascal = "".join(p[:1].upper() + p[1:] for p in parts)
        if pascal not in out:
            out.append(pascal)
        camel = pascal[:1].lower() + pascal[1:]
        if camel not in out:
            out.append(camel)
    return out

def terms_of(text, cap=6):
    seen, out = set(), []
    for w in re.findall(r"[A-Za-z_][A-Za-z0-9_]{3,}", text):
        lw = w.lower()
        if lw not in seen:
            seen.add(lw)
            out.append(lw)
        if len(out) >= cap:
            break
    return out

errors = []
claims = []
counters = {}

def add(doc, line_no, ctype, text, extra=None):
    code = DOC_CODE.get(doc, "MODE")
    counters[code] = counters.get(code, 0) + 1
    c = {
        "id": "C-%s-%02d" % (code, counters[code]),
        "type": ctype,
        "text": text.strip(),
        "source": "%s:%d" % (doc, line_no),
    }
    if extra:
        c.update(extra)
    claims.append(c)

# ── 00-index: implementation mode — Vault Lock SECTION only (a prose example
# line elsewhere in the doc must never become the mode claim) ──
lock_vals = vault_md.parse_vault_lock(docs.get("00-index.md", ""))
_ix_lines = docs.get("00-index.md", "").splitlines()
_in_lock = False
for i, line in enumerate(_ix_lines, 1):
    if line.startswith("## "):
        _in_lock = line.lstrip("# ").lower().startswith("vault lock")
        continue
    if _in_lock and MODE_RE.match(line.strip()):
        mode_val = lock_vals.get("implementation_mode")
        add("00-index.md", i, "mode", line.strip(),
            {"hints": {"terms": [mode_val.lower()] if mode_val else []}})
        break

# ── per numbered doc, in document order, one ordinal stream per doc ──
for fn in DOCS[1:]:
    md = docs.get(fn, "")
    if not md:
        continue
    lines = md.splitlines()

    # (a) `## §<id>` component/section claims — the same headings the
    # binding-coverage validator harvests, so ledger coverage == validator scope.
    # DELIBERATELY fence-blind, in parity with validate-vault-binding-coverage.sh
    # (equally fence-blind) — if one gains fence tracking, both must, together.
    for i, line in enumerate(lines, 1):
        sm = SECTION_RE.match(line)
        if sm:
            add(fn, i, "component", line.lstrip("# ").strip(),
                {"native_id": sm.group(1),
                 "hints": {"terms": terms_of(sm.group(2) or sm.group(1))}})

    if fn == "03-data-model.md":
        # (b) DBML entities, line-aware (shared regexes; fields at depth 1)
        in_fence, depth, pending_purpose, pending_line = False, 0, None, None
        current = None
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith("```"):
                if not in_fence and stripped.lower().startswith("```dbml"):
                    in_fence = True
                elif in_fence:
                    in_fence, depth, current, pending_purpose = False, 0, None, None
                continue
            if not in_fence:
                continue
            if depth == 0:
                pc = vault_md.PURPOSE_COMMENT_RE.search(line)
                if pc and stripped.startswith("//"):
                    pending_purpose, pending_line = pc.group(1).strip(), i
                    continue
                tm = vault_md.DBML_TABLE_RE.match(line)
                if tm:
                    # Grammar-marginal shapes fail LOUD, never narrow silently:
                    # a one-line `Table x { ... }` desyncs the depth tracker in
                    # BOTH this pass and the shared lib (the cross-count guard
                    # is blind to shared misses), dropping every later table.
                    if "}" in line:
                        errors.append(
                            f"03-data-model.md:{i}: one-line Table block "
                            f"(`Table X {{ ... }}` on a single line) is outside "
                            f"the vault DBML grammar — put fields on their own "
                            f"lines, or the following tables are silently lost."
                        )
                        continue
                    name = tm.group(1)
                    text = pending_purpose or stripped
                    add(fn, pending_line if pending_purpose else i, "entity",
                        text, {"entity": name, "fields": [],
                               "hints": {"symbols": name_variants(name)}})
                    current = claims[-1]
                    pending_purpose, pending_line = None, None
                    depth = 1
                elif re.match(r"^\s*[Tt]able\s", line):
                    # `Table café_orders {` etc. — a Table line the shared
                    # grammar cannot name would be dropped by BOTH passes
                    # (guard-blind). Fail closed instead.
                    errors.append(
                        f"03-data-model.md:{i}: Table line does not match the "
                        f"vault DBML grammar (name must be [A-Za-z0-9_]+): "
                        f"{stripped[:80]}"
                    )
                    pending_purpose, pending_line = None, None
                else:
                    # any other non-comment line at depth 0 detaches a pending
                    # Purpose comment (it must sit IMMEDIATELY above its Table)
                    if stripped:
                        pending_purpose, pending_line = None, None
                continue
            if depth == 1 and current is not None:
                first = stripped.split(None, 1)[0] if stripped else ""
                if (re.match(r"^\s+\S+\s+\S+", line)
                        and not stripped.startswith("//")
                        and first.lower() not in ("note", "note:", "indexes")
                        and "{" not in line):
                    current["fields"].append(first)
            depth += line.count("{") - line.count("}")
            if depth <= 0:
                depth, current = 0, None

    elif fn == "04-flows.md":
        for i, line in enumerate(lines, 1):
            fm = vault_md.FLOW_HEADING_RE.match(line)
            if fm:
                add(fn, i, "flow", fm.group(2).strip(),
                    {"native_id": fm.group(1),
                     "hints": {"terms": terms_of(fm.group(2))}})

    elif fn == "05-decisions.md":
        for i, line in enumerate(lines, 1):
            am = vault_md.ADR_HEADING_RE.match(line)
            if am:
                add(fn, i, "decision", am.group(2).strip(),
                    {"native_id": am.group(1),
                     "hints": {"terms": terms_of(am.group(2))}})

    elif fn == "06-constraints.md":
        # (c) NFR table rows: | Category | Requirement | Source |
        in_nfr = False
        for i, line in enumerate(lines, 1):
            if NFR_HEAD_RE.match(line):
                in_nfr = True
                continue
            if in_nfr and line.startswith("## "):
                in_nfr = False
            if in_nfr and line.strip().startswith("|"):
                # escaped pipes (\|) are cell content, not separators
                cells = [c.strip().replace("\\|", "|") for c in
                         re.split(r"(?<!\\)\|", line.strip().strip("|"))]
                if len(cells) >= 2 and cells[0] not in ("Category", "") \
                        and set(cells[0]) - set("-: "):
                    add(fn, i, "constraint", cells[1],
                        {"hints": {"terms": terms_of(cells[1])}})

# ── cross-count guard: line-aware extraction vs the shared-lib parsers.
# Lib parse errors are VAULT defects; a count fork with a clean lib parse is a
# DERIVER defect — the two failure messages must not blame the wrong side. ──
lib_errors = []
lib_entities = vault_md.parse_data_model(docs.get("03-data-model.md", ""), lib_errors)
lib_flows = vault_md.parse_flows(docs.get("04-flows.md", ""), lib_errors)
lib_adrs = vault_md.parse_adrs(docs.get("05-decisions.md", ""), lib_errors)
errors.extend(lib_errors)
mine = {
    "entities": sum(1 for c in claims if c["type"] == "entity"),
    "flows": sum(1 for c in claims if c["type"] == "flow"),
    "adrs": sum(1 for c in claims if c["type"] == "decision"),
}
theirs = {"entities": len(lib_entities), "flows": len(lib_flows),
          "adrs": len(lib_adrs)}
if not lib_errors:
    for cls in ("entities", "flows", "adrs"):
        if mine[cls] != theirs[cls]:
            errors.append(
                f"grammar fork on {cls}: ledger extracted {mine[cls]} vs "
                f"_lib/vault_md.py {theirs[cls]} on a clean lib parse — the "
                f"line-aware pass diverged from the shared grammar; fix "
                f"derive-claims-ledger.sh, never the lib."
            )

if not claims and not errors:
    errors.append(
        "zero claims extractable by the ledger grammar — the vault's claims "
        "may live in prose/named sections this deriver cannot see, or the "
        "vault is claimless (greenfield)."
    )

if errors:
    for e in errors:
        print("FAIL:", e)
    print(
        "KETERANGAN: ledger tidak bisa di-derive — BUKAN selalu cacat vault: "
        "klaim bisa saja hidup di luar grammar deriver, atau vault memang tanpa "
        "klaim (greenfield). bind --express akan fallback ke lane standar "
        "(baca vault utuh) secara eksplisit; perbaiki markdown vault HANYA jika "
        "pesan FAIL di atas menunjuk baris vault. JANGAN menulis "
        "claims-ledger.json manual (anti-laundering: E1 selalu re-derive)."
    )
    sys.exit(2)

out = {
    "schema": 1,
    "generated_by": "derive-claims-ledger@1.0.0",
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    # slug, never the caller's --vault argument: abs vs rel invocation must not
    # change the artifact's bytes (determinism) nor embed a machine path.
    "vault": os.path.basename(os.path.normpath(vault)),
    "doc_shas": doc_shas,
    "claims": claims,
}
try:
    prior = json.load(open(ledger_path, encoding="utf-8"))
except Exception:
    prior = None
if isinstance(prior, dict) and prior.get("generated_at"):
    a = {k: v for k, v in out.items() if k != "generated_at"}
    b = {k: v for k, v in prior.items() if k != "generated_at"}
    if a == b:
        out["generated_at"] = prior["generated_at"]

tmp = ledger_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, ledger_path)
print(f"PASS: derived claims-ledger.json ({len(claims)} claims)")
sys.exit(0)
PYEOF
