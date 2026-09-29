---
description: "Maintenance one-timer — force-update mega-sdd to the newest marketplace version and verify the install."
argument-hint: (no args)
---

The user wants to update the `mega-sdd` plugin (shipped via the `mega-sdd` marketplace) to the newest version. This is a FORCED update: refresh the marketplace, update the installed plugin, then verify. Do this exactly:

> **Path note**: the marketplace and the plugin share the name `mega-sdd`. Marketplace-level paths use `marketplaces/mega-sdd/`; the plugin lives inside that clone at `plugins/mega-sdd/`; the cache is keyed `cache/<marketplace>/<plugin>/` → `cache/mega-sdd/mega-sdd/`.

**Step 1 — Locate the marketplace clone.**

```
ls -d ~/.claude/plugins/marketplaces/mega-sdd 2>/dev/null
```

If the directory does not exist, tell the user the plugin isn't installed via marketplace and stop. Suggest `/plugin marketplace add FarhanRiuzaki/Mega-SDD` (or the appropriate add command for their setup).

**Step 2 — Capture the versions before updating.** Run the Step 5 verify command once now; save its `installed=` as `BEFORE_INSTALLED` and its `available=` as `BEFORE_VERSION`.

**Step 3 — Refresh the marketplace.**

```
claude plugin marketplace update mega-sdd
```

If the `claude` CLI is not on PATH, fall back to the clone: `cd ~/.claude/plugins/marketplaces/mega-sdd && git fetch --all --prune && git pull --ff-only origin main`. If that fails (non-fast-forward, conflict, detached HEAD, dirty tree), do NOT force anything: show the error, give a short diagnosis, and stop.

**Step 4 — Update the installed plugin(s)** (non-interactive):

```
claude plugin update mega-sdd@mega-sdd -s user
```

When `installed_plugins.json` also lists `mega-sdd-extras@mega-sdd`, run `claude plugin update mega-sdd-extras@mega-sdd -s user` too. If the CLI stops to confirm a marketplace-declared command (it shows the command and its sha256), show that command to the user verbatim and stop; never pass `-y` or `--accept-command` yourself. Without the CLI this step cannot run, and Step 5 reports FAIL.

**Step 5 — VERIFY (deterministic; never claim success on a mismatch).** The rule: the user-scope `mega-sdd@mega-sdd` entry has installed == available (the clone's `plugin.json` version) AND its `installPath` exists.

```
python3 -c "import json,os; P=os.path.expanduser('~/.claude/plugins'); a=json.load(open(P+'/marketplaces/mega-sdd/plugins/mega-sdd/.claude-plugin/plugin.json'))['version']; e=[x for x in json.load(open(P+'/installed_plugins.json'))['plugins'].get('mega-sdd@mega-sdd',[]) if x.get('scope')=='user'][:1] or [{}]; i=e[0].get('version'); p=e[0].get('installPath',''); print('VERIFY:', 'PASS' if i==a and os.path.isdir(p) else 'FAIL', 'installed=%s available=%s installPath=%s exists=%s' % (i,a,p or '-',os.path.isdir(p)))"
```

Report:

```
mega-sdd update (via mega-sdd marketplace)
- before:    <BEFORE_INSTALLED> (clone <BEFORE_VERSION>)
- available: <available>
- installed: <installed>  (<installPath>)
- VERIFY:    PASS | FAIL
```

On `VERIFY: FAIL`, say the update did NOT land, show the line above, and give the exact manual command: `claude plugin marketplace update mega-sdd && claude plugin update mega-sdd@mega-sdd -s user` (in a terminal), then re-run `/mega-sdd:update-plugin`. If `BEFORE_INSTALLED` already equalled the available version and VERIFY passes, say "already up to date" (the sweep below still runs — dormant dirs accumulate regardless).

**Step 5.5 — Dormant-cache sweep (confirm-first, NEVER silent — spec 2026-08-31-update-plugin-cache-sweep.md).**

Dormant version dirs pile up under the cache and are the root of the version-drift bug class. Sweep them, with ONE batched confirmation:

1. Derive the referenced set — every mega-sdd version `installed_plugins.json` points at, ANY scope (never just entry `[0]` — that was the wrapper bug) — PLUS `BEFORE_INSTALLED`, which this session still runs until it reloads:

```
python3 -c "import json,re,os; s=json.dumps(json.load(open(os.path.expanduser('~/.claude/plugins/installed_plugins.json')))); print(' '.join(sorted(set(re.findall(r'mega-sdd/mega-sdd/([0-9][0-9.]*)', s)))))"
```

2. `DORMANT` = dirs in `~/.claude/plugins/cache/mega-sdd/mega-sdd/` NOT in that set. Empty → report "cache bersih — hanya versi aktif" and skip to the closing note.
3. Ask ONCE via `AskUserQuestion` (keterangan in Indonesian): list the dormant versions (+ total size via `du -sh`), name the referenced version(s) being KEPT, and warn explicitly: **jangan hapus kalau ada sesi Claude Code lain yang masih jalan — sesi berumur panjang bisa masih memegang path versi lama; tutup dulu sesi lain kalau ragu.** Options: **Hapus versi dormant** (recommended — keterangan: yang aktif dipertahankan, aman untuk sesi ini) / **Biarkan** (keterangan: tidak ada yang dihapus; bisa disapu di update berikutnya).
4. On "Hapus": remove each dormant dir individually — the path MUST match the exact prefix `~/.claude/plugins/cache/mega-sdd/mega-sdd/<version>` (no globs outside that prefix, no other plugins' caches, and a referenced version is NEVER in the list). On "Biarkan": do nothing, say so.
5. Convergence note to relay: the OLD version stays referenced until this session reloads — so the NEXT `/mega-sdd:update-plugin` sweeps it. Two consecutive updates converge the cache to a single version.

**Honesty clause (relay verbatim when sweeping):** the sweep is hygiene — it shrinks the drift-bug surface and the disk. What actually GUARANTEES the running version is the latest is a `VERIFY: PASS` update + `/reload-plugins`; never present the sweep as that guarantee.

**Step 6 — Close.** Tell the user: restart Claude Code or run `/reload-plugins` so this session loads the new version (the CLI says a restart is required to apply). Until then, the session-start notice keeps saying which version is running.

> Note: the bare `/mega-sdd` wrapper (`~/.claude/commands/mega-sdd.md`) needs NO manual refresh on update — it resolves the active install path from `installed_plugins.json` at invocation time, and the SessionStart hook re-heals it (version-marker check) every session.

**Hard rules:**
- Never run destructive git ops (reset --hard, force pull, checkout -f) — fast-forward only.
- Never auto-accept a marketplace-declared command (`-y` / `--accept-command`) — a person confirms it.
- Never touch the user's own working directory; this command operates only inside `~/.claude/plugins/`.
- Never auto-restart Claude Code.
