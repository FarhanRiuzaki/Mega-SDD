#!/usr/bin/env bash
# detect-os.sh — canonical OS + package-manager detection (audit Phase-2b spec
# 2026-08-11-audit-phase2b-scripts-and-owners.md §S3).
#
# VERBATIM port of skills/install-deps/references/os-detection.md §Detection
# algorithm (canonical), lines 16-119 — keep in sync with that ref (the ref
# keeps the outcome table + special-case notes + fallback-chain policy).
#
# Output contract (consumed by install-deps SKILL.md Step 1):
#   OS: <macos|linux|wsl|windows-bash|unknown> <version> (<distro>)
#   PKG_MGR: <brew|apt|dnf|yum|pacman|apk|winget|scoop|choco|cargo-fallback|none> <version>
#   FALLBACKS: <secondary-native-managers + cargo npm go pipx that resolve>
#
# Read-only: writes nothing but the three stdout lines. Exit 0 always
# (PKG_MGR=none / OS=unknown are OUTPUT states; the pkg_mgr_not_found halt is
# the SKILL's call, not this script's).

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
exit 0
