"""windows_path.py — Windows USER PATH inspection + repair (mega-sdd shared lib).

Consumed by scripts/fix-windows-path.sh, which is invoked by
skills/install-deps/SKILL.md Step 6 (Verify) on `os = windows-bash`.

WHY THIS EXISTS
---------------
On Windows an installer writes `HKCU\\Environment\\Path`, but a bash session that
is ALREADY RUNNING never sees that change — the environment block was copied at
process creation. winget says so itself ("Path environment variable modified;
restart your shell to use the new value"). The consequence for mega-sdd is that
`verify_cmd` false-fails on a tool that installed perfectly, and install-deps
reports `unverified` for something that will work fine in the next terminal.

Two further Windows-only holes this closes:
  * `pip install --user <pkg>` drops binaries in
    %APPDATA%\\Roaming\\Python\\Python<XY>\\Scripts — a DIFFERENT directory from the
    main Python install's Scripts dir, and never on PATH.
  * `pipx install <pkg>` drops them in ~\\.local\\bin — also never on PATH (pipx
    tells you to run `pipx ensurepath`).

DELIBERATE NON-GOALS
--------------------
This module does NOT detect the WindowsApps App Execution Alias stub. That
already exists, is already tested, and is fork-free:
`scripts/_lib/resolve-python.sh` (`_mega_sdd_py_is_alias`). Do not restate it here.

SAFETY CONTRACT (each rule below is a real incident, not a hypothetical)
-----------------------------------------------------------------------
1. Registry reads go through `winreg.QueryValueEx`, never through parsing
   `reg query` output. For a long REG_EXPAND_SZ the shell output wraps and
   acquires artefacts, and a mis-parse here silently corrupts PATH.
2. Writes preserve REG_EXPAND_SZ. Writing REG_SZ instead expands `%USERPROFILE%`
   to a literal, which breaks the value for every other user profile and for
   roaming scenarios.
3. `ensure_user_path_dirs` is idempotent and never writes when nothing changed —
   an unnecessary registry write is an unnecessary chance to corrupt.
4. The caller is expected to persist `before` somewhere durable BEFORE acting on
   `after`. This module returns both for exactly that reason.

Methods that MUST NOT be used to do this job, all observed to fail destructively:
  * `reg add "HKCU\\Environment" /v Path ... /d "<value>"` from Git Bash — the
    value's backslashes and semicolons are mangled by the `reg` parser; it prints
    "ERROR: Invalid syntax" while still returning RC=0, so the caller believes it
    worked. Writes nothing, or writes partially.
  * A hand-written `.reg` file + `reg import` — getting the hex(2) UTF-16LE
    encoding wrong makes `reg import` report success while writing a CORRUPT
    value. Observed: a 798-character USER PATH truncated to 92 characters.
  * `setx PATH "..."` — truncates at 1024 characters AND expands `%VAR%`,
    destroying REG_EXPAND_SZ.
"""

import ntpath
import os

# Path STRING handling goes through `ntpath`, never `os.path`. These values always
# come from the Windows registry, so Windows semantics are the correct semantics —
# but `os.path` is whatever the RUNNING interpreter uses, and under a Cygwin/MSYS
# Python that is posixpath, where a backslash is an ordinary character. There,
# `os.path.normpath(r"C:\x\bin\")` is a no-op and the dedupe below would silently
# fail, appending the same directory on every run until PATH overflows. ntpath is
# importable on every platform and gives exact Windows behaviour, which also makes
# this testable off-Windows. Filesystem ACCESS still goes through `os.path`, which
# is what the running interpreter can actually open.

# winreg is Windows-only. Import lazily/guarded so this module can be IMPORTED and
# unit-tested on any platform (the test suite injects a fake); only the functions
# that actually touch the registry require the real thing.
try:  # pragma: no cover - platform dependent
    import winreg  # type: ignore
except ImportError:  # pragma: no cover - POSIX
    winreg = None  # type: ignore

USER_ENV_SUBKEY = "Environment"
SYSTEM_ENV_SUBKEY = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"


class WindowsPathError(RuntimeError):
    """Raised when the registry is unavailable or a write cannot be completed."""


def _require_winreg():
    if winreg is None:
        raise WindowsPathError(
            "winreg unavailable — windows_path is Windows-only. "
            "Callers must branch on platform before invoking registry functions."
        )
    return winreg


def _read_raw(hive, subkey, name="Path"):
    """Return (value, regtype). Missing value -> ('', REG_EXPAND_SZ), not an error:
    a fresh profile legitimately has no user Path yet, and that must be creatable."""
    wr = _require_winreg()
    key = wr.OpenKey(hive, subkey, 0, wr.KEY_READ)
    try:
        try:
            value, regtype = wr.QueryValueEx(key, name)
        except FileNotFoundError:
            return "", wr.REG_EXPAND_SZ
        return value, regtype
    finally:
        key.Close()


def read_user_path():
    """(value, regtype) of HKCU\\Environment\\Path, binary-accurate."""
    wr = _require_winreg()
    return _read_raw(wr.HKEY_CURRENT_USER, USER_ENV_SUBKEY)


