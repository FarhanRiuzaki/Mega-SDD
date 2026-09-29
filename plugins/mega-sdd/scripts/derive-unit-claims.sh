#!/usr/bin/env bash
# derive-unit-claims.sh — JIT bind step 1 (v8 P1, spec 2026-09-10 Appendix F2):
# each unit's claim set, derived deterministically from the unit files themselves —
# never from the vault, never from a model. Sole caller: rebind-units.sh (every bind).
#
#   derive-unit-claims.sh --cwd=<root> --vault=<vault-dir> --units=U-001,U-002[,…] | --units=all
#   (`all` = every unit under <vault>/units — the `sync --full-bind` sweep, 7.34.0)
#
# Per unit, claims are minted from:
#   target_files          create        → fs_must_not_exist (the path must be absent)
#                         modify|delete → fs_must_exist
#   ## Anchors            `path:line[-line]`   → fs_must_exist (+ line range check)
#   existing_interfaces   file + symbol → symbol (symbol index lookup, P1.b writer)
#   ## Claims             `- C-U<NNN>-<NN> "<text>" — expect: <path>[:<sym>] | <path> — must-exist | <path> — must-not-exist`
#                         → fs_* / symbol / text (text = ladder E3, jit-bind-and-quarantine.md — model)
# Output: <vault>/bolts/U-XXX/_claims.json per unit (spec 2026-09-25-state-anchor-design.md §3):
#   {schema:"unit-claims/1", head, dirty, scope, generated_by, units:[U], claims[{id, unit, kind, expect, source, text?}]}
#   ONE capture over the list's union scope; each file holds that unit's claims + the unit-scope
#   subset of `dirty`, so one unit's re-bind cannot change the capture another unit's E3 pass reads.
#   scope = the project-relative paths the capture looked at (the writer's D25a re-check
#           compares only there — a verdict anchor added later was never captured).
#   head  = the FULL HEAD sha (state anchor; was short-8), read with builtins.
#   dirty = {project-relative path: git blob hash | null}, freshness.dirty_map() (the ONE definition, 2 git execs).
# stdout: ONE JSON line {"jit_bind":{"units":N,"fs_claims":F,"symbol_claims":S,"text_claims":T,"out":"<path>,…"}}
#   — greenfield / create-only ⇒ symbol_claims=text_claims=0 ⇒ the bind needs ZERO model tokens.
# The claim grammar lives in scripts/_lib/unit_claims.py (shared with write-unit-binding.sh).
# Exit 0 written · 2 usage / unit file not found (nothing written).
set -u
CWD="."; VAULT=""; UNITS=""
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --units=*) UNITS="${arg#*=}" ;;
  *) echo "usage: derive-unit-claims.sh --cwd=<root> --vault=<vault> --units=U-001,…" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT" ] && [ -n "$UNITS" ] || { echo "usage: --vault=<existing dir> --units=U-001,… required" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
V_CWD="$CWD" V_VAULT="$VAULT" V_UNITS="$UNITS" V_LIB="$SCRIPT_DIR/_lib" python3 <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone
cwd = os.path.abspath(os.environ["V_CWD"]); vault = os.environ["V_VAULT"]
sys.path.insert(0, os.environ["V_LIB"])
import unit_claims
units = [u.strip() for u in os.environ["V_UNITS"].split(",") if u.strip()]
if units == ["all"]:  # sync --full-bind (7.34.0): the whole vault, sorted, both unit layouts
    units = unit_claims.all_unit_ids(vault)
    if not units:
        print("FAIL: --units=all but no units under %s/units" % vault, file=sys.stderr); sys.exit(2)
try:
    from plugin_meta import plugin_version as _pv
    GEN = "derive-unit-claims.sh@%s" % _pv()
except Exception:
    GEN = "derive-unit-claims.sh"

counts = {"fs": 0, "symbol": 0, "text": 0}
per_unit = {}
for uid in units:
    uf = unit_claims.unit_file(vault, uid)
    if not uf:
        print("FAIL: unit %s not found under %s/units" % (uid, vault), file=sys.stderr); sys.exit(2)
    text = open(uf, encoding="utf-8", errors="replace").read()
    mine = unit_claims.derive_claims(uid, text, os.path.relpath(uf, cwd))
    per_unit[uid] = mine
    for c in mine:
        k = c["kind"]
        counts["fs" if k.startswith("fs_") else ("symbol" if k == "symbol" else "text")] += 1

# ── the capture (state anchor §3): full HEAD + ONE dirty map over the union scope ──
head, dirty, scope_of, union = "nogit", {}, {}, set()
try:
    import freshness, vault_scope
    g = freshness.find_git(cwd)
    if g:
        h, _ = freshness.read_head(g)
        head = h or "nogit"
        for uid in units:
            sc = vault_scope.unit_scope(cwd, vault, uid)
            top = {freshness.to_top(g, p) for p in sc["paths"] | sc["globs"]} - {None}
            scope_of[uid] = top
            union |= top
        dirty = {freshness.to_proj(g, q): v for q, v in freshness.dirty_map(g, union).items()}
except Exception as e:  # a capture that cannot be taken is recorded as such, never as clean
    print("WARN: dirty capture failed (%s) — the writer will null the stamp" % type(e).__name__, file=sys.stderr)
    dirty = None

def write_json(path, doc):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp.%d" % os.getpid()
    with open(tmp, "w", encoding="utf-8") as f: json.dump(doc, f, indent=1, ensure_ascii=False)
    os.replace(tmp, path)

stamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
outs = []
for uid in units:
    sub = None
    if dirty is not None:
        g2 = freshness.find_git(cwd)
        sub = {p: v for p, v in dirty.items()
               if any(freshness.matches(freshness.to_top(g2, p) or "", sp) for sp in scope_of.get(uid, ()))}
    out = os.path.join(vault, "bolts", uid, "_claims.json")
    g3 = freshness.find_git(cwd)
    sc_proj = sorted(freshness.to_proj(g3, q) for q in scope_of.get(uid, ())) if g3 else []
    write_json(out, {"schema": "unit-claims/1", "head": head, "dirty": sub, "scope": sc_proj, "generated_by": GEN,
                     "generated_at": stamp, "units": [uid], "claims": per_unit[uid]})
    outs.append(os.path.relpath(out, cwd))
print(json.dumps({"jit_bind": {"units": len(units), "fs_claims": counts["fs"], "symbol_claims": counts["symbol"],
                               "text_claims": counts["text"], "out": ",".join(outs)}}))
PYEOF
