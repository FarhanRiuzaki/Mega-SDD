#!/usr/bin/env bash
# ADVISORY post-flight reuse-duplication heuristic. NEVER blocks (always exits 0).
# Compares newly-introduced symbol names against reuse-index.yaml entries; emits WARNINGs
# with both _source locations. Surfaced via /mega-sdd:analyze; NOT wired to PreToolUse.
set -u
CWD="${1:-$PWD}"
idx="$CWD/.mega-sdd/codebase/reuse-index.yaml"
[ -f "$idx" ] || { echo "[reuse-dup] no reuse-index.yaml — skipping (advisory)"; exit 0; }
names=$(grep -oE 'name: [A-Za-z_][A-Za-z0-9_]*' "$idx" | awk '{print $2}' | sort -u)
added=$(git -C "$CWD" diff HEAD~1 HEAD --unified=0 2>/dev/null | grep -E '^\+.*(function |def |public function )' || true)
hits=0
while IFS= read -r n; do
  [ -z "$n" ] && continue
  if echo "$added" | grep -qw "$n"; then
    echo "[reuse-dup][WARN] new code may reinvent existing '$n' (see reuse-index.yaml _source). Verify before merge."
    hits=$((hits+1))
  fi
done <<< "$names"
echo "[reuse-dup] advisory scan complete — $hits possible duplication(s). (non-blocking)"
exit 0
