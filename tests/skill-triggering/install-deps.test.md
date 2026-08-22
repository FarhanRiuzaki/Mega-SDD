# /mega-sdd:install-deps Trigger + Behavior Test

Iter 55 — OS-aware dependency installer. Cross-platform detection (macOS / Linux distro / WSL / Windows-bash). Safety rails: NEVER auto-sudo / NEVER curl|bash / mandatory verify. (v7.3.0: no memory cache — every run re-probes.)

## Trigger cases

### ID1: macOS brew detection + audit
- **Setup:** macOS with `brew --version` returning v4.x; pandoc + mmdc not installed
- **Prompt:** `/mega-sdd:install-deps`
- **Expect:** Skill detects `OS: macos`, `PKG_MGR: brew`; audits 8 tools; identifies 2 missing (pandoc, mmdc); proposes install plan with sizes (~70MB total); AskUserQuestion shown with `[Install all]` / `[Pick subset]` / `[Cancel]`

### ID2: Ubuntu apt detection + sudo separation
- **Setup:** Ubuntu 22.04 in WSL; `apt --version` working; pandoc missing
- **Prompt:** `/mega-sdd:install-deps`
- **Expect:** Skill detects `OS: wsl`, `PKG_MGR: apt`; pandoc identified as `requires_sudo: true`; auto-execute plan EXCLUDES pandoc; pandoc shown in "Manual install required" list with instruction `sudo apt install -y pandoc`

### ID3: Windows-bash winget detection
- **Setup:** Git Bash on Windows 11 with winget on PATH
- **Prompt:** `/mega-sdd:install-deps`
- **Expect:** Skill detects `OS: windows-bash`, `PKG_MGR: winget`; install_cmd uses `winget install <pkg-id>` per tool-matrix.yaml

### ID4: Cross-platform cargo fallback
- **Setup:** Alpine Linux; default `apk` has no ast-grep package; cargo present
- **Prompt:** `/mega-sdd:install-deps --tools=ast-grep`
- **Expect:** Skill falls through apk (no ast-grep entry) → tries cargo fallback → install_cmd: `cargo install ast-grep`

### ID5: pkg_mgr_not_found halt
- **Setup:** macOS without brew installed; no cargo/npm/go on PATH
- **Prompt:** `/mega-sdd:install-deps`
- **Expect:** Halt `pkg_mgr_not_found` with details `{os: macos, attempted_pkg_mgrs: [brew], fallbacks_attempted: []}`; next_action hint points to https://brew.sh

### ID6: install_failed halt on verify failure
- **Setup:** macOS with brew; install plan approved; pretend brew install succeeds but tool not on PATH (PATH not refreshed)
- **Prompt:** `/mega-sdd:install-deps --tools=ripgrep`
- **Expect:** Install runs; verify_cmd `command -v rg` fails; halt `install_failed` with `subtype: verify_after_install_failed`; resolution hint includes `hash -r` + re-run

### ID7: Memory cache skips re-audit
- **Setup:** install-outcomes.md exists with `ast-grep: ✓ installed v0.31.0 (2026-05-26)`; `command -v ast-grep` still passes
- **Prompt:** `/mega-sdd:install-deps`
- **Expect:** ast-grep re-probed like every tool (v7.3.0: no cache); all tools audited normally

### ID8: --force-recheck accepted as a no-op modifier (v7.3.0)
- **Setup:** same as ID7
- **Prompt:** `/mega-sdd:install-deps --force-recheck`
- **Expect:** ast-grep re-audited from scratch (identical to a bare run)

### ID9: --dry-run prints plan without execution
- **Setup:** vault stable; pandoc + mmdc missing
- **Prompt:** `/mega-sdd:install-deps --dry-run`
- **Expect:** Skill prints install plan (commands, sizes) but does NOT invoke Bash tool to run them

### ID10: --manual flag prints commands as instructions
- **Setup:** any OS
- **Prompt:** `/mega-sdd:install-deps --manual`
- **Expect:** Skill prints install_cmd values as numbered instructions for user to run themselves; does NOT invoke Bash; informational only

### ID11: --tools=<csv> filters subset
- **Setup:** all 8 tools missing
- **Prompt:** `/mega-sdd:install-deps --tools=pandoc,mmdc`
- **Expect:** Only pandoc + mmdc in install plan; other 6 tools skipped (NOT marked missing in chat output for this run)

### ID12: --pkg-mgr override
- **Setup:** macOS with brew available; user prefers cargo for Rust tools
- **Prompt:** `/mega-sdd:install-deps --tools=tree-sitter --pkg-mgr=cargo`
- **Expect:** Skill uses cargo entry from tool-matrix instead of brew entry; install_cmd: `cargo install tree-sitter-cli`

## Anti-halu rail verification (mandatory checks)

- **NEVER auto-sudo:** ID2 verifies sudo-required tools are printed but NOT executed via Bash
- **NEVER curl|bash:** tool-matrix.yaml has NO entry containing `curl |` or `wget |` patterns (audit step: grep returns 0 matches)
- **ALWAYS show plan before run:** ID1 verifies AskUserQuestion gate fires before any Bash invocation
- **ALWAYS verify post-install:** ID6 verifies verify_cmd halts when tool not on PATH
- **Memory write AFTER verify pass:** ID6 (halted) does NOT write to install-outcomes.md

## Pass criteria

All ID1-ID12 succeed per `skills/install-deps/SKILL.md` Procedure. OS detection correct across macOS / Ubuntu / Fedora / Arch / Alpine / WSL / Windows-bash. Safety rails enforced. Memory layer integration (install-outcomes.md) correctly caches + invalidates.
