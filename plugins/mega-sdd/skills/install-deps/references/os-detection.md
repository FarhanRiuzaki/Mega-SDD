# OS Detection — Canonical Bash Algorithm

> Consumed by `install-deps/SKILL.md` Step 1 (Detect environment).
> Cross-platform Bash patterns: macOS / Linux (Ubuntu/Debian/Fedora/Arch/Alpine) / WSL / Windows-bash (git-bash / MSYS2).

## Detection algorithm (canonical)

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

# === Step 3: Detect cross-platform fallback managers ===
FALLBACKS=""
command -v cargo >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}cargo "
command -v npm >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}npm "
command -v go >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}go "
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
- **Windows native (no WSL, no git-bash)**: out of scope for Iter 55 — user instructed to install WSL Ubuntu and re-run.
- **Alpine `apk`**: most mega-sdd deps (pandoc, tree-sitter) NOT available in default `apk` repos. Cross-platform cargo fallback used heavily on Alpine.

## Fallback chain

When primary PKG_MGR lacks a tool (per `tool-matrix.yaml`), install-deps Step 3 tries fallback managers in this order:

1. `cargo` (Rust-based: tree-sitter-cli, ast-grep, ripgrep, tectonic)
2. `npm` (Node-based: markdownlint-cli2, tree-sitter-cli, @ast-grep/cli)
3. `go install` (Go-based: jd)

If a tool has no matching `(tool, os, pkg_mgr)` entry AND no fallback works, mark tool as `unsupported` in install plan + skip with warning (don't halt — graceful degradation).

## Cross-reference

- `tool-matrix.yaml` — encodes which install_cmd to use per detected (OS, PKG_MGR) tuple
- `SKILL.md` §Procedure Step 1 — invokes this algorithm
- `SKILL.md` §Halt protocol — `pkg_mgr_not_found` halt fires when PKG_MGR = `none` AND no fallbacks
