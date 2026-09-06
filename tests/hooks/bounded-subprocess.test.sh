#!/usr/bin/env bash
# bounded-subprocess.test.sh
#
# One invariant: **no `subprocess.run` in a hook-reachable library may be
# unbounded.**
#
# Why this is a moat concern and not a tidiness one. `scripts/_lib/` is imported by
# the validators that hooks invoke, and `postflight_rules.py` in particular is
# RECOMPUTED at the execute-bolts gate — inside the BLOCKING PreToolUse hook. Its
# `ast-grep scan` is repo-wide. An unbounded child process there is the same failure
# shape as the 2026-07-28 Windows hang that started this whole line of work: work
# with no ceiling in a path Claude Code waits on. The 2026-07-30 install-deps
# regression was the same mistake in a different file — exec probes shipped with no
# timeout, which stalled an audit on a corporate laptop.
#
# The repo already had the right pattern (`state_probes.py` used `timeout=`); it
# simply was not applied consistently, which is exactly the kind of drift a
# mechanical check catches and prose does not.
#
# 2026-07-29 — WHY THIS FILE GREW A SECOND MATCHER. The check above globbed
# `scripts/_lib/*.py` and nothing else, so it stayed green for months while
# `scripts/run-preflight-scan.sh:225` ran a repo-wide `ast-grep scan` — the
# byte-identical twin of the call `postflight_rules.py` had already bounded — with
# no ceiling at all. The deterministic logic in this plugin is Python EMBEDDED IN
# SHELL HEREDOCS (`python3 <<'PYEOF'` inside `scripts/*.sh`), which no `*.py` glob
# can ever see. A matcher that cannot reach where the code actually lives is not a
# gate; it is decoration. The second matcher below extracts those heredocs and
# AST-parses them, so the invariant now covers the whole surface it claims.
#
# Corollary, and the reason the loud-skip path exists: a heredoc this extractor
# cannot parse is reported and FAILS the run. Silently under-scanning is the exact
# bug being fixed here — an unscanned block must never read as a green one.
#
# 2026-07-29 (same day, second pass) — AND THEN IT STILL COULD NOT SEE hooks/.
# The matcher above globbed `scripts/*.sh` + `scripts/_lib/*.sh`, so
# `plugins/mega-sdd/hooks/` — the single highest-risk surface in the plugin — was
# outside it entirely. Those are the BLOCKING `PreToolUse` / `SessionStart` /
# `UserPromptSubmit` hooks Claude Code synchronously waits on; an unbounded child
# there IS the 2026-07-28 Windows hang, not an analogue of it. And the six hook
# entry points are EXTENSIONLESS (`pre-tool-use`, `session-start`, …), so a `*.sh`
# glob can never reach them no matter which directory it is pointed at — the
# identical failure shape this header already condemns two paragraphs up, repeated
# one directory over. File enumeration is therefore BY CONTENT now (`*.sh`, or a
# first line that is a bash shebang), and a disk-equality assertion pins the
# enumerated set against what is actually in `hooks/` so a future ninth hook cannot
# be silently skipped.
#
# Note on what covers the `python3 -c '…'` INLINE form, which is most of the python
# in hooks/ (`post-tool-use` historically had 14 invocations and zero heredocs). Those bodies are
# NOT extracted — they are covered by the residual guard, which fails the run on any
# `subprocess.<attr>` sitting outside every extracted block. Coverage there is
# by-refusal, not by-parse. Do not read the green as "the -c bodies were scanned".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../../plugins/mega-sdd/scripts"
LIB="$SCRIPTS/_lib"
HOOKS="$HERE/../../plugins/mega-sdd/hooks"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

echo "── every subprocess.run in scripts/_lib must carry timeout= ──"
"$PY" - "$LIB" <<'PYEOF'
import ast, glob, os, sys

lib = sys.argv[1]
unbounded = []
total = 0
for path in sorted(glob.glob(os.path.join(lib, "*.py"))):
    tree = ast.parse(open(path, encoding="utf-8").read(), filename=path)
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        # match subprocess.run / subprocess.Popen / subprocess.check_output
        if not (isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name)
                and f.value.id == "subprocess"
                and f.attr in ("run", "Popen", "check_output", "call", "check_call")):
            continue
        total += 1
        if not any(k.arg == "timeout" for k in node.keywords):
            unbounded.append("%s:%d  subprocess.%s(...)" % (os.path.basename(path), node.lineno, f.attr))

print("  inspected %d subprocess call(s) across scripts/_lib/" % total)
if total == 0:
    print("  NOTHING INSPECTED — the AST matcher found no calls; this check is vacuous.")
    sys.exit(2)
if unbounded:
    for u in unbounded:
        print("  UNBOUNDED: %s" % u)
    sys.exit(1)
