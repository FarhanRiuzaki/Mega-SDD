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
run() { PATH="$SHIM:$PATH" MEGA_SDD_PUBLISH_URL="${U:-https://gw.test}" MEGA_SDD_PUBLISH_TOKEN="${T:-sekrit-tok-123}" \
        bash "$SCRIPT" --cwd="$P" </dev/null 2>&1; }

echo "── a1: inert without credentials (no curl, rc 0) ──"
: > "$LOG/count"; echo 0 > "$LOG/count"
OUT=$(PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] && [ ! -f "$MS/.publish-state.json" ] \
  && ok "a1 inert: rc 0, zero curl, no state" || fail "a1 rc=$RC count=$(cat "$LOG/count")"

echo "── a2: first push — manifest first entry, fields correct, full delta ──"
echo 200 > "$LOG/next-response"; echo 0 > "$LOG/count"; rm -f "$LOG/next-body"
OUT=$(run); RC=$?
[ "$RC" -eq 0 ] || fail "a2 rc=$RC"
"$PY" - "$LOG/last-body.tgz" "$HEAD" <<'PYEOF'
import tarfile, json, sys
tar = tarfile.open(sys.argv[1])
names = tar.getnames()
assert names[0] == "manifest.json", names
m = json.load(tar.extractfile("manifest.json"))
assert m["schema"] == "mega-sdd-publish/1", m
assert m["project_id"] == "scm.bankmegadev.com/grup/repo", m["project_id"]
assert m["vault"] == "app" and m["git_head"] == sys.argv[2], m
assert m["work_dir"] == "proj", m
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
PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
grep -q 'DECOY-OTHER-SERVICE' "$LOG/last-argv" "$LOG"/last-body.tgz 2>/dev/null && fail "r2 decoy token leaked" || ok "r2 decoy token never used"
[ "$(cat "$LOG/count")" = "1" ] && ok "r2b publish-block creds worked (1 push)" || fail "r2b config path dead: count=$(cat "$LOG/count")"

echo "── r3 (round M3): project_id normalization (creds/port/scp/remote-less) ──"
norm() { ( cd "$P2" && git remote remove origin 2>/dev/null; git remote add origin "$1" )
  echo 200 > "$LOG/next-response"
  printf 'x%s\n' "$RANDOM" >> "$MS2/vaults/app/00-index.md"
  PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
  "$PY" -c 'import tarfile,json,sys;print(json.load(tarfile.open("'"$LOG"'/last-body.tgz").extractfile("manifest.json"))["project_id"])'
}
[ "$(norm 'https://user:s3cret@scm.bankmegadev.com/grup/repo.git')" = "scm.bankmegadev.com/grup/repo" ] && ok "r3a creds stripped" || fail "r3a creds leaked into project_id"
[ "$(norm 'ssh://git@scm.bankmegadev.com:2222/grup/repo.git')" = "scm.bankmegadev.com/grup/repo" ] && ok "r3b ssh port dropped (identity unified)" || fail "r3b port split identity"
[ "$(norm 'git@scm.bankmegadev.com:grup/repo.git')" = "scm.bankmegadev.com/grup/repo" ] && ok "r3c scp-form normalized" || fail "r3c scp wrong"

echo "── r4 (round MINOR-5): over-cap bundle NOT sent ──"
printf 'y\n' >> "$MS2/vaults/app/00-index.md"
echo 0 > "$LOG/count"
OUT=$(PATH="$SHIM:$PATH" MEGA_SDD_PUBLISH_MAX_MB=0 bash "$SCRIPT" --cwd="$P2" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && [ "$(cat "$LOG/count")" = "0" ] && echo "$OUT" | grep -q 'NOT sent' \
  && ok "r4 cap pre-check blocks POST, rc 0" || fail "r4 rc=$RC count=$(cat "$LOG/count")"

echo "── r5 (round MINOR-6): symlinks never collected ──"
ln -s /etc/hosts "$MS2/vaults/app/leak.md" 2>/dev/null
echo 200 > "$LOG/next-response"
printf 'z\n' >> "$MS2/vaults/app/00-index.md"
PATH="$SHIM:$PATH" bash "$SCRIPT" --cwd="$P2" </dev/null >/dev/null 2>&1
"$PY" -c '
import tarfile,json
m=json.load(tarfile.open("'"$LOG"'/last-body.tgz").extractfile("manifest.json"))
assert "vaults/app/leak.md" not in m["files"]
' && ok "r5 symlink excluded from manifest+bundle" || fail "r5 symlink shipped"

echo
echo "publish-artifacts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
