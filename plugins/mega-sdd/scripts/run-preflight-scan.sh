#!/usr/bin/env bash
# run-preflight-scan.sh — deterministic writer for <vault>/bolts/U-XXX/preflight.json
# (the B1 pre-flight Hard-rule BASELINE snapshot).
#
# NOT the predictive precondition gate: scripts/validate-preflight.sh is the
# UNRELATED "predictive pre-flight" (skill-precondition checks — vault/units/map
# presence). THIS script is the Hard-rule pre-flight SNAPSHOT writer — the
# pre-bolt twin of run-postflight-scan.sh (the writer pair).
#
# W4 (spec 2026-07-19-w-batch-script-derive.md): the pre-flight snapshot used to
# be model-written on trust — and scan_unit gives a PRESENT sha/signature snapshot
# PRECEDENCE over git commit evidence (postflight_rules.py DO_NOT_MODIFY /
# SIGNATURE_RULE branches), so a wrong sha256 at pre-flight made a DO_NOT_MODIFY
# violation undetectable even at the recompute gate. This script is now the ONLY
# sanctioned write path (the artifact is Write/Edit- and Bash-verb-guarded by the
# PreToolUse hook, like postflight.json). It imports the SAME
# scripts/_lib/postflight_rules.py primitives the post-flight engine uses
# (extract_hard_rules lexer, STRICT/DIRECTIVE classification, sha256_of,
# find_decl_line, walk_unit_commits, normalize_v2_files) — so what pre-flight
# snapshots is byte-identical to what post-flight evaluates — and it REFUSES to
# mint a baseline after bolt commits exist (anti-laundering: a post-hoc baseline
# could record the post-tamper sha; post-flight then falls back to the honest
# commit-touched-set evidence instead). It ALSO refuses to mint when any rule
# TARGET path (a DO_NOT_MODIFY path, or the file declaring a SIGNATURE_RULE
# symbol) differs from HEAD on disk (exit 8): the baseline captures WORKING-TREE
# bytes, so tamper-BEFORE-mint would bake the tampered sha into the baseline and
# launder the committed violation past B1 — a dirty protected path at baseline
# time is indistinguishable from tampering. Legit clean-tree pre-flights are
# unaffected (HEAD == disk); unrelated dirty files never block.
#
# Usage:
#   run-preflight-scan.sh --cwd=<project-root> --unit=U-XXX \
#       [--grammar=v1|v2] [--quiet]
#   run-preflight-scan.sh --cwd=<project-root> --units=U-001,U-002,... \
#       [--grammar=v1|v2] [--quiet]
# Batch form (spec tranche 4d): ONE spawn-chain amortizes the fixed costs
# (rev-parse prefix, walk_unit_commits — one log walk already covers ALL units)
# across every target unit; snapshot_at/head_sha stay PER-UNIT at write time
# (identical provenance to the single-unit path — a v2 batch can span minutes). The batch is SEQUENTIAL and
# FAIL-FAST on every fatal code (2/3/4/5/6/8): the first offending unit stops
# the batch, the script exits with THAT unit's code, and the unprocessed
# remainder is listed on stderr (a half-processed batch must be visible, not
# silent). Exit 7 keeps its NON-FATAL contract: collected per unit, the batch
# continues, final exit is 7 iff >=1 refusal (stderr names each). Earlier
# units' artifacts written before a fatal stop are valid baselines and stay;
# re-batching the same list is idempotent (immutable-keep / no-Hard-rules).
# Exit: 0 = snapshot written / existing baseline kept (immutable) / no Hard rules
#       2 = cannot run (usage / unit not found / not a git repo)
#       3 = halt hard_rule_unparseable (a line matches no v1 production and is
#           not a directive; or a v2 YAML block fails parse-via-scan — stderr verbatim;
#           or that parse-via-scan exceeds its 120s bound, which is the SAME state —
#           the rule was not validated, and a baseline missing a rule's matched_files
#           is a FALSE baseline, so the run halts rather than snapshot a lie)
#       4 = halt hard_rule_mixed_grammar (bulleted v1 rules + YAML fences coexist;
#           force one grammar with --grammar=v1|v2, or run the migrate-rules procedure)
#       5 = halt hard_rule_unanchored (SIGNATURE_RULE symbol not in tracked source)
#       6 = halt dep_missing (v2 grammar present, ast-grep not on PATH)
#       7 = post-hoc refusal — bolt commits already exist for this unit and no
#           baseline is on disk; a baseline minted now could launder a violation.
#           NON-FATAL: proceed WITHOUT a baseline (post-flight uses git commit
#           evidence); log the refusal in the bolt-report.
#       8 = dirty-protected-path refusal — a rule target path differs from HEAD
#           at baseline time; no artifact written. FATAL for this run: commit or
#           restore the protected file, then re-run (NEVER proceed past it).
set -uo pipefail

