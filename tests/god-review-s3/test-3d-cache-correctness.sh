#!/usr/bin/env bash
# test-3d-cache-correctness.sh — god-review stage 3, Batch 3D.
# Pins deep-scan cache correctness:
#
#   ECO-3  compute-lock-digests.sh produces a NON-EMPTY dotnet digest from
#          *.csproj / packages.lock.json / Directory.Packages.props (pre-fix: all
#          empty → the deep-scan cache never invalidated on NuGet changes), and
#          the digest CHANGES when a dependency edit lands in a csproj.
#   DS-1   slice signatures include a source component + detector version
#          (doc-pinned: deep-scan-stage.md Step 10.5.1.3 + schema comments).
#   DS-2   failed slices re-dispatch (stale_slices ∪= prior.partial_slices; no
#          per_slice entry for failed domains) and the remediation for
#          starterkit_metrics_inconsistent is --no-cache (not --force-deep).
#   DS-6   the canonical schema documents 5 per_slice entries incl. reuse.
#
# Run: bash tests/god-review-s3/test-3d-cache-correctness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CLD="${ROOT}/plugins/mega-sdd/scripts/compute-lock-digests.sh"
DSS="${ROOT}/plugins/mega-sdd/skills/scan-codebase/references/deep-scan-stage.md"
SCS="${ROOT}/plugins/mega-sdd/references/starterkit-context-schema.md"
VC="${ROOT}/plugins/mega-sdd/skills/generate-intent/references/vault-contract.md"
# starterkit_metrics_inconsistent remediation text relocated (verbatim) from
# vault-contract.md §halt-protocol to the plugin-root canonical halt registry:
HPR="${ROOT}/plugins/mega-sdd/references/halt-protocol.md"
for f in "$CLD" "$DSS" "$SCS" "$VC" "$HPR"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t cache3d)"
trap 'rm -rf "$WORK"' EXIT

note "== 3D: deep-scan cache correctness =="

# ── ECO-3: dotnet digests non-empty + sensitive to csproj edits ──
mkdir -p "$WORK/dn/src/Api"
cat > "$WORK/dn/src/Api/Api.csproj" <<'XML'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.0" />
  </ItemGroup>
</Project>
XML
cp "$WORK/dn/src/Api/Api.csproj" "$WORK/dn/Root.csproj"
printf '%s\n' '{ "version": 1 }' > "$WORK/dn/packages.lock.json"
J1="$(bash "$CLD" --project="$WORK/dn" --app-ecosystem=dotnet)"
D1="$(OUT="$J1" python3 -c "import json,os;print(json.loads(os.environ['OUT'])['app_locks_digest'])")"
[ -n "$D1" ] && ok "ECO-3: dotnet app_locks_digest non-empty ($(printf '%.12s' "$D1")…)" || fail "ECO-3: dotnet digest EMPTY (pre-fix hole): $J1"
LF="$(OUT="$J1" python3 -c "import json,os;print(json.loads(os.environ['OUT'])['lock_files'].get('dotnet',''))")"
case "$LF" in *csproj*) ok "ECO-3: provenance lists csproj files ($LF)";; *) fail "ECO-3: provenance missing csproj: '$LF'";; esac
case "$LF" in *src/Api/Api.csproj*) ok "ECO-3: depth-2 src/<Project>/<Project>.csproj covered (dominant layout)";; *) fail "ECO-3: depth-2 csproj NOT folded: '$LF'";; esac
# dependency edit → digest changes
python3 -c "
import re
p = '$WORK/dn/Root.csproj'
s = open(p).read().replace('Version=\"8.0.0\"', 'Version=\"9.0.0\"')
open(p, 'w').write(s)
"
J2="$(bash "$CLD" --project="$WORK/dn" --app-ecosystem=dotnet)"
D2="$(OUT="$J2" python3 -c "import json,os;print(json.loads(os.environ['OUT'])['app_locks_digest'])")"
[ "$D1" != "$D2" ] && ok "ECO-3: NuGet version edit changes the digest (cache invalidates)" || fail "ECO-3: digest unchanged after dep edit"
# non-dotnet ecosystems unaffected (regression): php digest still works
mkdir -p "$WORK/php"; printf '%s\n' '{"packages":[]}' > "$WORK/php/composer.lock"
J3="$(bash "$CLD" --project="$WORK/php" --app-ecosystem=php)"
D3="$(OUT="$J3" python3 -c "import json,os;print(json.loads(os.environ['OUT'])['app_locks_digest'])")"
[ -n "$D3" ] && ok "ECO-3: php digest regression intact" || fail "ECO-3: php digest broke"

