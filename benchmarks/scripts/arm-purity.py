#!/usr/bin/env python3
"""arm-purity.py — is this headless arm the arm it claims to be? (vanilla control arm, 2026-09-26)

  python3 benchmarks/scripts/arm-purity.py <stream.jsonl> <megasdd|vanilla>

Reads the FIRST `system/init` record of the stream (the session's own roster: plugins, skills,
slash commands, agents) and prints run.meta lines:

  purity=PASS|FAIL <reason>
  plugins=<name@version,...>          the full roster — a confound to hold equal across arms
  megasdd_surfaces=<n>                plugins + skills + slash commands + agents naming mega-sdd

vanilla  PASS iff megasdd_surfaces == 0
megasdd  PASS iff a mega-sdd plugin is loaded
Exit 0 on PASS, 1 on FAIL, 2 when no init record exists (UNREADABLE — never PASS by absence).
"""
import json, sys


def init_record(path):
    try:
        for line in open(path, encoding="utf-8", errors="replace"):
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("type") == "system" and e.get("subtype") == "init":
                return e
    except OSError:
        pass
    return None


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in ("megasdd", "vanilla"):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    rec = init_record(sys.argv[1])
    if rec is None:
        print("purity=UNREADABLE no system/init record")
        return 2
    plugins = rec.get("plugins") or []
    roster = ",".join(f"{p.get('name')}@{p.get('version', '?')}" for p in plugins)
    names = [p.get("name", "") for p in plugins] + [p.get("source", "") for p in plugins]
    names += [str(x) for x in rec.get("skills") or []]
    names += [str(x) for x in rec.get("slash_commands") or []]
    names += [str(x) for x in rec.get("agents") or []]
    hits = sorted({n for n in names if "mega-sdd" in n})
    has_plugin = any("mega-sdd" == p.get("name") for p in plugins)
    if sys.argv[2] == "vanilla":
        ok = not hits
        reason = "no mega-sdd surface loaded" if ok else "mega-sdd loaded: " + ",".join(hits[:6])
    else:
        ok = has_plugin
        reason = "mega-sdd plugin loaded" if ok else "mega-sdd plugin NOT loaded"
    print(f"purity={'PASS' if ok else 'FAIL'} {reason}")
    print(f"plugins={roster}")
    print(f"megasdd_surfaces={len(hits)}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
