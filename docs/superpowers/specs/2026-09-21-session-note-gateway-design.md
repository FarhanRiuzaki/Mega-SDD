# Session note → AI gateway (in-band) — design spec (brainstorm-approved)

**Status:** SHIPPED **8.7.0** (2026-09-21) — approved in brainstorm by the owner decision by decision, then "gas sampe selesai". Additive, no gate behavior change. Implementation notes + the deltas from this text: §9. A same-day first draft of this spec designed an out-of-band POST; it was never committed and is superseded — see §2 "Rejected on record".

**Trigger:** the owner wants a complete audit of office Claude Code work — for every session: which repository it ran in and what was worked on. The office AI gateway builds that audit by querying its **Langfuse logs in ClickHouse**; it has no ingest endpoint for session data and none is planned. So the note must live **inside the run**, where that log already captures it.

**Evidence-first classification:** SHOULD — an office audit requirement stated by the owner. The standing DO-NOT list names "new observability only to support an audit"; **this spec is the owner's conscious override of that item**, recorded here so it is a decision and not a silent regression. What makes it different from the lane removed in v7.3.0: no token/cost/telemetry counting, no state file, no network, no python — one line of git facts per session.

Rules carried from the contract: no extra runtime dependency; the hook event count stays SIX; no gate, validator or blocking path is added, changed or read; the `mega-sdd-trace:*` tag contract is untouched; `publish-artifacts.sh` is untouched.

## 1. What the gateway lacks today

The gateway proxies every request of a gateway-routed session and logs it to Langfuse, so it already holds the whole conversation — every prompt, every tool call, every `git commit` Claude ran. What it cannot know is **where** that conversation happened: which repository, branch and commit. The publisher's `project_id` exists only per project/vault, only where a vault or graph exists, and only when an artifact changes; a repository that has not adopted mega-sdd is invisible.

The session note closes exactly that gap: one line in the session's context carrying the repository identity. It rides the proven path the `mega-sdd-trace:turn` tag already uses — hook stdout → context → request body → Langfuse → ClickHouse. "What was worked on" is composed by the gateway from the conversation it already stores; the plugin does not re-send what the log already has.

## 2. Decisions locked in brainstorm

1. **Facts are script-derived, zero model-authored text.** A model-written footnote was rejected: output tokens every session, prose cannot be enforced.
2. **Scope = every gateway-routed session, in any repository** — including ones without `.mega-sdd/`. A vanilla session (no `ANTHROPIC_BASE_URL`) stays totally silent and pays zero forks beyond the hook's own shell.
3. **In-band, one line at SessionStart, nothing per prompt.** `hooks/user-prompt-submit` and `hooks/stop` are not edited.
4. **No opt-out config** — same standing as the tag: a contract, not a preference.
5. **Own namespace `mega-sdd-note:`** — never `mega-sdd-trace:` (see §3.3).

**Rejected on record:**
- *Out-of-band `POST /mega-sdd/session-note`* (the first draft) — the gateway has no such endpoint; its data plane is Langfuse → ClickHouse. It would also have needed the credential ladder, a per-session state file, a python pass and curl. All of that is gone.
- *Piggybacking on the publish manifest* — fires only with a vault/graph and only on artifact change; contradicts decision 2.
- *A per-prompt delta line when HEAD/branch moves* — it would catch manual commits and branch switches made outside Claude, the one blind spot this design accepts. **Deferred lever, evidence-gated:** build it only if gateway data shows that blind spot actually matters.
- *A per-turn dirty-file list* — a `git status` spawn in a synchronous per-prompt hook (~220 ms/prompt on the office laptops) plus tokens that accumulate in history, to duplicate edits the log already shows as tool calls.

## 3. Design

### 3.1 Flow

