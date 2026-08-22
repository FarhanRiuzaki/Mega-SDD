#!/usr/bin/env bash
# make-bound.sh — deterministic deriver (W1): <vault>/bound/ is DERIVED from the
# vault docs + binding.json — the model must NEVER hand-write bound/ (a non-zero
# exit means fix the bind write, not bypass this script).
#
# Pipeline: (1) parity preflight via validate-binding-json.sh (non-zero exit
# passes through verbatim — the sidecar is trusted only after parity holds);
# (2) deterministic refusal gate — ANY claims[].verdict == CONFLICT → exit 2
# (leading-token match, so a decorated `CONFLICT (BLOCKING)` cell refuses too;
# regardless of `resolution`; bound/ only ever arrives via a fresh clean
# re-bind), and under --strict any verdict == OQ also refuses; refusal touches
# NOTHING on disk — a previously-clean bound/ stays; (3) byte-copy the vault's
# 0[0-6]-*.md docs into a temp dir, inserting one standalone
# `<!-- BIND: <verdict>=<claim-id> -->` comment line AFTER each claim's
# binding.json `vault_source` line (`<file>.md:<line>` form only — null /
# section-style / out-of-bounds / unmatched-file sources are SKIPPED and
# counted, never guessed); (4) byte-copy binding.md as the bound/binding.md
# mirror; (5) atomic swap temp → <vault>/bound/ so the existence signal is
# never a partial tree.
#
# Exit 0 = bound/ derived (one PASS line); 2 = REFUSED (conflicts / strict-OQs)
# or parity-gate failure passthrough; 3 = usage / missing vault or binding
# artifacts.
set -u
VAULT=""; STRICT=0
while [ $# -gt 0 ]; do case "$1" in --vault) VAULT="${2:-}"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;; --strict) STRICT=1; shift;; *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: make-bound.sh --vault <dir> [--strict]" >&2; exit 3; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT" >&2; exit 3; }
[ -f "$VAULT/vault.json" ] || { echo "FAIL: $VAULT/vault.json missing — not a vault" >&2; exit 3; }
# Dual layout (v7 Fase 3): legacy 0[0-6]-*.md OR layout-2 vault.md set.
set -- "$VAULT"/0[0-6]-*.md
[ -f "$1" ] || set -- "$VAULT"/vault.md
[ -f "$1" ] || { echo "FAIL: no vault docs (layout-2 vault.md or legacy 0[0-6]-*.md) in $VAULT" >&2; exit 3; }
[ -f "$VAULT/binding.md" ] || { echo "FAIL: $VAULT/binding.md missing — re-run bind Step 4" >&2; exit 3; }
[ -f "$VAULT/binding.json" ] || { echo "FAIL: $VAULT/binding.json missing — re-run bind Step 4.5 (derive-binding-json.sh)" >&2; exit 3; }
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

# (1) Parity preflight — REUSE the existing gate; its non-zero exit passes
# through verbatim (parity must hold before deriving).
POUT="$(bash "${SCRIPT_DIR}/validate-binding-json.sh" --vault "$VAULT" </dev/null 2>&1)"; PRC=$?
if [ "$PRC" -ne 0 ]; then
  printf '%s\n' "$POUT"
  echo "FAIL: binding.md<->binding.json parity must hold before deriving bound/ — fix the bind write (Steps 4/4.5) and re-run"
  exit "$PRC"
fi

V_VAULT="$VAULT" V_STRICT="$STRICT" python3 <<'PYEOF'
import json, os, re, shutil, sys, tempfile

vault = os.environ.get("V_VAULT") or ""
strict = os.environ.get("V_STRICT") == "1"
if not vault:
    print("FAIL: V_VAULT not set", file=sys.stderr); sys.exit(3)
md_path = os.path.join(vault, "binding.md")
js_path = os.path.join(vault, "binding.json")

try:
    data = json.load(open(js_path, encoding="utf-8"))
except Exception as e:
    print(f"FAIL: cannot read binding.json: {e}")
    sys.exit(3)
claims = [c for c in data.get("claims", []) if isinstance(c, dict)]

# (2) Deterministic refusal gate — refusal paths write NOTHING. The verdict is
# normalized to its LEADING token: a decorated cell like `CONFLICT (BLOCKING)`
# must refuse exactly like the bare enum (no validator enforces the closed
# verdict enum, so an exact-match compare was a decoration bypass).
def _verdict_tok(c):
    toks = str(c.get("verdict", "")).strip().split()
    return toks[0].upper() if toks else ""

conflict_ids = [str(c.get("id")) for c in claims
                if _verdict_tok(c) == "CONFLICT"]
if conflict_ids:
    print("REFUSE: CONFLICT verdict(s) in binding.json — bound/ is never "
          "produced while any conflict is active: " + ", ".join(conflict_ids))
    print("REFUSE: resolve via resolve-oq --binding " + md_path +
          " and re-bind; filesystem untouched (a previously-clean bound/ stays)")
    sys.exit(2)
if strict:
    oq_ids = [str(c.get("id")) for c in claims
              if _verdict_tok(c) == "OQ"]
    if oq_ids:
        print("REFUSE: --strict and OQ verdict(s) in binding.json: "
              + ", ".join(oq_ids))
        print("REFUSE: resolve the OQs (or bind without --strict); filesystem "
              "untouched (a previously-clean bound/ stays)")
        sys.exit(2)

# (3) Copy set per binding-contract.md §bound-vault structure: the vault's
# markdown docs (sorted) — legacy 0[0-6]-*.md OR the layout-2 fixed names
# (v7 Fase 3 dual read). vault.json is NOT copied.
docs = sorted(f for f in os.listdir(vault)
              if (re.match(r"^0[0-6]-.+\.md$", f)
                  or f in ("vault.md", "model.md", "flows.md", "constraints.md"))
              and os.path.isfile(os.path.join(vault, f)))

# Annotation index: only the exact `<file>.md:<line>` vault_source form is
# trusted; everything else (null / section-style / unmatched file) is SKIPPED
# and counted — never guessed (no-fabrication invariant).
SRC_RE = re.compile(
    r"^((?:\d{2}-[A-Za-z0-9._-]+|vault|model|flows|constraints)\.md):(\d+)$")
index = {}   # file -> {line -> [(verdict_lower, claim_id)] in binding.json order}
annotated = 0
skipped = 0
for c in claims:
    src = c.get("vault_source")
    m = SRC_RE.match(src.strip()) if isinstance(src, str) else None
    if not m or m.group(1) not in docs:
        skipped += 1
        continue
    index.setdefault(m.group(1), {}).setdefault(int(m.group(2)), []).append(
        (str(c.get("verdict", "")).strip().lower(), str(c.get("id"))))

tmp = tempfile.mkdtemp(prefix=".bound.tmp.", dir=vault)
try:
    for fname in docs:
        src_path = os.path.join(vault, fname)
        dst_path = os.path.join(tmp, fname)
        per_line = index.get(fname)
        if not per_line:
            shutil.copyfile(src_path, dst_path)  # byte-identical copy
            continue
        try:
            text = open(src_path, "rb").read().decode("utf-8")
        except UnicodeDecodeError:
            shutil.copyfile(src_path, dst_path)  # undecodable → raw copy
            skipped += sum(len(v) for v in per_line.values())
            continue
        eol = "\r\n" if "\r\n" in text else "\n"
        had_trailing = text.endswith(eol)
        body = text[: -len(eol)] if had_trailing else text
        lines = body.split(eol)
        n_orig = len(lines)
        # DESCENDING cited-line order: earlier insertions never shift later
        # targets. Same-line claims merge into ONE comment (binding.json order).
        for lineno in sorted(per_line, reverse=True):
            group = per_line[lineno]
            if lineno < 1 or lineno > n_orig:
                skipped += len(group)   # out-of-bounds → skip, counted
                continue
            comment = "<!-- BIND: " + ", ".join(
                f"{v}={cid}" for v, cid in group) + " -->"
            lines.insert(lineno, comment)
            annotated += len(group)
        out = eol.join(lines) + (eol if had_trailing else "")
        with open(dst_path, "w", encoding="utf-8", newline="") as f:
            f.write(out)

    # (4) bound/binding.md mirror — byte-identical copy of vault-root binding.md.
    shutil.copyfile(md_path, os.path.join(tmp, "binding.md"))

    # (5) Atomic swap: bound/ EXISTENCE is a routing/preflight signal — a
    # partial tree must never persist; a crash mid-swap leaves bound/ ABSENT
    # (fail-safe: absence routes back to bind-codebase, opens nothing).
    bound = os.path.join(vault, "bound")
    if os.path.isdir(bound):
        shutil.rmtree(bound)
    elif os.path.exists(bound):
        os.remove(bound)
    os.rename(tmp, bound)
except Exception as e:
    print(f"FAIL: bound/ production failed: {e}")
    sys.exit(3)
finally:
    if os.path.isdir(tmp):
        shutil.rmtree(tmp, ignore_errors=True)

print(f"PASS: bound/ derived ({len(docs)} docs, {annotated} annotations, {skipped} skipped)")
sys.exit(0)
PYEOF
