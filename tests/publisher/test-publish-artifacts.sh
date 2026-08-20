#!/usr/bin/env bash
# test-publish-artifacts.sh — pins spec 2026-08-17-artifact-publisher-gateway.md:
# the fail-open, delta-by-sha, manifest-first artifact publisher. Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/plugins/mega-sdd/scripts/publish-artifacts.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── fixture project ──────────────────────────────────────────────────────────
P="$TMP/proj"; MS="$P/.mega-sdd"
mkdir -p "$MS/vaults/app/units" "$MS/codebase" "$P/src"
printf '{"nodes":[],"edges":[],"_meta":{"source_hashes":{"a.md":"x1"}}}\n' > "$MS/graph.json"
printf '# idx\n' > "$MS/vaults/app/00-index.md"
printf '# binding\nCONFIRMED stuff\n' > "$MS/vaults/app/binding.md"
printf -- '---\nid: U-001\n---\nbody\n' > "$MS/vaults/app/units/U-001.md"
printf '{"vault_version":"1.0"}\n' > "$MS/vaults/app/vault.json"
printf '# map\n' > "$MS/codebase/codebase-map.md"
( cd "$P" && git init -q && git config user.email t@t && git config user.name t \
  && git remote add origin https://scm.bankmegadev.com/grup/repo.git \
  && git add -A && git commit -qm init )
HEAD=$(git -C "$P" rev-parse HEAD)

# curl shim: records args (minus token) + body file; scripted responses
SHIM="$TMP/shim"; LOG="$TMP/log"; mkdir -p "$SHIM" "$LOG"
cat > "$SHIM/curl" <<EOF
#!/bin/bash
printf '%s\\n' "\$@" > "$LOG/last-argv"
resp=\$(cat "$LOG/next-response" 2>/dev/null || echo 200)
body=""
prev=""
for a in "\$@"; do
  case "\$prev" in --data-binary) body="\${a#@}";; esac
  prev="\$a"
done
[ -n "\$body" ] && cp "\$body" "$LOG/last-body.tgz"
n=\$(cat "$LOG/count" 2>/dev/null || echo 0); echo \$((n+1)) > "$LOG/count"
printf '%s' "\$(cat "$LOG/next-body" 2>/dev/null)"
printf '\n%s' "\$resp"
EOF
chmod +x "$SHIM/curl"

# mega-code shim + fake HOMEs (v6.19.1 office-rung detection). Every invocation
# that must NOT hit the office rung runs under a scratch HOME **and USERPROFILE**
# (round MAJOR-1: Windows python's expanduser never consults HOME) — a real
# machine's ~/.claude/settings.json would otherwise arm rung 2 mid-suite.
# clean() strips ambient rung-1/office env so a developer shell with the
# publish pair exported can't turn hermetic arms red (round MINOR-9).
clean() { env -u MEGA_SDD_PUBLISH_URL -u MEGA_SDD_PUBLISH_TOKEN -u MEGA_SDD_PUBLISH_MAX_MB -u ANTHROPIC_BASE_URL "$@"; }
cat > "$SHIM/mega-code" <<'EOF'
#!/bin/bash
[ "$1" = "get-token" ] && { echo "office-tok-999"; exit 0; }
exit 1
EOF
chmod +x "$SHIM/mega-code"
# a REAL (shimmed) non-mega-code helper — f1b must fail via the signature CHECK,
# not via the helper binary happening to not exist (mutation-proofing)
cat > "$SHIM/other-helper" <<'EOF'
#!/bin/bash
echo "other-tok-777"
EOF
chmod +x "$SHIM/other-helper"
HOMELESS="$TMP/home-none"; mkdir -p "$HOMELESS"
HOME_OFF="$TMP/home-office"; mkdir -p "$HOME_OFF/.claude"
printf '{"apiKeyHelper":"mega-code get-token","env":{"ANTHROPIC_BASE_URL":"https://gw-office.test"}}\n' > "$HOME_OFF/.claude/settings.json"
HOME_PLAIN="$TMP/home-plain"; mkdir -p "$HOME_PLAIN/.claude"
printf '{"model":"opus"}\n' > "$HOME_PLAIN/.claude/settings.json"
HOME_NOURL="$TMP/home-nourl"; mkdir -p "$HOME_NOURL/.claude"
printf '{"apiKeyHelper":"mega-code get-token"}\n' > "$HOME_NOURL/.claude/settings.json"
HOME_OTHERHELPER="$TMP/home-otherhelper"; mkdir -p "$HOME_OTHERHELPER/.claude"
printf '{"apiKeyHelper":"other-helper get","env":{"ANTHROPIC_BASE_URL":"https://gw-other.test"}}\n' > "$HOME_OTHERHELPER/.claude/settings.json"
HOME_NOSCHEME="$TMP/home-noscheme"; mkdir -p "$HOME_NOSCHEME/.claude"
printf '{"apiKeyHelper":"mega-code get-token","env":{"ANTHROPIC_BASE_URL":"gw-noscheme.test"}}\n' > "$HOME_NOSCHEME/.claude/settings.json"