sys.exit(0)
PYEOF
st=$?
case "$st" in
  0) pass "all subprocess calls in scripts/_lib are bounded" ;;
  2) fail "matcher found zero calls — the check is vacuous, not green" ;;
  *) fail "unbounded subprocess call(s) in a hook-reachable library" ;;
esac

echo "── CONTROL: the matcher actually catches an unbounded call ──"
# Without this, a broken matcher would report green forever.
mkdir -p "$TMP/lib"
cat > "$TMP/lib/fake_mod.py" <<'PYEOF'
import subprocess
def bounded(cwd):
    return subprocess.run(["git", "status"], capture_output=True, timeout=5)
def unbounded(cwd):
    return subprocess.run(["ast-grep", "scan", cwd], capture_output=True)
PYEOF
out=$("$PY" - "$TMP/lib" <<'PYEOF'
import ast, glob, os, sys
lib = sys.argv[1]
bad = []
for path in sorted(glob.glob(os.path.join(lib, "*.py"))):
    tree = ast.parse(open(path, encoding="utf-8").read(), filename=path)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) \
           and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess" \
           and node.func.attr in ("run", "Popen", "check_output", "call", "check_call") \
           and not any(k.arg == "timeout" for k in node.keywords):
            bad.append("%s:%d" % (os.path.basename(path), node.lineno))
print(len(bad))
PYEOF
)
if [ "$out" = "1" ]; then
  pass "control: matcher flags exactly the 1 unbounded call and ignores the bounded one"
else
  fail "control: matcher reported $out unbounded (want 1) — the green above is not trustworthy"
fi

# ───────────────────────────────────────────────────────────────────────────────
# The heredoc matcher. Written ONCE to $TMP and invoked twice — against the real
# tree, and against a synthetic fixture — so the CONTROL exercises the exact code
# the green verdict came from, not a re-typed lookalike (the weakness of the
# duplicated matcher above).
# ───────────────────────────────────────────────────────────────────────────────
cat > "$TMP/heredoc_scan.py" <<'SCANEOF'
"""Extract Python embedded in shell scripts and AST-check its subprocess bounds.

Two embedding mechanisms are covered, because this plugin uses both:
  1. heredocs                -- `python3 <<'PYEOF' ... PYEOF`
  2. multi-line 'single-quoted' assignments -- `PY_COMMON=' ... '`, later injected
     into several heredocs (scripts/validate-bolt-artifacts.sh does exactly this,
     and a first draft of this matcher walked straight past its unbounded git
     helper -- which is how this docstring earned its length).

Anything mentioning `subprocess.<attr>` that falls OUTSIDE every extracted block is
reported as NOT SCANNED and fails the run. That residual guard is the actual moat:
it makes the next unforeseen embedding trick loud instead of invisible, which is
the failure mode this whole file exists to correct.

Output contract, one record per line (the bash caller parses these):
    ENUMERATED <basename>      a file this scanner DECIDED to open (see enum())
    INSPECTED <n>              subprocess.* calls found across all PARSED blocks
    UNBOUNDED <basename>:<line-in-the-.sh-file>
    SKIPPED <reason>           something mentioning subprocess that was NOT scanned

ENUMERATED exists so the caller can assert the enumerated set against what is on
disk. The caller must NOT re-implement enum() in bash to do that: a re-typed
lookalike proves only that two copies agree, which is the very weakness called out
above the first control. The scanner reports what it actually opened.

Exit: 0 = clean * 1 = unbounded found * 2 = vacuous (zero calls inspected)
      3 = something was skipped and nothing was unbounded (still a FAIL: an
          unscanned block has not been shown to be bounded).
"""
import ast, os, re, sys

CALLS = ("run", "Popen", "check_output", "call", "check_call")

# A heredoc opener: `<<` or `<<-`, optional quoting, then a WORD delimiter.
#   `1 << 2`  (arithmetic shift) never matches -- a digit cannot start a delimiter.
#   `<<<WORD` (herestring)       is rejected by the explicit look-behind below;
#                                the regex alone WOULD match it at offset+1.
HD = re.compile(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
# `NAME='` with nothing after the quote -- the multi-line single-quoted form only.
# A single-line `NAME='foo'` is deliberately NOT a block; if it ever held a
# subprocess call the residual guard below would flag it as unscanned.
ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)='\s*$")
USES_SUBPROCESS = re.compile(r"\bsubprocess\s*\.")


