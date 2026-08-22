#!/usr/bin/env bash
# test-5c-flow-pack-gates.sh — god-review stage 5, Batch 5C.
# Pins flow-coverage + pack-gate correctness:
#
#   GU-FC-FRONTMATTER  canonical frontmatter target_files are read — no false
#                      FAIL on schema-conformant units.
#   GU-FLOWCOV-1       mermaid-first derivation: per-transition units PASS on
#                      canonical vaults; signal-free mermaid falls back to DoD
#                      (the founding-defect false-PASS stays closed).
#   GU-HOOK-5          all-vault scanning: a violating small vault FAILs the
#                      state despite a bigger clean vault (vault-scoped match).
#   GU-PACKLINT-GATES  a typo'd gate header + an unrewritten extends
#                      placeholder are pack-lint violations.
#   GU-SKC-INDENT      starterkit-conformance parses the schema-doc indentation
#                      AND fail-louds (ERROR) when patterns: parses to zero.
#
# Run: bash tests/god-review-s5/test-5c-flow-pack-gates.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VFC="${ROOT}/plugins/mega-sdd/scripts/validate-flow-coverage.sh"
VPK="${ROOT}/plugins/mega-sdd/scripts/validate-pack.sh"
SKC="${ROOT}/plugins/mega-sdd/scripts/validate-starterkit-conformance.sh"
LARAVEL="${ROOT}/plugins/mega-sdd/references/framework-conventions/laravel.md"
for f in "$VFC" "$VPK" "$SKC" "$LARAVEL"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t flow5c)"
trap 'rm -rf "$WORK"' EXIT

note "== 5C: flow-coverage + pack gates =="

# ── canonical fixture: laravel + mermaid flow + DoD + frontmatter TF ──
F1="$WORK/f1"; mkdir -p "$F1/.mega-sdd/codebase" "$F1/.mega-sdd/vaults/demo/units"
printf -- '---\nframework: laravel\n---\n' > "$F1/.mega-sdd/codebase/codebase-map.md"
cat > "$F1/.mega-sdd/vaults/demo/04-flows.md" <<'EOF'
# Flows

### F-U-001: Widget Approval

```mermaid
flowchart TD
  S1["Maker submits widget draft"] --> S2["Checker reviews widget"]
  S2 --> S3["Checker approves or rejects"]
  S3 --> S4["Widget published"]
```

**Definition of Done**
- [ ] Maker can submit a widget draft
- [ ] Checker can review the widget
- [ ] Checker can approve or reject
- [ ] Publication is recorded
- [ ] Notification is sent on approval
EOF
cat > "$F1/.mega-sdd/vaults/demo/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: Widget approval module
task_type: create
target_files:
  - path: app/Http/Requests/WidgetSubmitRequest.php
  - path: app/Http/Requests/WidgetReviewRequest.php
  - path: app/Http/Requests/WidgetDecisionRequest.php
  - path: app/Http/Controllers/WidgetController.php
vault_source: 04-flows.md
acceptance_test:
  - type: feature
    assert: approval flow works
---
## Implementation steps
Body.
EOF
bash "$VFC" --cwd="$F1" --quiet >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "FC-FRONTMATTER + FLOWCOV-1: canonical unit (frontmatter TF, per-mermaid-transition artifacts) PASSes (was a permanent false-FAIL)" \
  || fail "canonical unit still blocked (rc=$RC): $(python3 -c "import json; print(json.load(open('$F1/.mega-sdd/.flow-coverage-state.json'))['missing_artifacts'])" 2>/dev/null)"

# ── signal-free mermaid + signal DoD → DoD fallback still catches under-coverage ──
python3 - "$F1" <<'PY'
import sys
p = sys.argv[1] + "/.mega-sdd/vaults/demo/04-flows.md"
s = open(p).read()
for a, b in [('S1["Maker submits widget draft"]', 'S1["State A"]'), ('S2["Checker reviews widget"]', 'S2["State B"]'),
             ('S3["Checker approves or rejects"]', 'S3["State C"]'), ('S4["Widget published"]', 'S4["State D"]')]:
    s = s.replace(a, b)
open(p, "w").write(s)
p2 = sys.argv[1] + "/.mega-sdd/vaults/demo/units/U-001.md"
s2 = open(p2).read()
for r in ("  - path: app/Http/Requests/WidgetSubmitRequest.php\n", "  - path: app/Http/Requests/WidgetReviewRequest.php\n", "  - path: app/Http/Requests/WidgetDecisionRequest.php\n"):
    s2 = s2.replace(r, "")
open(p2, "w").write(s2)
PY
bash "$VFC" --cwd="$F1" --quiet >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "FLOWCOV-1: signal-free mermaid labels fall back to DoD — zero-Request unit still FAILs (founding-defect false-PASS closed)" \
  || fail "FLOWCOV-1: false-PASS direction re-opened (rc=$RC)"

