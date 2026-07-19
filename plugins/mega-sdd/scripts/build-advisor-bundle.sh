#!/usr/bin/env bash
# build-advisor-bundle.sh — P7 (5.1.1): the phase-advisor SEED, materialized.
#
# The advisor's dispatch used to paste the WHOLE codebase-map + vault + KB into
# the subagent prompt — a FRESH, uncached seed paid at full 1.0x (the largest
# real-dollar token bucket per research/2026-07-19-v5-architecture-research.md).
# This deriver replaces the paste with a compact seed the advisor EXPANDS from:
# the draft verdict+anchor set (from binding.json) plus the PATHS of the map /
# vault / KB, sha-stamped for freshness — never the file contents.
#
# The moat guarantee is by construction, not promise: the bundle is a strict
# SUBSET pointer. The phase-advisor has Read/Grep/Glob and is instructed (its
# checklist) to Grep the full on-disk map for missed_match — so a contradiction
# living OUTSIDE these verdicts is still reachable and in scope. The bundle is a
# seed, never the advisor's horizon. (Same pattern as domain-extractor, which
# receives "the legacy paths to read", not the pasted corpus.)
#
# Usage: build-advisor-bundle.sh --vault <dir>
# Writes: <vault>/.advisor-bundle.md   (overwritten each bind)
# Exit 0 = bundle written; 3 = usage / missing binding artifacts.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
VAULT=""
while [ $# -gt 0 ]; do case "$1" in
  --vault) VAULT="${2:-}"; shift 2;;
  --vault=*) VAULT="${1#*=}"; shift;;
  *) shift;;
esac; done
[ -n "$VAULT" ] || { echo "usage: build-advisor-bundle.sh --vault <dir>" >&2; exit 3; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT" >&2; exit 3; }
[ -f "$VAULT/binding.md" ]   || { echo "FAIL: $VAULT/binding.md missing — run bind Step 4 first" >&2; exit 3; }
[ -f "$VAULT/binding.json" ] || { echo "FAIL: $VAULT/binding.json missing — run derive-binding-json.sh first" >&2; exit 3; }

# Resolve project root so a relative `codebase_map:` path resolves to disk.
. "$SCRIPT_DIR/_lib/resolve-project-root.sh"
ROOT="$(resolve_project_root "$VAULT")"

V_VAULT="$VAULT" V_ROOT="$ROOT" python3 <<'PYEOF'
import hashlib, json, os, re, sys

vault = os.environ["V_VAULT"]
root  = os.environ["V_ROOT"]
md    = os.path.join(vault, "binding.md")
js    = os.path.join(vault, "binding.json")

# map path from binding.md frontmatter `codebase_map:` (falls back to canonical).
map_rel = None
head_sha = None
try:
    with open(md, encoding="utf-8") as f:
        for line in f:
            m = re.match(r'\s*codebase_map:\s*(\S.*?)\s*$', line)
            if m and map_rel is None:
                map_rel = m.group(1).strip().strip('"').strip("'")
            h = re.match(r'\s*head:\s*(\S+)', line)
            if h and head_sha is None:
                head_sha = h.group(1).strip()
except Exception:
    pass
if not map_rel:
    map_rel = ".mega-sdd/codebase/codebase-map.md"

map_abs = map_rel if os.path.isabs(map_rel) else os.path.join(root, map_rel)
map_present = os.path.isfile(map_abs)
map_sha = None
if map_present:
    with open(map_abs, "rb") as f:
        map_sha = hashlib.sha256(f.read()).hexdigest()

# KB dir (first existing canonical location) — a search-space pointer, not pasted.
kb_dir = None
for cand in (".mega-sdd/knowledge-base", "docs/knowledge-base", "old-reference/knowledge-base"):
    p = os.path.join(root, cand)
    if os.path.isdir(p):
        kb_dir = p
        break

try:
    data = json.load(open(js, encoding="utf-8"))
except Exception as e:
    print(f"FAIL: cannot read binding.json: {e}", file=sys.stderr)
    sys.exit(3)
claims = [c for c in data.get("claims", []) if isinstance(c, dict)]

def cell(v):
    return (str(v).replace("|", "\\|").replace("\n", " ") if v is not None else "—")

rows = []
for c in claims:
    rows.append("| {} | {} | {} | {} |".format(
        cell(c.get("id")), cell(c.get("verdict")),
        cell(c.get("vault_source")), cell(c.get("anchor"))))

out = os.path.join(vault, ".advisor-bundle.md")
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write("---\n")
    f.write("bundle_kind: advisor-seed\n")
    f.write(f"vault: {os.path.basename(os.path.normpath(vault))}\n")
    f.write(f"codebase_map_path: {map_rel}\n")
    f.write(f"codebase_map_present: {'true' if map_present else 'false'}\n")
    f.write(f"codebase_map_sha256: {map_sha or 'null'}\n")
    f.write(f"binding_head: {head_sha or 'null'}\n")
    f.write(f"kb_dir: {os.path.relpath(kb_dir, root) if kb_dir else 'null'}\n")
    f.write("generated_by: build-advisor-bundle.sh\n")
    f.write("---\n\n")
    f.write("# Phase-advisor SEED bundle\n\n")
    f.write("> **This bundle is a SEED, not your horizon.** It is a strict subset "
            "of the evidence — a starting point, never the boundary of what you may "
            "read. The moat depends on you expanding past it.\n\n")
    f.write("## Draft verdicts (the claims to attack)\n\n")
    f.write("| id | verdict | vault_source | codebase anchor |\n")
    f.write("|---|---|---|---|\n")
    f.write(("\n".join(rows) if rows else "| — | — | — | — |") + "\n\n")
    f.write("## Search space — expand HERE (do NOT treat the bundle as complete)\n\n")
    f.write(f"- **codebase-map** (primary ground truth): `{map_rel}`"
            + (f" · sha256 `{map_sha}`" if map_sha else " · MISSING")
            + " — Grep this WHOLE file.\n")
    f.write(f"- **vault**: `{os.path.relpath(vault, root)}` — the claims' source docs.\n")
    f.write(f"- **KB**: " + (f"`{os.path.relpath(kb_dir, root)}`" if kb_dir else "none present")
            + " — secondary ground truth.\n\n")
    f.write("## Expansion contract (mandatory)\n\n")
    f.write("1. **false_confirmed** — for every `CONFIRMED`, open its codebase anchor "
            "and verify it REALLY matches the vault claim.\n")
    f.write("2. **missed_match** — for every `OQ`/`NEW`, **Grep the FULL codebase-map "
            f"at `{map_rel}`**: the implementation may exist under a DIFFERENT "
            "name/path that is NOT in the verdicts above. Evidence outside this "
            "bundle is IN SCOPE and expected — finding it is the point.\n")
    f.write("3. A finding still requires source evidence (file:line / map entry). "
            "Grep first, cite second — never fabricate.\n")

print(f"PASS: advisor bundle written ({len(claims)} verdicts, map={'present' if map_present else 'MISSING'}) -> {out}")
PYEOF
