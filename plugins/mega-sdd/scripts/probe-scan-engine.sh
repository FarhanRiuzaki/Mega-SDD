#!/usr/bin/env bash
# probe-scan-engine.sh — deterministic scan-codebase Step-0 engine resolution.
#
# D2 ladder (spec 2026-08-02-reuse-first-grounding-index.md §D2, v5.31.0;
# v7.4.0 Fase 5 №4 removed the --engine=tree-sitter opt-in lane entirely —
# the ladder is now exactly its unattended shape):
#   ast-grep → regex. No grammar compile step exists anywhere, so the clang
#   OOM class (`killed: 9`, live incident 2026-08-02) is structurally
#   unreachable, attended or not.
#
# Usage:
#   probe-scan-engine.sh [--cwd=<dir>] [--engine=ast-grep|regex]
#                        [--timeout=<sec>] --lang=<lang>[:<sample-file>] ...
#
#   --lang=python:src/app.py   detected language + one real source file to probe
#   --lang=python              detected language with NO source file yet
#                              (scaffold-only → probe SKIPPED, not failed)
#
# Output: ONE compact JSON digest on stdout:
#   { engine, precision_tier, astgrep_version,
#     astgrep_langs: [primary langs], fallbacks: [{lang, tier, reason}], halt }
# A forced --engine with ZERO --lang args resolves from an empty language set
# (engine falls out as regex) — the SKILL always passes the detected languages.
# Exit: 0 resolved · 2 usage · 3 dep_missing (forced engine absent; digest still
# printed with halt populated so the SKILL can emit the blocker verbatim).

set -u
CWD="."; FORCED=""; TIMEOUT=30; LANG_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --cwd=*)     CWD="${arg#--cwd=}" ;;
    --engine=*)  FORCED="${arg#--engine=}" ;;
    --timeout=*) TIMEOUT="${arg#--timeout=}" ;;
    --lang=*)
      v="${arg#--lang=}"
      case "$v" in *:) echo "probe-scan-engine.sh: empty sample file in --lang=$v (drop the colon for a scaffold-only language)" >&2; exit 2 ;; esac
      l="${v%%:*}"
      case "$l" in ''|*[!a-z0-9_-]*) echo "probe-scan-engine.sh: bad language name '$l' in --lang=$v" >&2; exit 2 ;; esac
      LANG_ARGS+=("$v") ;;
    *) echo "usage: probe-scan-engine.sh [--cwd=..] [--engine=..] [--timeout=N] --lang=<lang>[:<file>] ..." >&2; exit 2 ;;
  esac
done
[ -d "$CWD" ] || { echo "probe-scan-engine.sh: --cwd not a directory: $CWD" >&2; exit 2; }
case "$FORCED" in ""|ast-grep|regex) : ;; *) echo "probe-scan-engine.sh: bad --engine=$FORCED (tree-sitter lane removed v7.4.0)" >&2; exit 2 ;; esac
case "$TIMEOUT" in ''|*[!0-9]*|0) echo "probe-scan-engine.sh: --timeout must be a positive integer, got '$TIMEOUT'" >&2; exit 2 ;; esac

# Query files live next to the scan-codebase skill, resolved relative to this script.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUERIES_DIR="${SCRIPT_DIR}/../skills/scan-codebase/queries"

# `command -v` probes are shell builtins — no process cost, and probed ONCE here.
AG_BIN=""
command -v ast-grep >/dev/null 2>&1 && AG_BIN="ast-grep"

python3 - "$CWD" "$FORCED" "$TIMEOUT" "$AG_BIN" "$QUERIES_DIR" ${LANG_ARGS+"${LANG_ARGS[@]}"} <<'PYEOF'
import json, os, re, subprocess, sys

cwd, forced, timeout_s, ag_bin, queries_dir = sys.argv[1:6]
timeout_s = max(1, int(timeout_s))
lang_args = sys.argv[6:]

