#!/usr/bin/env bash
# resolve-python.sh — shared, fork-free Python interpreter probe.
#
# WHY THIS EXISTS
# ---------------
# `command -v python3` is a FALSE POSITIVE on Windows, and every mega-sdd hook
# was relying on it to decide whether to fail closed.
#
# Windows ships App Execution Alias stubs at
#   %LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe   (and python.exe)
# installed by the App Installer package — NOT by Python — and that directory is
# on the default per-user PATH. With no real interpreter present the stub prints
# "Python was not found; run without arguments to install from the Microsoft
# Store, ..." to STDERR and exits 49.
#
# The consequence inside a hook:
#     PARSE_OUTPUT=$(printf '%s' "$JSON" | python3 -c '...' 2>/dev/null)
#     # -> EMPTY (message went to stderr, which is discarded)
#     if [ -z "$PARSE_OUTPUT" ]; then
#       if ! command -v python3 >/dev/null 2>&1; then   # <- SUCCEEDS: stub IS on PATH
#         ... fail-closed ...                           # <- never reached
#       fi
#       exit 0                                          # <- every gate skipped, silently
#     fi
#
# Net effect: the binding->units gate, the CONFLICT gate, the quality gates and
# anti-self-bypass all pass without being evaluated, with no diagnostic anywhere.
# Measured on a Windows 11 corporate laptop 2026-07-28: `python3` AND `python`
# both resolved to the alias stub, `py` absent — zero usable interpreters, and
# the plugin reported nothing.
#
# CONTRACT
# --------
#   mega_sdd_python
#       Sets MEGA_SDD_PY to a usable interpreter command and returns 0, or
#       leaves it EMPTY and returns 1 when no usable interpreter exists.
#       Result is memoized per process.
#
#   Callers MUST expand it UNQUOTED — `py -3` is two words:
#       $MEGA_SDD_PY -c 'import json, sys; ...'
#
# COST
# ----
# Zero forks. The PATH scan uses only builtin `[ -x ]` tests and assigns through
# a global; a command substitution would itself be a bash.exe fork under Git
# Bash — precisely the cost this helper exists to avoid.

# True when a resolved path lives in the Windows App Execution Alias directory.
# Windows paths are case-insensitive, so the pattern is spelled out per-character
# rather than relying on shopt -s nocasematch (which is not safe to toggle
# globally inside a sourced helper).
_mega_sdd_py_is_alias() {
  case "$1" in
    *[Ww][Ii][Nn][Dd][Oo][Ww][Ss][Aa][Pp][Pp][Ss]/*) return 0 ;;
    *[Ww][Ii][Nn][Dd][Oo][Ww][Ss][Aa][Pp][Pp][Ss]\\*) return 0 ;;
  esac
  return 1
}

# Sets _MEGA_SDD_PY_HIT to the FIRST executable PATH hit for $1, or empty.
# "First hit" deliberately mirrors what the shell itself would execute: if the
# alias directory precedes a real interpreter on PATH, that NAME is unusable —
# returning it would hand the caller the stub.
_mega_sdd_py_first_on_path() {
  _MEGA_SDD_PY_HIT=""
  local name="$1" d p oldifs="$IFS"
  IFS=':'
  for d in $PATH; do
    [ -n "$d" ] || d='.'
    for p in "$d/$name" "$d/$name.exe"; do
      if [ -f "$p" ] && [ -x "$p" ]; then
        IFS="$oldifs"
        _MEGA_SDD_PY_HIT="$p"
        return 0
      fi
    done
  done
  IFS="$oldifs"
  return 1
}

mega_sdd_python() {
  # memoized: _MEGA_SDD_PY_DONE is set once per process, either way
  if [ -n "${_MEGA_SDD_PY_DONE:-}" ]; then
    [ -n "${MEGA_SDD_PY:-}" ] && return 0
    return 1
  fi
  _MEGA_SDD_PY_DONE=1
  MEGA_SDD_PY=""

  local cand
  for cand in python3 python; do
    if _mega_sdd_py_first_on_path "$cand"; then
      _mega_sdd_py_is_alias "$_MEGA_SDD_PY_HIT" && continue
      MEGA_SDD_PY="$cand"
      return 0
    fi
  done

  # Windows launcher fallback. `py` is installed by python.org outside the alias
  # directory, so it still resolves a real interpreter when the bare names are
  # shadowed by the stub.
  if _mega_sdd_py_first_on_path py; then
    if ! _mega_sdd_py_is_alias "$_MEGA_SDD_PY_HIT"; then
      MEGA_SDD_PY="py -3"
      return 0
    fi
  fi

  return 1
}

# One-line, human-facing remedy string — kept here so every surface that reports
# a missing interpreter says the same thing.
mega_sdd_python_remedy() {
  printf '%s' "python3 tidak tersedia (di Windows biasanya karena App Execution Alias stub di WindowsApps yang bukan Python asli). Jalankan \`/mega-sdd:install-deps\` — di Windows pilih route scoop (\`scoop install python\`), satu-satunya package manager yang menghasilkan perintah \`python3\` berfungsi; winget/python.org hanya memasang python.exe + py.exe sehingga \`python3\` tetap jatuh ke stub. Alternatif: matikan alias di Settings > Apps > Advanced app settings > App execution aliases lalu pasang Python."
}
