#!/usr/bin/env bash
# run-code-gates.sh — the single-call L0 code-gate executor for execute-bolts.
#
# WHY THIS EXISTS (spec §2c, 2026-07-30-token-and-latency-optimization.md)
# ------------------------------------------------------------------------
# The execute-bolts controller used to run the L0 floor as 9–13 sequential
# main-thread Bash turns per bolt attempt (plugin-root resolver, toolchain
# detection, per-tool format/lint/typecheck commands, then the four gate
# scripts) — re-run in full on every panel re-dispatch. This wrapper runs the
# SAME sequence in ONE call and emits ONE merged JSON: the exact payload the
# controller writes verbatim to <vault>/lens-inputs/U-XXX/l0-results.json for
# every review-panel lens prompt.
#
# WHAT IT DOES NOT DO: reimplement any gate. The five gate scripts are invoked
# as-is (their degradation paths — gitleaks runtime-failure → regex fallback,
# semgrep-absent → SKIP, offline registry → unverified WARNING — live INSIDE
# them and are untouched). This file only sequences, short-circuits, and merges.
#
# GATE ORDER (cheap → expensive, per references/code-gates.md):
#   toolchain detection (detect-toolchain.sh; detect, never impose)
#   1  format          detected check_cmd; on fail run fix_cmd then re-check
#   2  lint+typecheck  detected check_cmds                      (findings only)
#   3  secrets         secret-scan.sh --code         exit 1 → BLOCKING (always runs)
#   4  SAST            run-code-scan.sh              exit 2 → BLOCKING
#   5  new-dep exist   validate-new-deps.sh          exit 2 → BLOCKING (always runs)
#   6  dep-auth        validate-new-deps.sh --unit=  advisory, never blocks (one
#                      manifest-diff pass with gate 5 — v7 Fase 2 merge group 3)
#
# SHORT-CIRCUIT (the spec's hard constraint): a BLOCKING result STOPS the
# sequence — later gates are listed in `not_run[]` and their subprocesses are
# NEVER spawned. On a blocking run this wrapper does strictly LESS subprocess
# work than the per-turn flow it replaces, never more.
#
# GATE ACCOUNTING INVARIANT (review round 1): every gate appears in EXACTLY ONE
# of gates{ran:true} / skips[] / not_run[] on every exit-0/exit-1 path — a gate
# can never silently vanish from the record. Skips for gates that will not run
# (config-off, no --unit, unresolvable --unit) are recorded UP FRONT, before
# any gate executes, so a later short-circuit cannot drop them.
#
# UNKNOWN GATE EXIT CODES ARE NEVER "PASS" (review round 1 — Critical): the
# gate scripts call bare `python3` internally; on the documented WindowsApps
# alias-stub environment they exit 49 while this wrapper's own interpreter
# works. An rc outside a gate's documented set is:
#   secrets / new-dep (the always-run pair) → exit 2 — NOTHING certified;
#   SAST → a visible SKIP ("scan NOT performed"), never a clean pass;
#   dep-auth / detect-toolchain → a visible SKIP (advisory / detection tier).
#
# OPT-OUT PARITY: `--no-code-gates` (CLI) and `.mega-sdd/config.yaml`
# `code_gates: false` (TOP-LEVEL key only; first match wins — a nested
# `code_gates:` under another block never toggles the floor) both skip gates
# 1–2, 4 and 6. Gates 3 (secrets) and 5 (dep-existence) ALWAYS run — the
# critical + un-promptable pair; no flag or config disables them.
#
# PACK OVERRIDE: `--pack=<pack.md>` — when the pack carries a `## Toolchain`
# section (framework-conventions/_template.md: fenced yaml under the heading),
# its commands REPLACE detection for gates 1–2 (pack override > detection).
# A --pack that does not resolve or carries no parseable section is a VISIBLE
# note (never a silent fallback to detection).
#
# Usage:
#   run-code-gates.sh --cwd=<project-root> --base=<sha> --head=<sha>
#                     [--unit=<unit.md>] [--pack=<pack.md>] [--no-code-gates]
#
# stdout: ONE JSON object —
#   status (pass|blocked), halt (only when blocked: type/gate/details — the
#   controller adds unit/commit context per code-gates.md §Halt YAMLs),
#   gates{toolchain,format,lint_typecheck,secrets,sast,new_deps,dep_authorization},
#   skips[] (visible reasons — a SKIP is never silent), not_run[] (short-circuit
#   tail), config{}, range{} (RESOLVED 40-hex SHAs, never a moving ref),
#   written_by.
#
# Exit:
#   0  gates ran; NO blocking finding (non-blocking findings ride in the JSON)
#   1  BLOCKING finding — the JSON `halt` object carries the halt type
#      (secret_in_code | sast_critical_finding | dep_not_found); exit 1 is
#      emitted ONLY with that JSON present (an internal crash is exit 2)
#   2  usage / environment error (bad args, base/head unresolvable, an
#      always-run gate could not complete, internal error) — NOTHING was
#      certified; never treat as clean
#
# Timeouts: 120s per toolchain command, 300s per gate script — the bound rides
# on every subprocess call itself (the repo's bounded-subprocess law,
# tests/hooks/bounded-subprocess.test.sh; a process-group killpg variant was
# evaluated in review round 1 and REJECTED because it needs a bare Popen the
# law forbids). Disclosed residue: expiry kills the direct child only — an
# orphan grandchild of a timed-out toolchain command may briefly survive; the
# wrapper itself always returns within the bound. A toolchain timeout is a
# per-tool failure note (non-blocking); a SAST timeout is a visible SKIP; a
# secrets/new-dep timeout is exit 2.
#
# SPAWN BUDGET: constant wrapper overhead (this bash + one python) on top of
# the same children the per-turn flow spawned — minus the retired plugin-root
# resolver pipeline and minus one shell init per replaced Bash turn.

