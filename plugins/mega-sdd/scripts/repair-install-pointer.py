#!/usr/bin/env python3
"""repair-install-pointer.py — the active mega-sdd install must be the newest COMPLETE cached version.

Field report 2026-09-30 (Windows 11, Git Bash): `/plugin marketplace update` and uninstall+install
left installed_plugins.json on 8.7.0 while a complete cache/mega-sdd/mega-sdd/9.0.0 sat on disk, and
the Step 5.5 regex (POSIX separators over JSON-escaped Windows paths) returned an EMPTY referenced
set. This reads the parsed JSON (never a regex over escaped strings) and splits paths on / and \\.

  repair-install-pointer.py --check       JSON {installed, installPath, newest_complete, available, action}
  repair-install-pointer.py --referenced  referenced versions (every scope; version + installPath basename);
                                          exit 3 when EMPTY — the dormant sweep must then stop (fail-safe)
  repair-install-pointer.py --apply       repoint the user-scope mega-sdd@mega-sdd entry to the newest
                                          complete cache dir (backup first); no-op when already newest

Complete = <cache>/<v>/.claude-plugin/plugin.json says version == <v> and <cache>/<v>/commands exists.
Config dir = $CLAUDE_CONFIG_DIR, else ~/.claude. Exit: 0 ok · 2 unreadable input · 3 empty referenced set.
"""
import datetime, json, os, re, shutil, sys

KEY = "mega-sdd@mega-sdd"
VER = re.compile(r"^\d+(\.\d+)*$")


def vkey(v):
    return tuple(int(x) for x in v.split("."))


def base():
    return os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")


def leaf(path):
    return re.split(r"[\\/]+", str(path or "").rstrip("\\/"))[-1]


def load(p):
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        print("unreadable %s: %s" % (p, e), file=sys.stderr)
        sys.exit(2)


def complete(cache):
    out = []
    for v in (os.listdir(cache) if os.path.isdir(cache) else []):
        d = os.path.join(cache, v)
        try:
            ok = VER.match(v) and json.load(open(os.path.join(d, ".claude-plugin", "plugin.json"), encoding="utf-8")).get("version") == v
        except (OSError, ValueError):
            ok = False
        if ok and os.path.isdir(os.path.join(d, "commands")):
            out.append(v)
    return sorted(out, key=vkey)


def main():
    mode = (sys.argv[1:] or ["--check"])[0]
    plug = os.path.join(base(), "plugins")
    ipath = os.path.join(plug, "installed_plugins.json")
    cache = os.path.join(plug, "cache", "mega-sdd", "mega-sdd")
    data = load(ipath)
    entries = (data.get("plugins") or {}).get(KEY) or []
    if mode == "--referenced":
        refs = {e.get("version") for e in entries} | {leaf(e.get("installPath")) for e in entries}
        refs = sorted((r for r in refs if r and VER.match(r)), key=vkey)
        print(" ".join(refs))
        sys.exit(0 if refs else 3)
    user = next((e for e in entries if e.get("scope") == "user"), None)
    have = complete(cache)
    newest = have[-1] if have else None
    try:
        avail = json.load(open(os.path.join(plug, "marketplaces", "mega-sdd", "plugins", "mega-sdd", ".claude-plugin", "plugin.json"), encoding="utf-8")).get("version")
    except (OSError, ValueError):
        avail = None
    cur = user.get("version") if user else None
    need = bool(user and newest and (not cur or not VER.match(cur) or vkey(newest) > vkey(cur)))
    rep = {"installed": cur, "installPath": user.get("installPath") if user else None,
           "newest_complete": newest, "available": avail, "action": "repoint" if need else "none"}
    if mode == "--apply" and need:
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        shutil.copy2(ipath, ipath + ".bak-" + stamp)
        old = user.get("installPath") or ""
        sep = "\\" if "\\" in old else "/"
        target = os.path.join(cache, newest)
        user["installPath"] = target.replace("/", sep) if sep == "\\" else target
        user["version"] = newest
        user["lastUpdated"] = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
        tmp = ipath + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, ipath)
        rep.update(action="repointed", installed=newest, installPath=user["installPath"], backup=ipath + ".bak-" + stamp)
    print(json.dumps(rep))


if __name__ == "__main__":
    main()