run() { PATH="$SHIM:$PATH" MEGA_SDD_PUBLISH_URL="${U:-https://gw.test}" MEGA_SDD_PUBLISH_TOKEN="${T:-sekrit-tok-123}" \
        bash "$SCRIPT" --cwd="$P" </dev/null 2>&1; }

echo "── a1: inert without credentials (no curl, rc 0) ──"
: > "$LOG/count"; echo 0 > "$LOG/count"
OUT=$(clean HOME="$HOMELESS" USERPROFILE="$HOMELESS" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] && [ ! -f "$MS/.publish-state.json" ] \
  && ok "a1 inert: rc 0, zero curl, no state" || fail "a1 rc=$RC count=$(cat "$LOG/count")"

echo "── a2: first push — manifest first entry, fields correct, full delta ──"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"; rm -f "$LOG/next-body"
OUT=$(run); RC=$?
[ "$RC" -eq 0 ] || fail "a2 rc=$RC"
PLUGVER=$("$PY" -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$ROOT/plugins/mega-sdd/.claude-plugin/plugin.json")
"$PY" - "$LOG/last-body.tgz" "$HEAD" "$PLUGVER" <<'PYEOF'
import tarfile, json, sys
tar = tarfile.open(sys.argv[1])
names = tar.getnames()
assert names[0] == "manifest.json", names
m = json.load(tar.extractfile("manifest.json"))
assert m["schema"] == "mega-sdd-publish/1", m
assert m["project_id"] == "scm.bankmegadev.com/grup/repo", m["project_id"]
assert m["vault"] == "app" and m["git_head"] == sys.argv[2], m
assert m["work_dir"] == "proj", m
assert m["plugin_version"] == sys.argv[3] and m["plugin_version"], m  # governance version-floor signal
assert m["graph_meta"]["source_hashes"] == {"a.md": "x1"}, m
assert "graph.json" in m["files"] and "vaults/app/binding.md" in m["files"], m["files"]
sent = set(names) - {"manifest.json"}
assert sent == set(m["files"]), (sent, set(m["files"]))   # first push = full delta
PYEOF
[ $? -eq 0 ] && ok "a2 manifest-first wire format + fields + full first delta" || fail "a2 bundle wrong"
[ -f "$MS/.publish-state.json" ] && ok "a2b state written on 200" || fail "a2b no state"

echo "── a3: debounce — no changes → no POST ──"
echo 0 > "$LOG/count"
run >/dev/null; [ "$(cat "$LOG/count")" = "0" ] && ok "a3 unchanged → zero curl" || fail "a3 pushed without changes"

echo "── a4: delta — one changed file → bundle carries ONLY it (+manifest full) ──"
printf '# binding v2\nCONFLICT now\n' > "$MS/vaults/app/binding.md"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"
run >/dev/null
"$PY" - "$LOG/last-body.tgz" <<'PYEOF'
import tarfile, json, sys
tar = tarfile.open(sys.argv[1])
names = tar.getnames()
assert set(names) == {"manifest.json", "vaults/app/binding.md"}, names
m = json.load(tar.extractfile("manifest.json"))
assert len(m["files"]) > 1, "manifest must stay FULL on a delta push"
PYEOF
[ $? -eq 0 ] && ok "a4 delta-by-sha, manifest stays full" || fail "a4 delta wrong"

echo "── a5: fail-open — network error → rc 0, state preserved, retried next run ──"
printf '# map v2\n' > "$MS/codebase/codebase-map.md"
echo 000 > "$LOG/next-response"; echo 0 > "$LOG/count"
OUT=$(run); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'queued for retry' && ok "a5 rc 0 + queued message" || fail "a5 rc=$RC out=$OUT"
echo 200 > "$LOG/next-response"
run >/dev/null
"$PY" -c '
import tarfile,sys
assert "codebase/codebase-map.md" in tarfile.open("'"$LOG"'/last-body.tgz").getnames()
' && ok "a5b failed delta retried on next trigger" || fail "a5b retry lost"

echo "── a6: 401 → mega-code login hint, rc 0 ──"
printf '# idx v2\n' > "$MS/vaults/app/00-index.md"
echo 401 > "$LOG/next-response"
OUT=$(run); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'mega-code login' && ok "a6 401 handled with hint" || fail "a6 rc=$RC out=$OUT"

echo "── a7: token never leaks to stdout/stderr or state ──"
echo 200 > "$LOG/next-response"
OUT=$(run)
echo "$OUT" | grep -q 'sekrit-tok-123' && fail "a7 token in output" || ok "a7 token absent from output"
grep -q 'sekrit-tok-123' "$MS/.publish-state.json" && fail "a7b token in state" || ok "a7b token absent from state"

echo "── a8: missing[] response → paths evicted, resent next push ──"
printf '# map v3\n' > "$MS/codebase/codebase-map.md"
printf '{"missing":["graph.json"]}' > "$LOG/next-body"; echo 200 > "$LOG/next-response"
run >/dev/null
rm -f "$LOG/next-body"; echo 200 > "$LOG/next-response"
printf '# idx v3\n' > "$MS/vaults/app/00-index.md"
run >/dev/null
"$PY" -c '
import tarfile
names = tarfile.open("'"$LOG"'/last-body.tgz").getnames()
assert "graph.json" in names, names   # evicted by missing[] → resent
' && ok "a8 self-heal eviction resends missing path" || fail "a8 missing[] ignored"

echo "── h1: stop-hook wiring (guarded, fail-open, unconditional-safe) ──"
H="$ROOT/plugins/mega-sdd/hooks/stop"
grep -q 'publish-artifacts.sh' "$H" && ok "h1 stop hook invokes publisher" || fail "h1 not wired"
grep -A2 'PUBLISH_SCRIPT"' "$H" | grep -q '|| true' && ok "h1b invocation is || true" || fail "h1b not fail-open at hook"

echo "── r1 (round M2): token NEVER in curl argv ──"
grep -q 'sekrit-tok-123' "$LOG/last-argv" && fail "r1 token visible in argv (ps-leak)" || ok "r1 token absent from curl argv"
grep -q '^-H$' "$LOG/last-argv" && grep -q '^@' "$LOG/last-argv" && ok "r1b header passed via @file" || fail "r1b no header-file mechanism"

echo "── r2 (round M1): config.yaml probe scoped to publish: block ──"
P2="$TMP/proj2"; MS2="$P2/.mega-sdd"
mkdir -p "$MS2/vaults/app"
printf '# i\n' > "$MS2/vaults/app/00-index.md"
( cd "$P2" && git init -q && git config user.email t@t && git config user.name t && git add -A && git commit -qm i )
cat > "$MS2/config.yaml" <<'YAML'
context7:
  token: "DECOY-OTHER-SERVICE"
publish:
  gateway_url: "https://gw2.test"
  token: "right-tok"
telemetry: true
YAML
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"
clean HOME="$HOMELESS" USERPROFILE="$HOMELESS" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
grep -q 'DECOY-OTHER-SERVICE' "$LOG/last-argv" "$LOG"/last-body.tgz 2>/dev/null && fail "r2 decoy token leaked" || ok "r2 decoy token never used"
[ "$(cat "$LOG/count")" = "1" ] && ok "r2b publish-block creds worked (1 push)" || fail "r2b config path dead: count=$(cat "$LOG/count")"

echo "── r3 (round M3): project_id normalization (creds/port/scp/remote-less) ──"
norm() { ( cd "$P2" && git remote remove origin 2>/dev/null; git remote add origin "$1" )
  echo 200 > "$LOG/next-response"
  printf 'x%s\n' "$RANDOM" >> "$MS2/vaults/app/00-index.md"
  clean HOME="$HOMELESS" USERPROFILE="$HOMELESS" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
  "$PY" -c 'import tarfile,json,sys;print(json.load(tarfile.open("'"$LOG"'/last-body.tgz").extractfile("manifest.json"))["project_id"])'
}
[ "$(norm 'https://user:s3cret@scm.bankmegadev.com/grup/repo.git')" = "scm.bankmegadev.com/grup/repo" ] && ok "r3a creds stripped" || fail "r3a creds leaked into project_id"
[ "$(norm 'ssh://git@scm.bankmegadev.com:2222/grup/repo.git')" = "scm.bankmegadev.com/grup/repo" ] && ok "r3b ssh port dropped (identity unified)" || fail "r3b port split identity"
[ "$(norm 'git@scm.bankmegadev.com:grup/repo.git')" = "scm.bankmegadev.com/grup/repo" ] && ok "r3c scp-form normalized" || fail "r3c scp wrong"

echo "── r4 (round MINOR-5): over-cap bundle NOT sent ──"
printf 'y\n' >> "$MS2/vaults/app/00-index.md"
echo 0 > "$LOG/count"
OUT=$(clean HOME="$HOMELESS" USERPROFILE="$HOMELESS" PATH="$SHIM:$PATH" MEGA_SDD_PUBLISH_MAX_MB=0 bash "$SCRIPT" --cwd="$P2" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] && echo "$OUT" | grep -q 'NOT sent' \
  && ok "r4 cap pre-check blocks POST, rc 0" || fail "r4 rc=$RC count=$(cat "$LOG/count")"

echo "── r5 (round MINOR-6): symlinks never collected ──"
ln -s /etc/hosts "$MS2/vaults/app/leak.md" 2>/dev/null
echo 200 > "$LOG/next-response"
printf 'z\n' >> "$MS2/vaults/app/00-index.md"
clean HOME="$HOMELESS" USERPROFILE="$HOMELESS" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
"$PY" -c '
import tarfile,json
m=json.load(tarfile.open("'"$LOG"'/last-body.tgz").extractfile("manifest.json"))
assert "vaults/app/leak.md" not in m["files"]
' && ok "r5 symlink excluded from manifest+bundle" || fail "r5 symlink shipped"

echo "── f1 (v6.19.1): mega-code installed but session NOT managed → inert ──"
printf 'f1\n' >> "$MS/vaults/app/00-index.md"
echo 0 > "$LOG/count"
OUT=$(clean HOME="$HOME_PLAIN" USERPROFILE="$HOME_PLAIN" ANTHROPIC_BASE_URL="https://evil.test" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] \
  && ok "f1 vanilla session inert (binary on PATH alone never arms)" || fail "f1 rc=$RC count=$(cat "$LOG/count")"
# f1b: URL present in settings but apiKeyHelper is NOT mega-code → still inert
# (isolates the signature check from the URL checks)
echo 0 > "$LOG/count"
OUT=$(clean HOME="$HOME_OTHERHELPER" USERPROFILE="$HOME_OTHERHELPER" ANTHROPIC_BASE_URL="https://gw-other.test" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] \
  && ok "f1b non-mega-code apiKeyHelper → inert despite settings URL" || fail "f1b rc=$RC count=$(cat "$LOG/count")"

echo "── f2 (v6.19.1): mega-code-managed session (env matches settings) publishes ──"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"; rm -f "$LOG/next-body"
OUT=$(clean HOME="$HOME_OFF" USERPROFILE="$HOME_OFF" ANTHROPIC_BASE_URL="https://gw-office.test" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "1" ] && grep -q 'gw-office.test/mega-sdd/ingest' "$LOG/last-argv" \
  && ok "f2 office rung fires when session is routed through the gateway" || fail "f2 rc=$RC count=$(cat "$LOG/count")"
grep -q 'office-tok-999' "$LOG/last-argv" && fail "f2b office token in argv" || ok "f2b office token absent from argv"
# f2c (round MAJOR-2): signature present but process env ANTHROPIC_BASE_URL absent
# → session is NOT routed through the gateway right now → inert
printf 'f2c\n' >> "$MS/vaults/app/00-index.md"
echo 0 > "$LOG/count"
OUT=$(clean HOME="$HOME_OFF" USERPROFILE="$HOME_OFF" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] \
  && ok "f2c provisioned machine, unrouted session → inert" || fail "f2c rc=$RC count=$(cat "$LOG/count")"

echo "── f3 (v6.19.1 + round MAJOR-2): foreign env URL → inert, never a POST ──"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"
clean HOME="$HOME_OFF" USERPROFILE="$HOME_OFF" ANTHROPIC_BASE_URL="https://evil.test" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null >/dev/null 2>&1
[ "$(cat "$LOG/count")" = "0" ] && ok "f3 env≠settings → office rung disarmed (zero POST)" || fail "f3 count=$(cat "$LOG/count")"
grep -q 'evil.test' "$LOG/last-argv" && fail "f3b token redirected to foreign URL" || ok "f3b foreign URL never in argv"

echo "── f4 (v6.19.1): signature without usable settings URL → office rung disarmed ──"
printf 'f4\n' >> "$MS/vaults/app/00-index.md"
echo 0 > "$LOG/count"
OUT=$(clean HOME="$HOME_NOURL" USERPROFILE="$HOME_NOURL" ANTHROPIC_BASE_URL="https://evil.test" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] \
  && ok "f4 no settings URL → inert (env never substitutes)" || fail "f4 rc=$RC count=$(cat "$LOG/count")"
# f4b (round MINOR-4): settings URL without an http(s) scheme → disarmed
echo 0 > "$LOG/count"
OUT=$(clean HOME="$HOME_NOSCHEME" USERPROFILE="$HOME_NOSCHEME" ANTHROPIC_BASE_URL="gw-noscheme.test" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] \
  && ok "f4b scheme-less settings URL → inert" || fail "f4b rc=$RC count=$(cat "$LOG/count")"

echo "── f5 (v6.19.1): unarmed office probe falls through to config.yaml ──"
printf 'f5\n' >> "$MS2/vaults/app/00-index.md"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"
clean HOME="$HOME_PLAIN" USERPROFILE="$HOME_PLAIN" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
[ "$(cat "$LOG/count")" = "1" ] && grep -q 'gw2.test' "$LOG/last-argv" \
  && ok "f5 config rung reachable past installed-but-inactive mega-code" || fail "f5 count=$(cat "$LOG/count")"
# f5b (round MINOR-4): signature present but settings URL missing → STILL falls
# through to config.yaml (armed-but-unsatisfied probe never dead-ends)
printf 'f5b\n' >> "$MS2/vaults/app/00-index.md"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"
clean HOME="$HOME_NOURL" USERPROFILE="$HOME_NOURL" PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
[ "$(cat "$LOG/count")" = "1" ] && grep -q 'gw2.test' "$LOG/last-argv" \
  && ok "f5b signature-without-URL falls through to config rung" || fail "f5b count=$(cat "$LOG/count")"

# ── w-arms: the REAL office settings.json shape (evidence, 2026-08-21) ───────
# A live office laptop writes apiKeyHelper as a QUOTED ABSOLUTE PATH ending in
# `.cmd`, and an http:// (not https) gateway URL:
#   "apiKeyHelper": "\"C:\\Users\\x\\AppData\\Roaming\\npm\\mega-code.cmd\" get-token"
#   "env": { "ANTHROPIC_BASE_URL": "http://10.202.171.20:8001" }
# Both must arm the office rung, and the token must be minted through THAT path
# (not a bare `mega-code` that may not exist under this name on Windows).
cat > "$SHIM/mega-code.cmd" <<'EOF'
#!/bin/bash
[ "$1" = "get-token" ] && { echo "office-tok-cmd-777"; exit 0; }
exit 1
EOF
chmod +x "$SHIM/mega-code.cmd"
HOME_WIN="$TMP/home-win"; mkdir -p "$HOME_WIN/.claude"
"$PY" - "$HOME_WIN/.claude/settings.json" "$SHIM/mega-code.cmd" <<'PYEOF'
import json, sys
json.dump({"apiKeyHelper": '"%s" get-token' % sys.argv[2],
           "env": {"ANTHROPIC_BASE_URL": "http://10.202.171.20:8001"}},
          open(sys.argv[1], "w"))
PYEOF
P5="$TMP/proj5"; MS5="$P5/.mega-sdd"
mkdir -p "$MS5/vaults/app"
printf '# idx\n' > "$MS5/vaults/app/00-index.md"
printf '{"v":1}\n' > "$MS5/vaults/app/vault.json"
( cd "$P5" && git init -q && git config user.email t@t && git config user.name t \
  && git remote add origin https://scm.bankmegadev.com/grup/winrepo.git \
  && git add -A && git commit -qm init )

echo "── w1: quoted-absolute .cmd helper + http URL arms the office rung ──"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"
clean HOME="$HOME_WIN" USERPROFILE="$HOME_WIN" ANTHROPIC_BASE_URL="http://10.202.171.20:8001" \
  PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P5" </dev/null >/dev/null 2>&1
[ "$(cat "$LOG/count")" = "1" ] && grep -q '10.202.171.20:8001/mega-sdd/ingest' "$LOG/last-argv" \
  && ok "w1 office rung armed from the real settings shape" || fail "w1 count=$(cat "$LOG/count")"

echo "── w2: token minted via the settings helper path, never in argv ──"
grep -q 'office-tok-cmd-777' "$LOG/last-argv" && fail "w2 token leaked into argv" \
  || ok "w2 token never in curl argv"
HDR=$(grep -m1 '^@' "$LOG/last-argv" 2>/dev/null || true)
[ -n "$HDR" ] && ok "w2b bearer passed via @header-file" || ok "w2b bearer not inline in argv"

echo "── w3: same laptop, session NOT routed there (env absent) → inert ──"
echo 0 > "$LOG/count"
printf 'w3\n' >> "$MS5/vaults/app/00-index.md"
clean HOME="$HOME_WIN" USERPROFILE="$HOME_WIN" PATH="$SHIM:$PATH" \
  bash "$SCRIPT" --cwd="$P5" </dev/null >/dev/null 2>&1
[ "$(cat "$LOG/count")" = "0" ] && ok "w3 managed-machine, unmanaged session → zero POST" \
  || fail "w3 pushed from an unrouted session"

# ── c-arms: v6.20.0 scan-stage projects publish under the `_codebase` sentinel ─
# A project at scan stage has no vaults/ but DOES carry a code layer (graph.json
# symbols + codebase-map). Before v6.20.0 the script exited on `not vaults` and
# that knowledge never left the laptop.
P3="$TMP/proj3"; MS3="$P3/.mega-sdd"
mkdir -p "$MS3/codebase" "$P3/src"
printf '{"nodes":[{"id":"sym:a.php#f","type":"symbol"}],"edges":[],"_meta":{"source_hashes":{"c.md":"z1"}}}\n' > "$MS3/graph.json"
printf '# map\n' > "$MS3/codebase/codebase-map.md"
printf 'reuse_index:\n  helpers: []\n' > "$MS3/codebase/reuse-index.yaml"
( cd "$P3" && git init -q && git config user.email t@t && git config user.name t \
  && git remote add origin https://scm.bankmegadev.com/grup/scanonly.git \
  && git add -A && git commit -qm init )

echo "── c1: vault-less project publishes under the _codebase sentinel ──"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"; rm -f "$LOG/next-body"
clean PATH="$SHIM:$PATH" MEGA_SDD_PUBLISH_URL=https://gw.test MEGA_SDD_PUBLISH_TOKEN=tok3 \
  bash "$SCRIPT" --cwd="$P3" </dev/null >/dev/null 2>&1
RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "1" ] \
  && ok "c1 scan-only project pushed once (rc=$RC)" || fail "c1 rc=$RC count=$(cat "$LOG/count")"