set -uo pipefail

CWD=""; BASE=""; HEAD=""; UNIT=""; PACK=""; NO_CODE_GATES=0; WRITE=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*)  CWD="${arg#*=}" ;;
    --base=*) BASE="${arg#*=}" ;;
    --head=*) HEAD="${arg#*=}" ;;
    --unit=*) UNIT="${arg#*=}" ;;
    --pack=*) PACK="${arg#*=}" ;;
    --no-code-gates) NO_CODE_GATES=1 ;;
    --write) WRITE=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
if [ -z "$CWD" ] || [ -z "$BASE" ] || [ -z "$HEAD" ]; then
  echo "usage: run-code-gates.sh --cwd=<project-root> --base=<sha> --head=<sha> [--unit=<unit.md>] [--pack=<pack.md>] [--no-code-gates]" >&2
  exit 2
fi
[ -d "$CWD" ] || { echo "ERROR: --cwd is not a directory: $CWD" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib/resolve-python.sh
. "$SCRIPT_DIR/_lib/resolve-python.sh"
if ! mega_sdd_python; then
  echo "ERROR: no usable python3 interpreter (see _lib/resolve-python.sh)" >&2
  exit 2
fi

git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "ERROR: --cwd is not a git repository: $CWD" >&2; exit 2; }
# Resolve refs to full SHAs NOW — the emitted range{} must pin commits, never a
# moving branch name the panel payload would then misrepresent.
BASE_SHA="$(git -C "$CWD" rev-parse --verify --quiet "${BASE}^{commit}")" \
  || { echo "ERROR: --base does not resolve to a commit in $CWD: $BASE" >&2; exit 2; }
HEAD_SHA="$(git -C "$CWD" rev-parse --verify --quiet "${HEAD}^{commit}")" \
  || { echo "ERROR: --head does not resolve to a commit in $CWD: $HEAD" >&2; exit 2; }

# Absolutize --unit against the CALLER's cwd (the wrapper runs gates with
# cwd=--cwd, which would silently re-anchor a relative path). A --unit that
# does not resolve is a VISIBLE skip downstream, never a silent enforced:false.
UNIT_MISSING=0
if [ -n "$UNIT" ]; then
  if [ -f "$UNIT" ]; then
    UNIT="$(cd "$(dirname "$UNIT")" && pwd)/$(basename "$UNIT")"
  else
    UNIT_MISSING=1
  fi
fi

