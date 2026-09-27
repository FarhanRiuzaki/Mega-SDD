#!/usr/bin/env bash
# Fixture test for the vanilla-vs-mega-sdd harness (benchmarks/runbooks/vanilla-vs-megasdd.md):
#   arm-purity.py   — a vanilla arm with ANY mega-sdd surface in its init record FAILS; a
#                     mega-sdd arm without the plugin FAILS; no init record = UNREADABLE (exit 2)
#   arm-metrics.py  — cumulative result counters counted once per process, summed across
#                     --resume processes (marked not clean); tool calls / asks / reads counted
#   compare-arms.py — below min_clean_runs → INSUFFICIENT (never a verdict); non-overlapping
#                     ranges → BETTER/WORSE; overlapping → OVERLAP; unmeasured → "belum diukur"
#   p0-headless-run.sh — rejects an unknown P0_ARM and a front-door flag on the vanilla arm
# Pure file fixtures; no claude process is launched.
set -u
err=0
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/benchmarks/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*"; err=1; }

init() { # init <plugins-json> <skills-json>
  printf '{"type":"system","subtype":"init","session_id":"aaaaaaaa-1","plugins":%s,"skills":%s,"slash_commands":[],"agents":[]}\n' "$1" "$2"
}
# run <dir> <cost> <input> <output> <processes> <start-min> <end-min>
run() {
  local d="$1"; mkdir -p "$d"
  { init '[{"name":"superpowers","version":"6.4.1","source":"superpowers@x"}]' '["superpowers:brainstorming"]'
    printf '{"type":"assistant","session_id":"aaaaaaaa-1","timestamp":"2026-09-26T10:%02d:00Z","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/a"}},{"type":"tool_use","name":"Read","input":{"file_path":"/a"}},{"type":"tool_use","name":"AskUserQuestion","input":{}},{"type":"tool_use","name":"Agent","input":{}}]}}\n' "$6"
    printf '{"type":"assistant","session_id":"aaaaaaaa-1","timestamp":"2026-09-26T10:%02d:00Z","message":{"content":[]}}\n' "$7"
    local k=0; while [ $k -lt "$5" ]; do
      printf '{"type":"result","total_cost_usd":%s,"duration_ms":60000,"duration_api_ms":30000,"modelUsage":{"m":{"inputTokens":%s,"outputTokens":%s,"cacheReadInputTokens":10,"cacheCreationInputTokens":5}}}\n' "$2" "$3" "$4"
      k=$((k+1)); done
  } > "$d/stream.jsonl"
  printf 'sid=aaaaaaaa-1\narm_kind=vanilla\nmodel=opus\n' > "$d/run.meta"
  printf 'abc123 2026-09-26T10:%02d:30Z feat: x\n' "$7" > "$d/git-log.txt"
}

# --- arm-purity ---
init '[{"name":"mega-sdd","version":"8.8.1","source":"mega-sdd@mega-sdd"}]' '["mega-sdd:plan"]' > "$T/mega.jsonl"
init '[{"name":"superpowers","version":"6.4.1","source":"superpowers@x"}]' '[]' > "$T/plain.jsonl"
init '[]' '["mega-sdd"]' > "$T/wrapper.jsonl"
echo '{"type":"result"}' > "$T/noinit.jsonl"
python3 "$S/arm-purity.py" "$T/plain.jsonl" vanilla >/dev/null || fail "purity: plain roster must PASS vanilla"
python3 "$S/arm-purity.py" "$T/mega.jsonl" vanilla >/dev/null && fail "purity: mega-sdd plugin must FAIL vanilla"
python3 "$S/arm-purity.py" "$T/wrapper.jsonl" vanilla >/dev/null && fail "purity: user-level /mega-sdd wrapper skill must FAIL vanilla"
python3 "$S/arm-purity.py" "$T/mega.jsonl" megasdd >/dev/null || fail "purity: mega-sdd plugin must PASS megasdd"
python3 "$S/arm-purity.py" "$T/plain.jsonl" megasdd >/dev/null && fail "purity: no plugin must FAIL megasdd"
python3 "$S/arm-purity.py" "$T/noinit.jsonl" vanilla >/dev/null; [ $? -eq 2 ] || fail "purity: missing init must exit 2 (UNREADABLE)"

