#!/usr/bin/env bash
# derive-exec-plan.sh — the run-start CONFLICT gate and plan generator of the inline `execute-bolts` run (the default), zero model
# tokens (spec docs/superpowers/specs/2026-09-27-v9-simplification-design.md §8.1; skills/execute-bolts/references/inline-run.md).
#
#   derive-exec-plan.sh --cwd=<root> --vault=<vault> [--units=all|U-001,…] [--pending | --rebind-wip | --retire [--dry-run]] [--quiet]
#
# done       derive-ready-units.sh `done`, or _lib/exec_units.done (the rule the run-boundary scan uses).
# --pending  ONE JSON line {"pending":[…]}: not done, not `status: superseded`, topological — the list the
#            controller re-binds up front. Writes nothing.
# --rebind-wip  the close, before its evidence commit: re-binds each unit with an open own_wip CONFLICT (a resume's own work,
#            done since: CONFIRMED) → {"rebound":[…]}; a CONFLICT left, or named by a `Close: halt` ledger line → exit 1 + halt
#            {scope: close} + that line. --retire: the same (--dry-run: no re-bind), then removes plans, ledgers, workspaces.
# open run   a plan whose Run base is HEAD or an ancestor of it: the default mode returns it ("resumed":
#            true) and never regenerates it — a compaction, a re-run or a new session continues THIS run.
# default    candidates = pending ∩ --units, topological. A candidate is QUARANTINED by the SAME
#            predicates the per-dispatch gate applies (`via` = the depends_on unit that carried it):
#              binding_conflict     validate-handoff-binding-units.sh --units=<candidates> drops it, or its
#                                   binding.json has an open CONFLICT or is unparseable. Not blocking: an
#                                   fs_must_exist CONFLICT on a path an in-scope ancestor creates (`deferred`
#                                   to the task's re-bind) and an `own_wip` one (the unit's own uncommitted work).
#              quarantine_recorded  derive-ready-units.sh lists it (write-unit-quarantine.sh)
#              binding_stale        _lib/freshness.gate_check, the dispatch gate's own function
#              depends_on_quarantined  a depends_on unit is quarantined, or neither done nor a candidate
#            halt {type: binding_conflict}: a validator drop with no unit_id, or nothing left in scope while a
#            quarantine is a binding_conflict (otherwise exit 1 with halt null).
# Writes     <vault>/bolts/_exec-plan-<head12>.md + its built-in ledger _inline-ledger-<head12>.md (identity
#            line); a stale plan and its ledger are removed, all of them on exit 1. The plan: one `## Task N:
#            U-XXX — <title>` per unit (superpowers writing-plans), pointing at the unit file, then `## After
#            the last task` (the close, in the last task's brief). A never-committed in-scope unit's leftover
#            review-tier.json is renamed review-tier.retired.json. The validator rewrites .validation-blockers.json.
# stdout     ONE JSON line: schema exec-plan/1, vault, plan, run_base, in_scope, quarantined, deferred, done, halt (+ resumed).
# Exit 0 = plan written, resumed, re-bound or retired · 1 = nothing executable (no plan), or a CONFLICT left at the
# close · 2 = usage / cycle / unreadable input / a failed re-bind.
set -u
CWD="."; VAULT=""; UNITS="all"; MODE=""; QUIET=0; DRY=0
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --units=*) UNITS="${arg#*=}" ;;
  --pending|--retire|--rebind-wip) MODE="${arg#--}" ;; --quiet) QUIET=1 ;; --dry-run) DRY=1 ;;
  *) echo "usage: derive-exec-plan.sh --cwd=<root> --vault=<vault> [--units=…] [--pending | --rebind-wip | --retire [--dry-run]] [--quiet]" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT/units" ] || { echo "usage: --vault=<dir with units/> required" >&2; exit 2; }