def sh_blocks(path, skipped, in_block):
    """Yield (label, python_text, first_body_lineno) for each embedded block.

    `in_block` collects every body line number seen, parsed or not, so the
    residual guard never double-reports a block that already spoke for itself.
    """
    name = os.path.basename(path)
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    n = len(lines)
    i = 0
    while i < n:
        line = lines[i]
        # A pure comment line can open NEITHER construct. This is correctness, not a
        # convenience filter: scripts/certify-artifact.sh and scripts/kb-leak-scan.sh
        # both write `<<word` inside prose comments, and treating either as an opener
        # would swallow the rest of the file into a bogus unterminated body.
        if line.lstrip().startswith("#"):
            i += 1
            continue

        # ── (1) multi-line single-quoted assignment ──────────────────────────
        am = ASSIGN.match(line)
        if am:
            body, start, j, closed = [], i + 2, i + 1, False
            while j < n:
                if lines[j].rstrip("\r") == "'":
                    closed = True
                    break
                body.append(lines[j])
                j += 1
            # Inside a single-quoted shell word a literal quote can only be spelled
            # '"'"' or '\'' -- both close and reopen the quoting. Undo them to
            # recover the exact Python source.
            raw_body = "\n".join(body)
            text = raw_body.replace("'\"'\"'", "'").replace("'\\''", "'")
            # ...and once those two escapes are removed, a single-quoted shell word
            # can contain NO bare apostrophe at all -- one would have ended the word.
            # If any survives, what the shell sees is not what we just parsed, so the
            # scan result would be a fiction. Caught exactly this while writing the
            # fix that this test guards: an apostrophe in a new comment silently
            # truncated the block, and only `bash -n` noticed.
            if "'" in raw_body.replace("'\"'\"'", "").replace("'\\''", ""):
                skipped.append("%s:%d '-quoted assignment %s= contains a BARE "
                               "apostrophe -- the shell ends the string there, so this "
                               "block is not what it looks like -- NOT SCANNED"
                               % (name, i + 1, am.group(1)))
            for k in range(start, j + 1):
                in_block.add(k)
            if not closed:
                if "subprocess" in text:
                    skipped.append("%s:%d unterminated '-quoted assignment %s= whose "
                                   "body mentions subprocess -- NOT SCANNED"
                                   % (name, i + 1, am.group(1)))
                i = j
                continue
            yield ("%s=" % am.group(1)), text, start
            i = j + 1
            continue

        # ── (2) heredoc ──────────────────────────────────────────────────────
        opens = [m for m in HD.finditer(line)
                 if not (m.start() > 0 and line[m.start() - 1] == "<")]
        if not opens:
            i += 1
            continue
        if len(opens) > 1:
            # Two openers on one line (`cmd <<A <<B`) needs a delimiter QUEUE. No
            # such line exists in this tree; rather than scan it wrong, say so.
            skipped.append("%s:%d multiple heredoc openers on one line -- NOT SCANNED"
                           % (name, i + 1))
            i += 1
            continue
        m = opens[0]
        dash = m.group(1) == "-"
        delim = m.group(3)
        body, start, j, closed = [], i + 2, i + 1, False
        while j < n:
            # `<<-` strips leading TABS from the terminator AND from every body
            # line -- dropping the body half would hand ast.parse an IndentationError.
            # rstrip("\r") keeps this honest on a CRLF checkout (Git for Windows).
            raw = lines[j]
            probe = raw.lstrip("\t") if dash else raw
            if probe.rstrip("\r") == delim:
                closed = True
                break
            body.append(probe)
            j += 1
        text = "\n".join(body)
        for k in range(start, j + 1):
            in_block.add(k)
        if not closed:
            if "subprocess" in text:
                skipped.append("%s:%d unterminated heredoc <<%s whose body mentions "
                               "subprocess -- NOT SCANNED" % (name, i + 1, delim))
            i = j
            continue
        yield delim, text, start
        i = j + 1


def enum(d):
    """Shell scripts in `d`, BY CONTENT — not by extension.

    The `*.sh` glob this replaced could not see `plugins/mega-sdd/hooks/` at all:
    all six hook entry points are extensionless, because Claude Code invokes them
    by the bare name in hooks.json. Extension is not the property that matters; being
    a bash script is. So: `*.sh`, OR a first line that is a bash shebang.

    The shebang test is deliberately TIGHT (`#!` … containing `bash`) rather than
    accommodating — it would miss a hypothetical `#!/bin/sh` hook. That is fine, and
    intentional: the caller's disk-equality assertion catches anything on disk this
    function declined to open. Two narrow mechanisms covering each other beats one
    permissive mechanism that silently absorbs whatever it is handed.
    """
    out = []
    for nm in sorted(os.listdir(d)):
        p = os.path.join(d, nm)
        if not os.path.isfile(p):
            continue
        if nm.endswith(".sh"):
            out.append(p)
            continue
        try:
            first = open(p, encoding="utf-8", errors="replace").readline()
        except OSError:
            continue
        if first.startswith("#!") and "bash" in first:
            out.append(p)
    return out