```mermaid
flowchart TD
    A[SessionStart<br/>startup / resume / clear / compact] --> B{ANTHROPIC_BASE_URL<br/>set in process env?}
    B -- no --> Z[exit 0 — no output, no forks<br/>vanilla session is silent]
    B -- yes --> C[extract cwd from stdin<br/>with builtins; -d check]
    C -- unusable --> Z
    C --> D[git rev-parse: toplevel + HEAD + branch<br/>git remote get-url origin<br/>max 2 spawns]
    D --> E[normalize repo id<br/>strip credentials, port, .git]
    E --> F{repo id passes<br/>whitelist + cap?}
    F -- no --> G[repo=invalid]
    F -- yes --> H[repo=project_id]
    G --> I[sanitize branch + dir<br/>walk up for .mega-sdd<br/>read plugin version]
    H --> I
    I --> J[print ONE line to stdout<br/>mega-sdd-note: ...]
    J --> K[context → request body<br/>→ Langfuse → ClickHouse]
```

### 3.2 Hook wiring — `hooks/session-note` (new body), `hooks/hooks.json`

One new pure-shell body, registered as a **second entry on SessionStart**. Six events, unchanged.

| Event | Matcher | Entry |
|---|---|---|
| SessionStart | `startup\|resume\|clear\|compact` | `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-note"`, `"async": false` |

Synchronous on purpose: the line must be in context before the session's FIRST request, and an async hook gives no such guarantee (the hooks docs describe async command hooks as background, fire-and-forget). `compact` is included because compaction rewrites history and can drop the line; `resume` because branch/head may have moved since the session was last open. SessionStart fires under `claude -p` (probed 2026-07-20), so headless sessions are covered.

A separate body — not an edit to `hooks/session-start` — because that body exits silent on a no-signal CWD by design and emits the anchor as JSON; the note must fire exactly where it goes silent, and its failure must never touch anchor injection. `hooks/session-start` gets a one-line comment pointer at its "No-signal CWD: fully silent" block (comment only). Cost of the separation: one extra shell process per SessionStart firing.

The body follows the existing hook idiom exactly: `set -u`, `LC_ALL=C`, `HOOK_SELF` normalization, `read -r -d ''` stdin, first-match builtin `cwd` extraction, the two Windows backslash substitutions, `-d` check. No python, no `eval`, nothing from stdin or from git ever executed. Every failure path is `exit 0` with no output.

### 3.3 The line

Exactly one line, fixed key order, space-separated `key=value`, no value ever contains a space or is empty:

```
mega-sdd-note: repo=<project_id> branch=<branch> head=<sha7> dir=<work_dir> sdd=<0|1> v=<plugin_version>
```

| Key | Value | When unavailable |
|---|---|---|
| `repo` | `origin` remote, normalized to the publisher's `project_id` rules (userinfo/credentials dropped, ssh port dropped, scp-like `host:path` → `host/path`, scheme and trailing `.git` cut) | no remote or not a git repo → `local/<dir>`; fails §3.4 → `invalid` |
| `branch` | second line of `git rev-parse HEAD --abbrev-ref HEAD`; git prints `HEAD` when detached | `none` |
| `head` | first 7 chars of the sha (builtin slice), must be hex | unborn / not a repo → `none` |
| `dir` | basename of `git rev-parse --show-toplevel`, falling back to basename of `cwd` — never a full path | — |
| `sdd` | `1` when walking UP from `cwd` finds `.mega-sdd/` (sourced `_lib/resolve-project-root.sh`, no fork) | `0` |
| `v` | `version` from the plugin's own `.claude-plugin/plugin.json`, read with a builtin line scan | `unknown` |

Git budget: **at most two spawns** — `git -C <cwd> rev-parse --show-toplevel HEAD --abbrev-ref HEAD` and `git -C <cwd> remote get-url origin`. The first call prints three lines on a normal repo (toplevel, 40-hex sha, branch). **Its exit code is ignored and each line is validated on its own** — probed 2026-09-21: on an unborn repo git exits 128 yet still prints the toplevel, then echoes the literal `HEAD` as line 2 and prints no line 3. So: line 1 → `dir`; line 2 must be 40 hex or `head=none`; line 3 absent → `branch=none`. Option order matters and is pinned by the test: `--abbrev-ref` is sticky, so the plain `HEAD` must come before it. `git` does the resolving rather than a builtin parse of `.git/config` because worktrees, submodules, `insteadOf` rewrites and packed refs are git's job; the cost is once per SessionStart firing and only on gateway sessions.

