#!/usr/bin/env bash
# measure-seeds.sh — point the seeding_budget ruler at every consumer's CURRENT
# seed on a real vault and print a ranked table. This is the P7 baseline
# instrument: the number next to each consumer is what slice-first must shrink,
# and the same table is the "boros token" answer in bytes no competitor
# publishes (v5 telemetry substrate, P10).
#
# A "seed" is the corpus a consumer is handed at dispatch/open. We measure the
# FILE-resolvable seed components; components that vary per run (a domain-
# extractor's legacy wave slice, a subagent's live draft) are listed as
# "(varies)" and NOT invented — understating by omission is honest here, a
# fabricated count is not.
#
# Usage: measure-seeds.sh --vault <vault-dir> [--json] [--pack <pack.md>]
#   --vault  the vault dir (.mega-sdd/vaults/<slug>/)
#   --pack   the matched framework-conventions pack file (bind loads exactly one;
#            we cannot know WHICH without the binding metadata, so it is opt-in)
#   --json   emit the ranked records as JSON instead of the table
#
# Exit 0 = measured; 3 = usage / vault missing.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
LIB="$SCRIPT_DIR/_lib/seeding_budget.py"
VAULT="" ; AS_JSON=0 ; PACK=""
while [ $# -gt 0 ]; do case "$1" in
  --vault) VAULT="${2:-}"; shift 2;;
  --vault=*) VAULT="${1#*=}"; shift;;
  --pack) PACK="${2:-}"; shift 2;;
  --pack=*) PACK="${1#*=}"; shift;;
  --json) AS_JSON=1; shift;;
  *) shift;;