CWD=""
UNITS=""
GRAMMAR=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --unit=*|--units=*) UNITS="${UNITS:+${UNITS},}${arg#*=}" ;;
    --grammar=*) GRAMMAR="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then echo "ERROR: --cwd=<project-root> required" >&2; exit 2; fi
if [ -z "$UNITS" ]; then echo "ERROR: --unit=U-XXX (or --units=U-001,U-002,...) required" >&2; exit 2; fi
case "$GRAMMAR" in ""|v1|v2) ;; *) echo "ERROR: --grammar must be v1|v2" >&2; exit 2 ;; esac
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" UNITS="$UNITS" GRAMMAR="$GRAMMAR" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, shutil, subprocess, sys, tempfile
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts
import postflight_rules

cwd = os.environ["CWD"]
# Comma-separated batch (spec tranche 4d); dedupe preserving order. The single
# --unit form arrives here as a one-element list — behavior byte-compatible.
unit_ids = list(dict.fromkeys(u.strip() for u in os.environ["UNITS"].split(",") if u.strip()))
grammar_override = os.environ.get("GRAMMAR", "")
quiet = os.environ.get("QUIET", "0") == "1"
if not unit_ids:
    print("ERROR: --unit/--units carried no unit id", file=sys.stderr)
    sys.exit(2)

# Fail-fast batch contract: the first FATAL code stops everything; the
# unprocessed remainder is printed so a half-processed batch is never silent.
CURRENT = {"i": 0}
def die(code, msg):
    print(msg, file=sys.stderr)
    rest = unit_ids[CURRENT["i"] + 1:]
    if rest:
        print("BATCH STOPPED at %s — unprocessed unit(s): %s"
              % (unit_ids[CURRENT["i"]], ", ".join(rest)), file=sys.stderr)
    sys.exit(code)

def git(*a):
    # BOUNDED. Local git plumbing is low-risk, not zero-risk: an fsmonitor daemon,
    # a wedged index.lock, or a network-backed worktree can stall a read-only call
    # indefinitely, and this runs in a path Claude Code waits on. 60 s is 6x the
    # repo's own rev-parse precedent (refresh-doc-stamps.sh / validate-codebase-map.sh
    # use timeout=10) — generous for any honest local call, finite for a wedged one.
    try:
        return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True,
                              timeout=60)
    except subprocess.TimeoutExpired:
        # FAIL-CLOSED to exit 2 ("cannot run"), NEVER a synthetic empty result. This
        # helper feeds the dirty-protected-path refusal below, where an empty
        # `git status --porcelain` reads as "clean tree" — a swallowed timeout would
        # OPEN the anti-laundering gate. Exit 2 is already this script's documented
        # cannot-run code, so no consumer contract changes.
        print("ERROR: `git %s` exceeded 60s — cannot run (wedged git/fsmonitor?). "
              "No artifact written." % " ".join(a), file=sys.stderr)
        sys.exit(2)

PREFIX = git("rev-parse", "--show-prefix").stdout.strip()

# Fail-fast BEFORE any artifact write: a unit id that resolves to nothing is a
# controller bug, not a scan verdict — the whole batch is exit 2, zero writes.
unit_files = {}
for unit_id in unit_ids:
    uf = vault_layouts.find_unit_file(cwd, unit_id)
    if not uf:
        print("ERROR: unit %s not found under any vault layout" % unit_id, file=sys.stderr)
        sys.exit(2)
    unit_files[unit_id] = uf

