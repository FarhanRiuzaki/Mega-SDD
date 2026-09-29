"""pack_toolchain.py — a framework pack's OPTIONAL `## Toolchain` override for
the L0 code gates 1–2 (framework-conventions/_template.md §Toolchain). ONE test,
read by run-code-gates.sh (engages it) and ground.sh (silences its
l0_toolchain_vacuous advisory on it), so the two never disagree: a line starting
`## Toolchain` opens the section, and its fenced yaml must hold a command key
whose value is not a `<…>` placeholder — an unfilled _template block does neither."""
import glob, os, re

_KEY = re.compile(r"^\s*(format_check_cmd|format_fix_cmd|lint_cmd|typecheck_cmd):\s*(.+?)\s*$")


def toolchain(path):
    """A detect-toolchain-shaped dict from the pack's `## Toolchain`, or None
    when the file is unreadable or the section is absent or placeholder-only."""
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    in_sec = in_fence = False; keys = {}
    for line in text.splitlines():
        if line.startswith("## Toolchain"):
            in_sec = True; continue
        if in_sec and re.match(r"^##\s+", line):
            break
        if in_sec and line.strip().startswith("```"):
            in_fence = not in_fence; continue
        m = _KEY.match(line) if in_sec and in_fence else None
        if m and not m.group(2).startswith("<"):
            keys[m.group(1)] = m.group(2)
    if not keys:
        return None
    ev = os.path.basename(path) + " ## Toolchain"
    tc = {"formatters": [], "linters": [], "typecheckers": []}
    for key, kind in (("format_check_cmd", "formatters"), ("lint_cmd", "linters"), ("typecheck_cmd", "typecheckers")):
        if key in keys:
            tc[kind].append({"tool": "pack-override", "check_cmd": keys[key], "evidence": ev})
    if tc["formatters"] and "format_fix_cmd" in keys:
        tc["formatters"][0]["fix_cmd"] = keys["format_fix_cmd"]
    return tc


def project_pack(cwd):
    """(`.mega-sdd/packs/<name>.md`, toolchain) for the first project pack, in
    name order, whose `## Toolchain` engages; (None, None) when none does."""
    rel = os.path.join(".mega-sdd", "packs")
    for path in sorted(glob.glob(os.path.join(cwd, rel, "*.md"))):
        tc = toolchain(path)
        if tc is not None:
            return os.path.join(rel, os.path.basename(path)), tc
    return None, None