[ -d "$CWD" ] || { echo "usage: --cwd=<existing project root> required" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
V_CWD="$CWD" V_VAULT="$VAULT" V_UNITS="${UNITS:-all}" V_MODE="$MODE" V_QUIET="$QUIET" V_DRY="$DRY" V_SCRIPTS="$SCRIPT_DIR" \
  python3 - <<'PYEOF'
import glob, heapq, json, os, re, shlex, shutil, subprocess, sys

E = os.environ
root, vault, scripts = os.path.abspath(E["V_CWD"]), os.path.abspath(E["V_VAULT"]), E["V_SCRIPTS"]
BOLTS = os.path.join(vault, "bolts")


def die(msg):
    print("derive-exec-plan: %s" % msg, file=sys.stderr)
    sys.exit(2)


sys.path.insert(0, os.path.join(scripts, "_lib"))
try:
    import exec_units as xu
    import freshness as fr
    from plugin_meta import plugin_version
    from postflight_rules import unit_of
    VERSION = plugin_version(os.path.join(scripts, "_lib"))
except Exception as e:  # noqa: BLE001 — a missing library is unreadable input: fail closed
    die("cannot load the plugin libraries (%s)" % e)


def natkey(u):
    return [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", u)]


def run(args, timeout=180):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except (subprocess.TimeoutExpired, OSError):
        return None


def git_ok(*a):
    r = run(["git", "-C", root, *a], 20)
    return r.stdout.strip() if r and r.returncode == 0 else None


def open_conflicts(u):  # the open CONFLICT claims of a unit's binding.json ([] without one); None = unparseable
    bj = os.path.join(BOLTS, u, "binding.json")
    try:
        return [c for c in (json.load(open(bj, encoding="utf-8"))["claims"] if os.path.isfile(bj) else [])
                if c.get("verdict") == "CONFLICT" and not c.get("resolution")]
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return None


if E["V_MODE"] in ("rebind-wip", "retire"):  # the close: own_wip re-bind + check, then (--retire) the next run plans fresh
    ledgers = glob.glob(os.path.join(BOLTS, "_inline-ledger-*.md"))
    held = {u for lg in ledgers for ln in open(lg, encoding="utf-8", errors="replace") if ln.startswith("Close: halt ") for u in ln.split()[3:]}
    wip = [] if E["V_DRY"] == "1" else sorted((u for u in (os.path.basename(os.path.dirname(b)) for b in glob.glob(os.path.join(
        BOLTS, "U-*", "binding.json"))) if any(c.get("own_wip") for c in open_conflicts(u) or [])), key=natkey)
    out = dict({"rebound": wip}, **({"retired": []} if E["V_MODE"] == "retire" else {}))
    if wip:  # never carried open: the re-bind re-verdicts a done unit's own work
        r = run(["bash", os.path.join(scripts, "rebind-units.sh"), "--cwd=" + root, "--vault=" + vault, "--units=" + ",".join(wip)])
        if not r or r.returncode not in (0, 4):
            die("rebind-units.sh --units=%s failed (exit %s) — nothing retired" % (",".join(wip), r.returncode if r else "none"))
        out["text_pending"] = int((re.findall(r'"text_pending": (\d+)', r.stdout) or [0])[-1])
    left = {u: ids for u in sorted(set(wip) | held, key=natkey) for oc in [open_conflicts(u)] for ids in [["binding.json unparseable"]
            if oc is None else sorted((str(c.get("id")) for c in oc if not c.get("own_wip")), key=natkey)] if ids}
    if left:  # never closed over: the ledger names it until a human decides it (resolve-oq --binding)
        [open(lg, "a", encoding="utf-8").write("Close: halt binding_conflict %s\n" % " ".join(left)) for lg in ledgers if set(left) - held]
        out["halt"] = {"type": "binding_conflict", "scope": "close", "units": left, "next_action": "resolve-oq --binding, then this close "
                       "step again", "keterangan": "CONFLICT tersisa setelah re-bind: putuskan via resolve-oq --binding, lalu ulangi langkah ini"}
    elif E["V_MODE"] == "retire":
        out["retired"] = gone = sorted(glob.glob(os.path.join(BOLTS, "_exec-plan-*.md")) + ledgers)
        top = os.path.realpath(git_ok("rev-parse", "--show-toplevel") or root)
        ids = {x for p in gone for x in (os.path.relpath(os.path.realpath(p), top), os.path.realpath(p))}
        gone += [os.path.dirname(m) for m in glob.glob(os.path.join(top, ".superpowers", "sdd", "*", "plan-path"))
                 if open(m, encoding="utf-8", errors="replace").read().strip() in ids]
        for p in gone:
            shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    print(json.dumps(out))
    sys.exit(1 if left else 0)

units = {}
for uid, p in xu.unit_files(vault).items():
    try:
        units[uid] = xu.parse(p)
    except OSError as e:
        die("cannot read %s (%s)" % (p, e))
if not units:
    die("no units under %s/units" % vault)
r = run(["bash", os.path.join(scripts, "derive-ready-units.sh"), "--cwd=" + root, "--vault=" + vault])
try:
    ready = json.loads(r.stdout.strip().splitlines()[-1])
except (AttributeError, ValueError, IndexError):
    die("derive-ready-units.sh gave no readable verdict — fail closed")
done = {u for u in units if u in set(ready.get("done") or []) or xu.done(root, vault, u, units)}
pending = set(units) - done - {u for u, d in units.items() if d["status"] == "superseded"}

# ── topological order of the pending units (ties by unit id); a cycle is exit 2 ──
indeg = {u: len(set(units[u]["deps"]) & pending) for u in pending}
heap = [(natkey(u), u) for u in pending if not indeg[u]]
heapq.heapify(heap)
order = []
while heap:
    u = heapq.heappop(heap)[1]
    order.append(u)
    for c in pending:
        if u in units[c]["deps"]:
            indeg[c] -= 1
            if not indeg[c]:
                heapq.heappush(heap, (natkey(c), c))
if len(order) != len(pending):
    die("depends_on cycle among %s — fix the units' depends_on" % ", ".join(sorted(pending - set(order), key=natkey)))
if E["V_MODE"] == "pending":
    print(json.dumps({"pending": order}))
    sys.exit(0)

want = [u.strip() for u in E["V_UNITS"].split(",") if u.strip() and u.strip() != "all"]
if set(want) - set(units):
    die("unknown unit(s) %s under %s/units" % (",".join(sorted(set(want) - set(units))), vault))
cands = [u for u in order if not want or u in want]
head = git_ok("rev-parse", "HEAD") or ""
head = head if re.fullmatch(r"[0-9a-f]{40}", head) else ""
PLAN = os.path.join(BOLTS, "_exec-plan-%s.md" % (head[:12] or "nohead"))
LEDGER = os.path.join(BOLTS, "_inline-ledger-%s.md" % (head[:12] or "nohead"))
res = {"schema": "exec-plan/1", "vault": vault, "plan": None, "run_base": head or None, "in_scope": [],
       "quarantined": [], "deferred": {}, "done": sorted(done, key=natkey), "halt": None}
HALT = {"type": "binding_conflict", "next_action": "resolve via resolve-oq --binding (write-unit-binding.sh --resolve="
        "<claim-id>=KEEP_VAULT|KEEP_CODE|SPLIT|DEFER --by=user), then re-run the up-front bind",
        "keterangan": "CONFLICT memblokir run ini — pilih KEEP_VAULT / KEEP_CODE / SPLIT lewat resolve-oq --binding, "
                      "lalu jalankan ulang bind di awal"}


def finish(code):
    for old in glob.glob(os.path.join(BOLTS, "_exec-plan*.md")) + glob.glob(os.path.join(BOLTS, "_inline-ledger*.md")):
        if code or old not in (PLAN, LEDGER):
            os.remove(old)  # a stale plan (and its ledger) never outlives the verdict that voided it
    if E["V_QUIET"] != "1":
        print(json.dumps(res))
    sys.exit(code)


for old in sorted(glob.glob(os.path.join(BOLTS, "_exec-plan-*.md"))):  # an open run is resumed, never re-planned
    txt = open(old, encoding="utf-8", errors="replace").read()
    rb = (re.findall(r"(?m)^\*\*Run base:\*\* `([0-9a-f]{40})`", txt) or [""])[0]
    if head and rb and (rb == head or git_ok("merge-base", "--is-ancestor", rb, head) is not None):
        res.update(plan=old, run_base=rb, resumed=True, in_scope=re.findall(r"(?m)^## Task \d+: (U-[\w.-]+) — ", txt))
        print(json.dumps(res)) if E["V_QUIET"] != "1" else None
        sys.exit(0)
if not cands:
    finish(1)

# ── the CONFLICT gate at run start: the per-dispatch validator over every candidate ──
r = run(["bash", os.path.join(scripts, "validate-handoff-binding-units.sh"), "--cwd=" + root, "--units=" + ",".join(cands)])
try:
    drops = json.loads(r.stdout).get("drops") or [] if r and r.returncode in (0, 1) else None
except (ValueError, AttributeError):
    drops = None
if drops is None:
    die("validate-handoff-binding-units.sh gave no readable verdict — fail closed")
if any(not d.get("unit_id") for d in drops):
    res["halt"] = dict(HALT, scope="run", drops=[d.get("conflict_id") or d.get("type") for d in drops if not d.get("unit_id")][:10])
    finish(1)
dropped = {}
for d in drops:
    dropped.setdefault(d["unit_id"], set()).add(str(d.get("conflict_id") or d.get("type")))


def ancestors(u, seen):
    for a in units[u]["deps"]:
        if a in units and a not in seen:
            seen.add(a)
            ancestors(a, seen)
    return seen


quar, deferred, recorded = {}, {}, set(ready.get("quarantined") or [])
for u in cands:  # topological: an ancestor is decided before its dependents
    via = next((a for a in sorted(set(units[u]["deps"]), key=natkey) if a not in done and (a in quar or a not in cands)), None)
    opn = open_conflicts(u)  # None = unparseable: fail closed
    creates = {t["path"] for a in ancestors(u, set()) if a in cands and a not in quar
               for t in units[a]["targets"] if t["operation"] == "create"}
    dfr = sorted({str(c.get("id")) for c in opn or [] if c.get("kind") == "fs_must_exist" and xu.pnorm(c.get("expect")) in creates}, key=natkey)
    wip = {str(c.get("id")) for c in opn or [] if c.get("own_wip")}  # the unit's own uncommitted work (a resume)
    blocking = sorted(({str(c.get("id")) for c in opn or []} | dropped.get(u, set())) - set(dfr) - wip, key=natkey)
    try:
        why = None if (opn is None or blocking or u in recorded or via) else fr.gate_check(root, vault, u, None)[0]
    except Exception:  # noqa: BLE001 — a git failure: fail closed, as the dispatch gate does
        why = "not_evaluated"
    rec = ({"reason": "binding_conflict", "conflict_ids": blocking or ["binding.json unparseable"]} if opn is None or blocking
           else {"reason": "quarantine_recorded"} if u in recorded
           else {"reason": "binding_stale", "freshness": why} if why
           else {"reason": "depends_on_quarantined"} if via else None)
    if rec:
        quar[u] = dict({"unit": u}, **rec, **({"via": via} if via else {}))
    elif dfr:
        deferred[u] = dfr
res["quarantined"] = [quar[u] for u in cands if u in quar]
res["deferred"] = deferred
res["in_scope"] = in_scope = [u for u in cands if u not in quar]
if not in_scope:
    bc = [q["unit"] for q in res["quarantined"] if q["reason"] == "binding_conflict"]
    if bc:
        res["halt"] = dict(HALT, scope="all_units", units=bc)
    finish(1)

# an earlier per-dispatch attempt's panel obligation (review-tier.json) never binds a unit with no commit
rts = [u for u in in_scope if os.path.isfile(os.path.join(BOLTS, u, "review-tier.json"))]
lg = run(["git", "-C", root, "log", "--format=%x01%s%x02%(trailers:key=Unit,valueonly,separator=%x2C)", "-300", "--", "."], 60) if rts else None
if lg and lg.returncode == 0:
    bolted = {unit_of(*(c.split("\x02") + [""])[:2]) for c in lg.stdout.split("\x01")[1:]}
    for u in set(rts) - bolted:
        os.replace(os.path.join(BOLTS, u, "review-tier.json"), os.path.join(BOLTS, u, "review-tier.retired.json"))

# ── the plan: paragraphs joined by a blank line ──
q = shlex.quote


def sh(script, *args):
    return "bash %s %s" % (q(os.path.join(scripts, script)), " ".join(args))


rel_vault, base = os.path.relpath(vault, root), head or "<the HEAD at run start>"
spec = ["context `%s`" % os.path.join(vault, "context.md"), "units `%s/`" % os.path.join(vault, "units")]
try:
    spec += ["PRD `%s`" % json.load(open(os.path.join(vault, "vault.json")))["prd_path"]]
except (OSError, ValueError, KeyError, TypeError):
    pass
suite = sh("run-full-suite.sh", "--cwd=" + q(root), "--base=" + base)
gate = sh("validate-bolt-artifacts.sh", "--cwd=" + q(root), "--orphan-scan --batch-suite-gate --postflight-scan --recompute "
          "--whitelist-scan --acceptance-scan --panel-scan --conflict-bypass-scan")
retire, rewip = (sh("derive-exec-plan.sh", "--cwd=" + q(root), "--vault=" + q(vault), m) for m in ("--retire", "--rebind-wip"))
out = []
A = out.append
A("# Inline execution plan — vault %s (%d unit%s)" % (os.path.basename(vault), len(in_scope), "" if len(in_scope) == 1 else "s"))
A("> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline, in this session). Without superpowers, "
  "the built-in loop of execute-bolts `references/inline-run.md` runs the same steps (ledger `%s`). Steps use checkbox "
  "(`- [ ]`) syntax." % LEDGER)
A("**Goal:** implement %s of vault `%s` in one context, each unit with the evidence mega-sdd records per unit."
  % (", ".join(in_scope), os.path.basename(vault)))
A("**Architecture:** one task per unit, in `depends_on` order. The unit file a task names is its spec: `target_files` (the "
  "whitelist), `acceptance_test`, `## Hard rules`, `## Anchors`. This plan carries the order and the steps only.")
A("**Tech Stack:** the project's own. **Spec:** %s." % " · ".join(spec))
A("**Run base:** `%s`. **Generated by:** derive-exec-plan.sh (mega-sdd %s) — never hand-edit it." % (base, VERSION))
if res["quarantined"]:
    A("\n".join(["**Not in this plan (quarantined at run start — the Karantina table of the run report):**"] + [
        "- %s — %s%s%s" % (rq["unit"], rq["reason"], " (%s)" % ", ".join(rq.get("conflict_ids") or [rq.get("freshness") or ""])
                           if rq.get("conflict_ids") or rq.get("freshness") else "", " · via " + rq["via"] if rq.get("via") else "")
        for rq in res["quarantined"]]))
A("## Global Constraints")
A("\n".join([
    "- **Branch policy (overrides executing-plans Setup):** work on the branch checked out now, in this working tree — main/master "
    "included. The user's execute-bolts invocation is the consent: no worktree, no branch switch, no question.",
    "- **This plan is the run's until the close retires it:** a resume, a compaction or a new session continues THIS plan and its ledger "
    "(trust the ledger and `git log`); derive-exec-plan.sh returns this plan, never a new one, while it is open.",
    "- **Stops:** an exit code an `Expected:` line does not list is a STOP of the run. `hard_rule_violated` or an OQ P1 business question "
    "STOPS THE RUN (the one-screen halt; the human decides). A CONFLICT at a task's re-bind step "
    "quarantines that unit (the step says how) and skips every task whose **Depends on** reaches it. Any other DEFER-class halt on a "
    "unit with no commit yet is recorded the same way. A unit whose commit landed is never quarantined: fix it forward, or stop the "
    "run. Never commit a stopped unit's work, attributed or not.",
    "- **Whitelist and provenance:** a task writes only its unit's `target_files`, its tests and `%s/bolts/U-XXX/`; every file it "
    "creates or modifies starts with the provenance header the task shows (the unit file is tracked, this plan is not)." % rel_vault,
    "- **Commits:** subject `feat(U-XXX): <unit title>` (the conventional type that fits), trailers `Unit: U-XXX`, "
    "`SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-XXX`, `SDD-Acceptance: v5`. Stage by explicit path (`git add -- <paths>`, "
    "never `-A`, `--all` or `.`); never `--no-verify`, never amend another unit's commit, never push.",
    "- **Evidence:** the writers are scripts (never hand-write their JSON). Each task ends with its evidence commit "
    "(`chore(sdd): evidence U-XXX`, no Unit trailer) — skip it only when `git check-ignore -q %s/units` exits 0." % rel_vault,
    "- **Final review and Finishing (override executing-plans Final Review and Finish; never "
    "superpowers:finishing-a-development-branch):** the `## After the last task` section at the end of this plan."]))
A("## Review Focus")
A("\n".join([
    "- Project test script: the manifest's test script exists (e.g. `npm test`) and runs the tests the units wrote.",
    "- Navigation: every page or route a unit adds is reachable from the app's navigation, not only by typing its URL.",
    "- Leftover scaffold: framework boilerplate, placeholder copy and demo pages the units replaced are gone.",
    "- Empty env: the build passes with an empty environment (no `.env`); missing configuration fails with a clear message at use.",
    "- Cross-unit wiring: what one unit produces (routes, exports, schema, config keys) is exactly what a later unit consumes."] + (
    ["- Out of scope: %s — quarantined at run start (a human decides them); a finding about their missing work is ruled out "
     "by construction." % ", ".join(rq["unit"] for rq in res["quarantined"])] if res["quarantined"] else [])))
A("---")
for n, u in enumerate(in_scope, 1):
    d, verify = units[u], units[u]["task_type"] == "verify"
    report, ev = os.path.join(BOLTS, u, "bolt-report.md"), sh("run-acceptance-tests.sh", "--cwd=" + q(root), "--unit=" + u)
    steps = []
    S = steps.append
    S(("Re-bind this unit at HEAD", "Run: `%s`\nExpected: exit 4 (or 0) and `\"conflicts\": 0`%s. `text_pending` > 0: ladder E3 (`jit-bind-and-"
       "quarantine.md` §E3). A CONFLICT whose claim in `%s` has `\"own_wip\": true` (an untracked create target carrying this unit's "
       "provenance header — a resume) is this task's own in-progress work: continue (a file this task wrote without the header reads as "
       "a plain `ALREADY_EXISTS`: add the header, run this step again). Any other CONFLICT: run `%s --halt=binding_conflict --reason="
       "\"<the CONFLICT ids>\" --dependents=<the units whose Depends on reaches %s>`, skip this task and theirs, and go on with the next "
       "task (a human decides it via `resolve-oq --binding` after the run). Exit 2 or 3: STOP the run."
       % (sh("rebind-units.sh", "--cwd=" + q(root), "--vault=" + q(vault), "--units=" + u),
          " (the deferred %s re-verdicts now that the unit it waits for landed)" % ", ".join(deferred[u]) if u in deferred else "",
          os.path.join(BOLTS, u, "binding.json"), sh("write-unit-quarantine.sh", "--cwd=" + q(root), "--vault=" + q(vault), "--unit=" + u), u)))
    if not verify:
        S(("Capture the pre-flight baseline", "Run: `%s`\nExpected: exit 0 (no `## Hard rules`: skipped); exit 7 = bolt commits "
           "already exist: note it in the report and continue; exit 2/3/4/5/6/8: STOP the run with the halt execute-bolts "
           "SKILL.md pre-flight 4 names." % sh("run-preflight-scan.sh", "--cwd=" + q(root), "--unit=" + u)))
        S(("Write the failing acceptance test", "Write the test each `acceptance_test` entry of the unit names, before any "
           "implementation, and run its command.\nExpected: FAIL (the output lacks the entry's `expects`)"))
        S(("Implement inside the whitelist", "Implement the unit in its `target_files` only. Every file you create or modify "
           "starts with the provenance header, in that file's comment syntax:\n\n```\nGenerated by mega-sdd execute-bolts %s\n"
           "Unit: %s · provenance: %s\n```" % (VERSION, u, os.path.relpath(d["file"], root))))
    S(("Run the acceptance test", "Run each `acceptance_test` command of the unit%s.\nExpected: PASS — the output contains the "
       "entry's `expects`" % (" (read-only: a `task_type: verify` unit changes no code)" if verify else "")))
    rep = ("Write the bolt report", "Write `%s` per execute-bolts `references/superpowers-bridge.md` §bolt-report.md schema: "
           "`target_hashes` (%s), the commits, the tests run and a `bolt_self_report` block with every decision you made."
           % (report, "`{}` — a verify unit changes no file" if verify else "sha256 per target file at the unit's commit"))
    if verify:
        S(rep)
    S(("Commit", "```bash\ngit add %s-- %s\ngit commit -m %s -m %s\n```\n\nExpected: one new commit; `git show --stat HEAD` lists "
       "only whitelisted paths" % ("-f " if verify else "", q(report) if verify else " ".join(q(t["path"]) for t in d["targets"])
                                   + "   # plus the test files this task wrote",
                                   q("%s(%s): %s" % ("chore" if verify else "feat", u, d["title"])),
                                   q("Unit: %s\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=%s\nSDD-Acceptance: v5" % (u, u)))))
    S(("Record the evidence", "Run: `%s`\nExpected: exit 0 (exit 1 = acceptance red: fix forward and re-run; exit 2: STOP the run)%s"
       % (ev, "" if verify else "\nRun: `%s`\nExpected: exit 0 (exit 1 = hard_rule_violated: STOP the run; exit 2: STOP the run)"
          "\nRun: `%s`\nExpected: exit 0 (exit 1 = secret_in_code / sast_critical_finding / dep_not_found: fix it before the next "
          "task; exit 2: STOP the run)" % (sh("run-postflight-scan.sh", "--cwd=" + q(root), "--unit=" + u),
                                          sh("run-code-gates.sh", "--cwd=" + q(root), "--base=<BASE>", "--head=$(git rev-parse HEAD)",
                                             "--unit=" + q(d["file"]), "--write")))))
    if not verify:
        S(rep)
    S(("Commit the evidence", "```bash\ngit add -- %s\n[ -e %s ] && git add -- %s\ngit commit -m %s\n```\n\nExpected: one new "
       "commit touching only `%s/`" % (q(os.path.join(rel_vault, "bolts", u)), q(os.path.join(rel_vault, "lens-inputs", u)),
                                        q(os.path.join(rel_vault, "lens-inputs", u)), q("chore(sdd): evidence %s — %s" % (u, d["title"])),
                                        rel_vault)))
    A("## Task %d: %s — %s" % (n, u, d["title"]))
    A("**Spec — read it in full first:** `%s`." % d["file"])
    A("**Files:** %s" % (", ".join("`%s` (%s)" % (t["path"], t["operation"]) for t in d["targets"]) or "none (read-only unit)"))
    A("**Depends on:** %s" % (", ".join(sorted(d["deps"], key=natkey)) or "none"))
    A("**BASE:** the commit `task-start` printed (built-in loop: `git rev-parse HEAD` before step 1); paste it where a step says `<BASE>`.")
    for s, (title, body) in enumerate(steps, 1):
        A("- [ ] **Step %d: %s**" % (s, title))
        A(body)
    A("**Task done:** `task-done <this plan> %d <BASE> -- %s`. Built-in loop: run `%s`; only when it exits 0, append "
      "`Task %d: %s complete (commits <BASE7>..<HEAD7>, tests: run-acceptance-tests.sh → pass)` to `%s`." % (n, ev, ev, n, u, LEDGER))
A("## After the last task")
A("Only once every task above is done or skipped. These steps override executing-plans' Final Review and Finish, also after a compaction "
  "(execute-bolts `references/inline-run.md` (d)); never superpowers:finishing-a-development-branch.")
A("\n".join([
    "1. **Suite:** `%s` → green." % suite,
    "2. **ONE blind review of `%s..HEAD`:** its package is `git -C %s diff -U10 %s..HEAD -- . ':(exclude).mega-sdd' "
    "':(exclude)docs/mega-sdd'` (not review-package — the vault carries the implementer's self-report), the Spec pointers and the "
    "Review Focus verbatim; [DESCRIPTION] holds the in-scope unit ids and titles only — no ledger, no `Ruling:` pointer, no "
    "implementer summary. The reviewer dispatch prompt carries this line on its own line:" % (base, q(root), base)]))
A("mega-sdd-trace:execute-bolts")
A("\n".join([
    "3. **Fixes:** every Critical and Important finding is fixed RED→GREEN in ONE pass: a fix of one unit is `fix(U-XXX): …` with its "
    "trailers inside its `target_files`, then its `run-acceptance-tests.sh` and `run-postflight-scan.sh` run again and its evidence is "
    "committed again; a cross-cutting fix is `fix(review): …` and touches no path a `## Hard rules` line of an in-scope unit protects "
    "and no quarantined unit's target (else attribute it to a unit). A finding about a quarantined unit is ruled out by construction.",
    "4. **Finishing:** append `Close: reviewed` to `%s` (a resume starts here: no second review); `delivery-check.sh` (VERDICT: PASS); "
    "`%s` again when a commit landed since; `%s` (`text_pending` > 0: ladder E3; exit 1: STOP, `resolve-oq --binding`, then again); "
    "the run evidence commit (`git add -- %s/bolts`, `chore(sdd): evidence run %s`, skipped if `.mega-sdd/` is unversioned); the gate "
    "`%s` (exit 0); retire: `%s` (`rebound` non-empty: `chore(sdd): evidence re-bind`, the gate again); the result contract." % (
        LEDGER, suite, rewip, rel_vault, base[:7], gate, retire)]))

os.makedirs(BOLTS, exist_ok=True)
with open(PLAN + ".tmp", "w", encoding="utf-8") as f:
    f.write("\n\n".join(out) + "\n")
os.replace(PLAN + ".tmp", PLAN)
with open(LEDGER, "w", encoding="utf-8") as f:  # the built-in ledger exists from the start: any started run resumes
    f.write("# inline ledger — plan: %s\n" % PLAN)
res["plan"] = PLAN
finish(0)
PYEOF