def read_system_path():
    """(value, regtype) of the machine PATH."""
    wr = _require_winreg()
    return _read_raw(wr.HKEY_LOCAL_MACHINE, SYSTEM_ENV_SUBKEY)


def effective_new_process_path():
    """The PATH entries a NEWLY STARTED process will see, in Windows resolution
    order (system first, then user). This is the whole point of the module: it
    answers "will this work after a restart?" without restarting anything.

    Note this is an approximation of the real logon-time composition — it ignores
    PATH edits made by profile scripts and by the parent process. That is correct
    for our question, which is specifically about the PERSISTED value.
    """
    wr = _require_winreg()
    sys_val, _ = read_system_path()
    usr_val, _ = read_user_path()
    combined = ";".join(p for p in (sys_val, usr_val) if p)
    expanded = wr.ExpandEnvironmentStrings(combined)
    return [p for p in (d.strip() for d in expanded.split(";")) if p]


def resolves_in_new_shell(binary_name, dirs=None):
    """Absolute path to `binary_name` as a NEW shell would resolve it, or None.

    Tries the bare name and each PATHEXT-ish suffix. A hit means "the install
    worked; the running shell is simply stale" — the caller should report success
    and tell the user to restart the terminal, NOT report a failed install.
    """
    if dirs is None:
        dirs = effective_new_process_path()
    suffixes = ["", ".exe", ".cmd", ".bat", ".ps1"]
    for d in dirs:
        for suf in suffixes:
            # os.path.join, NOT ntpath.join: this string is handed straight to
            # isfile(), so it has to use the separator the RUNNING interpreter can
            # open. On real Windows the two are identical; under Cygwin/MSYS Python
            # os.path.join yields `C:\dir/name.exe`, and Windows accepts mixed
            # separators. (ntpath is for the dedupe key, where Windows STRING
            # semantics are what matter — see _norm.)
            candidate = os.path.join(d, binary_name + suf)
            if os.path.isfile(candidate):
                return candidate
    return None


def _norm(p):
    """Comparison key for PATH entries. normcase matters on Windows (case- and
    separator-insensitive); normpath collapses trailing separators so
    `C:\\x` and `C:\\x\\` do not both get prepended."""
    return ntpath.normcase(ntpath.normpath(p))


def ensure_user_path_dirs(dirs_to_add, dry_run=False):
    """Prepend `dirs_to_add` to the USER PATH, preserving REG_EXPAND_SZ + dedupe.

    Returns (changed, before, after). `changed` is False when every directory is
    already present, and in that case NO write is attempted at all.

    Prepending (rather than appending) is deliberate: the failure this repairs is
    usually a WindowsApps alias stub shadowing a real interpreter, and only a
    higher-precedence entry fixes that.

    The caller MUST persist `before` before acting on `after`.
    """
    wr = _require_winreg()
    wanted = [ntpath.normpath(d) for d in dirs_to_add if d and d.strip()]

    current, regtype = read_user_path()
    # Preserve REG_EXPAND_SZ. If the existing value is REG_SZ we still write
    # REG_EXPAND_SZ — that is strictly more capable and is what Windows itself
    # uses for Path; a plain REG_SZ here is already a (pre-existing) defect.
    if regtype not in (wr.REG_EXPAND_SZ, wr.REG_SZ):
        raise WindowsPathError(
            "refusing to write: HKCU\\Environment\\Path has unexpected type %r" % (regtype,)
        )

    parts = [p for p in current.split(";") if p.strip()]
    seen = {_norm(p) for p in parts}

    added = []
    for d in wanted:
        if _norm(d) in seen:
            continue
        parts.insert(len(added), d)  # keep the caller's order among new entries
        seen.add(_norm(d))
        added.append(d)

    after = ";".join(parts)
    if not added:
        return False, current, current
    if dry_run:
        return True, current, after

    key = wr.OpenKey(wr.HKEY_CURRENT_USER, USER_ENV_SUBKEY, 0, wr.KEY_READ | wr.KEY_WRITE)
    try:
        wr.SetValueEx(key, "Path", 0, wr.REG_EXPAND_SZ, after)
    finally:
        key.Close()

    # Read back and verify. A silent truncation is the exact failure mode of the
    # banned methods above, so we do not trust the write without confirming it.
    verify, _ = read_user_path()
    if verify != after:
        raise WindowsPathError(
            "PATH write did not round-trip (wrote %d chars, read back %d). "
            "Original value preserved in the caller's backup." % (len(after), len(verify))
        )
    return True, current, after


def candidate_dirs(home=None, python_xy=None):
    """The directories Windows installers use but never add to PATH.

    `python_xy` is the packed major+minor used by pip's per-user scheme
    ("314" for 3.14) — the directory is Python<XY>, not Python<X.Y>.
    """
    home = home or os.path.expanduser("~")
    out = [ntpath.join(home, ".local", "bin")]  # pipx
    if python_xy:
        out.append(
            ntpath.join(home, "AppData", "Roaming", "Python", "Python" + str(python_xy), "Scripts")
        )
    return out
