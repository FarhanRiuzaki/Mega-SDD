"""conflict_bypass.py — body of validate-bolt-artifacts.sh --conflict-bypass-scan (`conflict_bypassed`,
spec docs/superpowers/specs/2026-09-27-v9-simplification-design.md §8.1-§8.2).

A unit's bolt commit is judged against the CONFLICT state it landed under, never only the state now:
  own   inside an unresolved CONFLICT episode of its binding.json — open (`conflict_since`, else
        `generated_at`) or closed later by a re-bind (`conflict_history`) — or after its quarantine.json;
  via   while a depends_on ancestor (transitive) was so blocked and not yet implemented (done by its
        evidence, with its first commit before the block began);
  rebind_skipped  its first commit landed on a tree where a claim its binding holds did not hold, and
        no bind saw that tree (generated_at < the parent's author time).
A claim that held in the tree the commit landed on is not a bypass: fs_must_exist (the path existed
at the parent — a deferred claim), fs_must_not_exist only for an `own_wip` episode (the unit's own
uncommitted work at a resume; never a user's untracked file) whose target was absent before the
unit's first commit. Identity: postflight_rules.unit_of; AUTHOR times, compared >=; a human resolution
ends an episode; an unparseable binding of a bolted unit fails closed; a CONFLICT with no time is
advisory. Threat model (spec §8.2): honest slips only; deliberate evasion is out of scope.
"""
import glob
import json
import os
import re
from datetime import datetime, timezone

import exec_units as xu
import plugin_meta
import vault_layouts
from postflight_rules import unit_of

EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
FS = ("fs_must_exist", "fs_must_not_exist")


def epoch(s):
    try:
        d = datetime.fromisoformat(str(s).strip().replace("Z", "+00:00"))
        return (d if d.tzinfo else d.replace(tzinfo=timezone.utc)).timestamp()
    except (TypeError, ValueError):
        return None


def iso(t):
    return datetime.fromtimestamp(t, timezone.utc).isoformat().replace("+00:00", "Z")