# --- arm-metrics ---
run "$T/v1" 10 100 50 1 0 30
python3 "$S/arm-metrics.py" "$T/v1" --json "$T/v1.json" >/dev/null || fail "metrics: exit"
python3 - "$T/v1.json" <<'EOF' || err=1
import json, sys
d = json.load(open(sys.argv[1]))
checks = [
    (d['speed']['wall_min'] == 30.0, 'wall 30 min'),
    (d['speed']['review_ready_min'] == 30.5, 'review-ready = last commit 30.5 min'),
    (d['tokens']['total'] == 165 and d['tokens']['cost_usd'] == 10, 'token + cost sums'),
    (d['light']['ask_attempts'] == 1 and d['light']['subagent_dispatches'] == 1, 'ask + agent counts'),
    (d['light']['distinct_files_read'] == 1, 'distinct reads'),
    (d['clean']['is_clean'] is True, 'single process is clean'),
]
bad = [m for ok, m in checks if not ok]
if bad:
    print('FAIL: metrics:', bad); sys.exit(1)
EOF
# Cumulative counters: two turn completions of ONE process repeat the running total (count once);
# a --resume starts a new process whose counters restart lower (sum across processes).
run "$T/wake" 10 100 50 2 0 30
python3 "$S/arm-metrics.py" "$T/wake" --json "$T/wake.json" >/dev/null
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (d['clean']['is_clean'] and d['tokens']['cost_usd']==10 and d['tokens']['total']==165) else 1)" "$T/wake.json" \
  || fail "metrics: a repeated cumulative result (same process) must count once and stay clean"
# An empty completion record mid-process (cost unchanged, api 0) must not split the process.
run "$T/empty" 10 100 50 1 0 30
printf '{"type":"result","total_cost_usd":10,"duration_ms":0,"duration_api_ms":0,"num_turns":0,"modelUsage":{}}\n' >> "$T/empty/stream.jsonl"
printf '{"type":"result","total_cost_usd":10,"duration_ms":1000,"duration_api_ms":30000,"modelUsage":{"m":{"inputTokens":100,"outputTokens":50,"cacheReadInputTokens":10,"cacheCreationInputTokens":5}}}\n' >> "$T/empty/stream.jsonl"
python3 "$S/arm-metrics.py" "$T/empty" --json "$T/empty.json" >/dev/null
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (d['clean']['processes']==1 and d['tokens']['cost_usd']==10) else 1)" "$T/empty.json" \
  || fail "metrics: an empty mid-process result record must not start a new process (double count)"
run "$T/resumed" 10 100 50 1 0 30
printf '{"type":"result","total_cost_usd":4,"duration_ms":60000,"duration_api_ms":1000,"modelUsage":{"m":{"inputTokens":7,"outputTokens":3,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}}\n' >> "$T/resumed/stream.jsonl"
python3 "$S/arm-metrics.py" "$T/resumed" --json "$T/resumed.json" >/dev/null
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (not d['clean']['is_clean'] and d['tokens']['cost_usd']==14 and d['tokens']['total']==175 and d['clean']['processes']==2) else 1)" "$T/resumed.json" \
  || fail "metrics: a resumed run (counter reset) must sum both processes and be NOT clean"

# --- compare-arms ---
for i in 1 2 3; do
  run "$T/van$i" $((10 + i)) 100 50 1 0 $((30 + i)); python3 "$S/arm-metrics.py" "$T/van$i" --json "$T/van$i.json" >/dev/null
  run "$T/sdd$i" $((40 + i)) 900 90 1 0 $((50 + i)); python3 "$S/arm-metrics.py" "$T/sdd$i" --json "$T/sdd$i.json" >/dev/null
done
cat > "$T/man.json" <<EOF
{"min_clean_runs": 3, "targets": {"xs": {"review_ready_min": 60}},
 "runs": [
  {"scenario":"xs","arm":"vanilla","run":"v1","metrics":"$T/van1.json"},
  {"scenario":"xs","arm":"vanilla","run":"v2","metrics":"$T/van2.json"},
  {"scenario":"xs","arm":"vanilla","run":"v3","metrics":"$T/van3.json"},
  {"scenario":"xs","arm":"lite","run":"s1","metrics":"$T/sdd1.json"},
  {"scenario":"xs","arm":"lite","run":"s2","metrics":"$T/sdd2.json"},
  {"scenario":"xs","arm":"lite","run":"s3","metrics":"$T/sdd3.json"},
  {"scenario":"clinic","arm":"vanilla","run":"v1","metrics":"$T/van1.json"},
  {"scenario":"clinic","arm":"lite","run":"s1","metrics":"$T/sdd1.json"}]}
