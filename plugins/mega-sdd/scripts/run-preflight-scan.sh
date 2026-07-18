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
# commit-touched-set evidence instead).
#
# Usage:
#   run-preflight-scan.sh --cwd=<project-root> --unit=U-XXX \
#       [--grammar=v1|v2] [--quiet]
# Exit: 0 = snapshot written / existing baseline kept (immutable) / no Hard rules
#       2 = cannot run (usage / unit not found / not a git repo)
#       3 = halt hard_rule_unparseable (a line matches no v1 production and is
#           not a directive; or a v2 YAML block fails parse-via-scan — stderr verbatim)
#       4 = halt hard_rule_mixed_grammar (bulleted v1 rules + YAML fences coexist;
#           force one grammar with --grammar=v1|v2, or /mega-sdd:migrate-rules)
#       5 = halt hard_rule_unanchored (SIGNATURE_RULE symbol not in tracked source)
#       6 = halt dep_missing (v2 grammar present, ast-grep not on PATH)
#       7 = post-hoc refusal — bolt commits already exist for this unit and no
#           baseline is on disk; a baseline minted now could launder a violation.
#           NON-FATAL: proceed WITHOUT a baseline (post-flight uses git commit
#           evidence); log the refusal in the bolt-report.
set -uo pipefail

CWD=""
UNIT=""
GRAMMAR=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --unit=*) UNIT="${arg#*=}" ;;
    --grammar=*) GRAMMAR="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then echo "ERROR: --cwd=<project-root> required" >&2; exit 2; fi
if [ -z "$UNIT" ]; then echo "ERROR: --unit=U-XXX required" >&2; exit 2; fi
case "$GRAMMAR" in ""|v1|v2) ;; *) echo "ERROR: --grammar must be v1|v2" >&2; exit 2 ;; esac
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" UNIT="$UNIT" GRAMMAR="$GRAMMAR" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, shutil, subprocess, sys, tempfile
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts
import postflight_rules

cwd = os.environ["CWD"]
unit_id = os.environ["UNIT"]
grammar_override = os.environ.get("GRAMMAR", "")
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def git(*a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)

PREFIX = git("rev-parse", "--show-prefix").stdout.strip()

uf = vault_layouts.find_unit_file(cwd, unit_id)
if not uf:
    print("ERROR: unit %s not found under any vault layout" % unit_id, file=sys.stderr)
    sys.exit(2)
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
    sys.exit(0)

# Grammar detection (SKILL.md pre-flight check 4): both forms coexisting → mixed
# halt (doc-literal); --grammar=v1|v2 is the documented escape hatch.
if grammar_override == "v1":
    v2_rules = []
elif grammar_override == "v2":
    lines = []
elif lines and v2_rules:
    print("MIXED GRAMMAR: unit %s carries both bulleted v1 rules and YAML-fenced v2 "
          "rules — halt hard_rule_mixed_grammar (migrate via /mega-sdd:migrate-rules "
          "or force one grammar with --grammar=v1|v2)" % unit_id, file=sys.stderr)
    sys.exit(4)
grammar = "v2" if v2_rules else "v1"

# ── Anti-laundering lifecycle ────────────────────────────────────────────────
# Once ANY bolt commit exists for this unit, the baseline is immutable: an
# existing artifact is KEPT byte-identical; an absent one is REFUSED (exit 7) —
# a baseline minted post-hoc could record the post-tamper sha and launder a
# DO_NOT_MODIFY/SIGNATURE violation past the recompute gate (the engine gives a
# present snapshot precedence over commit evidence). Same walk as the gate.
unit_commits = postflight_rules.walk_unit_commits(git, PREFIX, 300).get(unit_id, [])
if unit_commits:
    if os.path.isfile(target):
        if not quiet:
            print("preflight %s: bolt commits exist — existing baseline kept unchanged "
                  "(immutable) -> %s" % (unit_id, target))
        sys.exit(0)
    print("REFUSED (post-hoc): bolt commits already exist for %s and no preflight "
          "baseline is on disk — a baseline minted now could launder a Hard-rule "
          "violation. Proceed WITHOUT a baseline: the post-flight engine falls back "
          "to git commit evidence. Log this refusal in the bolt-report." % unit_id,
          file=sys.stderr)
    sys.exit(7)

entries = []

# ── v1 lines: classify with the SHARED STRICT/DIRECTIVE productions ──────────
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
                print("UNANCHORED: function %s not found in tracked source — halt "
                      "hard_rule_unanchored (rule: %s)" % (name, raw), file=sys.stderr)
                sys.exit(5)
            entries.append({"type": rtype, "function": name,
                            "signature_at_preflight": decl.split("{")[0].strip()})
        # NAMING_RULE / FILE_PRESENCE_RULE: no pre-snapshot by documented schema
        # (post-flight checks new files / final presence only).
        continue
    if postflight_rules.DIRECTIVE.match(raw):
        continue  # directive tier — attested at post-flight; nothing to snapshot
    print("UNPARSEABLE: line matches no v1 production and is not a directive — halt "
          "hard_rule_unparseable. Offending line: %s" % raw, file=sys.stderr)
    sys.exit(3)

# ── v2 ast-grep rules: parse-via-scan + audit snapshot ───────────────────────
if v2_rules:
    astgrep = shutil.which("ast-grep")
    if not astgrep:
        print("DEP MISSING: v2 (ast-grep YAML) Hard rules present but ast-grep is not "
              "on PATH — halt dep_missing (install: brew install ast-grep)",
              file=sys.stderr)
        sys.exit(6)
    for i, ry in enumerate(v2_rules):
        rid_m = re.search(r"^id:\s*(\S+)", ry, re.MULTILINE)
        rid = rid_m.group(1) if rid_m else "v2-rule-%d" % (i + 1)
        ry_norm, _globs = postflight_rules.normalize_v2_files(ry)
        with tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False) as tf:
            tf.write(ry_norm)
            tmp_rule = tf.name
        try:
            rr = subprocess.run([astgrep, "scan", "--rule", tmp_rule, "--json", cwd],
                                capture_output=True, text=True)
            if rr.returncode not in (0, 1):
                # parse-via-scan: a rejected rule is the unparseable halt,
                # stderr verbatim (ast-grep test --validate does not exist).
                print("UNPARSEABLE (v2): ast-grep rejected rule %s — halt "
                      "hard_rule_unparseable. stderr: %s"
                      % (rid, rr.stderr.strip()[:400]), file=sys.stderr)
                sys.exit(3)
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

head_sha = git("rev-parse", "HEAD").stdout.strip()
artifact = {
    "unit_id": unit_id,
    "snapshot_at": ts,
    "head_sha": head_sha,
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
sys.exit(0)
PYEOF
