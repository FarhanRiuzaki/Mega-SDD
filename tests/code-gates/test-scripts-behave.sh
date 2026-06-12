#!/usr/bin/env bash
# Functional smoke: the four L0 scripts exist, are executable, and behave on fixtures.
set -u
err=0
S=plugins/mega-sdd/scripts
for f in detect-toolchain.sh run-code-scan.sh scan-secrets-code.sh validate-new-deps.sh; do
  [ -x "$S/$f" ] || { echo "missing or non-executable: $f"; err=1; }
done
[ $err -eq 0 ] || exit $err

# detect-toolchain: detects prettier+tsc from config evidence; empty dir → empty lists
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo '{"prettier":{}}' > "$tmp/package.json"; echo '{}' > "$tmp/tsconfig.json"
out=$("$S/detect-toolchain.sh" --cwd="$tmp")
echo "$out" | grep -q '"prettier"' || { echo "detect: prettier not detected from package.json key"; err=1; }
echo "$out" | grep -q '"tsc"' || { echo "detect: tsc not detected from tsconfig.json"; err=1; }
empty=$(mktemp -d); out=$("$S/detect-toolchain.sh" --cwd="$empty"); rm -rf "$empty"
echo "$out" | grep -q '"formatters": \[\]' || { echo "detect: empty repo must yield no formatters (never impose)"; err=1; }

# scan-secrets-code: fixture repo with a planted AWS-shaped key in the diff → exit 1
repo=$(mktemp -d)
( cd "$repo" && git init -q . \
  && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base \
  && printf 'key = "AKIA%s"\n' "ABCDEFGHIJKLMNOP" > app.py \
  && git add . && git -c user.email=t@t -c user.name=t commit -qm leak )
"$S/scan-secrets-code.sh" --base=HEAD~1 --head=HEAD --cwd="$repo" >/dev/null 2>&1
[ $? -eq 1 ] || { echo "secrets: planted AWS key in diff must exit 1"; err=1; }
# secret value must never be echoed in full
outj=$("$S/scan-secrets-code.sh" --base=HEAD~1 --head=HEAD --cwd="$repo" 2>/dev/null)
echo "$outj" | grep -q "AKIAABCDEFGHIJKLMNOP" && { echo "secrets: full secret value echoed in report"; err=1; }
rm -rf "$repo"

# validate-new-deps: no manifest change → exit 0, total_new 0
repo2=$(mktemp -d)
( cd "$repo2" && git init -q . \
  && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base \
  && echo hi > readme.md && git add . && git -c user.email=t@t -c user.name=t commit -qm docs )
out2=$("$S/validate-new-deps.sh" --base=HEAD~1 --head=HEAD --cwd="$repo2"); rc=$?
[ $rc -eq 0 ] || { echo "new-deps: no manifest change must exit 0"; err=1; }
echo "$out2" | grep -q '"total_new": 0' || { echo "new-deps: expected total_new 0"; err=1; }
rm -rf "$repo2"

# run-code-scan: must be a SKIP (exit 0 + skipped reason) when semgrep is absent —
# simulate by clearing PATH down to the essentials
repo3=$(mktemp -d)
( cd "$repo3" && git init -q . \
  && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base \
  && echo "x=1" > a.py && git add . && git -c user.email=t@t -c user.name=t commit -qm c )
out3=$(cd "$repo3" && PATH="/usr/bin:/bin" bash "$OLDPWD/$S/run-code-scan.sh" --base=HEAD~1 --head=HEAD); rc=$?
if command -v semgrep >/dev/null 2>&1 && [ -x /usr/bin/semgrep ]; then
  : # semgrep genuinely on the minimal PATH — skip-path untestable here
else
  [ $rc -eq 0 ] || { echo "sast: absent semgrep must exit 0 (skip)"; err=1; }
  echo "$out3" | grep -q '"skipped": true' || { echo "sast: absent semgrep must report skipped:true"; err=1; }
fi
rm -rf "$repo3"
exit $err
