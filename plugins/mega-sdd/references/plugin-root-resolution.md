# Resolving `$PLUGIN_ROOT` to the latest cached version

Every pipeline skill that runs a bundled script (`scripts/*.sh`) or reads a
bundled template/reference must first resolve **`$PLUGIN_ROOT`** — the absolute
path of the mega-sdd plugin. This note is the single source of truth for how;
the deterministic logic lives in [`scripts/resolve-plugin-root.sh`](../scripts/resolve-plugin-root.sh).

## The hazard

Claude Code keeps **every** downloaded plugin version side-by-side under
`~/.claude/plugins/cache/mega-sdd/mega-sdd/<version>/` and never garbage-collects
old ones. `${CLAUDE_PLUGIN_ROOT}` is **not** substituted inside reference files
and **not** exported to the Bash tool, so a skill must derive its root from a
path it already has. In a long session — or inside a dispatched subagent handed
a path built before a `/plugin marketplace update` — that derived path can point
at an **old** cache dir whose files still physically exist. The Read/Bash then
silently succeeds against stale templates or stale scripts. (Real instance: a
`generate-intent` subagent read `…/4.31.0/…/templates/04-flows.md` while the
session was on 4.36.0.)

## The resolution (copy this snippet into the block)

`DERIVED` = this reference file's own absolute path truncated before `/skills/`.
The invocation is **anchored to the version-independent cache glob**, never to
`DERIVED` — so a resolver from *any* cached version that has one re-anchors to
the true latest; it falls back to `DERIVED` only when no cached resolver exists
(manual / project-scoped / claude.ai / repo-dev installs, which have no
multi-version cache and so no staleness to fix).

```bash
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
# …then use "$PLUGIN_ROOT/scripts/<name>.sh" or "$PLUGIN_ROOT/skills/<skill>/references/templates/<name>.md"
```

The outer `tail -1` being a lexical pick is harmless: every cached resolver is
identical and re-globs/sorts version basenames numerically
(`sort -t. -k1,1n -k2,2n -k3,3n` — not `sort -V`, which macOS/BSD `sort` lacks),
so whichever one runs returns the same true-latest root. When no version ships a
resolver yet (all-old cache), `PLUGIN_ROOT` degrades to `DERIVED` — never worse
than deriving directly.

"Latest" means highest SemVer dir present; on a deliberate downgrade, prune the
cache to pin an older one. See the script header for that assumption.
