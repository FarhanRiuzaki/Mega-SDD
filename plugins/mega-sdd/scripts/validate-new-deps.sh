#!/usr/bin/env bash
# validate-new-deps.sh — ONE manifest-diff pass, TWO dependency concerns
# (execute-bolts L0 code gates 5+6; v7 Fase 2 merge group 3 folded the former
# check-dep-authorization.sh in here — added_deps computed once).
#
# Concern 1 (gate 5, BLOCKING): every ADDED package must EXIST on its official
# registry (LLMs hallucinate package names; attackers register them). Offline →
# unverified WARNING (fail-open with a visible note); a definite 404 → exit 2.
#
# Concern 2 (gate 6, ADVISORY — only when --unit is passed): did the UNIT
# sanction the added dependency (`allowed_new_deps:` frontmatter)? Unlisted →
# `authorization.finding: dep_unauthorized` + Indonesian keterangan warning in
# the JSON. NEVER affects the exit code (advisory-first, research §7; the
# blocking escalation stays deferred and would be commit-keyed like B4).
# Legacy-safe: a unit with NO allowed_new_deps key → enforced:false no-op.
#
# Usage:
#   validate-new-deps.sh --base=<sha> --head=<sha> [--cwd=<dir>] [--unit=<unit.md>]
# Exit: 0 no new deps / all exist / offline-unverified (warned) · 2 definite 404 (blocking)

set -u
BASE=""; HEAD=""; CWD="."; UNIT=""
for arg in "$@"; do
  case "$arg" in
    --base=*) BASE="${arg#--base=}" ;;
    --head=*) HEAD="${arg#--head=}" ;;
    --cwd=*)  CWD="${arg#--cwd=}" ;;
    --unit=*) UNIT="${arg#--unit=}" ;;
  esac
done
[ -n "$BASE" ] && [ -n "$HEAD" ] || { echo "usage: validate-new-deps.sh --base=<sha> --head=<sha> [--cwd=<dir>]" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
cd "$CWD" || exit 2

export VND_BASE="$BASE" VND_HEAD="$HEAD" VND_LIB="$SCRIPT_DIR/_lib" VND_UNIT="$UNIT"
python3 <<'PYEOF'
import json, os, re, sys, urllib.request
sys.path.insert(0, os.environ["VND_LIB"])
from dep_manifest import added_deps  # shared manifest-diff (gate 5 + gate 6)

base, head = os.environ["VND_BASE"], os.environ["VND_HEAD"]
unit = os.environ.get("VND_UNIT") or None


def parse_allowed(path):
    """Return (present: bool, allowed: set[str]). Absent key => (False, set()).

    Parses the `allowed_new_deps:` frontmatter entry without a YAML dependency —
    handles inline `[a, b]` / `[]` and block `- item` lists. (Merged verbatim
    from check-dep-authorization.sh, v7 Fase 2 group 3.)"""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return (False, set())
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    fm = m.group(1) if m else text
    lines = fm.splitlines()
    for i, line in enumerate(lines):
        km = re.match(r"^allowed_new_deps:\s*(.*)$", line)
        if not km:
            continue
        rest = km.group(1).strip()
        if rest.startswith("["):                       # inline list (incl. [])
            inner = rest[1:rest.rfind("]")] if "]" in rest else rest[1:]
            items = [x.strip().strip('"').strip("'") for x in inner.split(",")]
            return (True, {x for x in items if x})
        if rest and not rest.startswith("#"):           # scalar on the same line
            return (True, {rest.strip('"').strip("'")})
        allowed = set()                                 # block list on next lines
        for nxt in lines[i + 1:]:
            bm = re.match(r"^\s+-\s*(.+?)\s*$", nxt)
            if bm:
                allowed.add(bm.group(1).strip().strip('"').strip("'"))
            elif nxt.strip() == "" or nxt.startswith(" "):
                continue
            else:
                break
        return (True, allowed)
    return (False, set())

REGISTRY = {
    "package.json": ("npm",       lambda p: f"https://registry.npmjs.org/{p}"),
    "composer.json": ("packagist", lambda p: f"https://repo.packagist.org/p2/{p}.json"),
    "pyproject.toml": ("pypi",     lambda p: f"https://pypi.org/pypi/{p}/json"),
    "requirements":  ("pypi",      lambda p: f"https://pypi.org/pypi/{p}/json"),
    "go.mod":        ("goproxy",   lambda p: f"https://proxy.golang.org/{p.lower()}/@latest"),
    "Cargo.toml":    ("crates",    lambda p: f"https://crates.io/api/v1/crates/{p}"),
    "Gemfile":       ("rubygems",  lambda p: f"https://rubygems.org/api/v1/gems/{p}.json"),
}

def registry_for(path):
    name = os.path.basename(path)
    if re.match(r".*requirements[^/]*\.txt$", name):
        return REGISTRY["requirements"]
    return REGISTRY.get(name)

added = added_deps(base, head)  # ONE shared diff feeds both concerns
results, worst = [], 0
for entry in added:
    path, pkg = entry["manifest"], entry["package"]
    reg = registry_for(path)
    if not reg:
        continue
    reg_name, url_fn = reg
    status = "unverified"
    try:
        req = urllib.request.Request(url_fn(pkg), headers={"User-Agent": "mega-sdd-dep-check"})
        with urllib.request.urlopen(req, timeout=6) as resp:
            status = "exists" if resp.status == 200 else "unverified"
    except urllib.error.HTTPError as e:
        status = "NOT_FOUND" if e.code == 404 else "unverified"
    except Exception:
        status = "unverified"  # offline — warn, never fabricate a verdict
    if status == "NOT_FOUND":
        worst = 2
    results.append({"manifest": path, "package": pkg, "registry": reg_name, "status": status})

unverified = [r for r in results if r["status"] == "unverified"]
out = {
    "new_deps": results, "total_new": len(results),
    "blocking": worst == 2,
    "warning": ("registry unreachable for %d package(s) — verify manually before merge" % len(unverified)) if unverified else None,
}

# ─── Concern 2: unit authorization (advisory; never touches the exit code) ───
if unit:
    present, allowed = parse_allowed(unit)
    if not present:
        out["authorization"] = {
            "unit": os.path.basename(unit),
            "enforced": False,
            "added_deps": added,
            "unauthorized": [],
            "note": "allowed_new_deps absent (v4/pre-v5 unit) — dep-authorization not enforced",
        }
    else:
        unauthorized = [e for e in added if e["package"] not in allowed]
        warning = None
        if unauthorized:
            pkgs = ", ".join(sorted(e["package"] for e in unauthorized))
            # keterangan (Indonesian human-facing, per the interaction contract)
            warning = (f"dependency baru tidak diotorisasi unit: {pkgs} — bolt menambah "
                       f"library yang tidak ada di `allowed_new_deps` unit ini (dugaan "
                       f"over-engineering / scope creep). Tinjau: benar-benar perlu, atau "
                       f"pakai yang sudah ada? Jika memang perlu, tambahkan ke "
                       f"`allowed_new_deps` unit. (advisory — tidak memblok)")
        out["authorization"] = {
            "unit": os.path.basename(unit),
            "enforced": True,
            "allowed_new_deps": sorted(allowed),
            "added_deps": added,
            "unauthorized": unauthorized,
            "finding": "dep_unauthorized" if unauthorized else None,
            "warning": warning,
        }

print(json.dumps(out, indent=2))
sys.exit(worst)
PYEOF