echo "── c2: manifest vault + SHARED-only payload, reuse-index NOT shipped ──"
"$PY" - "$LOG/last-body.tgz" <<'PYEOF'
import tarfile, json, sys
tar = tarfile.open(sys.argv[1]); names = tar.getnames()
assert names[0] == "manifest.json", names
m = json.load(tar.extractfile("manifest.json"))
assert m["vault"] == "_codebase", m["vault"]
assert m["project_id"] == "scm.bankmegadev.com/grup/scanonly", m["project_id"]
assert "graph.json" in m["files"] and "codebase/codebase-map.md" in m["files"], m["files"]
assert not any(p.startswith("vaults/") for p in m["files"]), m["files"]
# the graph carries the derived symbol nodes; shipping the yaml too would give
# the gateway indexer a second source of truth for the same facts
assert not any("reuse-index" in p for p in m["files"]), m["files"]
assert not any("reuse-index" in n for n in names), names
PYEOF
[ $? -eq 0 ] && ok "c2 _codebase manifest = SHARED only, reuse-index excluded" || fail "c2 bundle wrong"

echo "── c3: nothing publishable → zero POST (no empty sentinel push) ──"
P4="$TMP/proj4"; mkdir -p "$P4/.mega-sdd"
( cd "$P4" && git init -q && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m i )
echo 0 > "$LOG/count"
clean PATH="$SHIM:$PATH" MEGA_SDD_PUBLISH_URL=https://gw.test MEGA_SDD_PUBLISH_TOKEN=tok4 \
  bash "$SCRIPT" --cwd="$P4" </dev/null >/dev/null 2>&1
[ "$(cat "$LOG/count")" = "0" ] && ok "c3 empty .mega-sdd → no push" || fail "c3 pushed nothing-bundle"

echo "── c4: a vault-bearing project never emits a _codebase push ──"
printf 'c4\n' >> "$MS/vaults/app/00-index.md"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"
run >/dev/null
"$PY" - "$LOG/last-body.tgz" <<'PYEOF'
import tarfile, json, sys
m = json.load(tarfile.open(sys.argv[1]).extractfile("manifest.json"))
assert m["vault"] == "app", m["vault"]
PYEOF
[ $? -eq 0 ] && [ "$(cat "$LOG/count")" = "1" ] \
  && ok "c4 normal vault path unchanged (vault=app, one push)" || fail "c4 vault path regressed"

echo
echo "publish-artifacts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