# round-2 (fix-review): depth-3 csproj, per-project packages.lock.json, vendored exclusion
mkdir -p "$WORK/dn/src/apps/Deep" "$WORK/dn/node_modules/junk"
cp "$WORK/dn/Root.csproj" "$WORK/dn/src/apps/Deep/Deep.csproj"
J4="$(bash "$CLD" --project="$WORK/dn" --app-ecosystem=dotnet)"
D4="$(OUT="$J4" python3 -c "import json,os;print(json.loads(os.environ['OUT'])['app_locks_digest'])")"
[ "$D4" != "$D2" ] && ok "r2: depth-3 csproj (src/apps/Deep/) folds into the digest" || fail "r2: depth-3 csproj invisible"
printf '%s\n' '{"version": 2}' > "$WORK/dn/src/Api/packages.lock.json"
J5="$(bash "$CLD" --project="$WORK/dn" --app-ecosystem=dotnet)"
D5="$(OUT="$J5" python3 -c "import json,os;print(json.loads(os.environ['OUT'])['app_locks_digest'])")"
[ "$D5" != "$D4" ] && ok "r2: PER-PROJECT packages.lock.json edit invalidates (locked-mode NuGet)" || fail "r2: per-project lock invisible"
cp "$WORK/dn/Root.csproj" "$WORK/dn/node_modules/junk/Vendored.csproj"
J6="$(bash "$CLD" --project="$WORK/dn" --app-ecosystem=dotnet)"
D6="$(OUT="$J6" python3 -c "import json,os;print(json.loads(os.environ['OUT'])['app_locks_digest'])")"
[ "$D6" = "$D5" ] && ok "r2: node_modules csproj pollution EXCLUDED (third-party churn decoupled)" || fail "r2: vendored csproj polluted the digest"

# ── DS-1: signatures carry src_component + detector version (doc-pinned) ──
grep -qF 'src_component(auth)' "$DSS" && grep -qF 'src_component(authz)' "$DSS" && grep -qF 'src_component(ui_ux)' "$DSS" \
  && ok "DS-1: auth/authz/ui_ux signature inputs include src_component" || fail "DS-1: src_component missing from signature inputs"
grep -qF '+ detector' "$DSS" && ok "DS-1: signature inputs include the detector (skill) version" || fail "DS-1: detector version missing"
grep -qF 'src_component(auth)' "$SCS" && ok "DS-1: schema comments mirror the new signature inputs" || fail "DS-1: schema comments stale"

# ── DS-2: failed slices re-dispatch; remediation corrected ──
grep -qF 'stale_slices ∪= prior.partial_slices' "$DSS" && ok "DS-2: staleness diff unions prior partial_slices" || fail "DS-2: partial_slices not unioned"
grep -qF 'do NOT write a per_slice entry for a domain listed in' "$DSS" && ok "DS-2: failed domains get no per_slice entry" || fail "DS-2: per_slice failed-domain rule missing"
grep -qF 'belt-and-braces option' "$HPR" && grep -qF 'failed slices — they carry no per_slice cache signature' "$HPR" \
  && ok "DS-2: remediation states the post-fix truth (plain re-run heals; --no-cache = belt-and-braces)" || fail "DS-2: remediation wording stale"
if grep -qF 're-run `scan-codebase --force-deep`' "$VC" || grep -qF 're-run `scan-codebase --force-deep`' "$HPR"; then fail "DS-2: stale --force-deep remediation survives"; else ok "DS-2: no stale --force-deep remediation"; fi

# ── DS-6: canonical schema documents 5 slices incl. reuse ──
python3 - "$SCS" <<'PY' && ok "DS-6: schema per_slice block lists all 5 domains (incl. reuse)" || fail "DS-6: schema per_slice incomplete"
import re, sys
doc = open(sys.argv[1]).read()
m = re.search(r"^  per_slice:.*?^```", doc, re.M | re.S)
assert m, "per_slice block not found"
block = m.group(0)
missing = [d for d in ("auth:", "authz:", "ui_ux:", "libs:", "reuse:") if d not in block]
sys.exit(0 if not missing else 1)
PY
grep -qF 'each of the 5 slices' "$SCS" && ok "DS-6: cache-reuse rule says 5 slices" || fail "DS-6: reuse rule still /4"
if grep -qE '\([1-4]/4\)' "$SCS"; then fail "DS-6: /4-denominated matrix rows survive"; else ok "DS-6: invalidation matrix re-denominated to /5"; fi

if [ "$FAILED" -eq 0 ]; then note "ALL 3D OK"; else note "3D had failures"; fi
exit $FAILED