**Why a separate namespace.** The gateway filters mega-sdd sessions with `contains "mega-sdd-trace"`. This note fires in non-adopted repositories too; under the `mega-sdd-trace` prefix every such session would be miscounted as a mega-sdd session. `mega-sdd-note:` does not contain that substring. The tag namespace stays exclusive, as the contract already requires of every non-tag line.

### 3.4 Sanitization — `.git/config` is untrusted input

The line enters the model's context. A remote URL or a branch name comes from the repository, which may be hostile: it is a **prompt-injection vector** and, for a credentialed remote (`https://user:token@host/…`), a **secret-leak vector** into the gateway log and the upstream provider. Rules, all pure-shell parameter expansion under `LC_ALL=C`:

- **`repo` is exact or `invalid` — never a lossy rewrite.** After normalization it must consist only of `[A-Za-z0-9._/~-]` and be ≤ 200 chars; otherwise `repo=invalid`. A mangled identity would silently split one repository into two; an honest `invalid` cannot.
- **`branch` and `dir` are lossy-safe:** every character outside `[A-Za-z0-9._/-]` becomes `_`; truncated to 100 / 64 chars. An exotic branch name must not cost the session its `repo`.
- Only the FIRST line of each git output is read; an embedded newline can never produce a second output line.
- `head` is accepted only as 7 hex chars; `v` only as `[0-9A-Za-z.+-]`, ≤ 32 chars.