EOF
python3 "$S/compare-arms.py" "$T/man.json" --json "$T/cmp.json" > "$T/cmp.md" || fail "compare: exit"
python3 - "$T/cmp.json" <<'EOF' || err=1
import json, sys
d = json.load(open(sys.argv[1]))
xs, cl = d['xs']['verdicts'], d['clinic']['verdicts']
checks = [
    (xs['cost_usd'] == ['lite: WORSE'], 'cost: every lite run above every vanilla run -> WORSE'),
    (xs['review_ready_min'] == ['lite: WORSE'], 'time WORSE'),
    (xs['ask_attempts'] == ['lite: OVERLAP'], 'identical asks -> OVERLAP'),
    (xs['rubric'] == ['lite: INSUFFICIENT'], 'no quality file -> INSUFFICIENT'),
    (cl['cost_usd'] == ['lite: INSUFFICIENT'], 'n=1 per arm -> INSUFFICIENT'),
]
bad = [m for ok, m in checks if not ok]
if bad:
    print('FAIL: compare:', bad); sys.exit(1)
EOF
grep -q 'belum diukur' "$T/cmp.md" || fail "compare: unmeasured cells must read 'belum diukur'"
grep -q 'review_ready_min ≤ 60 | PASS' "$T/cmp.md" || fail "compare: absolute target row missing"

# --- launcher argument guards (exit 2 before any claude call) ---
mkdir -p "$T/arm/.git"; echo x > "$T/arm/prd.md"
P0_ARM=bogus bash "$S/p0-headless-run.sh" "$T/arm" prd.md "$T/log" >/dev/null 2>&1; [ $? -eq 2 ] || fail "launcher: unknown P0_ARM must exit 2"
P0_ARM=vanilla P0_FLAGS=--lite bash "$S/p0-headless-run.sh" "$T/arm" prd.md "$T/log" >/dev/null 2>&1; [ $? -eq 2 ] || fail "launcher: --lite on vanilla must exit 2"
P0_ENTRY=bogus bash "$S/p0-headless-run.sh" "$T/arm" prd.md "$T/log" >/dev/null 2>&1; [ $? -eq 2 ] || fail "launcher: unknown P0_ENTRY must exit 2"

# --- launcher end-to-end with a stub `claude` on PATH (relative $0, as the runbook invokes it) ---
mkdir -p "$T/bin" "$T/arm2"
cat > "$T/bin/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = plugin ]; then echo "  ❯ mega-sdd@mega-sdd"; echo "    Version: 0.0.0"; exit 0; fi
printf '%s\n' "$@" > "$STUB_ARGS"
echo '{"type":"system","subtype":"init","session_id":"x","plugins":[{"name":"superpowers","version":"1"}],"skills":[],"slash_commands":[],"agents":[]}'
EOF
chmod +x "$T/bin/claude"
( cd "$T/arm2" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init ) && echo x > "$T/arm2/prd.md"
for kind in vanilla megasdd; do
  ( cd "$ROOT" && STUB_ARGS="$T/args-$kind" PATH="$T/bin:$PATH" P0_ARM=$kind \
      bash benchmarks/scripts/p0-headless-run.sh "$T/arm2" prd.md "$T/log-$kind" >/dev/null 2>&1 )
done
( cd "$ROOT" && STUB_ARGS="$T/args-frontdoor" PATH="$T/bin:$PATH" P0_ARM=megasdd P0_ENTRY=frontdoor \
    bash benchmarks/scripts/p0-headless-run.sh "$T/arm2" prd.md "$T/log-frontdoor" >/dev/null 2>&1 )
sleep 1
grep -qx -- '/mega-sdd:mega-sdd prd.md' "$T/args-frontdoor" || fail "launcher: P0_ENTRY=frontdoor must prompt the front door with the PRD and nothing else"
grep -q 'analyze' "$T/args-frontdoor" && fail "launcher: the frontdoor entry must not prescribe an analyze pass"
grep -q '^entry=frontdoor' "$T/log-frontdoor/run.meta" || fail "launcher: entry= must be recorded in run.meta"
grep -q '^purity=PASS' "$T/log-vanilla/run.meta" || fail "launcher: vanilla arm with a plugin-free roster must record purity=PASS"
grep -qx -- '--settings' "$T/args-vanilla" || fail "launcher: vanilla arm must pass --settings (plugins disabled)"
grep -qx -- '--settings' "$T/args-megasdd" && fail "launcher: mega-sdd arm must launch exactly as before (no --settings)"
grep -q '^purity=FAIL' "$T/log-megasdd/run.meta" || fail "launcher: mega-sdd arm without the plugin must record purity=FAIL"

[ $err -eq 0 ] && echo "PASS: vanilla-arm harness (purity, metrics, compare, launcher guards)"
exit $err
