#!/usr/bin/env bash
# detect-toolchain.sh — detect the repo's OWN formatter/linter/typechecker
# (execute-bolts L0 code gates; tech-agnostic — detect, NEVER impose).
#
# Probes config files + manifests across ecosystems and emits the commands the
# PROJECT already uses. A tool with no config evidence in the repo is never
# suggested — the repo's existing convention is the ground truth.
#
# Usage:
#   detect-toolchain.sh [--cwd=<dir>]
# Output: JSON {formatters:[], linters:[], typecheckers:[]} each entry
#   {tool, check_cmd, fix_cmd?, evidence}. Exit 0 always (detection only).

set -u
CWD="."
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
  esac
done
[ -d "$CWD" ] || { echo "usage: detect-toolchain.sh [--cwd=<dir>]" >&2; exit 2; }

python3 - "$CWD" <<'PYEOF'
import glob, json, os, sys

cwd = sys.argv[1]
def has(*patterns):
    for p in patterns:
        m = glob.glob(os.path.join(cwd, p))
        if m:
            return os.path.relpath(m[0], cwd)
    return None

def manifest_contains(path, needle):
    f = os.path.join(cwd, path)
    try:
        return needle in open(f, encoding="utf-8", errors="replace").read()
    except OSError:
        return False

formatters, linters, typecheckers = [], [], []
def add(bucket, tool, check_cmd, evidence, fix_cmd=None):
    e = {"tool": tool, "check_cmd": check_cmd, "evidence": evidence}
    if fix_cmd: e["fix_cmd"] = fix_cmd
    bucket.append(e)

# --- JS/TS ---
ev = has(".prettierrc", ".prettierrc.*", "prettier.config.*") or \
     ("package.json" if manifest_contains("package.json", '"prettier"') else None)
if ev: add(formatters, "prettier", "npx prettier --check .", ev, "npx prettier --write .")
ev = has("biome.json", "biome.jsonc")
if ev: add(formatters, "biome", "npx biome check .", ev, "npx biome check --write .")
ev = has("eslint.config.*", ".eslintrc", ".eslintrc.*")
if ev: add(linters, "eslint", "npx eslint .", ev, "npx eslint . --fix")
ev = has("tsconfig.json")
if ev: add(typecheckers, "tsc", "npx tsc --noEmit", ev)

# --- Python ---
ev = has("ruff.toml", ".ruff.toml") or ("pyproject.toml" if manifest_contains("pyproject.toml", "[tool.ruff") else None)
if ev:
    add(formatters, "ruff-format", "ruff format --check .", ev, "ruff format .")
    add(linters, "ruff", "ruff check .", ev, "ruff check --fix .")
ev = "pyproject.toml" if manifest_contains("pyproject.toml", "[tool.black") else None
if ev: add(formatters, "black", "black --check .", ev, "black .")
ev = "pyproject.toml" if manifest_contains("pyproject.toml", "[tool.mypy") else has("mypy.ini", ".mypy.ini")
if ev: add(typecheckers, "mypy", "mypy .", ev)

# --- Go ---
ev = has("go.mod")
if ev:
    add(formatters, "gofmt", "test -z \"$(gofmt -l .)\"", ev, "gofmt -w .")
    add(typecheckers, "go-vet", "go vet ./...", ev)
lint_ev = has(".golangci.yml", ".golangci.yaml", ".golangci.toml")
if lint_ev: add(linters, "golangci-lint", "golangci-lint run", lint_ev)

# --- Rust ---
ev = has("Cargo.toml")
if ev:
    add(formatters, "rustfmt", "cargo fmt --check", ev, "cargo fmt")
    add(linters, "clippy", "cargo clippy -- -D warnings", ev)

# --- PHP ---
ev = has("pint.json") or ("composer.json" if manifest_contains("composer.json", "laravel/pint") else None)
if ev: add(formatters, "pint", "vendor/bin/pint --test", ev, "vendor/bin/pint")
ev = has(".php-cs-fixer.php", ".php-cs-fixer.dist.php")
if ev: add(formatters, "php-cs-fixer", "vendor/bin/php-cs-fixer fix --dry-run --diff", ev, "vendor/bin/php-cs-fixer fix")
ev = has("phpstan.neon", "phpstan.neon.dist", "phpstan.dist.neon")
if ev: add(linters, "phpstan", "vendor/bin/phpstan analyse --no-progress", ev)
ev = has("psalm.xml", "psalm.xml.dist")
if ev: add(linters, "psalm", "vendor/bin/psalm --no-progress", ev)

# --- Ruby ---
ev = has(".rubocop.yml")
if ev: add(linters, "rubocop", "bundle exec rubocop", ev, "bundle exec rubocop -a")

# --- EditorConfig (cross-cutting baseline; informational) ---
ev = has(".editorconfig")
if ev: add(formatters, "editorconfig", "true  # baseline only — honored by the tools above", ev)

print(json.dumps({"cwd": cwd, "formatters": formatters, "linters": linters, "typecheckers": typecheckers}, indent=2))
PYEOF