unbounded, skipped, enumerated = [], [], []
total = 0
for d in sys.argv[1:]:
    for path in enum(d):
        name = os.path.basename(path)
        enumerated.append(name)
        in_block = set()
        for label, text, start in sh_blocks(path, skipped, in_block):
            if "subprocess" not in text:
                continue           # not a Python block we care about -- no noise
            try:
                tree = ast.parse(text)
            except SyntaxError as e:
                skipped.append("%s:%d block <%s> mentions subprocess but is not "
                               "parseable Python (%s) -- NOT SCANNED"
                               % (name, start, label, e.msg))
                continue
            # A Popen with NO timeout kwarg (Popen never accepts one) is bounded
            # iff the SAME block also calls .communicate(timeout=...) — the
            # process-group-kill pattern (Popen + communicate(timeout) + killpg)
            # is MORE bounded than run(timeout), which cannot killpg orphans
            # (v6.10.0 uat-run.sh). Block-scoped, controlled below.
            block_has_bounded_communicate = any(
                isinstance(nn, ast.Call) and isinstance(nn.func, ast.Attribute)
                and nn.func.attr == "communicate"
                and any(k.arg == "timeout" for k in nn.keywords)
                for nn in ast.walk(tree)
            )
            for node in ast.walk(tree):
                f = getattr(node, "func", None)
                if not (isinstance(node, ast.Call) and isinstance(f, ast.Attribute)
                        and isinstance(f.value, ast.Name) and f.value.id == "subprocess"
                        and f.attr in CALLS):
                    continue
                total += 1
                if not any(k.arg == "timeout" for k in node.keywords):
                    if f.attr == "Popen" and block_has_bounded_communicate:
                        continue
                    # node.lineno is 1-indexed WITHIN the block body; -1 folds the
                    # two 1-indexed origins into one .sh-file line number.
                    unbounded.append("%s:%d" % (name, start + node.lineno - 1))
        # ── residual guard: no `subprocess.<attr>` may live outside a block ──
        src = open(path, encoding="utf-8", errors="replace").read().split("\n")
        for idx, line in enumerate(src, 1):
            if line.lstrip().startswith("#") or idx in in_block:
                continue
            if USES_SUBPROCESS.search(line):
                skipped.append("%s:%d uses subprocess.<attr> outside every extracted "
                               "block -- an embedding form this matcher does not "
                               "understand -- NOT SCANNED" % (name, idx))

for e in enumerated:
    print("ENUMERATED %s" % e)
print("INSPECTED %d" % total)
for u in unbounded:
    print("UNBOUNDED %s" % u)
for s in skipped:
    print("SKIPPED %s" % s)
if total == 0:
    sys.exit(2)
if unbounded:
    sys.exit(1)
if skipped:
    sys.exit(3)
sys.exit(0)
SCANEOF

echo "── every subprocess.run EMBEDDED in scripts/*.sh heredocs must carry timeout= ──"
scan_out=$("$PY" "$TMP/heredoc_scan.py" "$SCRIPTS" "$LIB" 2>&1)
scan_st=$?
# ENUMERATED is one line per file (~90 here) — collapse it to a count so the
# verdict lines stay readable; the hooks run below prints its set in full, because
# there the identity of each file is the thing being asserted.
scan_files=$(printf '%s\n' "$scan_out" | grep -c '^ENUMERATED ')
printf '%s\n' "$scan_out" | grep -v '^ENUMERATED ' | sed 's/^/  /'
echo "  (enumerated $scan_files shell file(s) across scripts/ + scripts/_lib/)"
case "$scan_st" in
  0) pass "all embedded subprocess calls in scripts/*.sh are bounded" ;;
  2) fail "heredoc matcher found zero calls — the check is vacuous, not green" ;;
  3) fail "a heredoc mentioning subprocess could not be scanned — under-scan, not green" ;;
  *) fail "unbounded subprocess call(s) in Python embedded in scripts/*.sh" ;;
esac

