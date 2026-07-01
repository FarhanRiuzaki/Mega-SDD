#!/usr/bin/env bash
# verify-mermaid.sh — OPT-IN ground-truth render check for Mermaid blocks.
#
# The always-on hook gate (validate-kb-flows.sh / validate-vault-flows.sh) uses a
# zero-dependency heuristic. This script is the deeper, opt-in layer: it runs the
# REAL mermaid grammar (mermaid.parse(), headless — no Chromium) over every
# ```mermaid block in a file and reports blocks that will NOT render. It catches
# render-breakers the heuristic cannot (reserved-word `end` nodes, unterminated
# shapes, malformed transition labels, missing diagram type, ...).
#
# BEST-EFFORT: needs Node + the `mermaid` package (e.g. via the mermaid-cli you
# already have, or `npm i mermaid`). If neither is resolvable it SKIPs cleanly —
# never errors, never blocks. Intended for CI / on-demand, not the per-write hook.
#
# Usage: verify-mermaid.sh --file-path=<file.md> [--cwd=<dir>] [--quiet]
#        MEGA_SDD_MERMAID_CORE=/path/to/mermaid.esm.min.mjs verify-mermaid.sh ...
# Output: <cwd>/.mega-sdd/.mermaid-render-state.json
# Exit: 0 = PASS/SKIP, 1 = at least one non-rendering block, 2 = error
set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --file-path=*) FILE_PATH="${arg#--file-path=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
LIB_DIR="${SELF_DIR}/_lib"
ORACLE="${LIB_DIR}/mermaid_parse_oracle.mjs"

if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ -z "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"--file-path required"}' >&2; exit 2; fi
if [ ! -f "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"file not found"}' >&2; exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.mermaid-render-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

emit_skip() {
  local detail="$1"
  local json
  json=$(python3 -c "import json,sys; print(json.dumps({'status':'SKIP','detail':sys.argv[1]}))" "$detail")
  echo "$json" > "$STATE_FILE" 2>/dev/null || true
  [ "$QUIET" -eq 0 ] && echo "$json"
  exit 0
}

# ── Resolve Node + python3 + the mermaid core (best-effort) ───────────────────
command -v node >/dev/null 2>&1 || emit_skip "node not found — opt-in render check skipped (heuristic gate still applies)"
command -v python3 >/dev/null 2>&1 || emit_skip "python3 not found — opt-in render check skipped (heuristic gate still applies)"

resolve_core() {
  if [ -n "${MEGA_SDD_MERMAID_CORE:-}" ] && [ -f "${MEGA_SDD_MERMAID_CORE}" ]; then
    echo "${MEGA_SDD_MERMAID_CORE}"; return
  fi
  local roots=() r c mp groot
  roots+=("${CWD}/node_modules")
  groot="$(npm root -g 2>/dev/null || true)"; [ -n "$groot" ] && roots+=("$groot")
  if command -v mmdc >/dev/null 2>&1; then
    mp="$(command -v mmdc)"
    # Resolve a symlink portably (macOS/BSD readlink has no -f): a RELATIVE target
    # is relative to the symlink's own directory, not $PWD.
    tgt="$(readlink "$mp" 2>/dev/null || true)"
    if [ -n "$tgt" ]; then
      case "$tgt" in
        /*) mp="$tgt" ;;
        *)  mp="$(cd "$(dirname "$mp")" 2>/dev/null && cd "$(dirname "$tgt")" 2>/dev/null && pwd)/$(basename "$tgt")" ;;
      esac
    fi
    roots+=("$(dirname "$mp")/../node_modules")
    roots+=("$(dirname "$mp")/../lib/node_modules")
  fi
  for r in "${roots[@]}"; do
    for c in \
      "$r/mermaid/dist/mermaid.esm.min.mjs" \
      "$r/@mermaid-js/mermaid-cli/node_modules/mermaid/dist/mermaid.esm.min.mjs"; do
      [ -f "$c" ] && { echo "$c"; return; }
    done
    c="$(ls "$r"/mermaid/dist/mermaid.esm*.mjs 2>/dev/null | head -1)"
    [ -n "$c" ] && { echo "$c"; return; }
    c="$(ls "$r"/@mermaid-js/mermaid-cli/node_modules/mermaid/dist/mermaid.esm*.mjs 2>/dev/null | head -1)"
    [ -n "$c" ] && { echo "$c"; return; }
  done
  echo ""
}

CORE="$(resolve_core)"
[ -n "$CORE" ] && [ -f "$CORE" ] || emit_skip "mermaid package not resolvable (install mermaid or mermaid-cli) — render check skipped"
[ -f "$ORACLE" ] || emit_skip "oracle helper missing: $ORACLE"

# ── Extract blocks (shared lib) + run the oracle per block ────────────────────
RESULT=$(python3 - "$CWD" "$FILE_PATH" "$LIB_DIR" "$ORACLE" "$CORE" <<'PYEOF'
import json, os, re, sys, subprocess, tempfile
cwd, file_path, lib_dir, oracle, core = sys.argv[1:6]
sys.path.insert(0, lib_dir)
try:
    from mermaid_syntax import extract_mermaid_blocks
except Exception as e:
    print(json.dumps({"status": "SKIP", "detail": "cannot load mermaid_syntax lib: " + str(e)})); sys.exit(0)

try:
    text = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)})); sys.exit(0)

blocks = extract_mermaid_blocks(text)
errors = []
for (bs, be, body) in blocks:
    diagram = "\n".join(line for _, line in body)
    with tempfile.NamedTemporaryFile("w", suffix=".mmd", delete=False) as t:
        t.write(diagram); tp = t.name
    try:
        r = subprocess.run(["node", oracle, core, tp], capture_output=True, text=True, timeout=90)
        out = (r.stdout or "").strip()
        code = r.returncode
    except Exception as e:
        out, code = "ORACLE_UNAVAILABLE: " + str(e), 2
    finally:
        try: os.unlink(tp)
        except Exception: pass
    if code == 2:
        # oracle could not run at all -> degrade whole check to SKIP
        print(json.dumps({"status": "SKIP", "detail": "mermaid parser could not run: " + out[:120]})); sys.exit(0)
    if code == 1 and out.startswith("GRAMMAR_ERROR"):
        errors.append({"line_number": bs, "detail": out[len("GRAMMAR_ERROR: "):][:160]})

status = "FAIL" if errors else "PASS"
print(json.dumps({
    "status": status,
    "checked_file": os.path.relpath(file_path, cwd),
    "block_count": len(blocks),
    "grammar_errors": errors,
    "summary": (f"{len(errors)} of {len(blocks)} mermaid block(s) will NOT render (real mermaid parser)"
                if errors else f"all {len(blocks)} mermaid block(s) parse (real mermaid grammar)"),
}))
PYEOF
)

echo "$RESULT" > "$STATE_FILE" 2>/dev/null || true
[ "$QUIET" -eq 0 ] && echo "$RESULT"

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)
case "$STATUS" in
  PASS|SKIP) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
