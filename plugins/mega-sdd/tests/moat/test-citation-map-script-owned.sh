#!/usr/bin/env bash
# Moat regression (invariant #3 — citation discipline): the citation map + every
# sha256 stamp is SCRIPT-OWNED (W3, spec 2026-07-19-w-batch-script-derive.md).
#
#   1  both scripts exist under plugins/mega-sdd/scripts/ and run under bash </dev/null
#   2  tamper — a hand-forged source_sha256 in a script-written map is OVERWRITTEN
#      with the hashlib-true value on the next build (the map cannot hold a
#      fabricated hash across an emit)
#   3  SKILL.md instructs RUN of build-citation-map.sh in Step 4.6 and its rails
#      contain 'never writes a hash'
#   4  halt-protocol.md subtype enum contains 'citation_unresolvable'
#   5  a citation to a nonexistent path yields exit 1 (the halt trigger is
#      deterministic, not prose)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD="${PLUGIN_ROOT}/scripts/build-citation-map.sh"
DRIFT="${PLUGIN_ROOT}/scripts/check-citation-drift.sh"
SKILL="${PLUGIN_ROOT}/skills/emit-fsd/SKILL.md"
HP="${PLUGIN_ROOT}/references/halt-protocol.md"

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

sha_of() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

# --- Case 1: scripts exist + run under bash ---
[ -f "$BUILD" ] && [ -f "$DRIFT" ] || { echo "FAIL: script(s) missing under plugins/mega-sdd/scripts/"; exit 1; }

F="${ROOT}/proj"
V="${F}/.mega-sdd/vaults/v1"
mkdir -p "${V}/fsd"
printf '{"project_name":"moat"}\n' > "${V}/vault.json"
printf '# Overview\n\nPurpose.\n' > "${V}/01-overview.md"
cat > "${V}/fsd/FSD.md" <<'EOF'
# Moat fixture

**Mode:** Pre-development · **Source vault:** `.mega-sdd/vaults/v1` (sha256: `pending`)

## 1. Overview

Body.

**Sources for this section:**
- [¹] `vault/01-overview.md:L1-L3` (sha256: `pending`)
EOF

bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null >/dev/null 2>&1; code=$?
[ "$code" = "0" ] || { echo "FAIL: build-citation-map.sh did not run clean under bash (exit $code)"; exit 1; }
bash "$DRIFT" --vault="$V" --cwd="$F" </dev/null >/dev/null 2>&1; code=$?
[ "$code" = "0" ] || { echo "FAIL: check-citation-drift.sh did not run under bash (exit $code)"; exit 1; }
echo "PASS (both scripts exist + run under bash)"

# --- Case 2: forged map hash is OVERWRITTEN with the hashlib-true value ---
MAP="${V}/fsd/.citation-map.json"
TRUE_H=$(sha_of "${V}/01-overview.md")
MAP="$MAP" python3 - <<'PY'
import json, os
p = os.environ["MAP"]
m = json.load(open(p))
for s in m["sections"]:
    if s["source_path"] == "vault/01-overview.md":
        s["source_sha256"] = "f00d" * 16
json.dump(m, open(p, "w"), indent=2)
PY
bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null >/dev/null 2>&1
MAP="$MAP" TRUE_H="$TRUE_H" python3 - <<'PY'
import json, os, sys
m = json.load(open(os.environ["MAP"]))
e = [s for s in m["sections"] if s["source_path"] == "vault/01-overview.md"]
sys.exit(0 if e and all(x["source_sha256"] == os.environ["TRUE_H"] for x in e) else 1)
PY
[ $? = 0 ] || { echo "FAIL: forged source_sha256 survived a rebuild — the map can hold a fabricated hash"; exit 1; }
echo "PASS (tampered map hash overwritten with hashlib-true value)"

# --- Case 3: SKILL.md runs the builder in Step 4.6 + rails pin ---
sed -n '/^### Step 4.6:/,/^### Step 5:/p' "$SKILL" | grep -q 'Run `bash <plugin-root>/scripts/build-citation-map.sh' \
  || { echo "FAIL: SKILL.md Step 4.6 lost the build-citation-map.sh RUN instruction"; exit 1; }
grep -q 'never writes a hash' "$SKILL" \
  || { echo "FAIL: SKILL.md rails lost the 'never writes a hash' pin"; exit 1; }
echo "PASS (SKILL.md Step 4.6 run instruction + 'never writes a hash' rail present)"

# --- Case 4: halt-protocol subtype enum carries citation_unresolvable ---
grep -q 'citation_unresolvable' "$HP" \
  || { echo "FAIL: halt-protocol.md subtype enum missing citation_unresolvable"; exit 1; }
echo "PASS (halt-protocol enum contains citation_unresolvable)"

# --- Case 5: nonexistent cited path => deterministic exit 1 ---
cat >> "${V}/fsd/FSD.md" <<'EOF'

[Source: vault/does-not-exist.md (sha256: pending)]
EOF
bash "$BUILD" --vault="$V" --cwd="$F" --mode=pre-dev </dev/null >/dev/null 2>&1; code=$?
[ "$code" = "1" ] || { echo "FAIL: nonexistent cited path exited $code, want 1 (the halt trigger must be deterministic)"; exit 1; }
echo "PASS (fabricated citation path is a deterministic exit 1)"
