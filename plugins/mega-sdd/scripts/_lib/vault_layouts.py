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
import os

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


def decision_dirs(cwd):
    """Every `<vault>/decisions/` dir across all layouts (plus the one-level-nested
    shape the PBT citation check historically accepted), deduped."""
    got = []
    for pre in vault_prefixes(cwd):
        got.extend(glob.glob(os.path.join(pre, "decisions")))
    got.extend(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "*", "decisions")))
    return sorted({os.path.realpath(p) for p in got if os.path.isdir(p)})