**One normalizer truth, two implementations.** The publisher normalizes in python (`norm_project_id`, inside `publish-artifacts.sh`'s heredoc); this hook must not spawn python, so it carries a bash port. Drift between them would split `project_id` between the artifact store and the audit. Pin: a shared corpus `tests/fixtures/project-id-corpus.tsv` (input → expected) consumed by BOTH suites — the new suite drives the bash port, and `tests/publisher/test-publish-artifacts.sh` gains one additive arm driving the python through the same file. `publish-artifacts.sh` itself is not edited.

### 3.5 Cost

Vanilla session: one shell process per SessionStart firing, exits on the first test — no git, no output, no tokens. Gateway session: that shell + ≤ 2 git spawns per SessionStart firing (~0.5 s once per session on the CrowdStrike laptops, synchronous), and **~30–40 context tokens per session**, cached after the first request; re-paid once per compaction. Nothing per prompt, nothing per turn end.

### 3.6 What this exposes

Repository id, branch, short head and folder name enter the request body, so they reach the gateway log and the upstream model provider along with the rest of the prompt. The conversation already carries source code and the model can read the same facts with one tool call, so the marginal exposure is nil — stated here rather than left implicit. Credentials never ride it (§3.4).

## 4. Gateway-side contract (their build)

- The note is a line in the logged **input** of main-thread generations: `mega-sdd-note: repo=… branch=… head=… dir=… sdd=… v=…`. Parse `key=value` pairs by key, not by position — additive keys may appear later and must be ignored when unknown.
- **Last occurrence in an input wins** — a resumed or compacted session carries an older line above a newer one (ClickHouse: `extractAll(input, 'mega-sdd-note: ([^\n]*)')[-1]`).
- Subagent (sidechain) requests start from a fresh context and do NOT carry the line. Attribute them through whatever session grouping the gateway already applies — Claude Code sends `x-claude-code-session-id` on every request (documented in its LLM-gateway protocol) if the gateway logs headers; otherwise the existing per-NIP window.
- `repo` equals the publisher manifest's `project_id` for the same repository — the join key between the audit and the published artifacts. `repo=invalid` and `repo=local/<dir>` are honest non-identities, never to be merged.
- `sdd=0` with no `mega-sdd-trace:*` in the session = work outside the pipeline — the governance signal v6.19.2 wanted, now derivable without a session marker.

## 5. Doc and contract amendments

- **`docs/gateway-contract.md`** — new section "Catatan sesi (`mega-sdd-note:`)" carrying §3.3's grammar, §3.4's guarantees and §4's parse rules. Two sentences are amended: the tag family is no longer "the only artifact" — the tags and the note are the only two **in-band** artifacts, and token/cost/telemetry counting removed in v7.3.0 still does NOT return; "non-SDD CWD = total silence" stays true for the **turn tag** and gains the exception: a gateway-routed session gets exactly one note line at SessionStart in any CWD.
- **Sweep for the dead claim** (the leftover-sweep lesson): grep `hening total`, `fully silent`, `zero injected text`, `satu-satunya artefak` across `docs/`, `plugins/mega-sdd/CLAUDE.md`, `README*`, hook comments; amend each hit or confirm it is scoped to the turn tag. Hits at spec time (2026-09-21): `docs/gateway-contract.md:3` (status sentence) and `:9` (turn-tag row — stays, scoped to the tag), `hooks/session-start:110-112` (comment — gets the pointer line). Re-run the grep at release; do not trust this list.
- **`plugins/mega-sdd/CLAUDE.md`** §Hooks — SessionStart carries a second, pure-shell entry (the session note; six events unchanged).
- `CHANGELOG.md` `## [8.7.0]`; `plugin.json` + `marketplace.json` → 8.7.0 (parity).

## 6. Tests — `tests/session-note/test-session-note.sh`

Hermetic: scratch repos, a PATH-shimmed `git` that counts calls, `env -u ANTHROPIC_BASE_URL` wherever silence is asserted (the suite may itself be run from inside a gateway session). Each arm mutation-proved (the guarding check removed → ≥ 1 arm red).

| # | Arm | Asserts |
|---|---|---|
| 1 | vanilla (env unset) | empty stdout, rc 0, git shim called 0 times |
| 2 | gateway session, normal repo | exactly one line; matches the §3.3 grammar regex; key order fixed |
| 3 | project-id corpus | bash port = expected for every row of `project-id-corpus.tsv` (credentials stripped; https and ssh forms of one repo → one id) |
| 4 | hostile remote (newline, spaces, backticks, `$(touch pwned)`, "ignore previous instructions") | `repo=invalid`; still exactly one line; no `pwned` file |
| 5 | hostile / non-ASCII / 300-char branch | offending chars → `_`, length ≤ 100, `repo` intact |
| 6 | non-git directory | `repo=local/<dir> branch=none head=none` |
| 7 | non-adopted repo | `sdd=0`; `git status --porcelain` of that repo EMPTY; nothing created under scratch `HOME`/`USERPROFILE` |
| 8 | adopted repo, `cwd` = a subfolder | `sdd=1`, `dir` = the repo root's basename |
| 9 | detached HEAD / unborn repo | `branch=HEAD` / `branch=none head=none`, `repo` still resolved |
| 10 | namespace | stdout never contains `mega-sdd-trace` |
| 11 | git budget | shim call count ≤ 2 |
| 12 | Windows `cwd` (backslashes, `C:\…`) | normalized by the same two substitutions; proven with the ntpath-style fixture pattern the hook suites already use |
| 13 | `hooks.json` shape | exactly six events; SessionStart has two entries; the new one is `async: false` with the four-source matcher |
| 14 | untouched neighbours | `tests/hooks/session-start.test.sh`, `tests/weighted-routing/test-tier-s-hooks.sh`, `tests/surface/test-p9-audit-phase1.sh` (the tag-contract pins) green and unedited |
| 15 | publisher corpus arm | `tests/publisher/test-publish-artifacts.sh` (one additive arm) green on the same TSV |

Both test trees run before claiming green (the CI-runs-both lesson).

## 7. Field checkpoints (pending at the office — not release blockers)

1. The line is visible in a real Langfuse trace of a gateway session, in a non-adopted repo and in an adopted one.
2. The office Stop/SessionStart hook environment really carries `ANTHROPIC_BASE_URL` (the same open checkpoint the publisher's condition (c) has).
3. SessionStart latency on a Windows + CrowdStrike laptop with the extra entry.

## 8. Non-goals

Any gateway endpoint, storage or query/summary layer (their build, on data they already have). A model-authored narrative. Prompt text or file content in the note. Anything per prompt or per turn end. The note inside subagent dispatch prompts. Any opt-out switch. Any change to the tag contract, the gates, `hooks/stop`, `hooks/user-prompt-submit` or `publish-artifacts.sh`.

## 9. Implementation notes (8.7.0)

Plan: `docs/superpowers/plans/2026-09-21-session-note-gateway.md`. Deltas from the text above, all deliberate:

- **Wiring (§3.2):** the note is the second HOOK of the single SessionStart matcher group (`SessionStart[0].hooks[1]`), not a second group — one matcher, and `tests/weighted-routing/test-spawn-ceilings.sh` reads `SessionStart[0].hooks[0]`, which must stay `session-start`. It carries a `statusMessage` like every sync hook (`tests/delta-hygiene/test-a1-a4.sh` A3).
- **Vanilla = unset OR empty** `ANTHROPIC_BASE_URL` (arm a1c).
- **`dir` fallback** is `unknown` (a cwd of `/` has no basename); a non-repo costs ONE git spawn, not two (`remote get-url` runs only when `rev-parse` returned a toplevel).
- **Suite = 36 assertions**, arms a1–a13. Spec arm 14 ("untouched neighbours") and 15 (publisher corpus arm) are release verification, not re-run inside this suite: the neighbours ran green and unedited at release, and the python side of the corpus is `tests/publisher/test-publish-artifacts.sh` r3d.
- **Mutation proof, six guards:** gateway pre-check · `repo` whitelist · first-line read · namespace · lossy sanitizer · length cap — each mutation turns ≥ 1 arm red. Two findings came out of it: the first-line read was initially shadowed by the whitelist behind it (a whole-value read still produced `invalid`), so arm a4f now pins that line 1 of a multi-line remote *normalizes*; and the length-cap mutation initially SURVIVED — arms a4g/a4h (200 kept exact, 201 → `invalid`) exist because of it.
- **End-to-end proof (headless, 2026-09-21):** `ANTHROPIC_BASE_URL=https://api.anthropic.com claude -p … --plugin-dir plugins/mega-sdd` in a NON-adopted scratch repo whose remote carried `user:s3cret@` — the model quoted the line back verbatim: `mega-sdd-note: repo=git.example.com/demo/e2e-proof branch=Main head=51d9c7d dir=e2e sdd=0 v=8.7.0`. That settles three mechanism questions at once: a second SessionStart hook's PLAIN stdout does reach model context next to the first hook's JSON; SessionStart fires under `claude -p`; the credential never rides. What is left of field checkpoint 1 is only the last hop — the line showing up in the office Langfuse trace.
- **Producer-grammar sweep:** three suites enumerate hook bodies and were updated — `tests/hooks/direct-dispatch.test.sh` (D2 `HOOK_SELF` guard), `tests/platform/test-line-endings.sh` (9 paths), `tests/hooks/bounded-subprocess.test.sh` (7 entry points).
- **Observed while porting, NOT changed (pre-existing, owner's call):** `norm_project_id` drops userinfo at the FIRST `@`; a remote whose password contains a raw (un-percent-encoded) `@` would leave the tail of that password in the publisher's `project_id`. Such a URL is malformed, and on the note side the `@` fails the whitelist → `repo=invalid`, so nothing leaks here. The port mirrors the python exactly on purpose — fixing one side alone would split identity.
