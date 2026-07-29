#!/usr/bin/env bash
# fix-windows-path.sh — diagnose (and optionally repair) a stale Windows USER PATH.
#
# Invoked by skills/install-deps/SKILL.md Step 6 (Verify) when `os = windows-bash`
# and a `verify_cmd` fails even though the install exited 0. Mechanics + the binary
# location table: skills/install-deps/references/windows-path.md.
#
# The question this answers is NOT "is the tool on PATH" — the running shell's PATH
# is stale by construction after any installer writes HKCU\Environment\Path. It is
# "will this tool resolve in a NEW shell?", which is the only question that
# distinguishes "installed fine, restart your terminal" from "the install failed".
#
# Modes (exactly one):
#   --probe=<binary>   Is <binary> resolvable from the PERSISTED path? Prints the
#                      absolute path on success. rc 0 = yes, 3 = no.
#   --ensure-dirs      Prepend the well-known never-on-PATH dirs (pipx ~/.local/bin,
#                      pip --user Scripts) to the USER PATH. Idempotent; writes only
#                      when something actually changes.
#   --list             Print the effective new-process PATH, one entry per line.
#
# Flags:
#   --backup-to=<file> Write the CURRENT user PATH here before any modification.
#                      REQUIRED by --ensure-dirs; the write refuses without it.
#   --dry-run          With --ensure-dirs: compute and report, never write.
#   --quiet            Suppress human narration; machine-readable lines only.
#
# Exit codes:
#   0  success (probe hit / dirs ensured / nothing to do)
#   2  usage error
#   3  probe miss — the binary does NOT resolve even from the persisted PATH
#   4  no usable Python interpreter and the bash bootstrap could not find one
#   5  registry write failed or did not round-trip (backup is intact)
#   6  not a Windows environment
#   7  the interpreter is not a native Windows Python (no `winreg` module) — an
#      MSYS2/Cygwin Python cannot read HKCU. Distinct from 5 on purpose: 5 means
#      "the write failed", 7 means "we never got as far as looking", and the two
#      have completely different remedies.
set -uo pipefail

case "$0" in */*) SCRIPT_DIR="${0%/*}" ;; *) SCRIPT_DIR="." ;; esac

MODE=""
BACKUP_TO=""
PROBE_BIN=""
DRY_RUN=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --probe=*)      MODE="probe";  PROBE_BIN="${arg#*=}" ;;
    --ensure-dirs)  MODE="ensure" ;;
    --list)         MODE="list" ;;
    --backup-to=*)  BACKUP_TO="${arg#*=}" ;;
    --dry-run)      DRY_RUN=1 ;;
    --quiet)        QUIET=1 ;;
    --cwd=*)        : ;;  # accepted for call-site symmetry with the other scripts
    *) printf 'fix-windows-path.sh: unknown argument [%s]\n' "$arg" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ -z "$MODE" ]; then
  printf 'usage: fix-windows-path.sh (--probe=<binary> | --ensure-dirs | --list) [--backup-to=<file>] [--dry-run] [--quiet]\n' >&2
  exit 2
fi

# ── Windows only. Everything below manipulates the Windows registry; on POSIX the
# whole premise (a persisted PATH the running shell has not seen) does not exist.
case "${OSTYPE:-}" in
  msys*|cygwin*|win32*) : ;;
  *)
    say "fix-windows-path: not a Windows shell (OSTYPE=${OSTYPE:-unset}) — nothing to do."
    exit 6
    ;;
esac

# ── Backup gate ──────────────────────────────────────────────────────────────
# Validated BEFORE any work: a repair without a backup is the failure mode this
# script exists to prevent (a corrupt .reg import once truncated a 798-char USER
# PATH to 92 chars). Refuse up front rather than after a successful probe.
if [ "$MODE" = "ensure" ] && [ "$DRY_RUN" -eq 0 ] && [ -z "$BACKUP_TO" ]; then
  printf 'fix-windows-path.sh: --ensure-dirs requires --backup-to=<file>\n' >&2
  exit 2
fi

# ── Interpreter resolution, including the bootstrap case ─────────────────────
# CHICKEN-AND-EGG: the tool most likely to be missing from PATH is python3 itself,
# and this script needs a Python to read the registry. resolve-python.sh answers
# "is there a usable interpreter ON PATH" — which is exactly what is stale here. So
# when it says no, fall back to probing the absolute locations Windows installers
# actually use. Without this the script is unavailable in the one scenario that
# motivated it.
PY_LIB="${SCRIPT_DIR}/_lib/resolve-python.sh"
MEGA_SDD_PY=""
if [ -f "$PY_LIB" ]; then
  # shellcheck disable=SC1090
  . "$PY_LIB"
  mega_sdd_python >/dev/null 2>&1 && MEGA_SDD_PY="${MEGA_SDD_PY:-}"
fi

if [ -z "${MEGA_SDD_PY:-}" ]; then
  # Bash-only bootstrap: the known winget / python.org per-user install roots.
  # Globs are unquoted on purpose (they must expand); `-x` keeps a directory or a
  # 0-byte WindowsApps alias stub from being mistaken for an interpreter.
  _home="${USERPROFILE:-$HOME}"
  case "${OSTYPE:-}" in msys*|cygwin*|win32*) _home="${_home//\\//}" ;; esac
  for _cand in \
    "$_home"/AppData/Local/Programs/Python/Python3*/python.exe \
    "$_home"/AppData/Local/Programs/Python/Python3*/python3.exe \
    /c/Python3*/python.exe ; do
    case "$_cand" in *"*"*) continue ;; esac      # unexpanded glob → no match
    case "$_cand" in *[Ww]indows[Aa]pps*) continue ;; esac
    if [ -x "$_cand" ] && "$_cand" -c 'import sys' >/dev/null 2>&1; then
      MEGA_SDD_PY="$_cand"
      say "fix-windows-path: PATH is stale — bootstrapped interpreter at $_cand"
      break
    fi
  done
