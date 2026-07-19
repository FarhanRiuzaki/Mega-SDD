#!/usr/bin/env bash
# derive-binding-json.sh — deterministic generator (W2): <vault>/binding.json is
# DERIVED from <vault>/binding.md, never hand-written or model-emitted.
# Shares its md grammar with validate-binding-json.sh via _lib/binding_md.py
# (the B1 shared-engine precedent — parsing can never fork).
# Exit 0 = derived; 2 = derive/parse error — the artifact does not match the
# mega-sdd grammar. mega-sdd-authored: an authoring bug (fix the Step-4
# binding.md write and re-run — not a halt). Externally-authored binding.md:
# not a bug — the grammar simply was never adopted (the v5 adoption lane covers
# this); fix manually per binding-md-template.md or re-generate via the
# pipeline. 3 = usage / unreadable binding.md.
# On ANY error binding.json is NOT written (never a partial/stale overwrite).
set -u
VAULT=""
while [ $# -gt 0 ]; do case "$1" in --vault) VAULT="$2"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;; *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: derive-binding-json.sh --vault <dir>" >&2; exit 3; }
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

V_VAULT="$VAULT" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import binding_md

vault = os.environ.get("V_VAULT") or ""
if not vault:
    print("FAIL: V_VAULT not set", file=sys.stderr); sys.exit(3)
md_path = os.path.join(vault, "binding.md")
js_path = os.path.join(vault, "binding.json")

try:
    md = open(md_path, encoding="utf-8").read()
except Exception as e:
    print(f"FAIL: cannot read binding.md: {e}")
    sys.exit(3)

errors = []

# (1) Frontmatter metadata — value provenance is binding.md ONLY (head +
# provenance are written once at bind Step 4, never recomputed here, so a
# re-derive is idempotent on them and cannot falsely clear stale_vs_head).
meta = binding_md.parse_frontmatter_metadata(md)
if meta["codebase_map_provenance"] is None:
    print("WARN: binding_metadata.codebase_map_provenance absent in binding.md frontmatter -> null", file=sys.stderr)
if meta["head"] is None:
    print("WARN: binding_metadata.head absent in binding.md frontmatter -> null", file=sys.stderr)

# (2) State Map — ordered full-cell rows; parse errors / duplicates / missing
# heading collect into errors (exit 2). Empty table under the heading is fine.
rows = binding_md.parse_state_map(md, errors, full=True)

# (4) Confirmed Claims side-index (ids not in the State Map are ignored —
# parity contract scope).
sources = binding_md.parse_confirmed_sources(md)

# (5) CONFLICT resolutions (structural S4 grammar + Claim-line rules).
resolutions = binding_md.parse_conflict_resolutions(md, errors)
for rcid in resolutions:
    if rcid not in rows:
        errors.append(
            f"{rcid}: '- **Claim**:' line names a claim id not present in the "
            f"State Map — fix the Claim line and re-run"
        )

# (3) Per-row: [reason:] token strip+validate; anti-dull truncation check.
claims = []
for cid, row in rows.items():
    anchor_cell = row["anchor_cell"]
    anchor = anchor_cell
    state_reason = None
    m = binding_md.REASON_TOKEN_RE.search(anchor_cell)
    if m:
        token = m.group(1)
        if token in binding_md.STATE_REASON_ENUM:
            state_reason = token
        else:
            errors.append(
                f"{cid}: unknown [reason: {token}] token in Anchor cell "
                f"(closed enum: {', '.join(binding_md.STATE_REASON_ENUM)}) — never guess"
            )
        anchor = anchor_cell[: m.start()].rstrip()
    elif re.search(r"truncat", anchor_cell, re.IGNORECASE):
        # Anti-dull: the S4 implementation-state.md MUST, machine-enforced —
        # a truncation-citing Anchor cell without the machine-closed token
        # would silently derive state_reason: null and dull the
        # generate-units direct-probe protection.
        errors.append(
            f"{cid}: Anchor cell cites truncation without a "
            f"[reason: truncated_section] token — add the token per "
            f"implementation-state.md and re-run"
        )
    claims.append({
        "id": row["id"],
        "verdict": row["verdict"],
        "state": row["state"],
        "state_reason": state_reason,
        "anchor": anchor,
        "confidence": row["confidence"],
        "field_diff": row["field_diff"],
        "vault_source": sources.get(cid),
        "resolution": resolutions.get(cid),
    })

if errors:
    for e in errors:
        print("FAIL:", e)
    print(
        "KETERANGAN: artefak tidak cocok dengan grammar mega-sdd — kalau ini file "
        "hasil tulis eksternal, itu bukan bug: grammar-nya memang belum diadopsi "
        "(binding di-derive dari bind-codebase, bukan di-adopsi); perbaiki manual mengikuti "
        "binding-md-template.md, atau re-generate via pipeline (re-bind)."
    )
    sys.exit(2)

# (6) Assemble + atomic write. generated_at is PRESERVED from the existing
# binding.json when the derived content is otherwise identical (idempotent
# re-derive, no git churn); fresh UTC stamp only when content changed or no
# prior file exists.
out = {
    "schema_version": "1.0",
    "generated_by": "derive-binding-json@1.0.0",
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "vault": vault,
    "codebase_map_provenance": meta["codebase_map_provenance"],
    "head": meta["head"],
    "claims": claims,
}
try:
    prior = json.load(open(js_path, encoding="utf-8"))
except Exception:
    prior = None
if isinstance(prior, dict) and prior.get("generated_at"):
    a = {k: v for k, v in out.items() if k != "generated_at"}
    b = {k: v for k, v in prior.items() if k != "generated_at"}
    if a == b:
        out["generated_at"] = prior["generated_at"]

tmp = js_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, js_path)
print(f"PASS: derived binding.json ({len(claims)} claims)")
sys.exit(0)
PYEOF
