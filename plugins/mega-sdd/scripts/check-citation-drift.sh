#!/usr/bin/env bash
# check-citation-drift.sh — W3: the SANCTIONED reader of <vault>/fsd/.citation-map.json
# (spec 2026-07-19-w-batch-script-derive.md). The model NEVER Reads the map — this
# script reads the prior map itself, recomputes each source's sha256 from file
# bytes, and prints ONLY drifted-source lines. That replaces emit-fsd's wholesale
# prior-map read (~1.5-3k input tokens) with a ≤20-line diff list, and means the
# model can neither invent nor suppress hashes on the drift side: a forged hash in
# a legacy model-written map surfaces as DRIFT (the conservative direction).
#
# Usage:
#   check-citation-drift.sh --vault=<vault-dir> --cwd=<project-root>
#
# Stdout grammar (pinned — never 64-hex strings, never raw JSON):
#   DRIFT <section> <path> <old12> <new12>   source bytes changed since the prior emit
#   GONE <section> <path> <old12>            prior resolved source no longer exists
#   UNVERIFIED <section> <path>              prior entry cannot be re-verified
#                                            (schema-1.0 source_path that resolves to
#                                            no file via the builder's resolution
#                                            order, or a prior unresolved entry)
#   NO_PRIOR                                 no prior map — first emit
#   PRIOR_UNREADABLE                         prior map exists but is not parseable
#
# <section> is the major FSD section (drift callouts are per-section); duplicate
# (section, path) pairs are deduplicated. No output at all = nothing drifted.
#
# Exit codes: 0 for ALL informational outcomes (incl. NO_PRIOR/PRIOR_UNREADABLE);
# 2 usage error only.

set -uo pipefail

VAULT=""
CWD=""
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT="${arg#*=}" ;;
    --cwd=*)   CWD="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { echo "--vault=<vault-dir> required (dir must exist)" >&2; exit 2; }
[ -n "$CWD" ] && [ -d "$CWD" ] || { echo "--cwd=<project-root> required (dir must exist)" >&2; exit 2; }

MAP="$VAULT/fsd/.citation-map.json"
if [ ! -f "$MAP" ]; then
  echo "NO_PRIOR"
  exit 0
fi

VAULT="$VAULT" CWD="$CWD" MAP="$MAP" python3 <<'PYEOF'
import hashlib, json, os, sys

vault = os.path.abspath(os.environ["VAULT"])
cwd = os.path.abspath(os.environ["CWD"])

try:
    with open(os.environ["MAP"], "rb") as f:
        prior = json.load(f)
    entries = prior.get("sections")
    assert isinstance(entries, list)
except Exception:
    print("PRIOR_UNREADABLE")
    sys.exit(0)

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def resolve(cited):
    """Same vault/-prefix → vault → project → codebase-map order as the builder
    (build-citation-map.sh) — the schema-1.0 fallback for display-form paths."""
    c = str(cited).strip().strip("`")
    cands = []
    if c.startswith("vault/"):
        cands.append(os.path.join(vault, c[len("vault/"):]))
    cands.append(os.path.join(vault, c))
    cands.append(os.path.join(cwd, c))
    cands.append(os.path.join(cwd, ".mega-sdd", "codebase", c))
    for p in cands:
        if os.path.isfile(p):
            return os.path.abspath(p)
    return None

seen = set()
for e in entries:
    if not isinstance(e, dict):
        continue
    sec = str(e.get("fsd_section") or "?").split(".")[0]
    sp = str(e.get("source_path") or "?")
    key = (sec, sp)
    if key in seen:
        continue
    seen.add(key)

    prior_h = e.get("source_sha256")
    old12 = str(prior_h)[:12] if prior_h else ""
    rp = e.get("resolved_path")  # schema 2.0; absent in legacy 1.0 maps

    if not prior_h:
        # Prior entry carried no hash (unresolved at build time) — nothing to compare.
        print(f"UNVERIFIED {sec} {sp}")
        continue

    if rp:
        path_abs = os.path.join(cwd, rp)
        if not os.path.isfile(path_abs):
            print(f"GONE {sec} {sp} {old12}")
            continue
    else:
        path_abs = resolve(sp)
        if path_abs is None:
            print(f"UNVERIFIED {sec} {sp}")
            continue

    cur = sha256_file(path_abs)
    if cur != prior_h:
        print(f"DRIFT {sec} {sp} {old12} {cur[:12]}")

sys.exit(0)
PYEOF
exit $?
