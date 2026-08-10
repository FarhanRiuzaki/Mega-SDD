# OS Detection — Canonical Bash Algorithm

> Consumed by `install-deps/SKILL.md` Step 1 (Detect environment).
> Cross-platform Bash patterns: macOS / Linux (Ubuntu/Debian/Fedora/Arch/Alpine) / WSL / Windows-bash (git-bash / MSYS2).

## Contents

- Detection algorithm (canonical)
- Detection outcome table
- Special-case notes
- Fallback chain
- Cross-reference

## Detection algorithm (canonical)

> **OWNED by `scripts/detect-os.sh` — run the script; never transcribe this block.** The bash below remains as the script's readable spec (keep the two in sync when either changes).

```bash
# === Step 1: Detect OS family ===
OS=""
OS_VERSION=""
DISTRO=""

case "$OSTYPE" in
  darwin*)
    OS="macos"
    OS_VERSION=$(sw_vers -productVersion 2>/dev/null)
    ;;
  linux-gnu*|linux*)
    if uname -a 2>/dev/null | grep -qi microsoft; then
      OS="wsl"
    else
      OS="linux"
    fi
    if [ -f /etc/os-release ]; then
      DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"')
      OS_VERSION=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"')
    fi
    ;;
  msys*|cygwin*)
    OS="windows-bash"
    OS_VERSION=$(uname -r 2>/dev/null)
    ;;
  *)
    OS="unknown"
    ;;
esac

# === Step 2: Detect primary package manager ===
PKG_MGR="none"
PKG_MGR_VERSION=""

case "$OS" in
  macos)
    if command -v brew >/dev/null 2>&1; then
      PKG_MGR="brew"
      PKG_MGR_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
    fi
    ;;
  linux|wsl)
    case "$DISTRO" in
      ubuntu|debian|linuxmint|pop|elementary)
        if command -v apt >/dev/null 2>&1; then
          PKG_MGR="apt"
          PKG_MGR_VERSION=$(apt --version 2>/dev/null | awk '{print $2}')
        fi
        ;;
      fedora|rhel|centos|rocky|alma|amzn)
        if command -v dnf >/dev/null 2>&1; then
          PKG_MGR="dnf"
        elif command -v yum >/dev/null 2>&1; then
          PKG_MGR="yum"   # legacy fallback
        fi
        ;;
      arch|manjaro|endeavouros|garuda)
        command -v pacman >/dev/null 2>&1 && PKG_MGR="pacman"
        ;;
      alpine)
        command -v apk >/dev/null 2>&1 && PKG_MGR="apk"
        ;;
      *)
        PKG_MGR="cargo-fallback"   # unknown distro; try cargo if available
        ;;
    esac
    ;;
  windows-bash)
    if command -v winget >/dev/null 2>&1; then
      PKG_MGR="winget"
    elif command -v scoop >/dev/null 2>&1; then
      PKG_MGR="scoop"
    elif command -v choco >/dev/null 2>&1; then
      PKG_MGR="choco"
    fi
    ;;
esac

# === Step 3: Detect fallback managers ===
FALLBACKS=""
# On Windows, a SECONDARY native manager (scoop/winget/choco that is present but is
# NOT the detected primary) is a first-class fallback. Several tools (tree-sitter,
# ast-grep, jd) ship natively only via scoop, so a winget-primary box must
# still reach them when scoop is installed — prefer these over runtime installs.
if [ "$OS" = "windows-bash" ]; then
  for m in scoop winget choco; do
    if [ "$m" != "$PKG_MGR" ] && command -v "$m" >/dev/null 2>&1; then
      FALLBACKS="${FALLBACKS}${m} "
    fi
  done
fi
# Cross-platform runtime fallbacks (work on every OS incl. Windows when present)
command -v cargo >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}cargo "
command -v npm >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}npm "
command -v go >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}go "
command -v pipx >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}pipx "   # Python-based tools: semgrep
FALLBACKS=$(echo "$FALLBACKS" | sed 's/ $//')   # trim trailing space

# === Output (consumed by install-deps SKILL.md Step 1) ===
echo "OS: $OS $OS_VERSION ($DISTRO)"
echo "PKG_MGR: $PKG_MGR $PKG_MGR_VERSION"
echo "FALLBACKS: $FALLBACKS"
```

## Detection outcome table

