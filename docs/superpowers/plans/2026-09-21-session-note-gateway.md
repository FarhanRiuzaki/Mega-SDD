# Session Note (in-band gateway audit line) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On gateway-routed sessions, print one sanitized `mega-sdd-note:` line (repo / branch / head / dir / sdd / plugin version) into the session context at SessionStart, so the office AI gateway can read it from its Langfuse → ClickHouse log.

**Architecture:** One new pure-shell hook body `hooks/session-note`, registered as the second hook of the existing SessionStart group. No network, no python, no state, at most two `git` spawns. Every other hook body and `publish-artifacts.sh` stay untouched.

**Tech Stack:** bash 3.2-compatible shell (macOS `/bin/bash`, Git Bash on Windows, bash 5 on CI), `git`, python3 only inside test suites.

**Spec:** `docs/superpowers/specs/2026-09-21-session-note-gateway-design.md`

## Global Constraints

- Hook event count stays SIX; `hooks/stop`, `hooks/user-prompt-submit`, `publish-artifacts.sh` are NOT edited; `hooks/session-start` gets a comment-only pointer.
- Namespace is `mega-sdd-note:` — output must never contain `mega-sdd-trace`.
- Vanilla session (`ANTHROPIC_BASE_URL` unset/empty) → no output, zero `git` calls.
- At most TWO `git` spawns per firing; no python, no network, no file written anywhere.
- `repo` is exact-or-`invalid`: whitelist `[A-Za-z0-9._/~-]`, ≤ 200 chars. `branch`/`dir`: chars outside `[A-Za-z0-9._/-]` → `_`, caps 100 / 64. `head`: 7 hex or `none`. `v`: `[0-9A-Za-z.+-]` ≤ 32 or `unknown`. No value is ever empty or contains a space.
- Only the FIRST line of any `git` output is read; nothing from stdin or git is ever `eval`'d.
- Every failure path: `exit 0`, no output.
- The body must carry the literal `HOOK_SELF="${0//\\//}"` guard and never derive a path from raw `$0` (pinned by `tests/hooks/direct-dispatch.test.sh` D2).
- hooks.json: the new hook is `hooks[1]` of `SessionStart[0]` — `SessionStart[0].hooks[0]` must stay `session-start` (`tests/weighted-routing/test-spawn-ceilings.sh` reads that index). Sync hooks carry a `statusMessage` (`tests/delta-hygiene/test-a1-a4.sh` A3).
- Release = ONE commit `release(8.7.0): …` on `main`; `plugin.json` == `marketplace.json` == newest `CHANGELOG.md` entry. Never `git add -A` (a parallel session may share the tree) — stage explicit paths.
- Both test trees (`plugins/mega-sdd/tests` + `tests`) run before claiming green; suites run with `</dev/null`.

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `plugins/mega-sdd/hooks/session-note` | create (mode 755) | the hook body — gate, git facts, normalize, sanitize, print |
| `tests/session-note/test-session-note.sh` | create | the suite (13 arms) |
| `tests/fixtures/project-id-corpus.tsv` | create | shared normalizer corpus: `<remote>\t<expected project_id>` |
| `plugins/mega-sdd/hooks/hooks.json` | modify | second hook in the SessionStart group |
| `tests/publisher/test-publish-artifacts.sh` | modify (additive arm r3d) | python `norm_project_id` driven by the same corpus |
| `tests/hooks/direct-dispatch.test.sh` | modify | `HOOK_BODIES` += `session-note` |
| `tests/platform/test-line-endings.sh` | modify | `HOOK_ENTRIES` += `session-note`, `EXPECT_CHECKED` 8 → 9 |
| `tests/hooks/bounded-subprocess.test.sh` | modify | literal "6 extensionless entry points" → 7 |
| `plugins/mega-sdd/hooks/session-start` | modify (comment only) | pointer at the "No-signal CWD: fully silent" block |
| `docs/gateway-contract.md` | modify | new section + amended status sentence |
| `plugins/mega-sdd/CLAUDE.md` | modify | §Hooks mentions the session-note hook |
| `CHANGELOG.md`, `plugins/mega-sdd/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | modify | 8.7.0 |

---

### Task 1: The hook body, driven by its suite

**Files:**
- Create: `tests/fixtures/project-id-corpus.tsv`
- Create: `tests/session-note/test-session-note.sh`
- Create: `plugins/mega-sdd/hooks/session-note`

**Interfaces:**
- Consumes: `plugins/mega-sdd/scripts/_lib/resolve-project-root.sh` → `resolve_project_root <path>` (prints the project root); `plugins/mega-sdd/.claude-plugin/plugin.json` `"version"`.
- Produces: stdout line `mega-sdd-note: repo=<r> branch=<b> head=<h> dir=<d> sdd=<0|1> v=<v>`; the suite honours `SESSION_NOTE_HOOK=<path>` to aim itself at a mutated copy (used by Task 4's mutation proof).

- [x] **Step 1: Write the corpus** — `tests/fixtures/project-id-corpus.tsv`, TAB-separated, no header, no comments:

```
https://git.example.com/grup/repo.git	git.example.com/grup/repo
https://user:s3cret@git.example.com/grup/repo.git	git.example.com/grup/repo
ssh://git@git.example.com:2222/grup/repo.git	git.example.com/grup/repo
git@git.example.com:grup/repo.git	git.example.com/grup/repo
http://git.example.com:8080/grup/repo	git.example.com/grup/repo
git://git.example.com/grup/repo.git/	git.example.com/grup/repo
https://token@git.example.com/grup/sub/repo.git	git.example.com/grup/sub/repo
https://git.example.com/~user/repo.git	git.example.com/~user/repo
```

- [x] **Step 2: Write the failing suite** — `tests/session-note/test-session-note.sh` (full file in the repo after this step; arms map 1:1 to spec §6):

| Arm | Setup | Assert |
|---|---|---|
| a1 vanilla | `env -u ANTHROPIC_BASE_URL` | empty stdout, rc 0, git-shim call count 0 |
| a2 normal | repo + https remote + 1 commit | exactly 1 line; regex `^mega-sdd-note: repo=[^ ]+ branch=[^ ]+ head=[0-9a-f]{7} dir=[^ ]+ sdd=[01] v=[^ ]+$`; `repo=git.example.com/grup/repo`; `v` == plugin.json version |
| a3 corpus | per row: `git config remote.origin.url <in>` | `repo=<expected>` for every row |
| a4 hostile remote | one-line payload with spaces, backticks, `$(touch pwned)`; and a two-line payload | `repo=invalid` / injected text absent; exactly 1 line; no `pwned` |
| a5 hostile branch | `git checkout -b 'wip;x$y'`-style name + 120-char name | bad chars → `_`, length ≤ 100, `repo` intact |
| a6 non-git dir | plain dir | `repo=local/<dir> branch=none head=none`; git calls = 1 |
| a7 non-adopted | clean repo | `sdd=0`; `git status --porcelain` empty; scratch HOME empty |
| a8 adopted subfolder | `.mega-sdd/vaults/`, cwd = `src/deep` | `sdd=1`, `dir` = repo basename |
| a9 detached / unborn | `checkout --detach`; `git init` only | `branch=HEAD`; `branch=none head=none` with `repo` resolved |
| a10 namespace | any output | never contains `mega-sdd-trace` |
| a11 git budget | normal repo | shim count ≤ 2 |
| a12 Windows cwd | `OSTYPE=msys`, cwd sent as `\\tmp\\…` JSON-escaped backslashes | same line as the POSIX path |
| a13 hooks.json | python json | 6 events; `SessionStart[0].hooks` = [`session-start`, `session-note`]; note hook `async` false + `statusMessage` present |

Harness rules: `REAL_GIT="$(command -v git)"`; a PATH shim `git` appends a line to `$W/git-calls` then `exec "$REAL_GIT" "$@"`; the hook always runs under scratch `HOME`+`USERPROFILE` and `GIT_CONFIG_NOSYSTEM=1` (a developer's `url.insteadOf` must not leak into results); scratch commits use `-c user.name=t -c user.email=t@t -c commit.gpgsign=false`; `HOOK="${SESSION_NOTE_HOOK:-$P/hooks/session-note}"`; ends with `echo "session-note: $PASS ok, $FAIL fail"; [ "$FAIL" -eq 0 ]`.

- [x] **Step 3: Run it — must fail**

Run: `bash tests/session-note/test-session-note.sh </dev/null`
Expected: FAIL (hook file absent → every arm red, a13 red on hooks.json).

- [x] **Step 4: Write `plugins/mega-sdd/hooks/session-note`** — order of operations:

```bash
#!/usr/bin/env bash
set -u
export LC_ALL=C
HOOK_SELF="${0//\\//}"
[ -n "${ANTHROPIC_BASE_URL:-}" ] || exit 0          # vanilla → silent, before ANY work

