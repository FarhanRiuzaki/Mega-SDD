#!/usr/bin/env bash
# delivery-check.sh — the reviewer's-eye check at the END of a run, every lane
# (direct / assisted / guarded). Deterministic, zero model tokens, one call.
#
# Why it exists (benchmarks/results/vanilla-ab, commits cf8d3df3 + d447a6d2 —
# defects found by hand in the delivered repos, never
# by the pipeline's own gates, because every gate ran inside the working tree
# with the agent's local state):
#   - all 6 xs mega-sdd runs: tests existed and passed via `node --test`, but
#     package.json had no `test` script → `npm test` failed for a reviewer;
#   - all 6 xs mega-sdd runs: the "Tentang Kami" page existed but no page
#     linked to it (unreachable without typing the URL);
#   - clinic lite-2 / lite-4: `npm run build` failed on a fresh checkout (no
#     untracked .env) while prerendering pages;
#   - clinic lite-2: 1/220 tests passed only when the host TZ was UTC.
#
# What it does, against a FRESH copy of HEAD (git archive — untracked files,
# local .env*, build caches are NOT there; node_modules is cloned in so no
# network is needed):
#   D1 test_script   package.json has a real `scripts.test`       BLOCKING
#   D2 tests         `npm test` passes under TZ=UTC                BLOCKING
#   D3 tests_tz      `npm test` passes under TZ=Pacific/Kiritimati BLOCKING
#                    (UTC+14: a date-boundary bug cannot hide there)
#   D4 build         `npm run build` passes with a scrubbed env     BLOCKING
#                    (env -i: PATH/HOME/TZ/CI only — no secrets)
#   D5 routes        Next.js app-router pages that no other source  ADVISORY
#                    file links to (href/redirect/push string)
# Only D1–D4 block. A stack without package.json at HEAD → SKIP (exit 0, one
# line saying so) — the check never guesses another toolchain.
#
# Usage: delivery-check.sh [--cwd=<repo>] [--json=<out.json>] [--no-build]
#                          [--no-tests] [--keep]
# Exit: 0 = no blocking failure (incl. SKIP) · 1 = ≥1 blocking failure
#       2 = usage / not a git repo / HEAD unreadable
set -u
CWD="$PWD"; JSON=""; NO_BUILD=0; NO_TESTS=0; KEEP=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}";;
  --json=*) JSON="${arg#*=}";;
  --no-build) NO_BUILD=1;;
  --no-tests) NO_TESTS=1;;
  --keep) KEEP=1;;
  -h|--help) sed -n '2,36p' "$0"; exit 0;;
  *) echo "delivery-check: unknown arg $arg" >&2; exit 2;;
esac; done

git -C "$CWD" rev-parse --verify -q HEAD >/dev/null 2>&1 || { echo "delivery-check: $CWD is not a git repo with a HEAD" >&2; exit 2; }
ROOT="$(git -C "$CWD" rev-parse --show-toplevel)"
HEAD_SHA="$(git -C "$ROOT" rev-parse --short HEAD)"
RES="$(mktemp -d "${TMPDIR:-/tmp}/delivery-check.XXXXXX")"
printf '' > "$RES/rows"
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RES/rows"; }  # id status blocking detail

if ! git -C "$ROOT" cat-file -e HEAD:package.json 2>/dev/null; then
  row D0 SKIP no "no package.json at HEAD — node delivery checks not applicable"
