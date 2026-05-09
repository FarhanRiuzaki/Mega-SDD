---
description: Pull the latest grand-design-spec from the marketplace repo and refresh the local plugin cache.
argument-hint: (no args)
---

The user wants to update grand-design-spec to the latest version. Do this exactly:

**Step 1 — Locate the marketplace clone.**

Run via Bash:

```
ls -d ~/.claude/plugins/marketplaces/grand-design-spec 2>/dev/null
```

If the directory does not exist, tell the user the plugin isn't installed via marketplace and stop. Suggest `/plugin marketplace add airnd1/grand-design-spec` (or the appropriate add command for their setup).

**Step 2 — Capture the current version (before pulling).**

```
cat ~/.claude/plugins/marketplaces/grand-design-spec/plugins/grand-design-spec/.claude-plugin/plugin.json | grep -E '"version"' | head -1
```

Save the value as `BEFORE_VERSION`.

Also list current cache versions:

```
ls ~/.claude/plugins/cache/grand-design-spec/grand-design-spec/ 2>/dev/null
```

**Step 3 — Fetch latest from origin.**

```
cd ~/.claude/plugins/marketplaces/grand-design-spec && git fetch --all --prune && git pull --ff-only origin main
```

If `git pull` fails (non-fast-forward, conflict, detached HEAD, dirty working tree), do NOT force anything. Show the error to the user and stop with a short diagnosis.

**Step 4 — Read the new version.**

```
cat ~/.claude/plugins/marketplaces/grand-design-spec/plugins/grand-design-spec/.claude-plugin/plugin.json | grep -E '"version"' | head -1
```

Save as `AFTER_VERSION`.

**Step 5 — Report and instruct cache refresh.**

Output a short status block:

```
grand-design-spec update
- before: <BEFORE_VERSION>
- after:  <AFTER_VERSION>
- repo:   pulled cleanly from origin/main
- cache:  <list of cached versions before refresh>
```

Then tell the user the final step is one built-in command (custom slash commands can't invoke other slash commands):

> Run `/plugin marketplace update grand-design-spec` to rebuild the cache to <AFTER_VERSION>. After that, restart Claude Code or reload the plugin so the new commands and skills register.

If `BEFORE_VERSION == AFTER_VERSION`, say "already up to date" and skip the cache-refresh nudge.

**Hard rules:**
- Never run destructive git ops (reset --hard, force pull, checkout -f) — fast-forward only.
- Never touch the user's own working directory; this command operates only inside `~/.claude/plugins/`.
- Never auto-restart Claude Code.