echo "── CONTROL: the extractor handles every embedding form it claims to ──"
# A fixture built only from <<'EOF' would prove nothing about <<EOF, <<-EOF (tab
# stripping), several blocks in one file, herestrings, comment-borne false openers,
# or the multi-line 'single-quoted' assignment — all of which the extractor above
# claims to handle. Every one of them is present here, and the assertion pins the
# exact LINE NUMBERS so the `start + node.lineno - 1` offset arithmetic is proven,
# not just the count.
mkdir -p "$TMP/fx"
"$PY" - "$TMP/fx/fixture.sh" <<'FIXEOF'
import sys
# Line numbers are load-bearing — keep this list and the expectations in step.
L = [
    "#!/usr/bin/env bash",                                       # 1
    "# prose: emit <verdict> <<keterangan-on-stdin>> — NOT an opener",  # 2
    "grep -q x <<<HERESTRING_IS_NOT_A_HEREDOC || true",          # 3
    "cat > /dev/null <<TXT",                                     # 4
    "plain text, nothing here to parse",                         # 5
    "TXT",                                                       # 6
    "python3 - <<'AAA'",                                         # 7
    "import subprocess",                                         # 8
    "subprocess.run(['a'], capture_output=True)",                # 9  UNBOUNDED
    "AAA",                                                       # 10
    "python3 - <<BBB",                                           # 11
    "import subprocess",                                         # 12
    "subprocess.run(['b'], capture_output=True, timeout=5)",     # 13 bounded
    "BBB",                                                       # 14
    "python3 - <<-CCC",                                          # 15
    "\timport subprocess",                                       # 16
    "\tsubprocess.run(['c'], capture_output=True)",              # 17 UNBOUNDED
    "\tCCC",                                                     # 18
    "python3 - <<'DDD'",                                         # 19
    "import subprocess",                                         # 20
    "subprocess.Popen(['d'])",                                   # 21 UNBOUNDED
    "DDD",                                                       # 22
    "python3 - <<'EEE'",                                         # 23
    "import subprocess",                                         # 24
    "this is ( not python subprocess.run(",                      # 25 -> loud SKIP
    "EEE",                                                       # 26
    "PYVAR='",                                                   # 27
    "import subprocess",                                         # 28
    # double quotes ONLY: a bare ' would end the shell string (see line 30)
    "subprocess.check_output([\"e\"])",                           # 29 UNBOUNDED
    "# a shell-escaped quote: don'\"'\"'t trip on this",         # 30
    "'",                                                         # 31
    "python3 - <<'FFF'",                                         # 32
    "import subprocess",                                         # 33
    "p = subprocess.Popen(['f'], start_new_session=True)",       # 34 bounded via 35
    "p.communicate(timeout=5)",                                  # 35
    "FFF",                                                       # 36
    "",
]
open(sys.argv[1], "w").write("\n".join(L))
FIXEOF
fx_out=$("$PY" "$TMP/heredoc_scan.py" "$TMP/fx" 2>&1)
fx_st=$?
fx_lines=$(printf '%s\n' "$fx_out" | sed -n 's/^UNBOUNDED //p' | tr '\n' ' ')
fx_insp=$(printf '%s\n' "$fx_out" | sed -n 's/^INSPECTED //p')
fx_skip=$(printf '%s\n' "$fx_out" | grep -c '^SKIPPED ')
# line 21's bare Popen (NO communicate in its block) must STAY flagged; line 34's
# Popen + communicate(timeout=) in the SAME block must NOT be flagged.
FX_WANT="fixture.sh:9 fixture.sh:17 fixture.sh:21 fixture.sh:29 "
if [ "$fx_lines" = "$FX_WANT" ] \
   && [ "$fx_insp" = "6" ] && [ "$fx_skip" = "1" ] && [ "$fx_st" = "1" ]; then
  pass "control: 4 unbounded at the exact lines (bare Popen still flagged), bounded run + bounded-Popen-via-communicate ignored, 1 loud skip"
else
  printf '%s\n' "$fx_out" | sed 's/^/  /'
  fail "control: extractor gave lines=[$fx_lines] inspected=$fx_insp skipped=$fx_skip rc=$fx_st (want [$FX_WANT] 6 1 1)"
fi

echo "── CONTROL: a truncated 'single-quoted block is reported, not scanned ──"
# The bug this guards against is real and was committed during this very fix: an
# apostrophe added to a comment inside PY_COMMON=' … ' ended the shell string early,
# so the block the extractor parsed was NOT the block bash sees. Only `bash -n`
# caught it. A matcher that reports green on text the shell never had is worse than
# no matcher, so the extractor must call this out instead of scanning it.
mkdir -p "$TMP/fx2"
"$PY" - "$TMP/fx2/truncated.sh" <<'FIX2EOF'
import sys
L = [
    "#!/usr/bin/env bash",
    "PYBAD='",
    "import subprocess",
    "# this apostrophe -> don't <- silently ends the shell string",
    "subprocess.run([\"never\", \"reached\"])",
    "'",
    "",
]
open(sys.argv[1], "w").write("\n".join(L))
FIX2EOF
fx2_out=$("$PY" "$TMP/heredoc_scan.py" "$TMP/fx2" 2>&1)
fx2_st=$?
if printf '%s\n' "$fx2_out" | grep -q 'SKIPPED .*BARE apostrophe' \
   && [ "$fx2_st" != "0" ]; then
  pass "control: truncated '-quoted block is loudly skipped, never silently scanned"
else
  printf '%s\n' "$fx2_out" | sed 's/^/  /'
  fail "control: truncated '-quoted block was not reported (rc=$fx2_st) — the extractor would scan text the shell never sees"
fi

