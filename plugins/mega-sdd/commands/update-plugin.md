---
description: Pull the latest mega-sdd plugin from the grand-design-spec marketplace repo and refresh the local plugin cache.
argument-hint: (no args)
---

The user wants to update the `mega-sdd` plugin (shipped via the `grand-design-spec` marketplace) to the latest version. Do this exactly:

> **Path note**: the marketplace repo and its local clone keep the historical name `grand-design-spec`. The plugin inside it was renamed to `mega-sdd` in v1.2. So marketplace-level paths use `grand-design-spec/`; plugin-level paths inside that clone use `plugins/mega-sdd/`.

**Step 1 — Locate the marketplace clone.**

Run via Bash:

```
ls -d ~/.claude/plugins/marketplaces/grand-design-spec 2>/dev/null
```

If the directory does not exist, tell the user the plugin isn't installed via marketplace and stop. Suggest `/plugin marketplace add airnd1/grand-design-spec` (or the appropriate add command for their setup).

**Step 2 — Capture the current version (before pulling).**

```
cat ~/.claude/plugins/marketplaces/grand-design-spec/plugins/mega-sdd/.claude-plugin/plugin.json | grep -E '"version"' | head -1
```

Save the value as `BEFORE_VERSION`.

If that path returns nothing, the user may be on a pre-v1.2 clone where the plugin folder was still named `grand-design-spec/`. Fall back to:

```
cat ~/.claude/plugins/marketplaces/grand-design-spec/plugins/grand-design-spec/.claude-plugin/plugin.json | grep -E '"version"' | head -1
```

Also list current cache versions (cache keeps the historical `grand-design-spec/grand-design-spec/` shape because it's keyed by marketplace slug):

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
cat ~/.claude/plugins/marketplaces/grand-design-spec/plugins/mega-sdd/.claude-plugin/plugin.json | grep -E '"version"' | head -1
```

Save as `AFTER_VERSION`. (If on a pre-v1.2 fallback clone, use the `plugins/grand-design-spec/...` path from Step 2.)

**Step 5 — Report and instruct cache refresh.**

Output a short status block:

```
mega-sdd update (via grand-design-spec marketplace)
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
