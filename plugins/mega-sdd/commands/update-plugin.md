---
description: "Maintenance one-timer — pull the latest mega-sdd from the marketplace clone and guide the cache refresh."
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

If `BEFORE_VERSION == AFTER_VERSION`, say "already up to date" and skip the cache-refresh nudge (the cache sweep below still runs — dormant dirs accumulate regardless).

**Step 5.5 — Dormant-cache sweep (confirm-first, NEVER silent — spec 2026-08-31-update-plugin-cache-sweep.md).**

Dormant version dirs pile up under the cache and are the root of the version-drift bug class (the field wrapper once resolved a 6.6.0 dormant install). Sweep them, with ONE batched confirmation:

1. Derive the referenced set — every mega-sdd version `installed_plugins.json` points at, ANY scope (never just entry `[0]` — that was the wrapper bug):

```
python3 -c "import json,re,os; s=json.dumps(json.load(open(os.path.expanduser('~/.claude/plugins/installed_plugins.json')))); print(' '.join(sorted(set(re.findall(r'mega-sdd/mega-sdd/([0-9][0-9.]*)', s)))))"
```

2. `DORMANT` = dirs in `~/.claude/plugins/cache/mega-sdd/mega-sdd/` NOT in that set. Empty → report "cache bersih — hanya versi aktif" and skip to the closing note.
3. Ask ONCE via `AskUserQuestion` (keterangan in Indonesian): list the dormant versions (+ total size via `du -sh`), name the referenced version(s) being KEPT, and warn explicitly: **jangan hapus kalau ada sesi Claude Code lain yang masih jalan — sesi berumur panjang bisa masih memegang path versi lama; tutup dulu sesi lain kalau ragu.** Options: **Hapus versi dormant** (recommended — keterangan: yang aktif dipertahankan, aman untuk sesi ini) / **Biarkan** (keterangan: tidak ada yang dihapus; bisa disapu di update berikutnya).
4. On "Hapus": remove each dormant dir individually — the path MUST match the exact prefix `~/.claude/plugins/cache/mega-sdd/mega-sdd/<version>` (no globs outside that prefix, no other plugins' caches, and a referenced version is NEVER in the list). On "Biarkan": do nothing, say so.
5. Convergence note to relay: the OLD active version only becomes dormant AFTER the user runs `/plugin marketplace update` + `/reload-plugins` — so the NEXT `/mega-sdd:update-plugin` sweeps it. Two consecutive updates converge the cache to a single version.

**Honesty clause (relay verbatim when sweeping):** the sweep is hygiene — it shrinks the drift-bug surface and the disk. What actually GUARANTEES the running version is the latest is `/plugin marketplace update` + `/reload-plugins`; never present the sweep as that guarantee.

> Note: the bare `/mega-sdd` wrapper (`~/.claude/commands/mega-sdd.md`) needs NO manual refresh on update — it resolves the active install path from `installed_plugins.json` at invocation time, and the SessionStart hook re-heals it (version-marker check) every session.

**Hard rules:**
- Never run destructive git ops (reset --hard, force pull, checkout -f) — fast-forward only.
- Never touch the user's own working directory; this command operates only inside `~/.claude/plugins/`.
- Never auto-restart Claude Code.