# Fixed cost paid ONCE per batch (tranche 4d), lazy so a batch of
# no-Hard-rules units stays as cheap as the old single-unit path.
# snapshot_at + head_sha are deliberately NOT amortized — both are stamped
# PER UNIT at artifact-write time (a v2 batch can span minutes and a parallel
# session can move HEAD mid-batch; the artifact must record ITS capture).
WALK = {"d": None}     # walk_unit_commits — one log walk covers ALL units

refused = []           # exit-7 units (non-fatal; batch continues)

for _i, unit_id in enumerate(unit_ids):
    CURRENT["i"] = _i
    uf = unit_files[unit_id]
    # vault root: <vault>/units/U-X.md → up 2; <vault>/units/U-X/unit.md → up 3
    d = os.path.dirname(uf)
    vault_root = os.path.dirname(d) if os.path.basename(d) == "units" else os.path.dirname(os.path.dirname(d))
    bolt_dir = os.path.join(vault_root, "bolts", unit_id)
    target = os.path.join(bolt_dir, "preflight.json")

    text = open(uf).read()

    # The SHARED lexer — the same extraction the post-flight engine runs, so the
    # rule set snapshotted here is byte-identical to the rule set evaluated later.
    lines, v2_rules = postflight_rules.extract_hard_rules(text)

    # No Hard rules → nothing to snapshot; never create an empty artifact.
    if not lines and not v2_rules:
        if not quiet:
            print("preflight %s: no Hard rules — no baseline to capture" % unit_id)
        continue

    # Grammar detection (SKILL.md pre-flight check 4): both forms coexisting → mixed
    # halt (doc-literal); --grammar=v1|v2 is the documented escape hatch.
    if grammar_override == "v1":
        v2_rules = []
    elif grammar_override == "v2":
        lines = []
    elif lines and v2_rules:
        die(4, "MIXED GRAMMAR: unit %s carries both bulleted v1 rules and YAML-fenced v2 "
               "rules — halt hard_rule_mixed_grammar (migrate via the migrate-rules procedure — ask: \"migrate hard rules\" "
               "or force one grammar with --grammar=v1|v2)" % unit_id)
    grammar = "v2" if v2_rules else "v1"

    # ── Anti-laundering lifecycle ────────────────────────────────────────────
    # Once ANY bolt commit exists for this unit, the baseline is immutable: an
    # existing artifact is KEPT byte-identical; an absent one is REFUSED (exit 7) —
    # a baseline minted post-hoc could record the post-tamper sha and launder a
    # DO_NOT_MODIFY/SIGNATURE violation past the recompute gate (the engine gives a
    # present snapshot precedence over commit evidence). Same walk as the gate.
    if WALK["d"] is None:
        WALK["d"] = postflight_rules.walk_unit_commits(git, PREFIX, 300)
    unit_commits = WALK["d"].get(unit_id, [])
    if unit_commits:
        if os.path.isfile(target):
            if not quiet:
                print("preflight %s: bolt commits exist — existing baseline kept unchanged "
                      "(immutable) -> %s" % (unit_id, target))
            continue
        print("REFUSED (post-hoc): bolt commits already exist for %s and no preflight "
              "baseline is on disk — a baseline minted now could launder a Hard-rule "
              "violation. Proceed WITHOUT a baseline: the post-flight engine falls back "
              "to git commit evidence. Log this refusal in the bolt-report." % unit_id,
              file=sys.stderr)
        refused.append(unit_id)
        continue

    entries = []
    protected = []  # rule TARGET paths whose disk state must equal HEAD at mint time

    # ── v1 lines: classify with the SHARED STRICT/DIRECTIVE productions ──────
    for raw in lines:
        matched = None
        for rtype, rx in postflight_rules.STRICT:
            mm = rx.match(raw)
            if mm:
                matched = (rtype, mm)
                break
        if matched:
            rtype, mm = matched
            if rtype == "DO_NOT_MODIFY":
                path = mm.group(1)
                sha = postflight_rules.sha256_of(os.path.join(cwd, path))
                entries.append({"type": rtype, "path": path,
                                "sha256": sha if sha is not None else "absent"})
                protected.append(path)
            elif rtype == "DO_NOT_ADD_DEPS":
                # Audit-only capture (documented-schema parity): since S7-HARDRULES-5
                # the engine diffs the unit's OWN commits and never reads deps_section.
                manifest = mm.group(1)
                mpath = os.path.join(cwd, manifest)
                if not os.path.isfile(mpath):
                    deps_section = "absent"
                else:
                    rawm = open(mpath).read()
                    keys = postflight_rules.DEP_KEYS.get(os.path.basename(manifest))
                    try:
                        dj = json.loads(rawm)
                    except ValueError:
                        dj = None
                    if keys and isinstance(dj, dict):
                        deps_section = json.dumps({k: dj.get(k) or {} for k in keys},
                                                  sort_keys=True)
                    else:
                        deps_section = rawm
                entries.append({"type": rtype, "manifest": manifest,
                                "deps_section": deps_section})
            elif rtype == "SIGNATURE_RULE":
                # The SAME extractor post-flight uses — never codebase-map prose.
                name = mm.group(1)
                decl, loc = postflight_rules.find_decl_line(git, name)
                if decl is None:
                    die(5, "UNANCHORED: function %s not found in tracked source — halt "
                           "hard_rule_unanchored (rule: %s)" % (name, raw))
                entries.append({"type": rtype, "function": name,
                                "signature_at_preflight": decl.split("{")[0].strip()})
                if loc:
                    protected.append(loc.rsplit(":", 1)[0])
            # NAMING_RULE / FILE_PRESENCE_RULE: no pre-snapshot by documented schema
            # (post-flight checks new files / final presence only).
            continue
        if postflight_rules.DIRECTIVE.match(raw):
            continue  # directive tier — attested at post-flight; nothing to snapshot
        die(3, "UNPARSEABLE: line matches no v1 production and is not a directive — halt "
               "hard_rule_unparseable. Offending line: %s" % raw)

    # ── v2 ast-grep rules: parse-via-scan + audit snapshot ───────────────────
    if v2_rules:
        astgrep = shutil.which("ast-grep")
        if not astgrep:
            die(6, "DEP MISSING: v2 (ast-grep YAML) Hard rules present but ast-grep is not "
                   "on PATH — halt dep_missing (install: brew install ast-grep)")
        for i, ry in enumerate(v2_rules):
            rid_m = re.search(r"^id:\s*(\S+)", ry, re.MULTILINE)
            rid = rid_m.group(1) if rid_m else "v2-rule-%d" % (i + 1)
            ry_norm, _globs = postflight_rules.normalize_v2_files(ry)
            with tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False) as tf:
                tf.write(ry_norm)
                tmp_rule = tf.name
            try:
                # BOUNDED, and the bound is load-bearing — the same rationale the
                # post-flight TWIN already carries (_lib/postflight_rules.py, the
                # `ast-grep scan` there). This is a repo-wide AST scan, run once per v2
                # Hard rule PER UNIT, and execute-bolts makes this script a mandatory
                # per-unit call (SKILL.md pre-flight check 4, which also forbids
                # skipping it) — i.e. work with no ceiling in a path Claude Code waits
                # on, the exact shape of the 2026-07-28 Windows hang. 120 s mirrors the
                # twin exactly; the two sites must not drift apart again.
                try:
                    rr = subprocess.run([astgrep, "scan", "--rule", tmp_rule, "--json", cwd],
                                        capture_output=True, text=True, timeout=120)
                except subprocess.TimeoutExpired:
                    # HALT — and deliberately NOT `continue`. Post-flight can record a
                    # timeout as verdict `fail` because it produces VERDICTS; pre-flight
                    # produces a BASELINE and has no `fail` to record. Falling through
                    # would persist this rule with an EMPTY `matched_files`, i.e. a FALSE
                    # baseline that post-flight then compares against — strictly worse
                    # than stopping, because it is silent.
                    #
                    # Exit 3 (hard_rule_unparseable) is REUSED, not extended. v2 rules are
                    # validated by parse-via-scan — the returncode branch immediately
                    # below is what turns "ast-grep rejected the rule" into exit 3 — so
                    # "the scan never finished" and "the scan rejected the rule" are the
                    # same epistemic state: THE RULE WAS NOT VALIDATED. Inventing a ninth
                    # code would have to be wired into the execute-bolts exit-code table
                    # and its reference docs; the halt taxonomy is a closed enum and this
                    # branch does not need to open it.
                    die(3, "TIMEOUT (v2): ast-grep scan for rule %s exceeded 120s — the rule "
                           "was NOT validated and NO baseline was captured; halt "
                           "hard_rule_unparseable. Narrow the rule's `files:` globs (a "
                           "repo-wide pattern scan is the usual cause) and re-run." % rid)
                if rr.returncode not in (0, 1):
                    # parse-via-scan: a rejected rule is the unparseable halt,
                    # stderr verbatim (ast-grep test --validate does not exist).
                    die(3, "UNPARSEABLE (v2): ast-grep rejected rule %s — halt "
                           "hard_rule_unparseable. stderr: %s"
                           % (rid, rr.stderr.strip()[:400]))
                try:
                    matches = json.loads(rr.stdout or "[]")
                except ValueError:
                    matches = []
                mfiles = sorted({m.get("file") for m in matches if m.get("file")})
                recs = []
                for p in mfiles:
                    ap = p if os.path.isabs(p) else os.path.join(cwd, p)
                    recs.append({"path": os.path.relpath(ap, cwd),
                                 "sha256": postflight_rules.sha256_of(ap)})
                # AUDIT record only — post-flight re-scans the pattern; it never
                # sha-compares (a v2 rule is a pattern scan, not a file lock).
                entries.append({"type": "v2_ast_grep", "rule": rid,
                                "matched_files": recs})
            finally:
                os.unlink(tmp_rule)

    # ── Tamper-before-mint refusal (exit 8) ──────────────────────────────────
    # The baseline snapshots WORKING-TREE bytes and the engine gives a present
    # snapshot precedence over commit evidence — so a protected path edited BEFORE
    # the mint would bake the tampered sha into the baseline and the committed
    # violation would pass B1 ("sha256 unchanged"). A dirty protected path at
    # baseline time is indistinguishable from tampering: refuse, write nothing.
    # Scope is the rule TARGET paths only — an unrelated dirty file never blocks.
    dirty = []
    for path in sorted(set(protected)):
        st = git("status", "--porcelain", "--", path)
        if st.stdout.strip():
            dirty.append(path)
    if dirty:
        die(8, "REFUSED (dirty protected path): %s differ(s) from HEAD — a dirty "
               "protected path at baseline time is indistinguishable from tampering "
               "(the working-tree snapshot would launder a Hard-rule violation past "
               "B1). Commit or restore the protected file(s), then re-run "
               "run-preflight-scan.sh. No artifact written." % ", ".join(dirty))

    artifact = {
        "unit_id": unit_id,
        "snapshot_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "head_sha": git("rev-parse", "HEAD").stdout.strip(),
        "written_by": "run-preflight-scan.sh",
        "grammar": grammar,
        "rules": entries,
    }
    os.makedirs(bolt_dir, exist_ok=True)
    tmp = target + ".tmp.%d" % os.getpid()
    with open(tmp, "w") as f:
        json.dump(artifact, f, indent=1)
    os.replace(tmp, target)
    if not quiet:
        print("preflight %s: baseline captured (%d snapshot entr%s, grammar %s) -> %s"
              % (unit_id, len(entries), "y" if len(entries) == 1 else "ies", grammar, target))

# Batch verdict: exit 7 iff >=1 post-hoc refusal (each named above, non-fatal);
# 0 otherwise. Fatal codes never reach here (die() exits at the offending unit).
if refused:
    sys.exit(7)
sys.exit(0)
PYEOF
