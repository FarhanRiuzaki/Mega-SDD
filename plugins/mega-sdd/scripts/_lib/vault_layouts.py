"""vault_layouts.py — single source for every vault layout the validators accept.

S6 EB-VAL-2: the three validate-bolt-artifacts modes discovered only the canonical
`.mega-sdd/vaults/*` layout while validate-unit-spec.sh discover_units() (S5R-3)
covers 10 patterns including `docs/mega-sdd/vaults/**` and `*-bound/` siblings —
so legacy-layout projects failed B1/orphan OPEN and B2 permanently false-CLOSED.
This module mirrors that pattern list; a pin test (tests/god-review-s6) asserts
parity against validate-unit-spec.sh so the two can never drift apart again.

Consumers import via:  sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
"""
import glob
import json
import os
import re

# One prefix per vault-root layout; `<prefix>/units/...` and `<prefix>/bolts/...`
# hang off each. Mirrors validate-unit-spec.sh discover_units() (the *-bound
# entries under docs/mega-sdd/vaults are subsumed by the `*` glob but kept
# explicit there; realpath-dedup makes the overlap harmless).
def vault_prefixes(cwd):
    return (
        os.path.join(cwd, ".mega-sdd", "vaults", "*"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*"),
        os.path.join(cwd, "*-bound"),
        os.path.join(cwd, "*", "*-bound"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*-bound"),
    )


def unit_files(cwd):
    """Every unit file across all layouts (both U-*.md and U-*/unit.md shapes),
    realpath-deduped and sorted — same contract as discover_units()."""
    got = []
    for pre in vault_prefixes(cwd):
        got.extend(glob.glob(os.path.join(pre, "units", "U-*.md")))
        got.extend(glob.glob(os.path.join(pre, "units", "U-*", "unit.md")))
    return sorted({os.path.realpath(p) for p in got})


def find_unit_file(cwd, uid):
    """First unit file for `uid` across all layouts, or None."""
    for pre in vault_prefixes(cwd):
        for pat in (os.path.join(pre, "units", uid + ".md"),
                    os.path.join(pre, "units", uid, "unit.md")):
            g = sorted(glob.glob(pat))
            if g:
                return g[0]
    return None


def find_bolt_artifact(cwd, uid, name):
    """First `<vault>/bolts/<uid>/<name>` across all layouts, or None."""
    for pre in vault_prefixes(cwd):
        g = sorted(glob.glob(os.path.join(pre, "bolts", uid, name)))
        if g:
            return g[0]
    return None


def batch_suite_files(cwd):
    """Every `<vault>/bolts/_batch-suite.json` across all layouts, deduped."""
    got = []
    for pre in vault_prefixes(cwd):
        got.extend(glob.glob(os.path.join(pre, "bolts", "_batch-suite.json")))
    return sorted({os.path.realpath(p) for p in got})


def inflight_units(cwd):
    """Units whose bolt pipeline is legitimately IN FLIGHT, sorted by id.

    In-flight ⇔ `<vault>/bolts/U-XXX/dispatch-prompt.md` exists AND
    `postflight.json` is absent or OLDER than it. dispatch-prompt is the FIRST
    artifact of a bolt run (build-dispatch-prompt.sh writes it at dispatch);
    postflight.json is the LAST (the per-unit pipeline ends on the post-flight
    scan). The window between them is a unit that is running — its commit may
    exist while its panel / fix round / evidence writers have not run yet.

    Two consumers, ONE definition (spec 2026-08-30 §1.1 + §1.3):
      * the in-run execute-bolts gate (a bolt-implementer Agent dispatch) drops
        B1/B4/orphan issues for these units — their evidence is pending by
        construction, not missing;
      * the wave commit rail denies sweeping git verbs (`add -A`, `commit -a`,
        `--amend`, `stash`, `reset --hard`) while any unit is in flight — a
        sibling's half-written files must never ride an unrelated commit.
    A unit dispatched by hand (no dispatch-prompt.md) is NEVER in flight: it is
    evaluated in full, which is exactly the class the field gate caught."""
    got = set()
    for pre in vault_prefixes(cwd):
        for dp in glob.glob(os.path.join(pre, "bolts", "U-*", "dispatch-prompt.md")):
            bd = os.path.dirname(dp)
            uid = os.path.basename(bd)
            pf = os.path.join(bd, "postflight.json")
            try:
                dp_m = os.path.getmtime(dp)
                pf_m = os.path.getmtime(pf) if os.path.isfile(pf) else None
            except OSError:
                continue
            if pf_m is None or pf_m < dp_m:
                got.add(uid)
    return sorted(got)


def parallel_max(cwd, default=4):
    """`parallel_max:` from .mega-sdd/config.yaml — the execute-bolts in-flight
    cap (references/project-config.md). Top-level key only, first match wins,
    absent / unreadable / non-integer → default 4 (the value every controller
    run has used; the "default 5" the fan-out prose once carried was a doc
    drift, research/2026-09-15-v8-p3-report.md §2c.5)."""
    try:
        with open(os.path.join(cwd, ".mega-sdd", "config.yaml"),
                  encoding="utf-8", errors="replace") as f:
            for ln in f:
                m = re.match(r"^parallel_max:\s*(\d+)\s*(?:#.*)?$", ln)
                if m:
                    return max(1, int(m.group(1)))
    except OSError:
        pass
    return default


def _json_status_pass(path):
    try:
        with open(path, encoding="utf-8") as f:
            return str(json.load(f).get("status") or "").lower() == "pass"
    except (OSError, ValueError, AttributeError):
        return False


def panel_pending_units(cwd):
    """Units whose blind panel is legitimately PENDING, oldest dispatch first
    (v8 P3, research/2026-09-15-v8-p3-report.md §2 — the measured serializer).

    MEASURED on the clinic lite arm: the controller ran cap-sized slices with a
    full barrier (45 % of the net bolt-stage with ZERO implementers running,
    mean in-flight 1.46 of cap 4) because `inflight_units` ends at
    postflight.json — under lite the detect-after pipeline runs the moment the
    implementer returns, so a unit left "in flight" BEFORE its panel merged and
    the F-07 panel-evidence gate then read its not-yet-merged ledger as MISSING
    and denied every next bolt-implementer dispatch. Panel-pending ⇔ ALL of:
      * `<vault>/bolts/U-XXX/dispatch-prompt.md` exists (a real dispatch);
      * `postflight.json` AND `acceptance.json` are status pass AND newer than
        the dispatch-prompt (the detect-after pipeline ran for THIS dispatch);
      * `<vault>/lens-inputs/U-XXX/l0-results.json` is script-written
        (`written_by: run-code-gates.sh`) — L0 is synchronous, never pending;
      * NO `findings.json` ledger yet (the panel is running / about to merge).
    The in-run gate drops `panel_evidence_missing` for these units ONLY, and
    only while at most `parallel_max` units are pending (pipeline depth ≤ cap);
    `l0_evidence_missing` is never dropped; the run boundary (Skill entry, Stop
    hook) still enforces every ledger. A hand-dispatched unit (no
    dispatch-prompt) is never pending — it is evaluated in full."""
    got = []
    for pre in vault_prefixes(cwd):
        for dp in glob.glob(os.path.join(pre, "bolts", "U-*", "dispatch-prompt.md")):
            bd = os.path.dirname(dp)
            uid = os.path.basename(bd)
            vault = os.path.dirname(os.path.dirname(bd))
            if os.path.isfile(os.path.join(bd, "findings.json")):
                continue
            pf = os.path.join(bd, "postflight.json")
            ac = os.path.join(bd, "acceptance.json")
            if not (os.path.isfile(pf) and os.path.isfile(ac)):
                continue
            try:
                dp_m = os.path.getmtime(dp)
                if os.path.getmtime(pf) < dp_m or os.path.getmtime(ac) < dp_m:
                    continue
            except OSError:
                continue
            if not (_json_status_pass(pf) and _json_status_pass(ac)):
                continue
            l0 = os.path.join(vault, "lens-inputs", uid, "l0-results.json")
            try:
                with open(l0, encoding="utf-8") as f:
                    if json.load(f).get("written_by") != "run-code-gates.sh":
                        continue
            except (OSError, ValueError, AttributeError):
                continue
            got.append((dp_m, uid))
    return [uid for _, uid in sorted(got)]


def decision_dirs(cwd):
    """Every `<vault>/decisions/` dir across all layouts (plus the one-level-nested
    shape the PBT citation check historically accepted), deduped."""
    got = []
    for pre in vault_prefixes(cwd):
        got.extend(glob.glob(os.path.join(pre, "decisions")))
    got.extend(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "*", "decisions")))
    return sorted({os.path.realpath(p) for p in got if os.path.isdir(p)})
