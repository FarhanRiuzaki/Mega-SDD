"""dep_manifest.py — shared manifest-diff for the two dependency gates.

One home for "which packages did this bolt ADD between base..head", across every
supported ecosystem. Reused by:
  - validate-new-deps.sh  (gate 5, anti-slopsquat: do the added packages EXIST?)
  - check-dep-authorization.sh (gate 6, anti-over-engineering: did the UNIT
    sanction them?)
Extracted so the two gates can never disagree on what "a new dependency" is
(reuse over a second copy — WAJIB "pas").

No network, no third-party imports — git + stdlib only.
"""
import json
import os
import re
import subprocess

# basename -> True; requirements*.txt matched separately by _is_manifest.
_MANIFEST_NAMES = ("package.json", "composer.json", "pyproject.toml",
                   "go.mod", "Cargo.toml", "Gemfile")


def _is_manifest(path):
    base = os.path.basename(path)
    return base in _MANIFEST_NAMES or re.match(r".*requirements[^/]*\.txt$", base)


def _git_show(ref, path, cwd="."):
    # timeout: git is normally fast, but this runs inside hook-invoked validators
    # and an unbounded child in a path Claude Code waits on is the shape of the
    # 2026-07-28 hang. Matches state_probes.py's existing convention.
    try:
        r = subprocess.run(["git", "show", f"{ref}:{path}"],
                           capture_output=True, text=True, cwd=cwd, timeout=30)
    except subprocess.TimeoutExpired:
        return ""
    return r.stdout if r.returncode == 0 else ""


def changed_manifests(base, head, cwd="."):
    """Manifest paths that changed between base..head (dep files only)."""
    try:
        r = subprocess.run(["git", "diff", "--name-only", f"{base}..{head}"],
                           capture_output=True, text=True, cwd=cwd, timeout=30)
    except subprocess.TimeoutExpired:
        return []
    return [p for p in r.stdout.splitlines() if _is_manifest(p)]


def deps_of(path, text):
    """The set of declared package names in one manifest's text."""
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
                in_dep = True
                continue
            if line.strip().startswith("["):
                in_dep = False
                continue
            if in_dep:
                m = re.match(r"\s*([A-Za-z0-9_-]+)\s*=", line)
                if m:
                    out.add(m.group(1))
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
            if m:
                out.add(m.group(1).lower())
    return out


def added_deps(base, head, cwd="."):
    """[{manifest, package}] for every package ADDED between base..head.

    Order: changed-manifest order (git diff), packages sorted within each
    manifest — deterministic, and byte-parity with the pre-lib gate-5 loop."""
    added = []
    for path in changed_manifests(base, head, cwd):
        new = deps_of(path, _git_show(head, path, cwd))
        old = deps_of(path, _git_show(base, path, cwd))
        for pkg in sorted(new - old):
            added.append({"manifest": path, "package": pkg})
    return added