# ── GU-HOOK-5: violating small vault blocks despite bigger clean vault ──
mkdir -p "$F1/.mega-sdd/vaults/bigclean/units"
cat > "$F1/.mega-sdd/vaults/bigclean/04-flows.md" <<'EOF'
### F-U-001: Order Entry
```mermaid
flowchart TD
  A["Clerk submits order form"] --> B["Order stored"]
```
EOF
for i in 1 2 3; do
cat > "$F1/.mega-sdd/vaults/bigclean/units/U-00$i.md" <<EOF
---
unit_id: U-00$i
title: Order module $i
task_type: create
target_files:
  - path: app/Http/Requests/OrderSubmitRequest$i.php
vault_source: 04-flows.md
acceptance_test:
  - type: feature
    assert: order works
---
body
EOF
done
bash "$VFC" --cwd="$F1" --quiet >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$F1/.mega-sdd/.flow-coverage-state.json'))
vaults = {m.get('vault') for m in d['missing_artifacts']}
sys.exit(0 if d['status'] == 'FAIL' and 'demo' in vaults and 'bigclean' not in vaults else 1)
" && ok "HOOK-5: smaller vault's shortfall FAILs the state; the clean vault stays clean (vault-scoped)" \
  || fail "HOOK-5: multi-vault mask survives (rc=$RC)"

# ── round-2 S5-ATK-1: legacy -bound sibling must not double-count ──
F3="$WORK/bound"; mkdir -p "$F3/.mega-sdd/codebase" "$F3/.mega-sdd/vaults/demo" "$F3/.mega-sdd/vaults/demo-bound/units"
printf -- '---\nframework: laravel\n---\n' > "$F3/.mega-sdd/codebase/codebase-map.md"
cat > "$F3/.mega-sdd/vaults/demo/04-flows.md" <<'EOF'
### F-U-001: Widget Approval
```mermaid
flowchart TD
  S1["Maker submits widget draft"] --> S2["Checker reviews widget"]
  S2 --> S3["Checker approves widget"]
  S3 --> S4["Supervisor confirms decision form"]
```
EOF
cp "$F3/.mega-sdd/vaults/demo/04-flows.md" "$F3/.mega-sdd/vaults/demo-bound/04-flows.md"
cat > "$F3/.mega-sdd/vaults/demo-bound/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: Widget approval
task_type: create
target_files:
  - path: app/Http/Requests/WidgetSubmitRequest.php
  - path: app/Http/Requests/WidgetReviewRequest.php
vault_source: 04-flows.md
acceptance_test:
  - type: feature
    assert: works
---
body
EOF
bash "$VFC" --cwd="$F3" --quiet >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$F3/.mega-sdd/.flow-coverage-state.json'))
sh = sum(m['shortfall'] for m in d['missing_artifacts'])
sys.exit(0 if d['status'] == 'FAIL' and sh == 1 else 1)
" && ok "r2 ATK-1: -bound sibling pair counted ONCE — 3-step/2-Request shortfall=1 FAILs (double-count false-PASS closed)" \
  || fail "r2 ATK-1: -bound double-count survives (rc=$RC): $(python3 -c "import json; d=json.load(open('$F3/.mega-sdd/.flow-coverage-state.json')); print(d['status'], d['summary'])" 2>/dev/null)"

# ── round-2 ATK-FC-2: coarse mermaid must not suppress richer legacy steps ──
F4="$WORK/coarse"; mkdir -p "$F4/.mega-sdd/codebase" "$F4/.mega-sdd/vaults/demo/units"
printf -- '---\nframework: laravel\n---\n' > "$F4/.mega-sdd/codebase/codebase-map.md"
cat > "$F4/.mega-sdd/vaults/demo/04-flows.md" <<'EOF'
### F-U-001: Widget Approval
```mermaid
flowchart TD
  A["Maker submits everything"] --> B["Done"]
```
1. Maker submits a widget draft form
2. Checker reviews the widget submission
3. Checker approves or rejects the entry
4. Supervisor confirms the decision form
5. System records the final submission
EOF
cat > "$F4/.mega-sdd/vaults/demo/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: Widget approval
task_type: create
target_files:
  - path: app/Http/Requests/WidgetSubmitRequest.php
vault_source: 04-flows.md
acceptance_test:
  - type: feature
    assert: works
---
body
EOF
bash "$VFC" --cwd="$F4" --quiet >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$F4/.mega-sdd/.flow-coverage-state.json'))
sh = sum(m['shortfall'] for m in d['missing_artifacts'])
sys.exit(0 if d['status'] == 'FAIL' and sh >= 2 else 1)
" && ok "r2 ATK-FC-2: coarse 1-edge mermaid does NOT suppress signal-rich numbered steps" \
  || fail "r2 ATK-FC-2: mermaid suppression survives (rc=$RC)"

# ── GU-PACKLINT-GATES ──
# NOTE: capture output FIRST — under pipefail the validator's exit 1 would sink
# the pipeline even when grep matches.
sed 's/^## Flow-artifact derivation/## Flow artifact derivation/' "$LARAVEL" > "$WORK/typostack.md"
PK_OUT=$(bash "$VPK" "$WORK/typostack.md" 2>&1 || true)
echo "$PK_OUT" | grep -q "unrecognized gate-like" \
  && ok "PACKLINT: typo'd gate header is a lint violation (silent-SKIP downgrade caught at authoring time)" \
  || fail "PACKLINT: typo'd header passes the pack lint"
