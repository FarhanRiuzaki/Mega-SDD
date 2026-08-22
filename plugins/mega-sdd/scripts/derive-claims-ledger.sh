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

# Layout-aware doc set + DOC_CODE (v7 Fase 3 dual read): on layout-2 the
# per-file codes OV/AR/DC re-key to vault.md SECTIONS (the hard-header
# contract — vault_md.V2_SECTION_ANCHORS is the one mapping).
LAYOUT2 = vault_md.is_layout2_vault(vault)
if LAYOUT2:
    DOCS = ["vault.md", "model.md", "flows.md", "constraints.md"]
    DOC_CODE = {"model.md": "DM", "flows.md": "FL", "constraints.md": "CN"}
    DOC_IDX, DOC_DM, DOC_FL, DOC_DC = "vault.md", "model.md", "flows.md", "vault.md"
    DOC_CN = "constraints.md"
else:
    DOCS = ["00-index.md", "01-overview.md", "02-architecture.md",
            "03-data-model.md", "04-flows.md", "05-decisions.md",
            "06-constraints.md"]
    DOC_CODE = {"01-overview.md": "OV", "02-architecture.md": "AR",
                "03-data-model.md": "DM", "04-flows.md": "FL",
                "05-decisions.md": "DC", "06-constraints.md": "CN"}
    DOC_IDX, DOC_DM, DOC_FL, DOC_DC = ("00-index.md", "03-data-model.md",
                                       "04-flows.md", "05-decisions.md")
    DOC_CN = "06-constraints.md"
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
    print(f"FAIL: no vault docs found in {vault} "
          f"(layout-2: vault.md/model.md/flows.md/constraints.md; legacy: 00-06)")
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

def add(doc, line_no, ctype, text, extra=None, code=None):
    code = code or DOC_CODE.get(doc, "MODE")
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

# ── implementation mode claim ──
# Legacy: the Vault Lock SECTION bullet only (a prose example line elsewhere in
# the doc must never become the mode claim). Layout-2: the frontmatter scalar
# line in vault.md (gate addition 2 — the residue moved, it did not die).
lock_vals = vault_md.parse_vault_lock(docs.get(DOC_IDX, ""))
_ix_lines = docs.get(DOC_IDX, "").splitlines()
if LAYOUT2:
    # hard-header contract: fail LOUD (exit != 0, naming the header) before
    # any claim math can produce a silently thin ledger
    for _h in vault_md.v2_missing_headers(docs.get("vault.md", "")):
        errors.append(
            f"vault.md is missing the mandatory section header `{_h}` "
            f"(layout-2 hard-header contract — DOC_CODE re-keys from filename "
            f"to section, so the anchors are a contract, not a convention)"
        )
    _in_fm = False
    for i, line in enumerate(_ix_lines, 1):
        if i == 1 and line.strip() == "---":
            _in_fm = True
            continue
        if _in_fm and line.strip() == "---":
            break
        if _in_fm and re.match(r"^implementation_mode\s*:", line):
            mode_val = lock_vals.get("implementation_mode")
            add("vault.md", i, "mode", line.strip(),
                {"hints": {"terms": [mode_val.lower()] if mode_val else []}},
                code="MODE")
            break
else:
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

# ── per doc, in document order, one ordinal stream per doc/section-code ──
_CLAIM_DOCS = DOCS if LAYOUT2 else DOCS[1:]
for fn in _CLAIM_DOCS:
    md = docs.get(fn, "")
    if not md:
        continue
    lines = md.splitlines()
    # Layout-2 vault.md: per-line section attribution (OV/AR/DC) — the ONE
    # mapping in vault_md.v2_section_codes; a claim heading outside every
    # anchor section cannot be attributed and fails loud (no fabricated code).
    sec_codes = (vault_md.v2_section_codes(lines)
                 if (LAYOUT2 and fn == "vault.md") else None)

    def _code_at(i):
        if sec_codes is None:
            return None                     # add() falls back to DOC_CODE
        c = sec_codes.get(i)
        if c is None:
            errors.append(
                f"vault.md:{i}: claim heading sits outside the "
                f"Overview/Architecture/Decisions anchor sections — it cannot "
                f"be attributed a DOC_CODE (move it under an anchor header)"
            )
        return c

    # (a) `## §<id>` component/section claims — the same headings the
    # binding-coverage validator harvests, so ledger coverage == validator scope.
    # DELIBERATELY fence-blind (parity with the deleted binding-coverage validator's shape)
    # (equally fence-blind) — if one gains fence tracking, both must, together.
    for i, line in enumerate(lines, 1):
        sm = SECTION_RE.match(line)
        if sm:
            _c = _code_at(i)
            if sec_codes is not None and _c is None:
                continue
            add(fn, i, "component", line.lstrip("# ").strip(),
                {"native_id": sm.group(1),
                 "hints": {"terms": terms_of(sm.group(2) or sm.group(1))}},
                code=_c)

    if fn == DOC_DM:
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
                            f"{fn}:{i}: one-line Table block "
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
                        f"{fn}:{i}: Table line does not match the "
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

    elif fn == DOC_FL:
        for i, line in enumerate(lines, 1):
            fm = vault_md.FLOW_HEADING_RE.match(line)
            if fm:
                add(fn, i, "flow", fm.group(2).strip(),
                    {"native_id": fm.group(1),
                     "hints": {"terms": terms_of(fm.group(2))}})

    elif fn == DOC_DC:
        for i, line in enumerate(lines, 1):
            am = vault_md.ADR_HEADING_RE.match(line)
            if am:
                _c = _code_at(i)
                if sec_codes is not None and _c is None:
                    continue                # attribution error already recorded
                add(fn, i, "decision", am.group(2).strip(),
                    {"native_id": am.group(1),
                     "hints": {"terms": terms_of(am.group(2))}},
                    code=_c)

    elif fn == DOC_CN:
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
lib_entities = vault_md.parse_data_model(docs.get(DOC_DM, ""), lib_errors,
                                         doc_name=DOC_DM)
lib_flows = vault_md.parse_flows(docs.get(DOC_FL, ""), lib_errors, doc_name=DOC_FL)
lib_adrs = vault_md.parse_adrs(docs.get(DOC_DC, ""), lib_errors, doc_name=DOC_DC)
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