echo "── CONTROL: the EXTENSIONLESS-hook enumeration fires, and discriminates ──"
# This control is load-bearing in a way the others are not. hooks/ is CLEAN today —
# its single subprocess call is already bounded — so the verdict below is green
# either way, and a green tells you nothing unless you can distinguish "the hooks
# are clean" from "the matcher never looked". Round 1 was the second case and read
# exactly like the first.
#
# So the fixture has a NEGATIVE limb as well as a positive one. A match-everything
# enumerator would pass a positive-only control while proving nothing about shebang
# detection; here it would enumerate `helper-py` / `not-a-hook.json` too, and their
# `subprocess.` lines — outside any extracted block — would trip the residual guard
# into a SKIPPED record. Asserting skips=0 is therefore the assertion that those two
# were never opened, sourced from the scanner's own behaviour rather than from a
# claim it makes about itself.
mkdir -p "$TMP/hk"
"$PY" - "$TMP/hk" <<'HKEOF'
import os, sys
d = sys.argv[1]

# (+) extensionless, bash shebang, UNBOUNDED call inside a heredoc.
#     Body starts at line 4, so the call on block-line 2 must report as :5.
open(os.path.join(d, "fake-pre-tool-use"), "w").write("\n".join([
    "#!/usr/bin/env bash",                                          # 1
    "STDIN_JSON=\"$(cat)\"",                                        # 2
    "python3 <<'PYEOF'",                                            # 3
    "import subprocess",                                            # 4
    "subprocess.run(['git', 'status'], capture_output=True)",       # 5  UNBOUNDED
    "PYEOF",                                                        # 6
    "",
]))

# (+) extensionless, bash shebang, BOUNDED — must be inspected and NOT flagged.
open(os.path.join(d, "fake-session-start"), "w").write("\n".join([
    "#!/usr/bin/env bash",
    "python3 <<'PYEOF'",
    "import subprocess",
    "subprocess.run(['git', 'rev-parse', 'HEAD'], timeout=5)",
    "PYEOF",
    "",
]))

# (-) extensionless but NOT a bash script -- a python helper. Must not be opened.
open(os.path.join(d, "helper-py"), "w").write("\n".join([
    "#!/usr/bin/env python3",
    "import subprocess",
    "subprocess.run(['never', 'enumerated'])",
    "",
]))

# (-) the one real non-script in hooks/ has this shape: JSON, first line `{`.
open(os.path.join(d, "not-a-hook.json"), "w").write(
    '{\n  "note": "subprocess.run([\\"x\\"]) -- text, not code"\n}\n')
HKEOF
hk_out=$("$PY" "$TMP/heredoc_scan.py" "$TMP/hk" 2>&1)
hk_st=$?
hk_enum=$(printf '%s\n' "$hk_out" | sed -n 's/^ENUMERATED //p' | sort | tr '\n' ' ')
hk_insp=$(printf '%s\n' "$hk_out" | sed -n 's/^INSPECTED //p')
hk_unb=$(printf '%s\n' "$hk_out" | sed -n 's/^UNBOUNDED //p' | tr '\n' ' ')
hk_skip=$(printf '%s\n' "$hk_out" | grep -c '^SKIPPED ')
HK_ENUM_WANT="fake-pre-tool-use fake-session-start "
HK_UNB_WANT="fake-pre-tool-use:5 "
if [ "$hk_enum" = "$HK_ENUM_WANT" ] && [ "$hk_unb" = "$HK_UNB_WANT" ] \
   && [ "$hk_insp" = "2" ] && [ "$hk_skip" = "0" ] && [ "$hk_st" = "1" ]; then
  pass "control: extensionless bash hooks are enumerated and an unbounded call in one is flagged at the exact line; a python-shebang file and a .json are not opened"
else
  printf '%s\n' "$hk_out" | sed 's/^/  /'
  fail "control: enum=[$hk_enum] unbounded=[$hk_unb] inspected=$hk_insp skipped=$hk_skip rc=$hk_st (want [$HK_ENUM_WANT] [$HK_UNB_WANT] 2 0 1) — the hooks verdict below is not trustworthy"
fi

echo "── every subprocess.run EMBEDDED in hooks/ must carry timeout= ──"
# hooks/ is the surface Claude Code BLOCKS on. Everything above is about code a hook
# can reach; this is the hook itself.
hooks_out=$("$PY" "$TMP/heredoc_scan.py" "$HOOKS" 2>&1)
hooks_st=$?
hooks_enum=$(printf '%s\n' "$hooks_out" | sed -n 's/^ENUMERATED //p' | sort | tr '\n' ' ')
hooks_n=$(printf '%s\n' "$hooks_out" | sed -n 's/^INSPECTED //p')
printf '%s\n' "$hooks_out" | grep -v '^ENUMERATED ' | sed 's/^/  /'
echo "  enumerated: $hooks_enum"