sed 's/^extends:.*/extends: <other-pack-or-null>/' "$LARAVEL" > "$WORK/place.md"
PK_OUT=$(bash "$VPK" "$WORK/place.md" 2>&1 || true)
echo "$PK_OUT" | grep -q "unrewritten template placeholder" \
  && ok "PACKLINT: unrewritten extends placeholder is a lint violation (chain-walk break caught)" \
  || fail "PACKLINT: extends placeholder passes"
bash "$VPK" "$LARAVEL" >/dev/null 2>&1 && ok "PACKLINT: shipped laravel pack still lints clean" || fail "PACKLINT: laravel pack regressed"
# v7: scaffold-pack.sh demoted — the README documents a hand-copy of
# _template.md + fill; the LINTER is the safety net on that path. Two arms:
# (a) a raw copy that still carries the template's Laravel example tokens
#     must FAIL lint (leak back-stop alive on the README path);
# (b) a filled skeleton (frontmatter set + example tokens rewritten, as the
#     README instructs) must PASS.
TPL="${ROOT}/plugins/mega-sdd/references/framework-conventions/_template.md"
sed -e 's/^framework:.*/framework: r2teststack/' \
    -e 's/^framework_version_range:.*/framework_version_range: "1.x"/' \
    -e 's/^extends:.*/extends: _universal/' \
    "$TPL" > "$WORK/r2raw.md"
bash "$VPK" "$WORK/r2raw.md" >/dev/null 2>&1 \
  && fail "r2 S5R-2a: raw hand-copy with Laravel example tokens passed lint (leak back-stop dead)" \
  || ok "r2 S5R-2a: raw hand-copy FAILS lint — leak back-stop guards the README path"
sed -e 's|app/Http/Controllers/|src/controllers/|g' -e 's|app/Http/|src/|g' \
    -e 's|\.blade\.php|.tpl.html|g' -e 's|Eloquent|the ORM|g' \
    -e 's|artisan|the cli|g' -e 's|blade|tpl|g' -e 's|Blade|Tpl|g' \
    -e 's|composer\.json|the manifest|g' -e 's|app/Models/|src/models/|g' \
    "$WORK/r2raw.md" > "$WORK/r2teststack.md"
bash "$VPK" "$WORK/r2teststack.md" >/dev/null 2>&1 && ok "r2 S5R-2b: filled hand-scaffold (README path) passes lint" || fail "r2 S5R-2b: filled hand-scaffold fails lint — README authoring path broken"

# ── GU-SKC-INDENT ──
F2="$WORK/skc"; mkdir -p "$F2/.mega-sdd/codebase" "$F2/.mega-sdd/vaults/demo/units"
cat > "$F2/.mega-sdd/codebase/starterkit-context.yaml" <<'EOF'
patterns:
  controller:
    location: app/Http/Controllers/
EOF
cat > "$F2/.mega-sdd/vaults/demo/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: T
task_type: create
target_files:
  - path: src/random/WrongPlaceController.php
vault_source: x.md
---
body
EOF
bash "$SKC" --cwd="$F2" --quiet >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$F2/.mega-sdd/.starterkit-conformance-state.json'))
sys.exit(0 if d['status'] == 'FAIL' and len(d.get('violations', [])) == 1 else 1)
" && ok "SKC-INDENT: schema-doc col-0 indentation parses — real violation detected (was silent SKIP)" \
  || fail "SKC-INDENT: col-0 shape still parses to zero patterns (rc=$RC)"
printf 'patterns:\nunparseable drift here\n' > "$F2/.mega-sdd/codebase/starterkit-context.yaml"
bash "$SKC" --cwd="$F2" --quiet >/dev/null 2>&1; RC=$?
python3 -c "
import json, sys
d = json.load(open('$F2/.mega-sdd/.starterkit-conformance-state.json'))
sys.exit(0 if d['status'] == 'ERROR' else 1)
" && [ "$RC" -eq 2 ] && ok "SKC-INDENT: patterns-present-but-unparseable → ERROR/exit 2 (fail-loud, never silent SKIP)" \
  || fail "SKC-INDENT: unparseable block still SKIPs silently (rc=$RC)"

# ── GU-STATE-ATOMIC: no bare-open state writes remain in the two validators ──
if grep -qE 'with open\(state_file, "w"\)' "${ROOT}/plugins/mega-sdd/scripts/validate-sibling-consistency.sh"; then
  fail "ATOMIC: fanout-parity still writes non-atomically"
else
  ok "ATOMIC: fanout-parity uses tmp+os.replace"
fi
grep -q "os.replace(_tmp, '\$STATE_FILE')" "$SKC" && ok "ATOMIC: starterkit-conformance uses tmp+os.replace" || fail "ATOMIC: SKC write not atomic"

if [ "$FAILED" -eq 0 ]; then note "ALL 5C OK"; else note "5C had failures"; fi
exit $FAILED
