#!/usr/bin/env bash
# derive-plan-pins.sh — v8 P2 `plan` Step 0 pins, SCRIPT-DERIVED (0 model tokens;
# spec 2026-09-10 App. C3 + App. D: the at-generation pins are written once, in
# the context.md frontmatter, and NEVER asked — author = git user, stakeholders
# from the PRD or "[Pending]").
#
#   derive-plan-pins.sh --cwd=<root> (--prd=<prd-file> | --kb=<kb-dir>) [--vault=<dir>] [--mode=new|existing]
#
# Prints ONE JSON line:
#   {"schema":"plan-pins/1","prd_path":"<rel to root>","prd_sha256":"<hex>",
#    "author":"<git user.name | [Pending]>","slug":"<kebab>","vault":"<rel dir>",
#    "project_scale":"xs|standard","screens":N,"entities":N,"flows":N,
#    "implementation_mode":"new|existing","vault_exists":true|false}
# project_scale rides derive-project-scale.sh (document structure, never
# judgment). slug = PRD basename, extension dropped, leading `prd-`/`prd_`
# dropped, kebab-cased; vault default = .mega-sdd/vaults/<slug>.
# --kb (an extract-intelligence KB is the source — plan/references/kb-input.md
# §KB pins): prd_path = <kb>/README.md; prd_sha256 = sha256 of <kb>/census.json
# (it changes whenever a legacy source or the extraction changes; a legacy
# numbered-tree KB has none → README.md); project_scale = standard (legacy
# rebuilds are never xs; screens/entities/flows = 0); slug = basename of the
# census legacy_root, else the README H1 title (first segment), else "kb".
# Exit 0 · 2 usage · 3 PRD/KB README unreadable.
set -u
CWD="."; PRD=""; KB=""; VAULT=""; MODE=""
USAGE="usage: derive-plan-pins.sh --cwd=<root> (--prd=<file> | --kb=<kb-dir>) [--vault=<dir>] [--mode=new|existing]"
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --prd=*) PRD="${arg#*=}" ;; --kb=*) KB="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --mode=*) MODE="${arg#*=}" ;;
  *) echo "$USAGE" >&2; exit 2 ;;
esac; done
{ [ -n "$PRD" ] || [ -n "$KB" ]; } || { echo "usage: --prd=<file> or --kb=<kb-dir> required" >&2; exit 2; }
{ [ -z "$PRD" ] || [ -z "$KB" ]; } || { echo "usage: --prd and --kb are exclusive" >&2; exit 2; }
case "$MODE" in ""|new|existing) ;; *) echo "usage: --mode must be new|existing" >&2; exit 2 ;; esac
ROOT="$(cd "$CWD" 2>/dev/null && pwd -P)" || { echo "FAIL: cwd not found: $CWD" >&2; exit 2; }
KB_ABS=""
if [ -n "$KB" ]; then
  case "$KB" in /*) KB_ABS="${KB%/}" ;; *) KB_ABS="$ROOT/${KB%/}" ;; esac
  PRD_ABS="$KB_ABS/README.md"
  [ -f "$PRD_ABS" ] || { echo "FAIL: KB README not readable: $PRD_ABS" >&2; exit 3; }
  SCALE='{"project_scale":"standard"}'
else
  case "$PRD" in /*) PRD_ABS="$PRD" ;; *) PRD_ABS="$ROOT/$PRD" ;; esac
  [ -f "$PRD_ABS" ] || { echo "FAIL: PRD not readable: $PRD_ABS" >&2; exit 3; }
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  SCALE="$(bash "$SCRIPT_DIR/derive-project-scale.sh" --prd="$PRD_ABS" 2>/dev/null || echo '{}')"
fi
AUTHOR="$(git -C "$ROOT" config user.name 2>/dev/null || true)"
V_ROOT="$ROOT" V_PRD="$PRD_ABS" V_KB="$KB_ABS" V_VAULT="$VAULT" V_MODE="$MODE" V_SCALE="$SCALE" V_AUTHOR="$AUTHOR" python3 <<'PYEOF'
import hashlib, json, os, re
root, prd, kb = os.environ["V_ROOT"], os.environ["V_PRD"], os.environ["V_KB"]
try:
    scale = json.loads(os.environ["V_SCALE"] or "{}")
except Exception:
    scale = {}
prd_real = os.path.realpath(prd)
rel = os.path.relpath(prd_real, root) if prd_real.startswith(root + os.sep) else prd_real
def kebab(s): return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
hashed = prd_real
if kb:
    census = os.path.join(kb, "census.json")
    legacy = ""
    if os.path.isfile(census):
        hashed = os.path.realpath(census)
        try:
            legacy = str(json.load(open(census, encoding="utf-8")).get("legacy_root") or "")
        except Exception:
            legacy = ""
    title = next((m.group(1) for m in re.finditer(r"^#[ \t]+(.+?)\s*$", open(prd_real, encoding="utf-8", errors="replace").read(), re.M)), "")
    title = re.split(r"\s+[—–|:-]\s+", title)[0]
    slug = kebab(os.path.basename(legacy.rstrip("/\\"))) or kebab(title) or "kb"
else:
    base = re.sub(r"\.[A-Za-z0-9]+$", "", os.path.basename(prd_real))
    base = re.sub(r"^(?i:prd)[-_ ]+", "", base)
    slug = kebab(base) or "vault"
vault = os.environ["V_VAULT"] or os.path.join(".mega-sdd", "vaults", slug)
vault_abs = vault if os.path.isabs(vault) else os.path.join(root, vault)
out = {
    "schema": "plan-pins/1",
    "prd_path": rel,
    "prd_sha256": hashlib.sha256(open(hashed, "rb").read()).hexdigest(),
    "author": (os.environ["V_AUTHOR"].strip() or "[Pending]"),
    "slug": slug,
    "vault": vault,
    "project_scale": scale.get("project_scale") or "standard",
    "screens": scale.get("screens", 0), "entities": scale.get("entities", 0), "flows": scale.get("flows", 0),
    "implementation_mode": os.environ["V_MODE"] or "new",
    "vault_exists": os.path.isfile(os.path.join(vault_abs, "context.md")),
}
print(json.dumps(out))
PYEOF
