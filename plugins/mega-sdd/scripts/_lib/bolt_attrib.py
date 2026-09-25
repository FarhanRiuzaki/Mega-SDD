"""bolt_attrib.py — which commits are a unit's OWN bolt commits (state anchor,
spec docs/superpowers/specs/2026-09-25-state-anchor-design.md §5 (b) step 3).

A commit c is unit U's own bolt commit when ALL hold:
  * c is not a merge;
  * the run-boundary gates attribute c to U: `postflight_rules.unit_of(subject,
    Unit-trailer atom) == U` — the SAME function B1/B3/B4 use (imported, never
    re-typed), so an exempted commit is always one those gates owe evidence for;
  * c's FULL message carries, as line-anchored matches, exactly one `Unit: U`
    line and exactly one `SDD-PROVENANCE: mega-sdd/execute-bolts unit=U` line,
    and names no other unit in either key (a multi-bolt squash is never own);
  * U is v5-keyed in the same candidate log: at least one of U's own-shaped
    commits carries `SDD-Acceptance: v5` (B4 keys per unit, so the controller's
    L0 follow-up commit — Unit + PROVENANCE, no Acceptance — still counts);
  * every path c changed hits U's target_files (the B3 glob matcher,
    basename fallback OFF), lies under <vault>/bolts/U/, or is B3-sanctioned.
Git's trailer parser alone is never trusted for the body lines: it reads only
the LAST paragraph, and real bolt commits put the SDD lines before a separate
Co-Authored-By paragraph (91 of 113 field bolt-commit commands).

sanctioned()/TEST_PAT/bound_vault_roots() are B3's predicate copied from the
validate-bolt-artifacts.sh heredocs (not importable there); a parity test pins
the copies until B3 imports this module.
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import postflight_rules  # noqa: E402  (unit_of + the B3 glob matcher)

TEST_PAT = re.compile(
    r"(?:^|/)(?:tests?|spec|specs|__tests__)/|_test\.go$|Test\.php$|(?:^|/)test_[^/]+\.py$|\.(?:spec|test)\.[jt]sx?$")
ACCEPTANCE_V5 = re.compile(r"(?im)^SDD-Acceptance:\s*v5\b")


def bound_vault_roots(root):
    """Real legacy *-bound vault roots (hold units/ or bolts/), project-relative with a
    trailing slash — same set as validate-bolt-artifacts.sh _bound_vault_roots()."""
    roots = set()
    for pat in (os.path.join(root, "*-bound"), os.path.join(root, "*", "*-bound"),
                os.path.join(root, "docs", "mega-sdd", "vaults", "*-bound")):
        for d in glob.glob(pat):
            if os.path.isdir(d) and (os.path.isdir(os.path.join(d, "units"))
                                     or os.path.isdir(os.path.join(d, "bolts"))):
                roots.add(os.path.relpath(d, root).replace(os.sep, "/").rstrip("/") + "/")
    return roots


def sanctioned(p, bound_roots):
    """B3 sanctioned extras: mega-sdd state/artifacts, vault trees, test files.
    `p` is project-relative."""
    if p.startswith(".mega-sdd/") or p.startswith("docs/mega-sdd/"):
        return True
    if any(p == r.rstrip("/") or p.startswith(r) for r in bound_roots):
        return True
    if TEST_PAT.search(p):
        return True
    return False


def hits_target(p, targets):
    """B3's target match: exact, or the glob matcher with the basename fallback OFF
    (a bare file name never sanctions a same-named file elsewhere)."""
    return any(p == t or postflight_rules._glob_match(p, t, basename_fallback=False) for t in targets)


def attributed_to(subject, unit_trailer, uid):
    """True when the run-boundary gates attribute the commit to `uid`."""
    return postflight_rules.unit_of(subject or "", unit_trailer or "") == uid


def body_names_unit(message, uid):
    """Exactly one `Unit: <uid>` and exactly one
    `SDD-PROVENANCE: mega-sdd/execute-bolts unit=<uid>` line, each a whole line,
    and no Unit / SDD-PROVENANCE line naming anything else."""
    u = re.escape(uid)
    n_unit = len(re.findall(r"(?m)^Unit:[ \t]*%s[ \t]*$" % u, message))
    n_prov = len(re.findall(r"(?m)^SDD-PROVENANCE:[ \t]*mega-sdd/execute-bolts unit=%s[ \t]*$" % u, message))
    n_any_unit = len(re.findall(r"(?m)^Unit:[ \t]*\S", message))
    n_any_prov = len(re.findall(r"(?m)^SDD-PROVENANCE:[ \t]*\S", message))
    return n_unit == 1 and n_prov == 1 and n_any_unit == 1 and n_any_prov == 1


def own_shaped(commit, uid):
    """Non-merge, attributed to uid by unit_of, identity lines in the body."""
    return (len(commit.get("parents") or []) == 1
            and attributed_to(commit.get("subject"), commit.get("trailer"), uid)
            and body_names_unit(commit.get("body") or "", uid))


def v5_keyed(commits, uid):
    """B4 keys per unit: any own-shaped commit of uid carrying SDD-Acceptance: v5."""
    return any(own_shaped(c, uid) and ACCEPTANCE_V5.search(c.get("body") or "") for c in commits)


def within_own(paths, targets, bolt_dir, bound_roots):
    """Every changed path (project-relative) hits a target, lies under the unit's bolt
    dir, or is B3-sanctioned. A path outside the project (None) is never own."""
    for p in paths:
        if p is None:
            return False
        if hits_target(p, targets) or p == bolt_dir or p.startswith(bolt_dir + "/"):
            continue
        if sanctioned(p, bound_roots):
            continue
        return False
    return True