export RCG_CWD="$CWD" RCG_BASE="$BASE_SHA" RCG_HEAD="$HEAD_SHA" RCG_UNIT="$UNIT" \
       RCG_UNIT_MISSING="$UNIT_MISSING" RCG_PACK="$PACK" \
       RCG_NO_CODE_GATES="$NO_CODE_GATES" RCG_SCRIPT_DIR="$SCRIPT_DIR" RCG_WRITE="$WRITE"

$MEGA_SDD_PY <<'PYEOF'
import json, os, re, subprocess, sys

TOOL_TIMEOUT = 120   # per detected toolchain command
GATE_TIMEOUT = 300   # per gate script

def run(argv, cwd, timeout):
    """Returns (rc, stdout, stderr, timed_out). rc is None on timeout.
    subprocess.run WITH timeout= is the repo's bounded-subprocess law
    (tests/hooks/bounded-subprocess.test.sh — every subprocess call carries the
    bound on the call itself). Known residue, disclosed: on expiry only the
    DIRECT child is killed — a grandchild a toolchain command backgrounded may
    briefly survive; the wrapper itself always returns within the bound."""
    try:
        p = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=timeout)
        return p.returncode, p.stdout.decode("utf-8", errors="replace"), p.stderr.decode("utf-8", errors="replace"), False
    except subprocess.TimeoutExpired:
        return None, "", "", True

def parse_json(s):
    try:
        return json.loads(s)
    except Exception:
        return None

