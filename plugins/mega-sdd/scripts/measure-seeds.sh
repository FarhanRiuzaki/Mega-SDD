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

# Seed definitions: NAME|<space-separated component paths>. Missing components
# are counted as 0 by the lib and surfaced, never guessed.
_measure() {  # _measure <label> <paths...>
  python3 "$LIB" --label "$1" --json "${@:2}" 2>/dev/null
}

RECORDS="$(mktemp 2>/dev/null || mktemp -t measureseeds)"
trap 'rm -f "$RECORDS"' EXIT
: > "$RECORDS"

emit() {  # emit <label> <component paths...>
  local label="$1"; shift
  # Drop empty args so the lib doesn't choke; keep at least one token.
  local args=(); for a in "$@"; do [ -n "$a" ] && args+=("$a"); done
  [ ${#args[@]} -gt 0 ] || return 0
  _measure "$label" "${args[@]}" >> "$RECORDS"
}

# 1. bind-codebase main-context open: vault docs + codebase-map + KB + pack.
emit "bind-codebase" "${VAULT_DOCS[@]}" ${MAP:+"$MAP"} ${KB:+"$KB"} ${PACK:+"$PACK"}
# 2. phase-advisor subagent seed: checklist + draft binding + map + vault + KB.
emit "phase-advisor" "$ADV_CHECKLIST" ${BINDING_MD:+"$BINDING_MD"} ${MAP:+"$MAP"} "${VAULT_DOCS[@]}" ${KB:+"$KB"}
# 3. generate-units open: bound/ annotated docs + binding manifest + sidecar.
emit "generate-units" ${BOUND_DIR:+"$BOUND_DIR"} ${BINDING_MD:+"$BINDING_MD"} ${BINDING_JSON:+"$BINDING_JSON"}
# 4. resolve-oq open: the vault (re-read each pass unless all-priorities).
emit "resolve-oq" "${VAULT_DOCS[@]}"

python3 - "$RECORDS" "$AS_JSON" "${MAP:-}" "${KB:-}" "${PACK:-}" <<'PYEOF'
import json, sys
records_path, as_json, mapf, kbf, packf = sys.argv[1], sys.argv[2] == "1", sys.argv[3], sys.argv[4], sys.argv[5]
recs = []
with open(records_path, encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if line:
            recs.append(json.loads(line))
recs.sort(key=lambda r: r.get("bytes", 0), reverse=True)
total = sum(r.get("bytes", 0) for r in recs) or 1
notes = []
if not mapf: notes.append("codebase-map: not found (bind/advisor seeds understated)")
if not kbf:  notes.append("KB: not found (legacy-rebuild lane understated)")
if not packf: notes.append("framework-pack: not passed (--pack); bind loads exactly one, ~KB-scale")
notes.append("domain-extractor legacy wave slice + live drafts: (varies) — not counted")

if as_json:
    print(json.dumps({"seeds": recs, "notes": notes}, ensure_ascii=False, indent=2))
else:
    print("Seed budget (ranked by bytes) — current v5.0.0 baseline")
    print(f"{'consumer':<18}{'bytes':>10}{'~tokens':>10}{'share':>8}  components")
    print("-" * 72)
    for r in recs:
        share = 100.0 * r.get("bytes", 0) / total
        comps = len(r.get("components", []))
        miss = r.get("missing", [])
        cflag = f"{comps}" + (f" (+{len(miss)} missing)" if miss else "")
        print(f"{r.get('label',''):<18}{r.get('bytes',0):>10}{r.get('approx_tokens',0):>10}{share:>7.1f}%  {cflag}")
    print("-" * 72)
    print(f"{'TOTAL':<18}{total:>10}{sum(r.get('approx_tokens',0) for r in recs):>10}")
    if notes:
        print("\nNotes (honest omissions):")
        for n in notes:
            print(f"  - {n}")
PYEOF
