# Delta hygiene A1–A4 (v6.16.0)

**Status:** DRAFT
**Source:** adoption scan `research/2026-08-17-claude-code-delta-adoption-scan.md`, USER-GREENLIT 2026-08-17 (all four batches; this is release 1 of 4). Local Claude Code = 2.1.233 (all four capabilities present ≥2.1.229).

## A1 — `claude plugin validate --strict` in CI
New `tests.yml` step after checkout: install the CLI (`npm install -g @anthropic-ai/claude-code@2.1.233` — version-pinned, same registry-rot review class as the MCP pins) and run `claude plugin validate plugins/mega-sdd` (**plain, NOT `--strict` — amended on local proof**: `--strict` fails the baseline on the root-CLAUDE.md warning, but that file is the DELIBERATE contributor/AI contract, not runtime context — the design is correct, the warning is not ours to silence by moving the file. Plain mode still blocks on every field/schema ERROR, which is the manifest-typo class A1 exists for). Local proof 2026-08-17: plain = "Validation passed with warnings"; strict = fail on that single warning.

## A2 — vendored TodoWrite repair
Todo tools are DISABLED on Opus 4.8 / Sonnet 5 / Fable 5+ (v2.1.233 changelog); the current task tools are TaskCreate/TaskUpdate (proven live in this session on Fable 5). The 7 `TodoWrite` sites in `skills/_vendored/{executing-plans,subagent-driven-development}` instruct a dead tool on every current model. Fix: mechanical replace to "the task list (TaskCreate/TaskUpdate; legacy TodoWrite where available)" — semantics unchanged (create/track/complete). Pin test so a future `sync-superpowers.sh` re-import that reintroduces bare `TodoWrite` fails CI (the sync script's "review vendored diffs" step gets a deterministic backstop).

## A3 — hook `statusMessage`
Add `statusMessage` to the SLOW synchronous hooks in `hooks/hooks.json`: PreToolUse ("mega-sdd gates…"), SessionStart ("mega-sdd anchor + state…"), UserPromptSubmit ("mega-sdd routing…"), PreCompact ("mega-sdd snapshot…"). Async hooks skip it (no spinner). Unknown-field-tolerant on older CLIs (JSON field is ignored) — no version gate needed.

## A4 — `maxTurns` caps on plugin agents
Conservative ceilings (never clip legitimate work; the cap is a runaway backstop, not a budget): bolt-implementer 80 · domain-extractor 60 · resolution-verifier 30 · spec/code-quality/security/standards/design reviewers 25 · phase-advisor 25. Honesty note: subagent docs list `maxTurns` (v2.1.229+); whether PLUGIN agents honor it is unverified at runtime — worst case the field is ignored (harmless), pinned as adopted-best-effort in CLAUDE.md §Agents.

## Tests
`tests/delta-hygiene/test-a1-a4.sh`: CI step present + version-pinned; zero bare `TodoWrite` in vendored (the sync backstop); statusMessage on the 4 sync hooks + absent on async ones; every `agents/*.md` carries `maxTurns:` with the spec's values; hooks.json still valid JSON.

## Ship
v6.16.0 — CHANGELOG, manifests parity, both-tree suite, CI, stamp, memory.
