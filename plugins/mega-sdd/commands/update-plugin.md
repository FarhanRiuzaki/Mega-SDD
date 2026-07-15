---
description: Pull the latest mega-sdd plugin from the mega-sdd marketplace repo and refresh the local plugin cache.
argument-hint: (no args)
---

The user wants to update the `mega-sdd` plugin (shipped via the `mega-sdd` marketplace) to the latest version. Do this exactly:

> **Path note**: the marketplace and the plugin share the name `mega-sdd`. Marketplace-level paths use `marketplaces/mega-sdd/`; the plugin lives inside that clone at `plugins/mega-sdd/`; the rebuilt cache is keyed `cache/<marketplace>/<plugin>/` → `cache/mega-sdd/mega-sdd/`.

**Step 1 — Locate the marketplace clone.**

Run via Bash:

```
ls -d ~/.claude/plugins/marketplaces/mega-sdd 2>/dev/null
```

If the directory does not exist, tell the user the plugin isn't installed via marketplace and stop. Suggest `/plugin marketplace add https://scm.bankmegadev.com/ai-rnd/mega-sdd.git` (or the appropriate add command for their setup).

**Step 2 — Capture the current version (before pulling).**

```
cat ~/.claude/plugins/marketplaces/mega-sdd/plugins/mega-sdd/.claude-plugin/plugin.json | grep -E '"version"' | head -1
```

Save the value as `BEFORE_VERSION`.

Also list current cache versions (cache is keyed `<marketplace>/<plugin>/`):

```
ls ~/.claude/plugins/cache/mega-sdd/mega-sdd/ 2>/dev/null
```

**Step 3 — Fetch latest from origin.**

```
cd ~/.claude/plugins/marketplaces/mega-sdd && git fetch --all --prune && git pull --ff-only origin main
```

If `git pull` fails (non-fast-forward, conflict, detached HEAD, dirty working tree), do NOT force anything. Show the error to the user and stop with a short diagnosis.

**Step 4 — Read the new version.**

```
cat ~/.claude/plugins/marketplaces/mega-sdd/plugins/mega-sdd/.claude-plugin/plugin.json | grep -E '"version"' | head -1
```

Save as `AFTER_VERSION`.

**Step 5 — Report and instruct cache refresh.**

Output a short status block:

```
mega-sdd update (via mega-sdd marketplace)
- before: <BEFORE_VERSION>
- after:  <AFTER_VERSION>
- repo:   pulled cleanly from origin/main
- cache:  <list of cached versions before refresh>
```

Then tell the user the final step is one built-in command (custom slash commands can't invoke other slash commands):

> Run `/plugin marketplace update mega-sdd` to rebuild the cache to <AFTER_VERSION>. After that, run `/reload-plugins` (or restart Claude Code) so the new commands and skills register.

If `BEFORE_VERSION == AFTER_VERSION`, say "already up to date" and skip the cache-refresh nudge.

**Hard rules:**
- Never run destructive git ops (reset --hard, force pull, checkout -f) — fast-forward only.
- Never touch the user's own working directory; this command operates only inside `~/.claude/plugins/`.
- Never auto-restart Claude Code.