def run(cwd, state_file, quiet, ts, git, prefix, has_trailer_atom, lib_dir):
    # ── bolt commits, newest first: ONE log call (identity, parent, author time, files) ──
    fmt = "%x01%H%x02%P%x02%at%x02%s%x02" + ("%(trailers:key=Unit,valueonly,separator=%x2C)" if has_trailer_atom else "")
    commits = []
    for chunk in git("log", "--format=" + fmt, "--name-only", "-300", *(["--", "."] if prefix else [])).stdout.split("\x01")[1:]:
        head, _, tail = chunk.partition("\n")
        p = (head.split("\x02") + [""] * 5)[:5]
        uid = unit_of(p[3], p[4].strip())
        if uid:
            files = {f[len(prefix):] if prefix and f.startswith(prefix) else f for f in tail.split("\n") if f.strip()}
            commits.append({"sha": p[0].strip(), "parent": (p[1].split() or [EMPTY_TREE])[0],
                            "t": int(p[2]) if p[2].strip().isdigit() else 0, "uid": uid, "files": files})

    # ── vaults and units ──
    vaults = []
    for pre in vault_layouts.vault_prefixes(cwd):
        for d in sorted(glob.glob(pre)):
            segs = set(os.path.relpath(d, cwd).replace(os.sep, "/").split("/"))
            if os.path.isdir(os.path.join(d, "units")) and not segs & {"node_modules", "vendor"} \
                    and os.path.realpath(d) not in {os.path.realpath(x) for x in vaults}:
                vaults.append(d)
    units = {v: {} for v in vaults}
    for v in vaults:
        for uid, path in xu.unit_files(v).items():
            try:
                units[v][uid] = xu.parse(path)
            except OSError:
                pass

    # a unit id two vaults share is attributed to the vault whose targets the commit touched
    per = {}
    for c in commits:
        vs = [v for v in vaults if c["uid"] in units[v]]
        for v in [v for v in vs if {t["path"] for t in units[v][c["uid"]]["targets"]} & c["files"]] or vs:
            per.setdefault((v, c["uid"]), []).append(c)

    _b = {}

    def binding(v, uid):
        """{ok, eps: unresolved episodes (open + closed), legacy: an open CONFLICT with no time, doc}"""
        if (v, uid) not in _b:
            p, b = os.path.join(v, "bolts", uid, "binding.json"), {"ok": True, "eps": [], "legacy": False, "doc": {}}
            if os.path.isfile(p):
                try:
                    b["doc"] = doc = json.load(open(p, encoding="utf-8"))
                    for c in doc.get("claims") or []:
                        if c.get("verdict") == "CONFLICT" and not c.get("resolution"):
                            s = epoch(c.get("conflict_since") or doc.get("generated_at"))
                            b["legacy"] |= s is None
                            b["eps"] += [dict(c, since=s, until=None, wip=bool(c.get("own_wip")))] if s is not None else []
                    for e in doc.get("conflict_history") or []:
                        s, u = epoch(e.get("since")), epoch(e.get("closed_at"))
                        if not e.get("resolution") and s is not None and u is not None:
                            b["eps"].append(dict(e, since=s, until=u, wip=bool(e.get("own_wip"))))
                except (OSError, ValueError, TypeError, AttributeError):
                    b["ok"] = False
            _b[(v, uid)] = b
        return _b[(v, uid)]

    def qsince(v, uid):
        p = os.path.join(v, "bolts", uid, "quarantine.json")
        try:  # an unreadable quarantine counts from forever (fail closed)
            return (epoch(json.load(open(p, encoding="utf-8")).get("quarantined_at")) or 0.0) if os.path.isfile(p) else None
        except (OSError, ValueError, AttributeError):
            return 0.0

    def windows(v, uid):
        """(since, until|None, episode|None): when uid was blocked on its own."""
        b, q = binding(v, uid), qsince(v, uid)
        return ([(e["since"], e["until"], e) for e in b["eps"]] if b["ok"] else []) + ([(q, None, None)] if q is not None else [])

    _ex = {}

    def exists(rev, path):
        if (rev, path) not in _ex:
            _ex[(rev, path)] = git("cat-file", "-e", "%s:./%s" % (rev, path)).returncode == 0
        return _ex[(rev, path)]

    def held(v, uid, ep, c):
        """the fs claim already held in the tree commit c landed on (an episode's ALREADY_EXISTS: own_wip only)"""
        kind, exp = ep.get("kind"), str(ep.get("expect") or "")
        if kind == "fs_must_not_exist":
            return ep.get("wip", True) and not exists((per.get((v, uid)) or [c])[-1]["parent"], xu.pnorm(exp))
        if kind != "fs_must_exist" or "anchor_content_drift" in str(ep.get("evidence") or ""):
            return False
        m = re.match(r"^(.+?):(\d+)(?:-(\d+))?$", exp)
        if not m:
            return exists(c["parent"], xu.pnorm(exp))
        out = git("show", "%s:./%s" % (c["parent"], xu.pnorm(m.group(1))))
        return out.returncode == 0 and len(out.stdout.splitlines()) >= int(m.group(3) or m.group(2))

    def first_hit(cs, v, uid, skip=lambda since: False):
        """(commit, since, until, episode): the newest commit of cs inside a window of uid"""
        for s, u, ep in windows(v, uid):
            for c in ([] if skip(s) else cs):
                if c["t"] >= s and (u is None or c["t"] <= u) and not (ep and held(v, uid, ep, c)):
                    return c, s, u, ep
        return None

    _done = {}

    def implemented_before(v, a, since):
        """done by its evidence, and its first commit is older than the block (or the walk window)"""
        if (v, a) not in _done:
            _done[(v, a)] = xu.done(cwd, v, a, units[v])
        cs = per.get((v, a)) or []
        return _done[(v, a)] and (not cs or cs[-1]["t"] < since)

    def ancestors(v, uid):
        seen, out, todo = {uid}, [], list(units[v][uid]["deps"])
        while todo:
            a = todo.pop(0)
            if a not in seen and a in units[v]:
                seen.add(a)
                out.append(a)
                todo.extend(units[v][a]["deps"])
        return out

    issues, legacy = [], set()

    def add(v, uid, c, reason, detail, ep=None, **kw):
        issues.append(dict({"halt_type": "conflict_bypassed", "unit_id": uid, "reason": reason, "commit": c["sha"],
                            "commit_time": iso(c["t"]), "vault": os.path.relpath(v, cwd).replace(os.sep, "/"),
                            "conflict_ids": [str(ep.get("id"))] if ep else [], "detail": detail}, **kw))

    for (v, uid), cs in sorted(per.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        b = binding(v, uid)
        if not b["ok"]:
            add(v, uid, cs[0], "binding_unparseable", "%s: bolts/%s/binding.json is unparseable for a bolted unit — the CONFLICT "
                "gate cannot be evaluated (fail closed; restore it from git, then re-bind)" % (uid, uid))
            continue
        if b["legacy"]:
            legacy.add(uid)
        hit = first_hit(cs, v, uid)
        if hit:
            c, s, u, ep = hit
            reason = "quarantined" if ep is None else ("open_conflict" if u is None else "closed_conflict")
            add(v, uid, c, reason, "%s: bolt commit %s landed %s" % (uid, c["sha"][:9], (
                "after the unit was quarantined (bolts/%s/quarantine.json)" % uid if ep is None else
                "while CONFLICT %s was open%s" % (ep.get("id"), "" if u is None else " (a re-bind closed it at %s, after the commit)" % iso(u)))), ep)
            continue
        first, gen = cs[-1], epoch(b["doc"].get("generated_at"))
        pt = git("show", "-s", "--format=%at", first["parent"]).stdout.strip() if gen is not None else ""
        gone = [c for c in b["doc"].get("claims") or [] if pt.isdigit() and gen < int(pt) and c.get("verdict") != "CONFLICT"
                and not c.get("resolution") and c.get("kind") in FS and not held(v, uid, c, first)]
        if gone:
            add(v, uid, first, "rebind_skipped", "%s: bolt commit %s landed on a tree where claim %s did not hold, and its binding "
                "predates that tree (the task's re-bind was skipped)" % (uid, first["sha"][:9], gone[0].get("id")), gone[0])
            continue
        for a in ancestors(v, uid):
            ah = first_hit(cs, v, a, lambda since: implemented_before(v, a, since))
            if ah:
                add(v, uid, ah[0], "depends_on_blocked", "%s depends on %s, which was blocked (a CONFLICT or a quarantine) and "
                    "not yet implemented when bolt commit %s landed" % (uid, a, ah[0]["sha"][:9]), ah[3], via=a)
                break

    labels = sorted("%s %s%s" % (i["unit_id"], i["reason"], " via " + i["via"] if i.get("via") else "") for i in issues)
    state = {"ts": ts, "mode": "conflict-bypass-scan", "status": "FAIL" if issues else "PASS",
             "units_checked": len(per), "legacy_advisory": sorted(legacy), "issues_count": len(issues), "issues": issues,
             "next_action": ("%d unit commit(s) landed past an open CONFLICT, a quarantine or a skipped re-bind (conflict_bypassed: %s). "
                             "A CONFLICT is a human decision: resolve-oq --binding (write-unit-binding.sh --resolve=<claim-id>=KEEP_VAULT|"
                             "KEEP_CODE|SPLIT|DEFER --by=user; it also resolves a closed episode); a quarantine is released by the human "
                             "(write-unit-quarantine.sh --release --by=user); a rebind_skipped unit is re-bound (rebind-units.sh --units=<U>) "
                             "and the CONFLICT it records goes to the human. A re-bind never clears a commit made while a CONFLICT was open. "
                             "Keterangan: unit ini di-commit padahal CONFLICT di binding-nya (atau di unit yang ditunggu "
                             "lewat depends_on) belum diputuskan manusia, atau padahal unit itu dikarantina — putuskan lewat "
                             "resolve-oq --binding atau lepas karantinanya." % (len(issues), ", ".join(labels[:8]))) if issues else
                            "No unit committed past an open CONFLICT or a quarantine." + (
                                " (%d binding(s) without a CONFLICT time — advisory; re-bind to evaluate them.)" % len(legacy) if legacy else "")}
    state.update(plugin_meta.stamp(lib_dir))
    with open(state_file + ".tmp", "w", encoding="utf-8") as f:
        json.dump(state, f, indent=1)
    os.replace(state_file + ".tmp", state_file)
    if not quiet:
        print(json.dumps(state, indent=1))
    return 1 if issues else 0