STDIN_JSON=""; IFS= read -r -d '' STDIN_JSON || true
# cwd: first-match builtin extraction; fall back to $PWD; Windows substitutions; -d check
# git #1 (only spawn for a non-repo):
#   git -C "$CWD" rev-parse --show-toplevel HEAD --abbrev-ref HEAD   → TOP / SHA / BR
#   rc IGNORED; each line validated alone; trailing CR trimmed
# git #2 (only when TOP non-empty): git -C "$CWD" remote get-url origin → first line
# dir  = basename(TOP or CWD), lossy-sanitized, cap 64, empty → unknown
# head = ${SHA:0:7} iff SHA is ≥40 lowercase hex, else none
# branch = lossy-sanitized BR, cap 100, empty → none
# repo = _sn_norm_repo(remote): empty → local/<dir>; passes whitelist+cap → itself; else invalid
# sdd  = 1 iff [ -d "$(resolve_project_root "$CWD")/.mega-sdd" ]
# v    = builtin line scan of ../.claude-plugin/plugin.json, validated, else unknown
printf 'mega-sdd-note: repo=%s branch=%s head=%s dir=%s sdd=%s v=%s\n' ...
exit 0
```

`_sn_norm_repo` is a line-for-line port of `norm_project_id` in `scripts/publish-artifacts.sh:161-181`: strip each of `ssh:// https:// http:// git://` in that order; if the segment before the first `/` contains `@`, drop through the first `@`; split `head`/`rest` at the first `/`; if `head` contains `:` — all-digit suffix = ssh port (drop), anything else (incl. empty) = scp-like `host:path` (suffix joins `rest`); re-join; strip ALL trailing `/`; strip ONE trailing `.git`. The lossy sanitizer keeps its bracket pattern in a VARIABLE (`pat='[^A-Za-z0-9._/-]'; v="${1//$pat/_}"`) — a literal `/` inside `${var//pattern/}` would end the pattern.