fi

if [ -z "${MEGA_SDD_PY:-}" ]; then
  printf 'no_interpreter\n'
  say "fix-windows-path: no usable Python interpreter found, on PATH or at the known install roots."
  say "  Restart the terminal and re-run; if it still fails, python3 genuinely did not install."
  exit 4
fi

export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

# $MEGA_SDD_PY is expanded UNQUOTED on purpose — resolve-python.sh may resolve it
# to `py -3`, which is two words (see resolve-python.sh:39-41).
MODE="$MODE" PROBE_BIN="$PROBE_BIN" BACKUP_TO="$BACKUP_TO" DRY_RUN="$DRY_RUN" QUIET="$QUIET" \
$MEGA_SDD_PY - <<'PYEOF'
import os, sys

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import windows_path as wp

mode = os.environ["MODE"]
quiet = os.environ.get("QUIET") == "1"


def say(msg):
    if not quiet:
        print(msg)


try:
    if mode == "list":
        for d in wp.effective_new_process_path():
            print(d)
        raise SystemExit(0)

    if mode == "probe":
        name = os.environ["PROBE_BIN"]
        hit = wp.resolves_in_new_shell(name)
        if hit:
            print(hit)
            say("fix-windows-path: '%s' resolves from the persisted PATH — the install is "
                "fine, this shell is stale. Restart the terminal." % name)
            raise SystemExit(0)
        print("probe_miss")
        say("fix-windows-path: '%s' does NOT resolve even from the persisted PATH." % name)
        raise SystemExit(3)

    # mode == "ensure"
    xy = "%d%d" % (sys.version_info[0], sys.version_info[1])
    dirs = wp.candidate_dirs(python_xy=xy)
    dry = os.environ.get("DRY_RUN") == "1"

    before, _ = wp.read_user_path()
    backup = os.environ.get("BACKUP_TO") or ""
    if backup and not dry:
        # Backup FIRST, and fail closed if it cannot be written — proceeding without
        # a restore point is the thing this guard exists to prevent.
        d = os.path.dirname(os.path.abspath(backup))
        if d:
            os.makedirs(d, exist_ok=True)
        with open(backup, "w", encoding="utf-8") as fh:
            fh.write(before)
        say("fix-windows-path: current USER PATH (%d chars) backed up to %s" % (len(before), backup))

    changed, before, after = wp.ensure_user_path_dirs(dirs, dry_run=dry)
    if not changed:
        print("unchanged")
        say("fix-windows-path: every candidate dir is already on the USER PATH — no write made.")
        raise SystemExit(0)

    print("changed" if not dry else "would_change")
    say("fix-windows-path: USER PATH %d -> %d chars%s" %
        (len(before), len(after), " (dry run, nothing written)" if dry else ""))
    for d in dirs:
        say("  + %s" % d)
    if not dry:
        say("  Restart the terminal for the new value to take effect.")
    raise SystemExit(0)

except wp.WindowsPathError as e:
    # Separate "this interpreter cannot reach the registry at all" from "the write
    # failed": an MSYS2/Cygwin Python has no winreg, and telling the operator their
    # registry write failed would send them looking in entirely the wrong place.
    if "winreg unavailable" in str(e):
        print("not_native_python")
        sys.stderr.write(
            "fix-windows-path: this Python has no `winreg` module, so it is an "
            "MSYS2/Cygwin build, not a native Windows Python. Install Python via "
            "winget or scoop and re-run; nothing was read or written.\n")
        raise SystemExit(7)
    print("error")
    sys.stderr.write("fix-windows-path: %s\n" % e)
    raise SystemExit(5)
PYEOF
exit $?
