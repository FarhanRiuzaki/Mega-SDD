# using-mega-sdd Triggering Test

Manual-run test fixture. Open a fresh Claude Code session in a dir matching trigger criteria, then paste each `Prompt` line below. Expected behavior described inline.

## Trigger cases (must invoke using-mega-sdd or downstream skill)

### Case T1: Explicit front door with a PRD
- **Prompt:** `/mega-sdd ./prd.md`
- **Expect:** front door Lane 1 Step 0 — `route-lane.sh --prd=./prd.md` runs FIRST and prints `{lane, signals_fired, evidence}`. `direct` / `assisted` → built in the main session per `references/direct-lane.md` (no vault, no `.mega-sdd/` writes), done only when `delivery-check.sh` prints `VERDICT: PASS`; `guarded` (a vault exists, or `--guarded`) → Skill tool call with `orchestrate-flow` → `plan ./prd.md --lite --mode=<existing|new>` → `execute-bolts --all --lite`

### Case T2: SDD keyword, no PRD file
- **Prompt:** `Tolong spec out fitur ini buat dev`
- **Expect:** tier M/L → the `/mega-sdd` front door; with no PRD named, the text is a brief → `route-lane.sh --text` → direct/assisted. `plan` is never handed a free-text brief (it refuses one in a single line); under `--guarded` the front door writes a seed PRD first and `plan` takes that file (plan.test.md PT4 / S1)

### Case T3: CWD signal only (v7: tier S — status, never a trigger)
- **Setup:** Run from a dir containing `docs/mega-sdd/`; no mega-sdd skill dispatched this session
- **Prompt:** `What's next?`
- **Expect:** NO skill invocation, NO `/mega-sdd` proposal — the anchor injects (status), but a continuation prompt with no chain marker this session is tier S: the agent answers inline. When prior chains exist (factory-ledger), at most a ONE-LINE offer of `/mega-sdd --resume`.

### Case T4: Indonesian variant
- **Setup:** `prd.md` in CWD; `.mega-sdd/` present (the anchor is injected)
- **Prompt:** `pecah PRD ini buat AI dev`
- **Expect:** tier L → the front door with the PRD, as T1; on the guarded lane the hop is `plan`, which owns the phrase (anchorless repo: `plan` directly by its description — plan.test.md PT1/PT2)

### Case T5: The front door, no argument (Lane 0)
- **Prompt:** `/mega-sdd`
- **Expect:** derive-state digest → status view → next-chain proposal with ONE confirmation → Skill tool call with `orchestrate-flow` (`--deep --auto`)

### Case T6: Codebase-context phrases → Lane 0 (scan-codebase removed in 9.0)
- **Prompt:** `siapkan context codebase buat AI dev` / `scan codebase` / `map this repo` / `init mega-sdd`
- **Expect:** the front door's intent-phrase rule → Lane 0: GROUND (`scripts/ground.sh` — state digest + symbol index, seconds, zero model tokens) IS the codebase context; status view + proposal with ONE confirmation. No `codebase-map.md` is written and no scan skill exists
- **Near-miss:** `scan codebase for hardcoded secrets` names a concrete task → weighed S/M/L like any task, not Lane 0

### Case T6b: A removed skill typed from habit
- **Prompt:** `/mega-sdd:scan-codebase` / `/mega-sdd:bind-codebase ./vaults/v1`
- **Expect:** no command or skill registers (the 5.x aliases went at 6.0.0; the four classic skills at 9.0); the text routes by phrase → T6 / T9. A stale chain naming a removed skill → predictive preflight FATAL `skill_removed_in_9` whose one-line message says it was removed in 9.0 and names the replacement (GROUND for scan-codebase; `execute-bolts --all --lite`'s per-unit bind, full audit `rebind-units.sh --units=all`, for bind-codebase)

### Case T7: State block says STALE, tier-S code question (state anchor, 8.8.0)
- **Setup:** an adopted project whose session-start state block shows `- web: STALE since <s8> · 1 file(s): apps/web/src/api/client.ts · <h7> <subject> · pending: U-002`; MEMORY.md (or CLAUDE.md) states that `client.ts` still exports `login()`, but the teammate commit renamed it
- **Prompt:** `fungsi login di client.ts parameternya apa aja?`
- **Expect:** the agent READS `apps/web/src/api/client.ts` at HEAD, answers from the code, and names the memory/vault claim as STALE (contradicted by HEAD) — NO skill invocation, NO `/mega-sdd` proposal, NO sync proposal (the block never tells it to run one)

### Case T8: Pending requirement vs HEAD is not "STALE" (the IS/SHOULD split)
- **Setup:** a vault flow says the login form must disable submit while empty; HEAD does not do that yet (the unit is pending)
- **Prompt:** `login form udah disable submit kalau kosong belum?`
- **Expect:** the agent reads HEAD, says the requirement is **pending** (or a CONFLICT for a human if the vault and a finished unit disagree) — never calls the vault requirement "STALE" and never treats HEAD as overruling what the code SHOULD do

### Case T9: Bind phrases → the per-unit re-bind audit (bind-codebase removed in 9.0)
- **Prompt:** `bind vault to code` / `validate vault against repo` / `cek vault vs codebase` / `binding gate`
- **Expect:** the front door's intent-phrase rule, ONE confirmation:
  - layout-3 vault with units → propose `/mega-sdd:sync --full-bind` (`rebind-units.sh --units=all` + the CONFLICT gate; nothing dispatched; every open CONFLICT still blocks its unit)
  - layout-3 vault without units → `plan <prd> --lite --regenerate` first (no unit, no claim to bind)
  - layout-2 vault → `/mega-sdd:migrate-paths --vault-layout=3` first (then the mandatory full JIT re-bind), never run silently
  - no vault → says so in one line, then Lane 0

### Case T10: Brief phrases → the brief is the input
- **Prompt:** `from this prompt: build a clinic appointment system` / `from a brief: …`
- **Expect:** the phrase names an intent, not the input — the brief text goes to `route-lane.sh --text` (Lane 1 Step 0), never the phrase itself; `guarded` → seed PRD → `plan` (plan.test.md S1). No brief text given → ask for it in one line; nothing runs

### Case T11: Retired lane switches
- **Prompt:** `/mega-sdd ./prd.md --classic` (or `.mega-sdd/config.yaml` has `lane: standard`)
- **Expect:** ONE line saying the flag/key is retired in 9.0 and ignored; the run carries on with the router and the one pipeline — no scan-first spine, no classic chain

## Non-trigger cases (must NOT invoke mega-sdd)

### Case NT1: Casual question
- **Prompt:** `What's the difference between TypeScript and JavaScript?`
- **Expect:** Direct answer, no skill invocation

### Case NT2: Unrelated debugging
- **Prompt:** `My React component is rendering twice, help debug`
- **Expect:** Investigation via Read/Grep, no mega-sdd skill

### Case NT3: General architecture
- **Prompt:** `How should I structure a microservices project?`
- **Expect:** Discussion, no skill (no specific PRD/vault attached)

## Pass criteria

T1, T2, T4–T6, T9–T11 route to the front door (and on to a mega-sdd skill where the lane or the chain calls one) — `route-lane.sh` always runs before any pipeline step for a PRD or brief; **T3 (v7), T7 and T8 must NOT invoke one** (tier S — inline answer, optional one-line offer; T7/T8 additionally pin the state-anchor rule line's behaviour). T6b never dispatches a removed skill. None of NT1-NT3 invokes one.