# ── the enumerated set must equal what is ON DISK ────────────────────────────────
# This is the half of the fix that survives the next hook being added. Content
# enumeration already picks up a ninth hook automatically; this assertion is what
# makes a ninth FILE that enumeration declined to open (a .py helper, a .md note, a
# `#!/bin/sh` hook) an actionable red instead of a silent gap. The exemption list is
# exactly one entry and is named in the failure text on purpose.
HOOKS_EXEMPT="hooks.json"
hooks_disk=$(
  cd "$HOOKS" || exit 1
  for f in *; do
    if [ -f "$f" ] && [ "$f" != "$HOOKS_EXEMPT" ]; then printf '%s\n' "$f"; fi
  done | sort | tr '\n' ' '
)
if [ "$hooks_enum" = "$hooks_disk" ]; then
  pass "enumeration covers every file in hooks/ except the declared exemption ($HOOKS_EXEMPT)"
else
  fail "hooks/ enumeration MISMATCH — scanner opened [$hooks_enum] but disk (minus the one exemption, $HOOKS_EXEMPT) holds [$hooks_disk]; a file in hooks/ is going unscanned, which is exactly the round-1 gap"
fi

case "$hooks_st" in
  # v7.5.0 №A: hooks.json dispatches each of the SIX extensionless entry bodies
  # DIRECTLY — run-hook.sh (the old dispatcher) is deleted. Six entry scripts,
  # no dispatcher. Spelling that out here so the count is not re-derived.
  0) pass "all $hooks_n embedded subprocess call(s) in hooks/ are bounded (across $(printf '%s\n' "$hooks_out" | grep -c '^ENUMERATED ') enumerated shell file(s): 6 extensionless entry points, direct dispatch)" ;;
  # v7.3.0: pre-compact (the one historical subprocess carrier) is DELETED with
  # observability — hooks/ now legitimately embeds ZERO python-subprocess calls.
  # Zero-total is accepted as green ONLY together with the enumeration check
  # above (every hooks/ file was actually opened), so this cannot go vacuous
  # by a scanner bug: an unscanned file trips the enumeration mismatch first.
  2) pass "hooks/ embeds zero python-subprocess calls (pre-compact removed v7.3.0; enumeration verified above)" ;;
  3) fail "something in hooks/ mentioning subprocess could not be scanned — under-scan, not green (see SKIPPED above; the \`python3 -c\` inline form lands here by design)" ;;
  *) fail "UNBOUNDED subprocess call(s) in Python embedded in hooks/ — this is a blocking PreToolUse/SessionStart path; Claude Code waits on it" ;;
esac

echo "── the gate-path timeout fails CLOSED, never open ──"
# A Hard-rule check that did not finish has not been shown to hold. If a timeout
# were treated as `pass`, running out of time would launder a violation past a
# blocking gate.
PF="$LIB/postflight_rules.py"
if grep -q 'TimeoutExpired' "$PF"; then
  blk=$(grep -A6 'except subprocess.TimeoutExpired' "$PF" | head -8)
  if printf '%s' "$blk" | grep -q '"verdict": "fail"'; then
    pass "ast-grep timeout yields verdict=fail (fail-closed)"
  else
    fail "ast-grep timeout does not yield verdict=fail — a timeout could pass the gate"
  fi
else
  fail "postflight_rules.py does not handle TimeoutExpired at all"
fi

echo "── the PRE-flight timeout HALTS, and must never fall through ──"
# Pre-flight is not post-flight and the difference is the whole point. Post-flight
# records a verdict, so a timeout can be recorded as `fail`. Pre-flight mints a
# BASELINE and has no `fail` to record — a rule whose `matched_files` was never
# captured would be persisted as an EMPTY match set, i.e. a FALSE baseline that
# post-flight then compares against. So the timeout branch must EXIT non-zero.
# `continue` is called out by name because it is the plausible-looking edit that
# reintroduces exactly that false baseline while leaving `timeout=` in place — and
# the bounded-ness check above would stay green through it.
# The probe must target the AST-GREP call SPECIFICALLY. A plain
# `grep -A12 'except subprocess.TimeoutExpired'` matches the FIRST such handler in
# the file — which is now the `git()` helper this same fix added, not the repo-wide
# scan — and would report a confident verdict about the wrong block entirely. The
# first draft of this check did exactly that and passed vacuously; anchoring on the
# ast-grep call and walking the handler body by INDENT is immune both to that and to
# someone editing the comment length inside the branch.
cat > "$TMP/halt_probe.py" <<'HALTEOF'
import re, sys

lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
anchor = None
for i, ln in enumerate(lines):
    if "astgrep" in ln and "scan" in ln and "subprocess.run" in ln:
        anchor = i
        break
if anchor is None:
    print("no-astgrep"); sys.exit(0)
