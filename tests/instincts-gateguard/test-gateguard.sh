#!/usr/bin/env bash
# Functional: GateGuard deny→force→allow on LOCKED-anchored files.
set -u
err=0
H=plugins/mega-sdd/hooks/pre-tool-use
B=plugins/mega-sdd/scripts/build-locked-index.sh

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.mega-sdd/vaults/v" "$T/app"
echo "x" > "$T/app/x.js"; echo "y" > "$T/app/y.js"
printf 'claim #3 settlement calc CONFIRMED [LOCKED] anchor `app/x.js:10`\n' > "$T/.mega-sdd/vaults/v/binding.md"

req() { printf '{"session_id":"%s","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$T" "$2"; }

# index builds standalone too
bash "$B" --cwd="$T"
grep -q '"app/x.js"' "$T/.mega-sdd/.locked-files-index.json" || { echo "index missing locked file"; err=1; }

# 1st edit on locked file -> deny with the prescription
out=$(req s1 "$T/app/x.js" | bash "$H")
echo "$out" | grep -q '"permissionDecision": "deny"' || { echo "first edit not denied"; err=1; }
echo "$out" | grep -qi 'GateGuard' || { echo "deny reason missing GateGuard"; err=1; }
echo "$out" | grep -qi 'RETRY the same edit' || { echo "deny reason missing retry instruction"; err=1; }
# retry -> allowed (empty output)
out=$(req s1 "$T/app/x.js" | bash "$H")
[ -z "$out" ] || { echo "retry was not allowed"; err=1; }
# different session -> gates again
out=$(req s2 "$T/app/x.js" | bash "$H")
echo "$out" | grep -q '"permissionDecision": "deny"' || { echo "new session must re-gate"; err=1; }
# non-locked file -> never gated
out=$(req s3 "$T/app/y.js" | bash "$H")
[ -z "$out" ] || { echo "non-locked file gated (false positive)"; err=1; }
# opt-out
echo "gateguard: false" > "$T/.mega-sdd/config.yaml"
out=$(req s4 "$T/app/x.js" | bash "$H")
[ -z "$out" ] || { echo "gateguard: false not honored"; err=1; }
rm -f "$T/.mega-sdd/config.yaml"
# greenfield (no LOCKED anywhere) -> inert
T2=$(mktemp -d); mkdir -p "$T2/.mega-sdd/vaults/v" "$T2/app"; echo z > "$T2/app/z.js"
printf 'no locked markers here\n' > "$T2/.mega-sdd/vaults/v/binding.md"
out=$(printf '{"session_id":"s1","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s/app/z.js"}}' "$T2" "$T2" | bash "$H")
[ -z "$out" ] || { echo "greenfield project gated (must be inert)"; err=1; }
rm -rf "$T2"
exit $err
