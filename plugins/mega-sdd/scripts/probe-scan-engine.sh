#!/usr/bin/env bash
# probe-scan-engine.sh — deterministic scan-codebase Step-0 engine resolution.
#
# D2 ladder (spec 2026-08-02-reuse-first-grounding-index.md §D2, v5.31.0):
#   AUTO    ast-grep → regex. tree-sitter is NEVER probed in auto, so the clang
#           grammar-compile OOM class (`killed: 9`, live incident 2026-08-02) is
#           structurally unreachable on any unattended run.
#   OPT-IN  --engine=tree-sitter — the T1 grammar smoke tests run HERE only,
#           SERIALLY with a hard per-probe timeout (the smoke test is also a
#           clang compile step; serial-by-construction is what makes the lane
#           safe for the rare hand-configured-grammar machine).
#
# Usage:
#   probe-scan-engine.sh [--cwd=<dir>] [--engine=tree-sitter|ast-grep|regex]
#                        [--timeout=<sec>] --lang=<lang>[:<sample-file>] ...
#
#   --lang=python:src/app.py   detected language + one real source file to probe
#   --lang=python              detected language with NO source file yet
#                              (scaffold-only → probe SKIPPED, not failed)
#
# Output: ONE compact JSON digest on stdout:
#   { engine, precision_tier, binary_name (opt-in-lane relevance only — stamped
#     in auto too, purely informational), tree_sitter_version, astgrep_version,
#     grammars_used: [opt-in tree-sitter langs], astgrep_langs: [auto primary langs],
#     fallbacks: [{lang, tier, reason}], halt }
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
case "$FORCED" in ""|tree-sitter|ast-grep|regex) : ;; *) echo "probe-scan-engine.sh: bad --engine=$FORCED" >&2; exit 2 ;; esac
case "$TIMEOUT" in ''|*[!0-9]*|0) echo "probe-scan-engine.sh: --timeout must be a positive integer, got '$TIMEOUT'" >&2; exit 2 ;; esac

# Query files live next to the scan-codebase skill, resolved relative to this script.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUERIES_DIR="${SCRIPT_DIR}/../skills/scan-codebase/queries"

# `command -v` probes are shell builtins — no process cost, and probed ONCE here.
TS_BIN=""
command -v tree-sitter >/dev/null 2>&1 && TS_BIN="tree-sitter"
[ -z "$TS_BIN" ] && command -v tree-sitter-cli >/dev/null 2>&1 && TS_BIN="tree-sitter-cli"
AG_BIN=""
command -v ast-grep >/dev/null 2>&1 && AG_BIN="ast-grep"

python3 - "$CWD" "$FORCED" "$TIMEOUT" "$TS_BIN" "$AG_BIN" "$QUERIES_DIR" ${LANG_ARGS+"${LANG_ARGS[@]}"} <<'PYEOF'
import json, os, re, subprocess, sys

cwd, forced, timeout_s, ts_bin, ag_bin, queries_dir = sys.argv[1:7]
timeout_s = max(1, int(timeout_s))
lang_args = sys.argv[7:]

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
        # first X.Y-shaped token — some tree-sitter releases append "(<sha>)"
        m = re.search(r"\d+\.\d+[\w.\-]*", out.strip().splitlines()[0])
        return m.group(0) if m else None
    return None

digest = {
    "engine": None, "precision_tier": None,
    "binary_name": ts_bin or None,
    "tree_sitter_version": version_of(ts_bin),
    "astgrep_version": version_of(ag_bin),
    "grammars_used": [], "astgrep_langs": [],
    "fallbacks": [], "halt": None,
}

def emit(code):
    print(json.dumps(digest, separators=(",", ":")))
    sys.exit(code)

def dep_missing(binary):
    digest["halt"] = {"type": "dep_missing", "required_binary": binary}
    emit(3)

# ── forced-engine short circuits (never a silent fall-through) ──────────────
if forced == "tree-sitter" and not ts_bin:
    dep_missing("tree-sitter")
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