esac; done
[ -n "$VAULT" ] || { echo "usage: measure-seeds.sh --vault <dir> [--json] [--pack <file>]" >&2; exit 3; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT" >&2; exit 3; }
[ -f "$LIB" ] || { echo "FAIL: seeding_budget.py lib missing at $LIB" >&2; exit 3; }

# Resolve project root (for codebase-map + KB, which live outside the vault).
. "$SCRIPT_DIR/_lib/resolve-project-root.sh"
ROOT="$(resolve_project_root "$VAULT")"

# Locate the shared, out-of-vault seed components (first existing wins).
_first() { for p in "$@"; do [ -e "$p" ] && { printf '%s' "$p"; return 0; }; done; return 1; }
MAP="$(_first "$ROOT/.mega-sdd/codebase/codebase-map.md" "$ROOT/.mega-sdd/codebase-map.md" "$ROOT/codebase-map.md" || true)"
KB="$(_first "$ROOT/.mega-sdd/knowledge-base" "$ROOT/docs/knowledge-base" "$ROOT/old-reference/knowledge-base" || true)"
ADV_CHECKLIST="$SCRIPT_DIR/../skills/bind-codebase/references/advisor-checklist.md"

# Vault-local components (globs expand to what exists).
VAULT_DOCS=(); for f in "$VAULT"/0[0-6]-*.md; do [ -f "$f" ] && VAULT_DOCS+=("$f"); done
[ -f "$VAULT/vault.json" ] && VAULT_DOCS+=("$VAULT/vault.json")
BOUND_DIR="$VAULT/bound"
BINDING_MD="$VAULT/binding.md"
BINDING_JSON="$VAULT/binding.json"

# Cache weighting: a FRESH subagent seed is paid at 1.0x; a RESIDENT main-context
# load is cached ~0.1x after turn 1 (research §2). Ranking by cost-units, not raw
# bytes, is what points slice-first at real dollars — a whole-map paste into a
# subagent outranks a bigger resident load.
BUNDLE="$VAULT/.advisor-bundle.md"   # post-5.1.1 advisor seed (build-advisor-bundle.sh)

RECORDS="$(mktemp 2>/dev/null || mktemp -t measureseeds)"
trap 'rm -f "$RECORDS"' EXIT
: > "$RECORDS"

emit() {  # emit <label> <weight fresh|resident> <component paths...>
  local label="$1" weight="$2"; shift 2
  local args=(); for a in "$@"; do [ -n "$a" ] && args+=("$a"); done
  [ ${#args[@]} -gt 0 ] || return 0
  python3 "$LIB" --label "$label" --weight "$weight" --json "${args[@]}" 2>/dev/null >> "$RECORDS"
}

# 1. bind-codebase — RESIDENT main context: vault + codebase-map + KB + pack.
emit "bind-codebase" resident "${VAULT_DOCS[@]}" ${MAP:+"$MAP"} ${KB:+"$KB"} ${PACK:+"$PACK"}
# 2. phase-advisor — FRESH subagent. Post-5.1.1 the PASTED seed is the compact
#    bundle + checklist (+ draft binding); the map/vault/KB are grep-on-demand,
#    NOT pasted. Absent bundle → surfaced as MISSING (bind hasn't built it yet).
emit "phase-advisor" fresh "$ADV_CHECKLIST" "$BUNDLE" ${BINDING_MD:+"$BINDING_MD"}
# 3. generate-units — RESIDENT: bound/ annotated docs + binding manifest + sidecar.
emit "generate-units" resident ${BOUND_DIR:+"$BOUND_DIR"} ${BINDING_MD:+"$BINDING_MD"} ${BINDING_JSON:+"$BINDING_JSON"}
# 4. resolve-oq — RESIDENT: the vault (re-read each pass unless all-priorities).
emit "resolve-oq" resident "${VAULT_DOCS[@]}"

python3 - "$RECORDS" "$AS_JSON" "${MAP:-}" "${KB:-}" "${PACK:-}" "$BUNDLE" <<'PYEOF'
import json, os, sys
records_path, as_json, mapf, kbf, packf, bundlef = (
    sys.argv[1], sys.argv[2] == "1", sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
recs = []
with open(records_path, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if line:
            recs.append(json.loads(line))
# Rank by cost-units (cache-weighted) — the unit that reflects real dollars.
recs.sort(key=lambda r: r.get("cost_units", r.get("approx_tokens", 0)), reverse=True)
total = sum(r.get("bytes", 0) for r in recs) or 1
total_cu = sum(r.get("cost_units", 0) for r in recs) or 1
notes = []
if not mapf: notes.append("codebase-map: not found (bind seed understated; advisor greps it on demand)")
if not kbf:  notes.append("KB: not found (legacy-rebuild lane understated)")
if not packf: notes.append("framework-pack: not passed (--pack); bind loads exactly one, ~KB-scale")
if not os.path.isfile(bundlef): notes.append("advisor bundle: not built yet (run build-advisor-bundle.sh at bind) — phase-advisor seed shows the checklist floor only")
notes.append("phase-advisor is FRESH (1.0x): its map/vault/KB are grep-on-demand, NOT pasted (5.1.1) — the eliminated whole-map paste was the top real-dollar lever")
notes.append("domain-extractor legacy wave slice + live drafts: (varies) — not counted")

if as_json:
    print(json.dumps({"seeds": recs, "notes": notes}, ensure_ascii=False, indent=2))
else:
    print("Seed budget (ranked by cost-units = tokens x cache-weight) — v5.1.x")
    print(f"{'consumer':<16}{'cache':>9}{'bytes':>9}{'~tokens':>9}{'cost-un':>9}{'share':>8}  comp")
    print("-" * 74)
    for r in recs:
        cu = r.get("cost_units", 0)
        share = 100.0 * cu / total_cu
        comps = len(r.get("components", []))
        miss = r.get("missing", [])
        cache = "fresh" if r.get("weight", 0) >= 1.0 else "resident"
        cflag = f"{comps}" + (f" +{len(miss)}miss" if miss else "")
        print(f"{r.get('label',''):<16}{cache:>9}{r.get('bytes',0):>9}{r.get('approx_tokens',0):>9}{cu:>9}{share:>7.1f}%  {cflag}")
    print("-" * 74)
    print(f"{'TOTAL':<16}{'':>9}{total:>9}{sum(r.get('approx_tokens',0) for r in recs):>9}{total_cu:>9}")
    if notes:
        print("\nNotes (honest omissions):")
        for n in notes:
            print(f"  - {n}")
PYEOF