| OSTYPE pattern | OS | Distro examples | Primary PKG_MGR |
|---|---|---|---|
| `darwin*` | `macos` | n/a | `brew` (or `none` if absent) |
| `linux-gnu*` (no microsoft) | `linux` | ubuntu, debian, fedora, arch, alpine | `apt` / `dnf` / `pacman` / `apk` / `cargo-fallback` |
| `linux-gnu*` (microsoft) | `wsl` | usually ubuntu | `apt` (most common in WSL) |
| `msys*` / `cygwin*` | `windows-bash` | git-bash / MSYS2 | `winget` / `scoop` / `choco` / `none` |
| unknown | `unknown` | — | `none` (halt `pkg_mgr_not_found`) |

## Special-case notes

- **macOS without brew**: PKG_MGR = `none` initially; install-deps proposes installing brew first via official Apple-pkg-manager-friendly method. Auto-execution of Homebrew's own install script (`/bin/bash -c "$(curl -fsSL https://...)"`) is FORBIDDEN per safety rails — instead, point user to https://brew.sh and instruct manual install.
- **WSL Ubuntu without `apt`**: extremely rare; happens in chroot/container envs. Halt `pkg_mgr_not_found` with hint to install apt.
- **Windows native (no WSL, no git-bash)**: out of scope — user instructed to install WSL Ubuntu (or git-bash) and re-run.
- **Windows + winget primary**: `ripgrep`, `pandoc`, `tree-sitter` (`tree-sitter.tree-sitter-cli`), `ast-grep` (`ast-grep.ast-grep`), `jd` (`josephburnett.jd`), and `gitleaks` (`Gitleaks.Gitleaks`) all install via winget; `scoop` remains an alternative source and `go` the cross-platform fallback for gitleaks; `semgrep` is Python-based and installs via `pipx`. If a tool's needed manager (pipx for semgrep / a runtime) is absent, it is reported `unsupported` with the concrete remedy (install pipx / a runtime) — not a silent skip. This was the "some deps don't install on Windows" gap.
- **Alpine `apk`**: most mega-sdd deps (pandoc, tree-sitter) NOT available in default `apk` repos. Cross-platform cargo fallback used heavily on Alpine.

## Fallback chain

When primary PKG_MGR lacks a tool (per `tool-matrix.yaml`), install-deps Step 3 tries fallback managers in this order:

0. **(Windows only)** a secondary native Windows manager that is installed but not the primary — `scoop`, then `winget`, then `choco`. Every matrix tool with a Windows row (`tree-sitter`, `ast-grep`, `ripgrep`, `jd`, `pandoc`, `gitleaks`) now has BOTH winget and scoop routes, so this step matters mainly for a box whose primary manager lacks a specific package version or is broken.
1. `cargo` (Rust-based: tree-sitter-cli, ast-grep, ripgrep)
2. `npm` (Node-based: markdownlint-cli2, tree-sitter-cli, @ast-grep/cli)
3. `go install` (Go-based: jd, gitleaks)
4. `pipx` (Python-based: semgrep)

**Detected-but-no-matrix-row managers.** Some managers are detected as a primary yet have **no rows in `tool-matrix.yaml`**: `choco` (Windows) and `yum` (legacy RHEL/CentOS), plus `pacman`/`apk`. A box whose primary is one of these detects the manager but installs nothing *from* it — every tool routes through the runtime fallback chain above (`cargo`/`npm`/`go`/`pipx`). This is by design: the runtime installers are cross-platform, so choco/yum/pacman/apk are treated as detect-only-then-fallback rather than carrying their own tool rows.

If a tool has no matching `(tool, os, pkg_mgr)` entry AND no fallback works, mark tool as `unsupported` in install plan + skip with warning (don't halt — graceful degradation). On Windows specifically, when an `unsupported` tool was skipped purely for lack of a manager, the warning MUST name the concrete remedy — "install `scoop` (https://scoop.sh) then re-run, or install Node/Rust/Go/pipx for the cross-platform fallback" — rather than a bare skip, so the user knows why the tool is missing and how to get it.

> **The scoop remedy has a precondition, and on a locked-down corporate image it can be unreachable.** Scoop's official bootstrap is **PowerShell-only** (`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then `irm get.scoop.sh | iex`). Where PowerShell is blocked by Group Policy — a common bank/government build, where `cmd` and Git Bash are the only shells — scoop cannot be installed at all, so pointing the user there is a dead end. On such a box say so explicitly and route to `winget` instead, verifying `python` rather than `python3` (see the `python3` rows in `tool-matrix.yaml`: the winget/python.org installer never ships `python3.exe`, and `resolve-python.sh`'s ladder falls through to `python`).

## Cross-reference

- `tool-matrix.yaml` — encodes which install_cmd to use per detected (OS, PKG_MGR) tuple
- `SKILL.md` §Procedure Step 1 — invokes this algorithm
- `SKILL.md` §Halt protocol — `pkg_mgr_not_found` halt fires when PKG_MGR = `none` AND no fallbacks
