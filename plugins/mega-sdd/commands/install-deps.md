---
description: "Maintenance — detect OS + pkg manager, install missing optional native deps (tree-sitter, ast-grep, pandoc, …) with one batch confirm; never auto-sudo, never curl|bash."
argument-hint: "[--dry-run] [--tools=<csv>] [--force-recheck] [--pkg-mgr=<name>] [--manual] [--auto]"
---

Invoke the `mega-sdd:install-deps` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- `--dry-run`: show install plan + estimated sizes; don't execute (useful to preview)
- `--tools=<csv>`: limit to subset (e.g., `--tools=pandoc,mmdc` for emit PDF deps only)
- `--force-recheck`: accepted no-op modifier — every run already re-audits from scratch (v7.3.0)
- `--pkg-mgr=<name>`: override auto-detected manager (e.g., `--pkg-mgr=cargo` to use Rust toolchain instead of brew/apt)
- `--manual`: print install commands as instructions but skip Bash invocation (user runs manually)
- `--auto`: emit handoff YAML (orchestrator-invoked); the batch confirmation still runs

Follow `skills/install-deps/SKILL.md` Procedure exactly.

Hard rails (anti-halu + safety):
- NEVER auto-`sudo` — for tools requiring elevation (most apt/dnf installs), the skill PRINTS the command + instructs user to run manually. Memory records as "sudo-pending".
- NEVER use curl|bash patterns — only signed package manager commands per `tool-matrix.yaml`.
- ALWAYS show exact `install_cmd` + source pkg manager + size estimate BEFORE running.
- Single batch confirmation via AskUserQuestion — user sees full plan before any install runs.
- ALWAYS verify post-install with `verify_cmd` from matrix — claim "installed" only after verify passes.
- Memory write happens AFTER verify pass — never record "installed" on partial state.
- This skill installs OPTIONAL mega-sdd deps only — never installs Claude Code itself.

On completion, announce summary: "✅ Install complete: N verified, M failed, K skipped. Memory: outcomes written to <path>."