def main():
    cwd   = os.environ["RCG_CWD"]
    base  = os.environ["RCG_BASE"]
    head  = os.environ["RCG_HEAD"]
    unit  = os.environ["RCG_UNIT"]
    unit_missing = os.environ["RCG_UNIT_MISSING"] == "1"
    pack  = os.environ["RCG_PACK"]
    sdir  = os.environ["RCG_SCRIPT_DIR"]
    no_flag = os.environ["RCG_NO_CODE_GATES"] == "1"

    # --- config read: .mega-sdd/config.yaml TOP-LEVEL `code_gates:` only ------
    # First match wins; an indented `code_gates:` nested under another block is
    # NOT this key (project-config.md documents a flat top-level schema).
    cfg_enabled = True
    try:
        with open(os.path.join(cwd, ".mega-sdd", "config.yaml"), encoding="utf-8", errors="replace") as f:
            for line in f:
                m = re.match(r"^code_gates:\s*[\"']?([A-Za-z]+)[\"']?\s*(#.*)?$", line)
                if m:
                    cfg_enabled = m.group(1).lower() not in ("false", "no", "off")
                    break
    except OSError:
        pass

    toolchain_on = cfg_enabled and not no_flag   # governs gates 1–2, 4, 6

    ORDER = ["format", "lint_typecheck", "secrets", "sast", "new_deps", "dep_authorization"]

    result = {
        "status": "pass",
        "gates": {},
        "skips": [],
        "not_run": [],
        "config": {"code_gates_enabled": cfg_enabled, "no_code_gates_flag": no_flag},
        "range": {"base": base, "head": head},
        "written_by": "run-code-gates.sh",
    }
    # Gates decided OFF up front (accounting invariant: recorded BEFORE any gate
    # runs, so a short-circuit can never drop them from the record).
    prerecorded = set()

    def skip_gate(g, reason):
        result["skips"].append({"gate": g, "reason": reason})
        result["gates"][g] = {"ran": False}
        prerecorded.add(g)

    def run_tool(cmd_str):
        return run(["bash", "-c", cmd_str], cwd, TOOL_TIMEOUT)

    def gate_script(name, argv):
        return run(["bash", os.path.join(sdir, name)] + argv, cwd, GATE_TIMEOUT)

    def die_env(msg):
        if result["gates"].get("format", {}).get("fix_applied"):
            print("WARN: gate 1 already ran fix_cmd — the working tree may carry formatting changes", file=sys.stderr)
        print("ERROR: " + msg, file=sys.stderr)
        sys.exit(2)

    def block(halt_type, gate_key, details):
        result["status"] = "blocked"
        result["halt"] = {"type": halt_type, "gate": gate_key, "details": details}
        idx = ORDER.index(gate_key)
        for g in ORDER[idx + 1:]:
            if g in prerecorded:
                continue  # already a visible skip — never double-listed
            result["not_run"].append(g)
        print(json.dumps(result, indent=2))
        sys.exit(1)

    # --- pack `## Toolchain` override (pack override > detection) -------------
    def pack_toolchain(path):
        """Parse the OPTIONAL `## Toolchain` yaml block from a framework pack.
        Returns a detect-toolchain-shaped dict, or None when absent/unparseable."""
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            return None
        in_sec = False; in_fence = False; keys = {}
        for line in text.splitlines():
            if re.match(r"^##\s+Toolchain\b", line):
                in_sec = True; continue
            if in_sec and re.match(r"^##\s+", line):
                break
            if not in_sec:
                continue
            if line.strip().startswith("```"):
                in_fence = not in_fence; continue
            if in_fence:
                m = re.match(r"^\s*(format_check_cmd|format_fix_cmd|lint_cmd|typecheck_cmd):\s*(.+?)\s*$", line)
                if m and not m.group(2).startswith("<"):
                    keys[m.group(1)] = m.group(2)
        if not keys:
            return None
        tc = {"formatters": [], "linters": [], "typecheckers": []}
        ev = os.path.basename(path) + " ## Toolchain"
        if "format_check_cmd" in keys:
            e = {"tool": "pack-override", "check_cmd": keys["format_check_cmd"], "evidence": ev}
            if "format_fix_cmd" in keys:
                e["fix_cmd"] = keys["format_fix_cmd"]
            tc["formatters"].append(e)
        if "lint_cmd" in keys:
            tc["linters"].append({"tool": "pack-override", "check_cmd": keys["lint_cmd"], "evidence": ev})
        if "typecheck_cmd" in keys:
            tc["typecheckers"].append({"tool": "pack-override", "check_cmd": keys["typecheck_cmd"], "evidence": ev})
        return tc

    # --- upfront skips (accounting invariant) ---------------------------------
    if not toolchain_on:
        reason = "--no-code-gates" if no_flag else "config code_gates: false"
        for g in ("format", "lint_typecheck", "sast", "dep_authorization"):
            skip_gate(g, "skipped: " + reason + " (secrets + dep-existence still run)")
        result["gates"]["toolchain"] = {"ran": False, "reason": reason}
    else:
        if unit_missing:
            skip_gate("dep_authorization", "--unit path does not resolve on disk — advisory gate not evaluated (never a silent enforced:false)")
        elif not unit:
            skip_gate("dep_authorization", "no --unit passed — advisory gate not evaluated")

    # --- toolchain detection + gates 1–2 --------------------------------------
    if toolchain_on:
        tc = None; tc_source = "detect"; pack_note = None
        if pack:
            tc = pack_toolchain(pack)
            if tc is not None:
                tc_source = "pack"
            else:
                pack_note = ("--pack requested but NOT engaged (file missing or no parseable fenced `## Toolchain` section) — "
                             "fell back to detection; fix the pack path/section if the override was intended")
                result["skips"].append({"gate": "toolchain", "reason": pack_note})
        if tc is None:
            rc, out, err, to = gate_script("detect-toolchain.sh", ["--cwd=" + cwd])
            tc = parse_json(out) if (rc == 0 and not to) else None
        if tc is None:
            result["gates"]["toolchain"] = {"ran": False, "reason": "detect-toolchain.sh failed or timed out"}
            for g in ("format", "lint_typecheck"):
                result["skips"].append({"gate": g, "reason": "toolchain detection failed — not evaluated (visible SKIP, not a clean pass)"})
                result["gates"][g] = {"ran": False}
        else:
            result["gates"]["toolchain"] = {
                "ran": True, "source": tc_source,
                "formatters": len(tc.get("formatters", [])),
                "linters": len(tc.get("linters", [])),
                "typecheckers": len(tc.get("typecheckers", [])),
            }
            if pack_note:
                result["gates"]["toolchain"]["pack_requested_not_engaged"] = True
            # Gate 1 — format (auto-fix + re-check; formatting is machine territory)
            formatters = tc.get("formatters", [])
            if not formatters:
                result["skips"].append({"gate": "format", "reason": "no formatter config detected (detect, never impose)"})
                result["gates"]["format"] = {"ran": False}
            else:
                entries = []; fix_applied = False
                for f in formatters:
                    rc, out, err, to = run_tool(f.get("check_cmd", "false"))
                    e = {"tool": f.get("tool"), "check_cmd": f.get("check_cmd"), "pass": rc == 0}
                    tail_src = out + err
                    if to:
                        e["pass"] = False; e["timeout"] = True
                    elif rc != 0 and f.get("fix_cmd"):
                        rcf, outf, errf, tof = run_tool(f["fix_cmd"])
                        fix_applied = True
                        e["fix_applied"] = True                      # fix_cmd was RUN
                        e["fix_rc"] = None if tof else rcf           # ...and how it exited
                        rc2, out2, err2, to2 = run_tool(f["check_cmd"])
                        e["pass"] = (rc2 == 0) and not to2
                        e["fixed"] = e["pass"]
                        tail_src = out2 + err2                       # the re-check's output, not the first check's
                    if not e["pass"]:
                        e["output_tail"] = tail_src[-1500:]
                    entries.append(e)
                result["gates"]["format"] = {"ran": True, "results": entries, "fix_applied": fix_applied}
            # Gate 2 — lint + typecheck (failures are findings, non-blocking)
            checkers = tc.get("linters", []) + tc.get("typecheckers", [])
            if not checkers:
                result["skips"].append({"gate": "lint_typecheck", "reason": "no linter/typechecker config detected (detect, never impose)"})
                result["gates"]["lint_typecheck"] = {"ran": False}
            else:
                entries = []; findings = 0
                for c in checkers:
                    rc, out, err, to = run_tool(c.get("check_cmd", "false"))
                    e = {"tool": c.get("tool"), "check_cmd": c.get("check_cmd"), "pass": (rc == 0) and not to}
                    if to:
                        e["timeout"] = True
                    if not e["pass"]:
                        findings += 1
                        e["output_tail"] = (out + err)[-1500:]
                    entries.append(e)
                result["gates"]["lint_typecheck"] = {"ran": True, "results": entries, "findings": findings}

    # --- gate 3 — secrets (ALWAYS runs; rc set {0,1} — anything else is exit 2)
    rc, out, err, to = gate_script("secret-scan.sh", ["--code", "--base=" + base, "--head=" + head, "--cwd=" + cwd])
    if to:
        die_env("secret gate (secret-scan.sh --code) timed out — the always-run gate was NOT completed; never treat as clean")
    if rc not in (0, 1):
        die_env("secret-scan.sh --code exited %s — the always-run gate did not complete; never treat as clean. stderr: %s"
                % (rc, err.strip()[-500:] or "(empty)"))
    data = parse_json(out)
    result["gates"]["secrets"] = {"ran": True, "rc": rc, "result": data}
    if rc == 1:
        block("secret_in_code", "secrets", data)

    # --- gate 4 — SAST (rc set {0,1,2}; 2+JSON blocks; anything else is a SKIP)
    if toolchain_on:
        rc, out, err, to = gate_script("run-code-scan.sh", ["--base=" + base, "--head=" + head, "--cwd=" + cwd])
        if to:
            result["skips"].append({"gate": "sast", "reason": "run-code-scan.sh timed out — scan NOT performed (visible SKIP, never reported clean)"})
            result["gates"]["sast"] = {"ran": False}
        elif rc not in (0, 1, 2):
            result["skips"].append({"gate": "sast", "reason": "run-code-scan.sh exited %s — scan NOT performed (visible SKIP, never reported clean). stderr: %s"
                                    % (rc, err.strip()[-300:] or "(empty)")})
            result["gates"]["sast"] = {"ran": False, "rc": rc}
        else:
            data = parse_json(out)
            if rc == 2 and data is None:
                die_env("run-code-scan.sh failed: " + (err.strip() or "bad invocation"))
            result["gates"]["sast"] = {"ran": True, "rc": rc, "result": data}
            if rc == 2:
                block("sast_critical_finding", "sast", data)

    # --- gates 5+6 — ONE manifest-diff pass (v7 Fase 2 merge group 3) --------
    # gate 5 (new-dep existence) ALWAYS runs; gate 6 (dep authorization,
    # advisory) rides the same invocation via --unit when its preconditions
    # hold — the exit code stays gate-5-only (0/2), authorization never blocks.
    run_auth = bool(toolchain_on and unit and not unit_missing)
    vnd_args = ["--base=" + base, "--head=" + head, "--cwd=" + cwd]
    if run_auth:
        vnd_args.append("--unit=" + unit)
    rc, out, err, to = gate_script("validate-new-deps.sh", vnd_args)
    if to:
        die_env("new-dep gate (validate-new-deps.sh) timed out — the always-run gate was NOT completed; never treat as clean")
    if rc not in (0, 2):
        die_env("validate-new-deps.sh exited %s — the always-run gate did not complete; never treat as clean. stderr: %s"
                % (rc, err.strip()[-500:] or "(empty)"))
    data = parse_json(out)
    if rc == 2 and data is None:
        die_env("validate-new-deps.sh failed: " + (err.strip() or "bad invocation"))
    gate5 = dict(data) if isinstance(data, dict) else data
    auth = gate5.pop("authorization", None) if isinstance(gate5, dict) else None
    result["gates"]["new_deps"] = {"ran": True, "rc": rc, "result": gate5}
    if rc == 2:
        block("dep_not_found", "new_deps", gate5)

    # gate-6 accounting: same shape as before the merge (ran:True + result,
    # or a recorded skip — a gate can never silently vanish).
    if run_auth:
        if auth is not None:
            result["gates"]["dep_authorization"] = {"ran": True, "result": auth}
        else:
            result["skips"].append({"gate": "dep_authorization", "reason": "authorization section missing from validate-new-deps.sh output (advisory gate — recorded, never blocks)"})
            result["gates"]["dep_authorization"] = {"ran": False}

    # F-07/F-26 (spec 2026-08-30 §3): --write persists the merged record as
    # <vault>/lens-inputs/U-XXX/l0-results.json — the controller used to hand-
    # write it (7/36 on the field run, one edited by hand), so the L0 record
    # is now script-written, stamped, and hook-guarded like the other evidence.
    _write = os.environ.get("RCG_WRITE") == "1"
    _u = os.environ.get("RCG_UNIT", "")
    if _write and _u and os.path.isfile(_u):
        sys.path.insert(0, os.path.join(os.environ["RCG_SCRIPT_DIR"], "_lib"))
        import plugin_meta
        ud = os.path.dirname(os.path.abspath(_u))
        if os.path.basename(ud) == "units":
            uid = os.path.splitext(os.path.basename(_u))[0]; vault_root = os.path.dirname(ud)
        else:
            uid = os.path.basename(ud); vault_root = os.path.dirname(os.path.dirname(ud))
        try:
            _fm = open(_u, encoding="utf-8", errors="replace").read()
            _m = re.search(r"(?m)^unit_id:\s*[\"']?(U-[A-Za-z0-9_-]+)", _fm)
            if _m:
                uid = _m.group(1)
        except OSError:
            pass
        rec = dict(result)
        rec["unit_id"] = uid
        rec.update(plugin_meta.stamp(os.environ["RCG_SCRIPT_DIR"]))
        try:
            ldir = os.path.join(vault_root, "lens-inputs", uid)
            os.makedirs(ldir, exist_ok=True)
            tgt = os.path.join(ldir, "l0-results.json")
            tmp = tgt + ".tmp.%d" % os.getpid()
            with open(tmp, "w") as fh:
                json.dump(rec, fh, indent=2)
            os.replace(tmp, tgt)
            result["l0_results_path"] = tgt
        except OSError as e:
            result["skips"].append({"gate": "l0_results_write", "reason": "could not write l0-results.json: %s" % e})
    elif _write:
        result["skips"].append({"gate": "l0_results_write", "reason": "--write needs a resolvable --unit path"})
    print(json.dumps(result, indent=2))
    sys.exit(0)

try:
    main()
except SystemExit:
    raise
except Exception as e:  # crash is NEVER exit 1 (that would read as a blocking finding)
    print("ERROR: run-code-gates.sh internal error: %r" % (e,), file=sys.stderr)
    sys.exit(2)
PYEOF
rc=$?
case "$rc" in
  0|1|2) exit "$rc" ;;
  *) echo "ERROR: run-code-gates.sh internal error (python exited $rc)" >&2; exit 2 ;;
esac
