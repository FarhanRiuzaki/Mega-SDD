# Windows PATH — post-install triage & repair

> Consumed by `install-deps/SKILL.md` Step 6 (Verify), on `OS = windows-bash` only.
> Deterministic half lives in `plugins/mega-sdd/scripts/fix-windows-path.sh`.

## Contents

- [The failure this fixes](#the-failure-this-fixes)
- [Triage — stale PATH vs failed install](#triage--stale-path-vs-failed-install)
- [Where each installer actually puts the binary](#where-each-installer-actually-puts-the-binary)
- [The WindowsApps stub is a different problem](#the-windowsapps-stub-is-a-different-problem)
- [Repair procedure](#repair-procedure)
- [Dangerous methods — never use](#dangerous-methods--never-use)

## The failure this fixes

An installer writes the persisted user PATH (`HKCU\Environment\Path`). A bash
session that is **already running** never sees it — its environment block was
copied at process creation. winget states this outright: *"Path environment
variable modified; restart your shell to use the new value."*

So on Windows, a `verify_cmd` failing right after an install proves **nothing**
about whether the install worked. Reporting `unverified` there is wrong, and it is
what a field run on a Windows 11 + Git Bash + winget laptop did to four tools that
had all installed correctly.

## Triage — stale PATH vs failed install

The distinguishing question is *"will this resolve in a NEW shell?"*, which is
answerable without restarting anything:

```bash
bash "<plugin>/scripts/fix-windows-path.sh" --probe=<binary>
```

| rc | meaning | what to report |
|---|---|---|
| 0 | prints the absolute path — resolves from the persisted PATH | **`verified`**, with "restart the terminal". NOT a halt. |
| 3 | `probe_miss` — not on the persisted PATH either | Real gap. Try the repair below, then re-probe. |
| 4 | `no_interpreter` — no Python, on PATH or at the known install roots | Cannot introspect. Tell the user to restart the terminal and re-run. |
| 6 | not a Windows shell | Should be unreachable; the Step 6 branch is `windows-bash`-gated. |
| 7 | `not_native_python` — the interpreter has no `winreg` (MSYS2/Cygwin build) | Nothing was read or written. Install Python via winget or scoop, then re-run. |

Only after a repair attempt still yields rc 3 should this become
`install_failed` / `verify_after_install_failed`.

## Where each installer actually puts the binary

The reason rc 3 happens even after a successful install: several installers use
directories that are **never** added to PATH on Windows.

| installer | binary lands in | on PATH? |
|---|---|---|
| `winget install <pkg>` | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\<PkgId>_<src>\` | added to USER PATH — but only for **new** shells |
| `winget install Python.Python.3.x` | `%LOCALAPPDATA%\Programs\Python\Python3<XY>\python.exe` | same — and note it ships `python.exe`, never `python3.exe` |
| `pip install --user <pkg>` | `%APPDATA%\Roaming\Python\Python<XY>\Scripts\` | **no** — and this is a *different* dir from the main install's `Scripts` |
| `pipx install <pkg>` | `%USERPROFILE%\.local\bin\` | **no** — pipx tells you to run `pipx ensurepath` |
| `npm install -g <pkg>` | `%APPDATA%\Roaming\npm\` | usually yes |

`Python<XY>` is the packed major+minor — `Python314` for 3.14, not `Python3.14`.

## The WindowsApps stub is a different problem

`python3` / `python` resolving to
`%LOCALAPPDATA%\Microsoft\WindowsApps\python*.exe` is **not** a PATH-staleness
issue — that is the App Execution Alias stub, which prints *"Python was not found;
run without arguments to install from the Microsoft Store…"* to stderr and exits
49. `command -v python3` succeeds against it.

Do not re-implement that detection here. `scripts/_lib/resolve-python.sh`
(`mega_sdd_python`) already rejects any candidate under `WindowsApps` and walks the
ladder `python3` → `python` → `py -3`, fork-free, and is pinned by
`tests/hooks/resolve-python.test.sh`. Note the two interact: prepending a real
interpreter's directory is what lets it **out-rank** the stub, which is why the
repair below prepends rather than appends.

## Repair procedure

1. **Show the user what will change and get confirmation.** This writes a
   persistent machine setting, so it follows the same gate as an install — never
   silent. A dry run produces the exact diff:

   ```bash
   bash "<plugin>/scripts/fix-windows-path.sh" --ensure-dirs --dry-run
   ```

2. **Repair, with a backup.** `--backup-to` is mandatory — the script refuses
   without it, because the corruption modes below are silent and a restore point is
   the only recovery:

   ```bash
   bash "<plugin>/scripts/fix-windows-path.sh" \
     --ensure-dirs --backup-to=<project>/.mega-sdd/memory/path-backup-<ts>.txt
   ```

   Prints `changed` / `unchanged` / `would_change`. It is idempotent: re-running
   makes no write. The write is read back and compared; a mismatch raises rather
   than being assumed good.

3. **Re-probe** (step 1 of Triage). Still rc 3 → the install genuinely did not
   produce the binary → halt.

4. **Tell the user to restart the terminal.** Nothing mega-sdd does can refresh an
   already-running shell's environment block.

To restore from a backup, the file contains the previous value verbatim; write it
back with the same script's Python helper (`windows_path.ensure_user_path_dirs` is
additive, so a full restore is a manual `winreg.SetValueEx` with
`REG_EXPAND_SZ`) — never with any of the methods below.

## Dangerous methods — never use

Every entry here was observed to fail **destructively** on a real machine. They
look like they work, which is what makes them dangerous.

- **`reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "<value>" /f` from Git
  Bash.** The value's backslashes and semicolons are mangled by the `reg` parser.
  It prints `ERROR: Invalid syntax` **while returning RC=0**, so the caller
  believes it succeeded. Writes nothing, or writes partially.
- **A hand-written `.reg` file + `reg import`.** Get the `hex(2)` UTF-16LE encoding
  wrong and `reg import` reports success while storing a corrupt value. Observed: a
  798-character USER PATH truncated to 92 characters, leaving only
  `%USERPROFILE%\AppData\Local\Temp` and a OneDrive entry.
- **`setx PATH "…"`.** Truncates at 1024 characters **and** expands `%VAR%`,
  destroying `REG_EXPAND_SZ` — `%USERPROFILE%` becomes a literal path.
- **Parsing `reg query` output for a long `REG_EXPAND_SZ`.** The shell output wraps
  and acquires artefacts; a mis-parse here silently corrupts PATH. Read
  binary-accurately via `winreg.QueryValueEx` (which `windows_path.py` does).