# Languages with a shipped tier-2 rule pack — derived from the pack files
# themselves so a new pack enables its lane without touching this script.
# LANE LAW: one pack file per ast-grep language, filename == language key
# (glossary fix 2026-08-03: tsx rules parked inside typescript.yml were
# invisible to this filename-derived set — 182 .tsx files fell to regex).
import glob as _glob
ASTGREP_LANGS = {os.path.splitext(os.path.basename(f))[0]
                 for f in _glob.glob(os.path.join(queries_dir, "astgrep", "*.yml"))}
# Detected-language keys whose files are parsed by ANOTHER pack's grammar.
# jsx: ast-grep's javascript grammar parses JSX — a jsx.yml would double-count
# every .jsx symbol in the index, so jsx routes through the javascript lane.
ASTGREP_ALIASES = {"jsx": "javascript"}

def run(cmd, tmo, cwd=None):
    """One bounded child process (repo law: every child gets a hard timeout)."""
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           errors="replace",  # probe output can carry raw bytes
                           timeout=tmo, stdin=subprocess.DEVNULL)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return None, "", "probe timed out"
    except OSError as e:
        return 127, "", str(e)

def version_of(binname):
    if not binname:
        return None
    rc, out, _ = run([binname, "--version"], 10)
    if rc == 0 and out.strip():
        # first X.Y-shaped token — some releases append "(<sha>)"
        m = re.search(r"\d+\.\d+[\w.\-]*", out.strip().splitlines()[0])
        return m.group(0) if m else None
    return None

digest = {
    "engine": None, "precision_tier": None,
    "astgrep_version": version_of(ag_bin),
    "astgrep_langs": [],
    "fallbacks": [], "halt": None,
}

def emit(code):
    print(json.dumps(digest, separators=(",", ":")))
    sys.exit(code)

def dep_missing(binary):
    digest["halt"] = {"type": "dep_missing", "required_binary": binary}
    emit(3)

# ── forced-engine short circuits (never a silent fall-through) ──────────────
if forced == "ast-grep" and not ag_bin:
    dep_missing("ast-grep")
if forced == "regex":
    digest["engine"], digest["precision_tier"] = "regex", "regex"
    emit(0)

langs, _seen = [], set()  # (lang, sample_or_None); repeated --lang deduped
for a in lang_args:
    lang, _, sample = a.partition(":")
    if lang in _seen:
        continue
    _seen.add(lang)
    langs.append((lang, sample or None))

# ── lane resolution (D2; the tree-sitter opt-in lane was removed v7.4.0) ────
for lang, sample in langs:
    if not sample:
        # scaffold-only language: nothing to probe, nothing to extract —
        # SKIPPED, never counted as a fallback
        digest["fallbacks"].append({"lang": lang, "tier": "skipped", "reason": "no_source_file"})
        continue
    if ag_bin and (lang in ASTGREP_LANGS or ASTGREP_ALIASES.get(lang) in ASTGREP_LANGS):
        # the PRIMARY route, not a fallback — no fallbacks[] row, so the
        # map's precision_downgrade_reason stays clean on the happy path
        digest["astgrep_langs"].append(lang)
    elif ag_bin:
        digest["fallbacks"].append({"lang": lang, "tier": "regex", "reason": "no_astgrep_pack"})
    else:
        digest["fallbacks"].append({"lang": lang, "tier": "regex", "reason": "astgrep_absent"})

# ── ladder resolution: highest tier that extracted ≥1 language ──────────────
if digest["astgrep_langs"]:
    digest["engine"], digest["precision_tier"] = "ast-grep", "ast"
elif langs and all(f.get("tier") == "skipped" for f in digest["fallbacks"]) and ag_bin:
    # scaffold-only repo, ast-grep present: keep the AST engine claim per
    # binary presence (nothing was extracted either way). Guarded on ALL
    # entries being skips: a real fallback here would stamp `ast` on a map
    # that extracted via regex.
    digest["engine"], digest["precision_tier"] = "ast-grep", "ast"
else:
    digest["engine"], digest["precision_tier"] = "regex", "regex"
emit(0)
PYEOF
