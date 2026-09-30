#!/usr/bin/env bash
# test-utf8-io.sh — every script reads and writes files as UTF-8, whatever the
# host locale. Field report 2026-09-30 (Windows 11, Python 3.14, locale cp1252,
# PYTHONUTF8 unset): one ground.sh run rewrote a tracked vault.json title
# "— perubahan" as "â€” perubahan" (UTF-8 bytes read as cp1252,
# then ensure_ascii), exit 0, and derive-state.sh wrote .mega-sdd/.gitignore in
# cp1252, rewriting it on every run (a dirty tree that blocks migrate-paths).
# macOS/Linux default to UTF-8, so the live arm uses an ISO-8859-1 locale to
# get the same failure there.
#   A  no text-mode open()/fdopen()/NamedTemporaryFile() without encoding=
#   B  every bash entry script that runs python exports PYTHONUTF8=1
#   C  live: ground.sh under ISO-8859-1 keeps vault.json and .gitignore UTF-8
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
P="$REPO/plugins/mega-sdd"
FAIL=0; ok() { echo "  ok: $1"; }; bad() { echo "  FAIL: $1"; FAIL=1; }

echo "── A: explicit encoding on every text-mode file open ──"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
python3 - "$P" > "$T/lint" <<'PY'
import os, re, sys
root = sys.argv[1]; out = []
for base in ("scripts", "hooks"):
    for dp, _, fn in os.walk(os.path.join(root, base)):
        for n in fn:
            p = os.path.join(dp, n)
            try: s = open(p, encoding="utf-8").read()
            except (OSError, UnicodeDecodeError): continue
            for m in re.finditer(r"(?<![\w.])(open|fdopen|NamedTemporaryFile)\(", s):
                if "#" in s[s.rfind("\n", 0, m.start()) + 1:m.start()]: continue   # comment
                i = j = m.end(); d = 1
                while j < len(s) and d: d += (s[j] == "(") - (s[j] == ")"); j += 1
                a = s[i:j - 1]
                if not a.strip() or "encoding" in a: continue
                if re.search(r"""['"][rwax+]*b[rwax+]*['"]""", a): continue
                if m.group(1) == "NamedTemporaryFile" and not re.search(r"""^\s*['"][rwax+]*['"]""", a): continue  # default mode w+b
                out.append("%s:%d" % (os.path.relpath(p, root), s.count("\n", 0, m.start()) + 1))
print(" ".join(out))
PY
A=$(cat "$T/lint")
[ -z "$A" ] && ok "A1 no text-mode open without encoding" || bad "A1 missing encoding: $A"

echo "── B: PYTHONUTF8=1 in every bash script that runs python ──"
B=""
for f in "$P"/scripts/*.sh "$P"/hooks/*; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q 'sh' || continue
  grep -v '^[[:space:]]*#' "$f" | grep -qE '\bpython3?\b|MEGA_SDD_PY' || continue
  grep -q '^export PYTHONUTF8=1' "$f" || B="$B ${f#$P/}"
done
[ -z "$B" ] && ok "B1 all export PYTHONUTF8=1" || bad "B1 missing:$B"

echo "── C: live under a non-UTF-8 locale ──"
if ! LC_ALL=en_US.ISO8859-1 python3 -c 'import locale,sys; sys.exit(0 if locale.getpreferredencoding(False).upper().replace("-","").startswith("ISO88591") else 1)' 2>/dev/null; then
  echo "  skip: no ISO-8859-1 locale on this host"
else
  V="$T/.mega-sdd/vaults/fe-06"; mkdir -p "$V"
  printf '{\n  "title": "Keputusan checker (E7) — perubahan transport"\n}\n' > "$V/vault.json"
  echo '{}' > "$T/package.json"; git -C "$T" init -q
  printf '# mega-sdd-managed v1 \x97 regenerable\n' > "$T/.mega-sdd/.gitignore"   # a cp1252 file an older run left
  env -u PYTHONUTF8 LC_ALL=en_US.ISO8859-1 bash "$P/scripts/ground.sh" --cwd="$T" >/dev/null 2>&1
  grep -q '"mode": "existing"' "$V/vault.json" && ok "C1 mode guard ran (mode -> existing)" || bad "C1 mode guard did not run"
  grep -qF 'E7) — perubahan' "$V/vault.json" && ! grep -q 'u00e2' "$V/vault.json" \
    && ok "C2 vault.json em-dash kept as UTF-8" || bad "C2 vault.json corrupted: $(grep title "$V/vault.json")"
  python3 -c 'import sys; open(sys.argv[1], encoding="utf-8").read()' "$T/.mega-sdd/.gitignore" 2>/dev/null && grep -q '— ' "$T/.mega-sdd/.gitignore" \
    && ok "C3 .gitignore rewritten as UTF-8 (the cp1252 copy healed)" || bad "C3 .gitignore not UTF-8: $(head -1 "$T/.mega-sdd/.gitignore" | cat -v)"
  s1=$(cksum < "$T/.mega-sdd/.gitignore")
  env -u PYTHONUTF8 LC_ALL=en_US.ISO8859-1 bash "$P/scripts/derive-state.sh" --cwd="$T" >/dev/null 2>&1
  [ "$s1" = "$(cksum < "$T/.mega-sdd/.gitignore")" ] && ok "C4 second run leaves .gitignore untouched" || bad "C4 .gitignore rewritten again"
fi

[ "$FAIL" = 0 ] && echo "test-utf8-io: ALL PASS" || { echo "test-utf8-io: FAILED"; exit 1; }