else
  COPY="$RES/head"; mkdir -p "$COPY"
  git -C "$ROOT" archive HEAD | tar -x -C "$COPY" || { echo "delivery-check: git archive failed" >&2; exit 2; }
  if [ -d "$ROOT/node_modules" ]; then
    # APFS clone (macOS) → reflink (GNU) → plain copy. A symlink is not used:
    # some bundlers refuse a node_modules that resolves outside the project root.
    cp -Rc "$ROOT/node_modules" "$COPY/node_modules" 2>/dev/null \
      || cp -R --reflink=auto "$ROOT/node_modules" "$COPY/node_modules" 2>/dev/null \
      || cp -R "$ROOT/node_modules" "$COPY/node_modules"
  fi
  TEST_CMD="$(python3 -c 'import json,sys; print((json.load(open(sys.argv[1])).get("scripts") or {}).get("test",""))' "$COPY/package.json" 2>/dev/null)"
  BUILD_CMD="$(python3 -c 'import json,sys; print((json.load(open(sys.argv[1])).get("scripts") or {}).get("build",""))' "$COPY/package.json" 2>/dev/null)"

  if [ -z "$TEST_CMD" ] || printf '%s' "$TEST_CMD" | grep -q 'no test specified'; then
    row D1 FAIL yes "package.json has no real scripts.test — a reviewer's \`npm test\` fails; add the command the tests actually run with"
  else
    row D1 PASS yes "scripts.test = $TEST_CMD"
    if [ "$NO_TESTS" = 1 ]; then
      row D2 SKIP yes "--no-tests"; row D3 SKIP yes "--no-tests"
    else
      ( cd "$COPY" && env TZ=UTC CI=1 npm test > "$RES/test-utc.log" 2>&1 ); U=$?
      ( cd "$COPY" && env TZ=Pacific/Kiritimati CI=1 npm test > "$RES/test-tz.log" 2>&1 ); Z=$?
      if [ $U -eq 0 ]; then row D2 PASS yes "npm test (TZ=UTC) exit 0"
      else row D2 FAIL yes "npm test (TZ=UTC) exit $U — tail: $(tail -3 "$RES/test-utc.log" | tr '\n\t' '  ' | cut -c1-240)"; fi
      if [ $Z -eq 0 ]; then row D3 PASS yes "npm test (TZ=Pacific/Kiritimati) exit 0"
      elif [ $U -eq 0 ]; then row D3 FAIL yes "tests depend on the host timezone: pass under UTC, exit $Z under UTC+14 — pin the zone in the code or the test, never rely on the machine's — tail: $(tail -3 "$RES/test-tz.log" | tr '\n\t' '  ' | cut -c1-240)"
      else row D3 FAIL yes "npm test (TZ=Pacific/Kiritimati) exit $Z (also fails under UTC — see D2)"; fi
    fi
  fi

  if [ -z "$BUILD_CMD" ]; then
    row D4 SKIP yes "no scripts.build"
  elif [ "$NO_BUILD" = 1 ]; then
    row D4 SKIP yes "--no-build"
  else
    ( cd "$COPY" && env -i PATH="$PATH" HOME="$HOME" TZ=UTC CI=1 NEXT_TELEMETRY_DISABLED=1 npm run build > "$RES/build.log" 2>&1 ); B=$?
    if [ $B -eq 0 ]; then row D4 PASS yes "npm run build on a fresh checkout, empty env: exit 0"
    else row D4 FAIL yes "npm run build fails on a fresh checkout with an empty env (exit $B) — a missing secret must fail at request time with a clear message, not at import/prerender — tail: $(grep -i -E 'error|throw|missing' "$RES/build.log" | head -3 | tr '\n\t' '  ' | cut -c1-300)"; fi
  fi

  # D5 — advisory route reachability (Next.js app router only)
  python3 - "$COPY" >> "$RES/rows" <<'EOF'
import os, re, sys
root = sys.argv[1]
app = next((os.path.join(root, d) for d in ('src/app', 'app') if os.path.isdir(os.path.join(root, d))), None)
if not app:
    sys.exit(0)
routes = {}
for dp, dns, fns in os.walk(app):
    dns[:] = [d for d in dns if not d.startswith(('_', '@')) and d not in ('api', 'node_modules')]
    for f in fns:
        if re.fullmatch(r'page\.(t|j)sx?', f):
            rel = os.path.relpath(dp, app)
            segs = [] if rel == '.' else rel.split(os.sep)
            if any(s.startswith('[') for s in segs):
                continue                                  # dynamic: reached via a param, not a literal link
            segs = [s for s in segs if not (s.startswith('(') and s.endswith(')'))]
            routes['/' + '/'.join(segs)] = os.path.join(dp, f)
src = []
for base in ('src', 'app', 'components', 'lib'):
    b = os.path.join(root, base)
    for dp, dns, fns in os.walk(b):
        dns[:] = [d for d in dns if d not in ('node_modules', '.next')]
        src += [os.path.join(dp, f) for f in fns if re.search(r'\.(t|j)sx?$|\.mdx?$', f)]
src = sorted(set(src))
text = {p: open(p, encoding='utf-8', errors='replace').read() for p in src}
orphans = []
for r, own in sorted(routes.items()):
    if r == '/':
        continue
    pat = re.compile(r'''["'`]''' + re.escape(r) + r'''/?(?=["'`?#])''')
    if not any(pat.search(t) for p, t in text.items() if p != own):
        orphans.append(r)
if orphans:
    print('D5\tWARN\tno\t%d of %d page route(s) are linked from no other source file: %s — a user can only reach them by typing the URL'
          % (len(orphans), len(routes) - ('/' in routes), ', '.join(orphans)))
else:
    print('D5\tPASS\tno\tevery static page route (%d) is linked from another source file' % (len(routes) - ('/' in routes)))
EOF
fi

FAILS=$(awk -F'\t' '$2=="FAIL" && $3=="yes"' "$RES/rows" | wc -l | tr -d ' ')
echo "delivery-check @ $HEAD_SHA ($ROOT)"
awk -F'\t' '{printf "  %s %-4s %s\n", $1, $2, $4}' "$RES/rows"
if [ "$FAILS" -gt 0 ]; then echo "VERDICT: FAIL ($FAILS blocking)"; else echo "VERDICT: PASS"; fi
if [ -n "$JSON" ]; then
  python3 - "$RES/rows" "$JSON" "$HEAD_SHA" "$FAILS" <<'EOF'
import json, sys
rows = [l.rstrip('\n').split('\t', 3) for l in open(sys.argv[1]) if l.strip()]
json.dump({'head': sys.argv[3], 'verdict': 'FAIL' if int(sys.argv[4]) else 'PASS',
           'checks': [{'id': a, 'status': b, 'blocking': c == 'yes', 'detail': d} for a, b, c, d in rows]},
          open(sys.argv[2], 'w'), indent=1)
EOF
fi
[ "$KEEP" = 1 ] && echo "kept: $RES" || rm -rf "$RES"
[ "$FAILS" -gt 0 ] && exit 1 || exit 0
