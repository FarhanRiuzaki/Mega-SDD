#!/usr/bin/env bash
# compute-lock-digests.sh — deterministic per-ecosystem lock digests for the
# scan-codebase deep-scan cache (cache schema v2.1).
#
# Tech-agnostic by construction: probes EVERY supported ecosystem's lock/manifest
# (php/js/rust/go/ruby/python/jvm), emits one sha256 digest per ecosystem present,
# plus the three derived digest groups the per-slice signatures consume:
#   app_locks_digest      — locks of the APP ecosystem (from §7 Framework)
#   frontend_locks_digest — js lock when APP ecosystem ≠ js and a js lock exists; else app digest
#   all_locks_digest      — every detected ecosystem folded together
#
# Usage:
#   compute-lock-digests.sh --project=<root> --app-ecosystem=<php|js|rust|go|ruby|python|jvm>
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
