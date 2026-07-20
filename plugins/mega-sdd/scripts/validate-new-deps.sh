#!/usr/bin/env bash
# validate-new-deps.sh — anti-slopsquatting check on a bolt's NEW dependencies
# (execute-bolts L0 code gates).
#
# Diffs the dependency manifests between base..head; every ADDED package is
# verified to EXIST on its official registry (LLMs hallucinate package names;
# attackers register them). Offline → unverified WARNING (fail-open with a
# visible note); a definite registry 404 → blocking.
#
# Usage:
#   validate-new-deps.sh --base=<sha> --head=<sha> [--cwd=<dir>]
# Exit: 0 no new deps / all exist / offline-unverified (warned) · 2 definite 404 (blocking)

set -u
BASE=""; HEAD=""; CWD="."
for arg in "$@"; do
  case "$arg" in
    --base=*) BASE="${arg#--base=}" ;;
    --head=*) HEAD="${arg#--head=}" ;;
    --cwd=*)  CWD="${arg#--cwd=}" ;;
  esac
done
[ -n "$BASE" ] && [ -n "$HEAD" ] || { echo "usage: validate-new-deps.sh --base=<sha> --head=<sha> [--cwd=<dir>]" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
cd "$CWD" || exit 2

export VND_BASE="$BASE" VND_HEAD="$HEAD" VND_LIB="$SCRIPT_DIR/_lib"
python3 <<'PYEOF'
import json, os, re, sys, urllib.request
sys.path.insert(0, os.environ["VND_LIB"])
from dep_manifest import added_deps  # shared manifest-diff (gate 5 + gate 6)

base, head = os.environ["VND_BASE"], os.environ["VND_HEAD"]

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

results, worst = [], 0
for entry in added_deps(base, head):  # shared diff (changed-manifest order, pkgs sorted)
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
print(json.dumps({
    "new_deps": results, "total_new": len(results),
    "blocking": worst == 2,
    "warning": ("registry unreachable for %d package(s) — verify manually before merge" % len(unverified)) if unverified else None,
}, indent=2))
sys.exit(worst)
PYEOF