def fall_to_regex(lang, reason):
    # D2: every recorded fall lands on regex — the opt-in tree-sitter lane never
    # detours to ast-grep (the caller chose tree-sitter), and the auto primary
    # route is recorded in astgrep_langs, never here.
    digest["fallbacks"].append({"lang": lang, "tier": "regex", "reason": reason})

# ── lane resolution (D2): auto NEVER probes tree-sitter ─────────────────────
# use_ts is true ONLY under the explicit --engine=tree-sitter opt-in; the
# grammar smoke tests below are unreachable in auto, so no clang compile can
# ever run on an unattended invocation.
use_ts = bool(ts_bin) and forced == "tree-sitter"
for lang, sample in langs:
    if not sample:
        # scaffold-only language: nothing to probe, nothing to extract —
        # SKIPPED on EVERY tier path, never counted as a fallback
        digest["fallbacks"].append({"lang": lang, "tier": "skipped", "reason": "no_source_file"})
        continue
    if not use_ts:
        if ag_bin and (lang in ASTGREP_LANGS or ASTGREP_ALIASES.get(lang) in ASTGREP_LANGS):
            # the PRIMARY route, not a fallback — no fallbacks[] row, so the
            # map's precision_downgrade_reason stays clean on the happy path
            digest["astgrep_langs"].append(lang)
        elif ag_bin:
            digest["fallbacks"].append({"lang": lang, "tier": "regex", "reason": "no_astgrep_pack"})
        else:
            digest["fallbacks"].append({"lang": lang, "tier": "regex", "reason": "astgrep_absent"})
        continue
    scm = os.path.join(queries_dir, "tags-%s.scm" % lang)
    if not os.path.isfile(scm):
        fall_to_regex(lang, "no_query_file")
        continue
    rc, out, err = run([ts_bin, "query", scm, sample], timeout_s, cwd=cwd)
    blob = err + "\n" + out
    if rc == 0:
        digest["grammars_used"].append(lang)
    elif rc is None:
        fall_to_regex(lang, "probe_timeout")
    elif rc < 0 or rc == 137 or "Killed: 9" in blob:
        # The clang-OOM class, BOTH spellings (verified live 2026-08-02):
        # tree-sitter itself SIGKILLed → rc -9/137; or tree-sitter exits rc=1
        # with the OOM-killed clang child's "Killed: 9" in stderr. Retryable,
        # NOT an install problem.
        fall_to_regex(lang, "grammar_compile_killed")
    elif rc == 127:
        # the binary resolved on PATH but could not be executed (OSError /
        # command-not-found at exec time — e.g. npm's extensionless sh shim
        # under Windows CreateProcess)
        fall_to_regex(lang, "binary_unrunnable")
    elif "compilation failed" in blob.lower():
        fall_to_regex(lang, "grammar_compile_failed")
    elif "No language found" in blob or "Failed to load language" in blob:
        fall_to_regex(lang, "grammar_missing")
    else:
        fall_to_regex(lang, "query_error")

# ── ladder resolution: highest tier that extracted ≥1 language ──────────────
if digest["grammars_used"]:
    digest["engine"], digest["precision_tier"] = "tree-sitter", "ast"
elif digest["astgrep_langs"]:
    digest["engine"], digest["precision_tier"] = "ast-grep", "ast"
elif langs and all(f.get("tier") == "skipped" for f in digest["fallbacks"]) and (use_ts or ag_bin):
    # scaffold-only repo, an AST binary present: keep the AST engine claim per
    # binary presence (nothing was extracted either way — the pre-D2 rule,
    # re-homed to the D2 ladder). Guarded on ALL entries being skips: a real
    # fallback here would stamp `ast` on a map that extracted via regex.
    digest["engine"] = "tree-sitter" if use_ts else "ast-grep"
    digest["precision_tier"] = "ast"
else:
    digest["engine"], digest["precision_tier"] = "regex", "regex"
emit(0)
PYEOF