- [x] **Step 5: `chmod 755 plugins/mega-sdd/hooks/session-note`, run the suite**

Run: `bash tests/session-note/test-session-note.sh </dev/null`
Expected: every arm ok EXCEPT a13 (hooks.json not wired yet — Task 2).

### Task 2: Wiring + the suites that enumerate hook bodies

**Files:**
- Modify: `plugins/mega-sdd/hooks/hooks.json` (SessionStart group)
- Modify: `tests/hooks/direct-dispatch.test.sh:28`, `tests/platform/test-line-endings.sh:36,53`, `tests/hooks/bounded-subprocess.test.sh:~604`
- Modify: `tests/publisher/test-publish-artifacts.sh` (after line 208)

**Interfaces:**
- Consumes: Task 1's hook body + corpus.
- Produces: nothing new.

- [x] **Step 1: hooks.json** — append inside `SessionStart[0].hooks`, after the `session-start` hook:

```json
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-note\"",
            "async": false,
            "statusMessage": "mega-sdd: session note…"
          }
```

- [x] **Step 2: enumerating suites** — `HOOK_BODIES` and `HOOK_ENTRIES` gain ` session-note`; `EXPECT_CHECKED=8` → `9` (comment updated: 7 hook entry points); bounded-subprocess literal `6 extensionless entry points` → `7 extensionless entry points` (+ the comment above it).

- [x] **Step 3: publisher corpus arm** — after the `r3c` line:

```bash
# r3d (8.7.0): ONE corpus, two normalizers — hooks/session-note carries a bash
# port of norm_project_id; drift would split project_id between the artifact
# store and the session audit. tests/session-note drives the port on this file.
CORPUS="$(cd "$(dirname "$0")/../fixtures" && pwd)/project-id-corpus.tsv"
R3D_BAD=0
while IFS=$'\t' read -r c_in c_exp; do
  [ -n "$c_in" ] || continue
  c_got="$(norm "$c_in")"
  [ "$c_got" = "$c_exp" ] || { R3D_BAD=1; echo "    corpus drift: '$c_in' → '$c_got' (want '$c_exp')"; }
done < "$CORPUS"
[ "$R3D_BAD" -eq 0 ] && ok "r3d shared project-id corpus (python side)" || fail "r3d python norm_project_id drifted from the corpus"
```

- [x] **Step 4: run the touched suites**

Run: `for t in tests/session-note/test-session-note.sh tests/publisher/test-publish-artifacts.sh tests/hooks/direct-dispatch.test.sh tests/platform/test-line-endings.sh tests/hooks/bounded-subprocess.test.sh tests/weighted-routing/test-spawn-ceilings.sh tests/delta-hygiene/test-a1-a4.sh tests/platform/test-platform-pins.sh tests/hooks/session-start.test.sh tests/weighted-routing/test-tier-s-hooks.sh tests/surface/test-p9-audit-phase1.sh; do bash "$t" </dev/null >/dev/null 2>&1 && echo "ok  $t" || echo "RED $t"; done`
Expected: all `ok`.

### Task 3: Contract, docs, release stamp

**Files:** `docs/gateway-contract.md`, `plugins/mega-sdd/CLAUDE.md`, `plugins/mega-sdd/hooks/session-start` (comment), `CHANGELOG.md`, `plugins/mega-sdd/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.

- [x] **Step 1: `docs/gateway-contract.md`** — (a) status sentence: the tag family + the session note are the only two IN-BAND artifacts; token/cost/telemetry still do not return; (b) new section `## Catatan sesi (mega-sdd-note:)` with the line grammar table, the sanitization guarantees, and the three parse rules (parse by key · last occurrence wins, `extractAll(input, 'mega-sdd-note: ([^\n]*)')[-1]` · `repo` == publisher `project_id`, `invalid`/`local/…` never merged) + the sidechain note + `sdd=0` governance signal; (c) the pin-test line gains `tests/session-note/test-session-note.sh`.
- [x] **Step 2: dead-claim sweep** — `grep -rn "hening total\|fully silent\|zero injected text\|satu-satunya artefak" docs plugins/mega-sdd/CLAUDE.md plugins/mega-sdd/hooks README.md`; amend or confirm each hit is scoped to the turn tag; add the pointer comment in `hooks/session-start`.
- [x] **Step 3: `plugins/mega-sdd/CLAUDE.md` §Hooks** — SessionStart runs two bodies: anchor injection + the pure-shell session note (gateway sessions only).
- [x] **Step 4: versions + CHANGELOG** — `8.6.1` → `8.7.0` in both manifests (mega-sdd entry only in marketplace.json); `## [8.7.0] - 2026-09-21` entry in the file's natural Indonesian register.

### Task 4: Proof, commit, push

- [x] **Step 1: mutation proof** — for each guard, build a mutated copy under a scratch plugin mirror (`hooks/` copy + symlinks to `scripts/` and `.claude-plugin/`), run the suite with `SESSION_NOTE_HOOK=<copy>`, expect RED: (m1) gateway pre-check removed → a1 red; (m2) whitelist check forced true → a4 red; (m3) `remote get-url` read with a multi-line-preserving read → a4 red; (m4) namespace swapped to `mega-sdd-trace:note` → a10 red; (m5) lossy sanitizer made identity → a5 red.
- [x] **Step 2: both trees, background** — the CI loop verbatim (find both trees, both naming conventions, minus the three quarantined pack suites), each suite `</dev/null`; expected `rc=0`.
- [x] **Step 3: `claude plugin validate`-class checks** — `python3 -c 'import json;json.load(open("plugins/mega-sdd/hooks/hooks.json"))'`; manifest parity vs CHANGELOG head.
- [x] **Step 4: commit** — explicit paths only; message `release(8.7.0): …` + the session's Co-Authored-By trailer.
- [ ] **Step 5: push + verify both legs** *(runs after this file is committed, so it cannot tick itself — the outcome is in the release report)* — `rtk proxy git push origin main`; then `rtk proxy git ls-remote` per push URL and compare to local HEAD; report any leg that cannot be reached (off-site the office scm DNS is dead).
