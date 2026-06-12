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
cd "$CWD" || exit 2

export VND_BASE="$BASE" VND_HEAD="$HEAD"
python3 <<'PYEOF'
import json, os, re, subprocess, sys, urllib.request

base, head = os.environ["VND_BASE"], os.environ["VND_HEAD"]

def show(ref, path):
    r = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""

def changed_manifests():
    r = subprocess.run(["git", "diff", "--name-only", f"{base}..{head}"], capture_output=True, text=True)
    names = ("package.json", "composer.json", "pyproject.toml", "go.mod", "Cargo.toml", "Gemfile")
    return [p for p in r.stdout.splitlines()
            if os.path.basename(p) in names or re.match(r".*requirements[^/]*\.txt$", p)]

def deps_of(path, text):
    name = os.path.basename(path)
    out = set()
    if name in ("package.json", "composer.json"):
        try:
            j = json.loads(text or "{}")
        except ValueError:
            return out
        for k in ("dependencies", "devDependencies", "require", "require-dev"):
            out |= set(j.get(k, {}) or {})
        out.discard("php")
    elif name == "go.mod":
        out |= set(re.findall(r"^\s*([\w./-]+\.[\w./-]+)\s+v[\d.]", text, re.M))
    elif name == "Cargo.toml":
        in_dep = False
        for line in text.splitlines():
            if re.match(r"\[(.*-)?dependencies", line.strip()):
                in_dep = True; continue
            if line.strip().startswith("["):
                in_dep = False; continue
            if in_dep:
                m = re.match(r"\s*([A-Za-z0-9_-]+)\s*=", line)
                if m: out.add(m.group(1))
    elif name == "Gemfile":
        out |= set(re.findall(r"""^\s*gem\s+['"]([^'"]+)['"]""", text, re.M))
    elif name == "pyproject.toml" or name.endswith(".txt"):
        src = text
        if name == "pyproject.toml":
            m = re.search(r"dependencies\s*=\s*\[(.*?)\]", text, re.S)
            src = m.group(1) if m else ""
            src = "\n".join(re.findall(r"""['"]([^'"]+)['"]""", src))
        for line in src.splitlines():
            line = line.strip()
            if not line or line.startswith(("#", "-")):
                continue
            m = re.match(r"([A-Za-z0-9._-]+)", line)
            if m: out.add(m.group(1).lower())
    return out

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
for path in changed_manifests():
    reg = registry_for(path)
    if not reg:
        continue
    added = deps_of(path, show(head, path)) - deps_of(path, show(base, path))
    for pkg in sorted(added):
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
