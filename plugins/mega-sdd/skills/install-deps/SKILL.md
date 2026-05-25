---
name: install-deps
version: 1.0.0
description: Auto-detect OS + package manager (brew/apt/dnf/pacman/apk/winget/scoop/cargo/npm/go) and install missing native deps mega-sdd can leverage (tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh). Single explicit batch confirmation; never auto-sudo; never curl|bash; mandatory post-install verify; memory-cached outcomes. Triggers — "install deps", "auto install", "install tools", "install pandoc", "pasang tools", "auto install deps", or paraphrases.
---

# Install-Deps — OS-Aware Dependency Installer

**Announce at start:** "I'm using the install-deps skill to audit + install missing native deps."

## When to use

- "install deps" / "auto install" / "install tools" / "pasang tools"
- After fresh mega-sdd install — bootstrap optional native binaries
- After predictive-checks warn (e.g., `pandoc_installed: warn` from emit-fsd predictive checks)
- After Iter 54 emit-fsd ship — pandoc + tectonic needed for FSD PDF
- Cross-machine re-sync (memory layer skips already-installed tools)

## Inputs

- `--dry-run` (show install plan; don't execute)
- `--tools=<csv>` (limit to subset, e.g., `--tools=pandoc,tectonic` for FSD-only)
- `--force-recheck` (ignore memory; re-audit every tool from scratch)
- `--pkg-mgr=<name>` (override auto-detected manager; e.g., force `cargo` instead of `brew`)
- `--manual` (print install commands but skip Bash invocation — user runs commands themselves)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per orchestrate-flow handoff-contract)

## Outputs

```
<project>/.mega-sdd/memory/install-outcomes.md   # memory log of install runs
```

Plus chat-only output: detected OS, tool inventory, install plan, per-tool verify result.

## Pre-flight checks

1. **pkg_mgr_detected**: at least one of (brew | apt | dnf | pacman | apk | winget | scoop | cargo | npm | go) is on PATH
   - If none → halt `pkg_mgr_not_found`
2. **memory_writable**: `<project>/.mega-sdd/memory/` exists and writable (or can be created)

## Procedure

(filled in Task 4 — see plan)

## Halt protocol

(filled in Task 4)

## Handoff emission (v1.0.0+, Iter 55)

(filled in Task 4)
