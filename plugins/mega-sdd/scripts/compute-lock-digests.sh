#!/usr/bin/env bash
# compute-lock-digests.sh — deterministic per-ecosystem lock digests for the
# scan-codebase deep-scan cache (cache schema v2.1).
#
# Tech-agnostic by construction: probes EVERY supported ecosystem's lock/manifest
# (php/js/rust/go/ruby/python/jvm/dotnet), emits one sha256 digest per ecosystem present,
# plus the three derived digest groups the per-slice signatures consume:
#   app_locks_digest      — locks of the APP ecosystem (from §7 Framework)
#   frontend_locks_digest — js lock when APP ecosystem ≠ js and a js lock exists; else app digest
#   all_locks_digest      — every detected ecosystem folded together
#
# Usage:
#   compute-lock-digests.sh --project=<root> --app-ecosystem=<php|js|rust|go|ruby|python|jvm|dotnet>
#
# Output: single JSON object on stdout. Exit 0 always (absence of locks is data,
# not an error); exit 2 only on bad invocation.

set -u

PROJECT=""
APP_ECO=""
for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT="${arg#*=}" ;;
    --app-ecosystem=*) APP_ECO="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$PROJECT" ] && [ -d "$PROJECT" ] || { echo "--project=<root> required (dir must exist)" >&2; exit 2; }
[ -n "$APP_ECO" ] || { echo "--app-ecosystem=<eco> required" >&2; exit 2; }

python3 - "$PROJECT" "$APP_ECO" <<'PYEOF'
import hashlib, json, os, sys

project, app_eco = sys.argv[1], sys.argv[2]

# first-found wins inside each ecosystem's candidate list
CANDIDATES = {
    "php":    ["composer.lock"],
    "js":     ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb"],
    "rust":   ["Cargo.lock"],
    "go":     ["go.sum"],
    "ruby":   ["Gemfile.lock"],
    "python": ["poetry.lock", "uv.lock", "Pipfile.lock", "requirements.txt"],
    "jvm":    ["gradle.lockfile", "pom.xml", "build.gradle", "build.gradle.kts"],
}

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

locks, lock_files = {}, {}
for eco, names in CANDIDATES.items():
    for name in names:
        p = os.path.join(project, name)
        if os.path.isfile(p):
            locks[eco] = sha256_file(p)
            lock_files[eco] = name
            break

# dotnet (S3 ECO-3): NuGet state lives in per-project *.csproj + their sibling
# packages.lock.json (locked mode writes it NEXT TO each csproj), at arbitrary
# nesting (src/apps/Api/…). Bounded recursive walk — prune vendored/build dirs,
# cap depth + file count — folding EVERY found file into one digest, so any
# dependency edit (direct csproj OR per-project lock) invalidates the cache.
_DN_NAMES = {"packages.lock.json", "Directory.Packages.props"}
_DN_EXTS = (".csproj", ".fsproj")
_DN_PRUNE = {"node_modules", "vendor", "bin", "obj", "packages", "out", "dist",
             ".git", ".mega-sdd", ".vs", ".idea", "TestResults", "artifacts"}
_DN_MAX_DEPTH, _DN_MAX_FILES = 6, 500
_dn = []
for dirpath, dirnames, filenames in os.walk(project):
    rel = os.path.relpath(dirpath, project)
    depth = 0 if rel == "." else rel.count(os.sep) + 1
    if depth >= _DN_MAX_DEPTH:
        dirnames[:] = []
    dirnames[:] = [d for d in dirnames if d not in _DN_PRUNE and not d.startswith(".")]
    for name in filenames:
        if name in _DN_NAMES or name.endswith(_DN_EXTS):
            _dn.append(os.path.join(dirpath, name))
    if len(_dn) > _DN_MAX_FILES:
        break
_dn = sorted(_dn)[:_DN_MAX_FILES]
if _dn:
    h = hashlib.sha256()
    for p in _dn:
        h.update(os.path.relpath(p, project).encode())
        h.update(b"\0")
        h.update(sha256_file(p).encode())
    locks["dotnet"] = h.hexdigest()
    rels = [os.path.relpath(p, project) for p in _dn]
    lock_files["dotnet"] = ",".join(rels[:5]) + (",..." if len(rels) > 5 else "")

def fold(ecos):
    pairs = sorted(f"{e}:{locks[e]}" for e in ecos if e in locks)
    return hashlib.sha256("|".join(pairs).encode()).hexdigest() if pairs else ""

app_digest = fold([app_eco])
frontend_digest = fold(["js"]) if (app_eco != "js" and "js" in locks) else app_digest
all_digest = fold(locks.keys())

print(json.dumps({
    "locks_sha256": locks,
    "lock_files": lock_files,            # provenance: which file produced each digest
    "app_ecosystem": app_eco,
    "app_locks_digest": app_digest,      # empty string when the app ecosystem has no lock yet
    "frontend_locks_digest": frontend_digest,
    "all_locks_digest": all_digest,
}, indent=2))
PYEOF