exc = None
for i in range(anchor, min(anchor + 6, len(lines))):
    if re.match(r"\s*except subprocess\.TimeoutExpired\s*:", lines[i]):
        exc = i
        break
if exc is None:
    print("no-handler"); sys.exit(0)
indent = len(lines[exc]) - len(lines[exc].lstrip())
body = []
for ln in lines[exc + 1:]:
    if not ln.strip():
        body.append(ln); continue
    if (len(ln) - len(ln.lstrip())) <= indent:
        break
    body.append(ln)
text = "\n".join(body)
if re.search(r"^\s*continue\s*$", text, re.M):
    print("falls-through")
elif re.search(r"sys\.exit\(\s*[1-9]", text):
    print("halts")
elif re.search(r"\bdie\(\s*[1-9]", text):
    # 4d batch form: fatal exits route through a local die(code, msg) helper so
    # the unprocessed batch remainder is disclosed. A die() call counts as a
    # halt ONLY when the helper body PROVABLY calls sys.exit on its code arg —
    # a die() that logs without exiting is still the silent-false-baseline bug.
    src = "\n".join(lines)
    m = re.search(r"^def die\(code[^\n]*\n((?:[ \t]+[^\n]*\n?|\n)*)", src, re.M)
    if m and re.search(r"sys\.exit\(\s*code\s*\)", m.group(1)):
        print("halts")
    else:
        print("no-exit")
else:
    print("no-exit")
HALTEOF
halt_verdict() { "$PY" "$TMP/halt_probe.py" "$1"; }

# CONTROL first — every verdict must be reachable, or "halts" below means nothing.
# v_git is the REGRESSION control for the false pass described above: a git() handler
# that exits 2 sits BEFORE the ast-grep one, so a probe that grabs the first handler
# in the file reports "halts" while the real branch falls through.
"$PY" - "$TMP" <<'VEOF'
import os, sys
d = sys.argv[1]
AST = ('                rr = subprocess.run([astgrep, "scan", "--rule", t, "--json", cwd],\n'
       '                                    capture_output=True, text=True, timeout=120)\n')
EXC = "            except subprocess.TimeoutExpired:\n"
GIT = ("def git(*a):\n"
       "    try:\n"
       '        return subprocess.run(["git"], timeout=60)\n'
       "    except subprocess.TimeoutExpired:\n"
       "        sys.exit(2)\n")
open(os.path.join(d, "v_cont.py"), "w").write(AST + EXC + "                continue\n")
open(os.path.join(d, "v_halt.py"), "w").write(AST + EXC + "                sys.exit(3)\n")
open(os.path.join(d, "v_none.py"), "w").write(AST + EXC + "                pass\n")
open(os.path.join(d, "v_bare.py"), "w").write(AST)
open(os.path.join(d, "v_git.py"), "w").write(GIT + AST + EXC + "                continue\n")
DIE_OK = ("def die(code, msg):\n"
          "    print(msg)\n"
          "    sys.exit(code)\n")
DIE_BAD = ("def die(code, msg):\n"
           "    print(msg)\n")
open(os.path.join(d, "v_dieok.py"), "w").write(DIE_OK + AST + EXC + "                die(3, \"t\")\n")
open(os.path.join(d, "v_diebad.py"), "w").write(DIE_BAD + AST + EXC + "                die(3, \"t\")\n")
VEOF
v_all="$(halt_verdict "$TMP/v_cont.py")/$(halt_verdict "$TMP/v_halt.py")/$(halt_verdict "$TMP/v_none.py")/$(halt_verdict "$TMP/v_bare.py")/$(halt_verdict "$TMP/v_git.py")/$(halt_verdict "$TMP/v_dieok.py")/$(halt_verdict "$TMP/v_diebad.py")"
V_WANT="falls-through/halts/no-exit/no-handler/falls-through/halts/no-exit"
if [ "$v_all" = "$V_WANT" ]; then
  pass "control: every halt verdict is reachable, and a preceding git() handler does not fool the probe"
else
  fail "control: halt_verdict gave [$v_all] (want $V_WANT) — the verdict below is not trustworthy"
fi

case "$(halt_verdict "$SCRIPTS/run-preflight-scan.sh")" in
  halts) pass "pre-flight ast-grep timeout exits non-zero (halts; no false baseline)" ;;
  falls-through) fail "pre-flight ast-grep timeout falls through to \`continue\` — that writes a FALSE baseline" ;;
  no-exit) fail "pre-flight ast-grep timeout does not reach a non-zero sys.exit() — the run would not halt" ;;
  no-handler) fail "run-preflight-scan.sh does not handle TimeoutExpired — its repo-wide ast-grep scan is unbounded" ;;
  *) fail "run-preflight-scan.sh no longer contains an ast-grep scan call — probe anchor lost" ;;
esac

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
