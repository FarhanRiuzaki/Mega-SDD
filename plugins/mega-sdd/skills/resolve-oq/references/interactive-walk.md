# resolve-oq — interactive walk procedure

## Contents
- Step 0 — Vault location & integrity check
- Step 0.5 — Resume detection
- Step 0.6 — Resolution scope
- Step 1 — Parse OQ list
- Step 2 — Loop per OQ (display, the ONE collapsed prompt, state transitions)
- Step 2b — The single prompt: 4 slots + Other + Esc, keterangan, no-recommendation shape, "Other" parse order
- Step 2c — Apply outcome (Resolve / Out of Scope / Defer / Skip), incl. the Defer two-question follow-up
- Step 2d — Continue / end the walk (Esc) + the per-OQ prompt budget
- Step 3 — Update vault metadata (version + Changelog template)
- Step 4 — Self-check before exit
- Step 5 — Present summary

Loaded by `resolve-oq` for the standard (non-`--binding`) walk. The SKILL.md body carries the compact skeleton + rails; this file carries the full procedure, display formats, templates, and the self-check. Resolution content is recorded in the vault's existing language.

## Step 0 — Vault location & integrity check (MANDATORY)

1. **Get the vault path** from the user.
   - **Claude Code**: use `AskUserQuestion` with options like `["Use auto-detected '<path>'", "Specify path", "Cancel"]`.
   - Auto-detect: scan CWD for a directory containing `vault.md` + `model.md` + `flows.md` + `constraints.md` (layout-2) — or the legacy 7-file set (`00-index.md` … `06-constraints.md`). If exactly one such directory exists, suggest it as default.
   - Fallback: ask plainly — *"Path to the vault directory? (must contain vault.md — or the legacy 00-index.md set)"*

2. **Verify integrity**:
   - Layout-2: the 4 files exist (`vault.md`, `model.md`, `flows.md`, `constraints.md`) and `constraints.md` has `## Open Questions`. Legacy: the 7 files exist and `00-index.md` has the roll-up.
   - At least one `[ ]` OQ entry exists across the 6 numbered docs.
   - If any check fails → STOP, surface the issue. Suggest the user run `generate-intent` first if the vault is malformed/missing.

3. **Lock check**: layout-2 — the vault.md frontmatter `lock_status:`/lock scalars; legacy — the `00-index.md` Vault Lock Status section `Status:` line.
   - If `Status: 🔒 LOCKED` → ask via `AskUserQuestion`: *"This vault is LOCKED for `<scope>`. Resolving OQs will edit it and require re-sign-off after. Proceed?"* → options `["Unlock and proceed (re-sign-off needed after)", "Cancel"]`.
   - If user cancels → STOP. If proceeds → record in the resolution-round Changelog entry that the vault was unlocked for this round. User is responsible for re-locking after the round: edit the lock home (vault.md frontmatter; legacy: 00-index.md Vault Lock Status) — change `Status: ⚠️ DRAFT (unlocked for resolve-oq round)` back to `Status: 🔒 LOCKED for <scope>`, refresh `Locked at` / `Locked by`, append a Changelog entry confirming the relock.
   - If `Status: ⚠️ DRAFT` → no lock; continue normally.

4. **Persist** the vault path:
   - Echo: `VAULT_DIR=<resolved-absolute-path>`.
   - Re-echo at the start of each major step.

> Skill never proceeds to Step 0.5 without a verified vault and lock-state acknowledged.

## Step 0.5 — Resume detection (MANDATORY, after vault path)

1. Parse the vault Changelog (`vault.md ## Changelog`; legacy: `00-index.md ## Changelog`) for entries from prior runs of this skill (look for `### v{X.Y} (YYYY-MM-DD)` entries that say "Resolved N OQs via resolve-oq").
2. If a prior round exists:
   - Show: *"Vault is currently at v{X.Y}. Last resolution round on {date} resolved {N} OQs. {M} OQs are still `[ ]` open."*
   - Ask via `AskUserQuestion` — every option carries its keterangan (what it does to the queue), per `plugins/mega-sdd/references/output-language.md §Prompt surfaces`:
     - `Continue from current state` **(recommended — idempotent per the Atomicity rule)** — walk only the {M} still-open `[ ]` OQs, with the prior round's stats shown as context; prior resolutions untouched.
     - `Start fresh review of all open OQs` — the QUEUE is identical (the same still-open `[ ]` set; resolved `[x]` / out-of-scope `[~]` entries are NEVER re-opened and skips are not tracked) — the only difference is framing: the prior round's stats/changelog context is disregarded.
     - `Cancel` — exit now; nothing written.
3. If no prior round: this is the first resolution pass. Continue.

## Step 0.6 — Resolution scope (MANDATORY, after resume detection)

Ask the user which OQs to walk through this session:

- **`all-priorities`** **(recommended)** — ONE walk, P1 → P2 → P3 in order (the blocking tier still resolves first); avoids re-entering and re-reading the whole vault for a separate P2 pass. (Single source of the default — mirrors SKILL.md Step 0.6.)
- **`p1-only`** — only Priority 1 OQs (sprint-0 blockers). Pick this only when P2/P3 are deliberately deferred to a later session.
- **`p1-then-p2`** — P1 first, then P2. Skip P3.
- **`by-category`** — group by category from the roll-up (e.g., "PRD inconsistencies" first, "Tech stack" second). Useful when each category aligns with a different stakeholder.
- **`single-oq`** — jump to a specific OQ tag (e.g., `OQ-FL-1`). For quick targeted resolution.

Persist: `RESOLUTION_SCOPE=<choice>`. Echo back so the user sees the plan.

## Step 1 — Parse OQ list

1. Read all 7 vault files.
2. For each numbered doc (01–06), extract entries from its `## Open Questions` section that are still `[ ]` (open) — skip `[x]` (resolved) and `[~]` (out of scope).
3. For each OQ, capture:
   - Tag (`OQ-{CODE}-{N}`)
   - Priority (`P1 | P2 | P3`)
   - Doc origin
   - Question text
   - Any resolution-path hint already written by the original generator (often after "Resolution:" or "Resolve:").
4. Category comes from the OQ line bracket (`[tech …]`/`[business]`, bracket-first). Legacy vaults only: fall back to the `00-index.md` roll-up header category — this informs the by-category scope.
5. Build the work queue based on `RESOLUTION_SCOPE` from Step 0.6.

If the queue is empty (e.g., user picked `p1-only` and there are no P1 OQs left) → skip to Step 5 with summary.

## Step 2 — Loop per OQ

For each OQ in the queue:

### Step 2a — Display

Show the user (**human framing FIRST, technical detail demoted — 7.21.1**, spec 2026-09-02 §Amendemen; field evidence: the owner failed to parse a verbatim jargon OQ they themselves knew the answer to):

```
[{i}/{N}] {OQ tag}  {priority}  {category}
  Konteks: {1–2 kalimat bahasa manusia common ID/EN — situasi bisnisnya; jargon tidak boleh jadi subjek kalimat}
  Maksudnya: {apa yang SEBENARNYA diminta dari user — keputusan/aturan/informasi apa; satu kalimat}
  ── detail teknis ──
  Doc: {doc filename} → {section anchor if available}
  Teks asli: {full question text verbatim — never silently rewritten}
  Hint: {resolution-path hint from generator, if present}
```

Framing rules (mandatory, every OQ, regardless of how the stored text was written — old artifacts included):
- **Translate, never rewrite:** the `Konteks`/`Maksudnya` lines are a DISPLAY-layer translation into common Indonesian/English; the stored OQ text is quoted verbatim under `Teks asli` and the artifact is never edited by displaying it.
- **No invented facts:** the framing derives ONLY from the OQ text + its citations/probe findings. Anything not derivable stays honest — "belum ketahuan dari kode" — never filled in from general knowledge (the no-invention rail applies to framing too).
- **Meaning-first evidence:** when probe/recommendation findings are narrated, lead with the business meaning ("hasilnya dipakai modul credit analysis buat hitung skor"), the `file:line` evidence follows in parentheses — never a bare citation dump.
- Option labels are full words with keterangan — never truncated/garbled labels.

When `vault.json` has a `scope` field, prepend scope context to the panel (and to each `AskUserQuestion`):

```
OQ-AR-7 [P1] [tech] (scope: BE — Backend API):
  Question: Use RFC 7807 problem+json envelope?
  ...
```

Lightweight: read `vault.json` scope at skill start; prepend scope context to each `AskUserQuestion`. Helps multi-architect scenarios where one OQ might involve cross-scope dependencies — the user knows which scope they're answering for. (The matching scope handoff block is documented under the `--auto` / handoff reference the SKILL.md router lists.)

This panel is not a separate turn — it is the header of the ONE prompt specified in Step 2b, which
carries it verbatim. Render it and the `AskUserQuestion` together.

### Step 2b — The single prompt (ONE `AskUserQuestion` per OQ)

> **Express-batched variant (P3 — chain-routed express path only).** The SAME per-OQ question shape (4 slots + Other, every keterangan rule below intact, exactly one `(recommended)` per question) packs up to **4 blocking-tier OQs into ONE `AskUserQuestion` call** (the tool takes 1–4 questions per call — the contract SKILL.md §Flags already states). >4 open P1s → ceil(N/4) sequential calls, disclosed upfront ("N blocker, K prompt"). Slot semantics, write-back, and the derive-per-outcome contract are UNCHANGED — batching changes the round-trip count, never the grammar. Esc ends the whole walk as usual — and in a BATCHED call it discards EVERY answer in the interrupted call (AskUserQuestion is atomic); those OQs stay open. The no-recommendation 3-option shape applies per question independently. This variant never fires on a standalone/classic invocation.

> **The common path costs exactly ONE human round trip.** The action choice, the answer text, and
> the destination confirmation are the SAME surface: picking an option IS answering, and IS
> confirming where that answer lands. **Never** emit a separate "what is your answer?" prompt, and
> **never** emit a separate "confirm/override the destination?" prompt — that two-extra-prompt walk
> is exactly what this step replaced.

**This file is canonical for the prompt's shape.** `recommendation-context.md` owns how the
recommended answer, its rationale, and its citation are BUILT (source priority, citation probe,
silent fallback) and points here for the shape — it does not restate it. If the two ever disagree,
this file wins.

**Platform cap: `AskUserQuestion` takes at most 4 options** (plus the automatic free-text "Other"
and Esc) — same constraint the propose-and-confirm menu resolved in
`execute-bolts/references/propose-and-confirm-prompt.md`. The slots are spent as:

| Slot | Carries | Notes |
|---|---|---|
| `[1]` | the **recommended answer** | marked `(recommended)`; exactly one option ever is |
| `[2]` | **Skip** | this OQ only: no file change, OQ stays `[ ]` open, it returns next pass |
| `[3]` | **Defer** | always present in the standard walk (carve-out below) |
| `[4]` | **Out of scope** | |
| *Other* | **the free-text answer** (and the destination override) | this IS the answer-capture channel |
| *Esc* | **end the walk** | progress already applied is safe; jump to Step 3, bump + Changelog, exit |

**Esc ends the WALK, not the item.** That is the plugin-wide meaning of the platform escape — the
only two other `AskUserQuestion` surfaces both read it as *cancel the activity*
(`execute-bolts/references/halt-recovery.md` "Cancel rides the built-in 'Other'/Esc escape";
`execute-bolts/references/propose-and-confirm-prompt.md` "Cancel chain — pause everything for
review — rides the built-in 'Other'/Esc escape"). A control that means "abandon everything" in two
surfaces and "skip one item, continue" in a third is a trap for the operator, so **Skip gets a real
slot** and Esc keeps its plugin-wide meaning. There is **no `STOP`/`BERHENTI` text sentinel** — a
typed end-the-walk token would silently swallow a legitimate answer (an OQ like *"payment gateway
timeout — lanjut atau berhenti?"* is answerable with the word "stop"), so ending the walk is Esc and
nothing else.

**The presented alternative loses its slot — its INFORMATION does not.** "Other" already covers
"answer in my own words", so a pre-typed alternative is a convenience, whereas Skip and
end-the-walk have no other home. The considered alternatives are therefore listed **in the question
text as prose**, on the `Alternatif yang sudah dipertimbangkan:` line of the template below
(`… {alt-1} — kalau …; {alt-2} — kalau …`), each still carrying its source or the
explicit `tanpa sumber` marker per `recommendation-context.md`. The question text has no length cap;
the operator reads them and types one into "Other" to pick it. Same knowledge, zero slot cost.
**Never invent an alternative to fill the prose line** — no grounded alternative → omit the line.

**Defer is ALWAYS visible** in the standard walk — a stakeholder defer must be reachable in every
context (the "No invention" hard rule routes `idk`/`whatever` here; a greenfield user waiting on
legal/PM needs it too). Only its **`to binding` sub-target** is conditional, offered as Q1 of the
Step-2c Defer follow-up when ALL of these are true:
- Vault `mode: existing` (brownfield)
- CWD has repo signals (any of `.git`, `package.json`, `composer.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`)

In greenfield contexts OR when no repo signals are detected, Defer offers the stakeholder defer only
and the follow-up carries the reason question alone.
(The `--binding` propagated-OQ walk drops slot `[3]` — see `binding-mode.md` Step 3.)

#### The prompt, verbatim

Copy this shape. Every bracketed field is mandatory. **Everything human-facing here — the panel, the
question body, its bullets, the `Alternatif` line, every option `label` and `description`, and the
Step-2c narration — is Tier-2 narration and follows the standing language precedence**
(`plugins/mega-sdd/references/output-language.md §Precedence`): an explicit language request wins,
otherwise mirror the language the user is writing in, and only fall back to the Indonesian shown
below for short/ambiguous input. The Indonesian strings below are the DEFAULT rendering, not a fixed
string catalog — an English-writing user gets this same prompt in English by precedence rule 2.
**Tier-1 tokens (`OQ-…`, `P1`, `[ ]`/`[x]`/`[~]`, file names, `defer_to`, `stakeholder`, `binding`,
`HIGH`/`MEDIUM`) stay English in every language.**

```
[{i}/{N}]  {OQ tag}  [{priority}]  [{category}]  {(scope: {id} — {name}) when vault.json has scope}
  Doc      : {origin doc} → {section}
  Pertanyaan: "{full OQ question text, verbatim}"
  Sumber   : {citation of the recommendation, probed OK — file §section:line / memory row / D-XXX}
  Hint     : {generator resolution hint, when the OQ carries one}
  {⚠️ **High-stakes business OQ.** Review citation + rationale carefully before accepting.
     AI recommendation is a starting point, not authority.   ← ONLY when category: business AND P1}

question: |
  {the OQ question text again, verbatim — the tag alone is never a question}

  Alternatif yang sudah dipertimbangkan: {alt-1} — kalau {kapan kamu memilihnya} ({Sumber: <citation>} | tanpa sumber — alternatif umum); {alt-2} — kalau {…} ({…}).
  {← omit this whole block when no grounded alternative exists; NEVER invent one}

  Pilihanmu LANGSUNG jadi resolusi: opsi rekomendasi sudah menuliskan ke mana jawabannya mendarat,
  jadi memilih = sekaligus mengonfirmasi tujuan. Ringkasan diff tetap ditampilkan setelahnya.
  • Mau jawab sendiri (termasuk mengambil salah satu alternatif di atas)? pilih "Other", ketik
    jawabanmu; tambahkan "→ <file>.md" di akhir kalau mau memaksa dokumen tujuan lain — nama
    filenya HARUS salah satu dokumen vault (layout-2: `vault.md`/`model.md`/`flows.md`/`constraints.md`; legacy: `00-index.md` … `06-constraints.md`), di luar
    itu override-nya ditolak dan kamu diberi tahu.
  • Cuma mau memindahkan tujuan tanpa mengubah jawaban? ketik "→ <file>.md" saja di "Other" (juga
    harus salah satu dari 7 dokumen vault): itu berarti "terima rekomendasi, tapi taruh di file itu".
  • Skip (opsi [2]) = lewati OQ INI SAJA lalu walk LANJUT ke OQ berikutnya — tidak ada perubahan file, OQ tetap `[ ]` open dan muncul lagi di pass berikutnya.
  • Tekan Esc = AKHIRI SELURUH walk sekarang, OQ ini tidak disentuh — progres yang sudah ter-derive aman, skill lompat ke Step 3 (bump versi + Changelog) lalu keluar.
header: "{OQ tag}"          # short — e.g. "OQ-DC-4"
multiSelect: false
options:
  - label: "{recommended answer, ≤ ~40 chars}  (recommended)"
    description: "{⚠️ High-stakes business OQ — cek sumber + rationale sebelum menerima; rekomendasi
                  AI itu titik awal, bukan otoritas. ← prefix WAJIB, dan HANYA, saat category:
                  business AND P1}{rationale, 1-3 kalimat}. Sumber: {citation}. Kalau salah:
                  {fallback-if-wrong}. Confidence: {HIGH|MEDIUM}. → mendarat sebagai {inline di
                  entri OQ | ADR baru D-XXX di vault.md ## Decisions | constraint di constraints.md
                  | …}{, plus cross-ref di {doc}, {doc} (cross-cutting)}."
  - label: "Skip"
    description: "Lewati OQ ini saja: tidak ada edit file, tidak ada derive run, OQ tetap `[ ]`
                  open dan dihitung sebagai 'still open' di ringkasan akhir. Walk LANJUT ke OQ
                  berikutnya — kalau mau mengakhiri walk-nya, tekan Esc."
  - label: "Defer"
    description: "Belum bisa dijawab sekarang. OQ tetap `[ ]` open dan ditandai
                  `**Deferred (v{X.Y})**`; aku tanya SATU kali lagi — satu prompt berisi dua
                  pertanyaan: alasan/PIC/kapan{, dan (brownfield) apakah `defer_to: binding`
                  supaya diselesaikan di fase bind-codebase} — lalu catatan itu masuk ke vault."
  - label: "Out of scope"
    description: "OQ dinyatakan di luar scope proyek: entri pindah ke section `## Out of Scope`
                  di {origin doc} dan ditandai `[~]`; aku minta SATU kalimat alasan dulu."
```

**Keterangan rules on this prompt (contract, not style):**

- Every option's `description` is MANDATORY, non-empty, in the narration language, and states the
  mechanic the plugin actually performs. A bare code, a literal `...`, `TBD`, `{same keterangan as
  …}`, or an empty description is a violation — same rule `recommendation-context.md` already states
  for alternatives ("NEVER left blank/'…' and NEVER given a fabricated citation").
- **Exactly one** option carries `(recommended)`, and only when a citation-probed recommendation
  exists.
- The **destination disclosure** (`→ mendarat …`) is part of the ANSWER option's description
  (slot `[1]`). It carries the auto-classified target doc, the density (inline vs promoted),
  and — when the OQ is cross-cutting — the primary doc plus the docs that get terse cross-refs.
  That disclosure is what makes the old "confirm the destination?" prompt unnecessary.
- The **high-stakes marker** (category `business` + `P1`) rides BOTH the panel banner above AND the
  recommended option's `description` prefix — both slots are written into the template above, per
  `recommendation-context.md §High-stakes domain warning`. Never dropped, never moved.
- **Esc ends the walk; Skip is slot `[2]`.** Both are stated in the question text so neither is
  folklore, and both match the plugin-wide reading of Esc (see the two precedent surfaces named
  above). No typed sentinel exists for either.

#### When there is NO recommendation

`recommendation-context.md` may yield nothing — no KB/memory/vault/codebase signal, or the citation
probe failed and it downgraded silently. **The prompt is still ONE round trip**, and it must NOT
present an unsourced guess as a recommendation. Slot `[1]` is simply not spent, and the answer rides
"Other". Same language precedence as the full shape — the strings below are the default rendering.

```
[{i}/{N}]  {OQ tag}  [{priority}]  [{category}]
  Doc      : {origin doc} → {section}
  Pertanyaan: "{full OQ question text, verbatim}"
  Sumber   : (tidak ada — tidak ada sinyal KB / memory / vault / codebase yang bisa dikutip)

question: |
  {the OQ question text again, verbatim}

  Belum ada rekomendasi untuk OQ ini: tidak ada sumber yang bisa dikutip, dan menebak tanpa
  sumber dilarang. **Tulis jawabanmu langsung di "Other"** — jawabannya akan mendarat
  {inline di entri OQ | sebagai {ADR baru di vault.md ## Decisions | …}} sesuai prefix `{CODE}-`;
  tambahkan "→ <file>.md" di akhir kalau mau dokumen tujuan lain — nama filenya HARUS salah satu
  dari dokumen vault (layout-2 4 file / legacy 7 file), di luar itu override-nya ditolak.
  Karena belum ada rekomendasi, menulis "→ <file>.md" SAJA tanpa jawaban tidak mengubah apa pun —
  OQ tetap `[ ]` open.
  • Skip (opsi [1]) = lewati OQ INI SAJA lalu walk LANJUT ke OQ berikutnya — tidak ada perubahan file, OQ tetap `[ ]` open.
  • Tekan Esc = AKHIRI SELURUH walk sekarang, OQ ini tidak disentuh — progres yang sudah ter-derive aman, skill lompat ke Step 3 lalu keluar.
header: "{OQ tag}"
multiSelect: false
options:
  - label: "Skip"
    description: "Lewati OQ ini saja: tidak ada edit file, tidak ada derive run, OQ tetap `[ ]`
                  open dan dihitung sebagai 'still open' di ringkasan akhir. Walk LANJUT ke OQ
                  berikutnya — kalau mau mengakhiri walk-nya, tekan Esc."
  - label: "Defer"
    description: "Belum bisa dijawab sekarang. OQ tetap `[ ]` open dan ditandai
                  `**Deferred (v{X.Y})**`; aku tanya SATU kali lagi — satu prompt berisi dua
                  pertanyaan: alasan/PIC/kapan{, dan (brownfield) apakah `defer_to: binding`
                  supaya diselesaikan di fase bind-codebase} — lalu catatan itu masuk ke vault."
  - label: "Out of scope"
    description: "OQ dinyatakan di luar scope proyek: entri pindah ke section `## Out of Scope`
                  di {origin doc} dan ditandai `[~]`; aku minta SATU kalimat alasan dulu."
```

Three options + Other + Esc — that IS the shape, not four with a hole. The answer slot is simply
unspent; there is no phantom empty slot to fill, and no invented answer may be minted to fill one.
Never advertise the bare-`→ <file>.md` shortcut here either — there is no recommendation for it to
compose with.

#### Reading the "Other" free text (deterministic parse order)

"Other" is one channel carrying two meanings that compose. **There is no sentinel branch** — the
`STOP` token was deleted precisely because it would swallow a legitimate answer (an OQ that asks
"lanjut atau berhenti?" is answerable with the word "stop"). Parse in THIS order — no re-prompt is
permitted at any branch:

1. **Destination override FIRST.** Strip a trailing `→ <file>.md` (or `-> <file>.md`), then
   **VALIDATE the stripped target BEFORE any write.** The comparison is exact: take the value's
   basename and compare it, character for character, against the vault's document filenames
   — layout-2: `vault.md`, `model.md`, `flows.md`, `constraints.md`; legacy: `00-index.md` …
   `06-constraints.md`. Nothing else is a legal destination (no directory, no
   path outside `VAULT_DIR`, no invented filename, no near-miss spelling). The collapse removed the
   pre-write "confirm/override the destination?" prompt, so this check — not the post-write
   narration — is what catches a bad target.
   - **Hit** → that file becomes the resolution destination, overriding the auto-classification.
     Record it; it needs no confirmation prompt (the Step 2c diff summary shows it and can still be
     corrected there).
   - **Miss** → the fragment is NOT an override, and it is DROPPED from the answer text (it was
     plainly a destination attempt, not content). Narrate the rejection, naming the legal set:
     *"`→ {X}` bukan salah satu dokumen vault (layout-2 4 file / legacy 7 file) —
     override tujuan diabaikan."* Then continue deterministically, with **no re-prompt**: a
     non-empty remainder still resolves the OQ, landing at the AUTO-CLASSIFIED target (narrate
     which file it landed in); a BARE invalid override resolves nothing — no markdown change, the
     OQ stays `[ ]` open, counted as skipped, because the user's stated intent was to redirect and
     that intent cannot be honored. **Never land an answer in a file outside the seven.**
2. **Non-empty remainder is the answer.** Action `A` (Answer) with that text, landing at the
   override from (1) when one was present, otherwise at the auto-classified target.
3. **Empty remainder after a bare override → accept the RECOMMENDED answer, land it at the
   override.** `→ vault.md` alone means *"terima rekomendasi, tapi taruh di file itu"* —
   the question text advertises exactly that. Action `A`, answer text = the slot-`[1]` recommended
   answer, destination = the override. Narrate what was recorded so the composition is visible:
   *"Rekomendasi diterima, didaratkan di `vault.md ## Architecture` (bukan tujuan otomatis)."*
   **Carve-out:** on the no-recommendation shape there is nothing to accept — a bare override
   changes nothing; narrate *"Belum ada rekomendasi untuk diterima — OQ tetap `[ ]` open, tidak ada
   perubahan file."* and count it as skipped. Never substitute a guess for the missing
   recommendation.
4. **Empty string / whitespace only → Skip** (nothing was answered). Do NOT re-prompt, but **do
   narrate**: *"Tidak ada jawaban yang masuk — OQ tetap `[ ]` open, tidak ada perubahan file."*

`idk` / `whatever` / `any default` arriving via Other is NOT an answer — push back once in narration
and treat the OQ as still-pending on the next pass, or take the user's Defer if they restate it. The
"No invention" hard rule is unchanged.

**Per-action state transitions — the derive contract is UNCHANGED by the collapse.** The slot
numbers are a display detail; the recorded `action` letters are contract. The vault.json field
changes are EFFECTED by `derive-vault-json.sh` reading your markdown edits (status from the
checkbox, `resolution`/`out_of_scope_reason`/`deferred_reason` from the annotation text,
`resolved_at`/`deferred_at` script-stamped on the transition). The model's job is (1) the markdown
edit and (2) the derive args. Note `--patch` takes a FILE path (`<tmp-patch>` = a scratchpad temp
file holding the JSON shown; passing inline JSON exits 3):

| Prompt slot | Action | Markdown edit produces `status` | Derive args (`derive-vault-json.sh --vault <VAULT_DIR> …`) |
|---|---|---|---|
| `[1]` / Other-with-text / bare `→ <file>.md` override | A — Answer | `[x]` → `resolved` (+ `→ Resolved v{X.Y}: …` → `resolution`) | `--event '{"event":"oq-resolved","id":"OQ-XXX","at":"<iso>","action":"A"}'` |
| `[3]` | B — Defer (stakeholder) | `[ ]` + `**Deferred (v{X.Y})**: …` → `deferred` | `--event '{"event":"oq-deferred","id":"OQ-XXX","at":"<iso>","action":"B"}'` + `--patch <tmp-patch>` (file content: `{"open_questions":{"OQ-XXX":{"defer_to":"stakeholder"}}}`) |
| `[3]` + brownfield sub-target | B — Defer (to binding) | `[ ]` + `**Deferred (v{X.Y})**: …` → `deferred` | `--event '{"event":"oq-deferred","id":"OQ-XXX","at":"<iso>","action":"B"}'` + `--patch <tmp-patch>` (file content: `{"open_questions":{"OQ-XXX":{"defer_to":"binding"}}}`) |
| `[4]` | C — Out of scope | `[~]` + `→ Out of Scope v{X.Y}: …` → `out_of_scope` | `--event '{"event":"oq-out-of-scope","id":"OQ-XXX","at":"<iso>","action":"C"}'` |
| `[2]` (or an empty Other) | D — Skip | no markdown change; OQ remains `open` | no derive run; **walk continues** to the next OQ |
| *Esc* | — end the walk | no markdown change for THIS OQ; it remains `open` | no derive run; jump to Step 3 |
| bare override that cannot be honored (no recommendation to accept, **or** a target outside the vault's 7 documents) | — no-op | no markdown change; OQ remains `open` | no derive run; narrate, count as skipped |

**The letters `A` / `B` / `C` in `"action"` are the recorded contract — they are NOT the slot
numbers.** A prompt renumbered to `[1]`–`[4]` still emits `"action":"A"|"B"|"C"`; never
`"action":"1"`. Skip emits no event at all.

Run the derive immediately after each outcome's markdown edits — it recomputes status/summary from the markdown, appends the `--event` object to the vault changelog, and holds the `vault.json.lock` itself (exit 4 → `memory_in_use` halt; exit 2 = your markdown edit broke the OQ grammar — fix the markdown and re-run). Never hand-edit `vault.json`.

### Step 2c — Apply outcome

This step is the WORK (markdown edits, derive calls, cross-reference writing), not a round trip. On
the Answer path it asks NOTHING — the answer and its destination already arrived in Step 2b. Only
the two minority paths spend a second prompt, and they must: Defer needs who/when and Out of scope
needs a rationale, and both are recorded state that may not be invented (hard rule "No invention").

**Recorded language on BOTH follow-ups — the Tier-2/Tier-3 seam, resolved.** The two follow-up
prompts are Tier-2 narration and render in the narration language (same precedence as Step 2b).
What they cause to be WRITTEN is Tier-3 vault content and goes in the **vault's content language**
(`plugins/mega-sdd/references/output-language.md §Tier-3` — "content recorded INTO the vault … stays
the vault's language"). The seam is resolved per channel, and the option descriptions must promise
only what the channel delivers:

- **A canned option** records that option's fixed reason category **expressed in the vault's
  language**. When narration language and vault language are the same — the common case — that is
  the label verbatim. When they differ, it is the same one of four known categories rendered in the
  vault's language: a fixed mapping, never a re-interpretation and never a new reason. So a canned
  option's description says *"Tercatat sebagai: …"*, never *"tercatat verbatim"*.
- **"Other" free text is the human's own words and is recorded VERBATIM, never translated** — the
  same rule the OQ answer text follows. Only this channel may be described as verbatim.

**If `Resolve`:**

1. The answer text is already in hand — it came from the chosen option's label (slot `[1]`), from
   the "Other" free text, or (on a bare `→ <file>.md` override) from the recommended answer the
   override composed with. **Do not ask again.**
2. The resolution destination is already settled: the auto-classification disclosed in the chosen
   option's description, or the user's `→ <file>.md` override from Other. **Do not ask to confirm
   it.** The auto-classification map (used when BUILDING the disclosure in Step 2b) is:
   - `OV-` → typically updates `vault.md ## Overview` (success criteria, OOS, persona)
   - `AR-` → typically `vault.md ## Architecture` (component, endpoint, tech stack, layer detail)
   - `DM-` → typically `model.md` (field constraint, table, relation)
   - `FL-` → typically `flows.md` (flow step, DoD detail, edge case)
   - `DC-` → typically `vault.md ## Decisions` (new ADR `D-XXX`)
   - `CN-` → typically `constraints.md` (NFR, business, technical, regulatory)
   Any OQ can land in any doc; the prefix is only the hint that BUILT the disclosure. The user's
   override channel is "Other" (`→ <file>.md`) plus the Step 2c diff summary below.
3. Resolution density — also already disclosed in the chosen option, not asked:
   - **Inline** (default for short answers) — the answer goes inline in the OQ entry: `[x] **OQ-XXX-N** [P{x}]: <original question> → **Resolved v{X.Y}** (YYYY-MM-DD): <answer>.`
   - **Promoted** (for substantial answers) — the answer is added to the target doc as a new entry (e.g., new ADR `D-XXX` in `vault.md ## Decisions`, new field constraint in `model.md`), and the OQ entry points to it: `[x] **OQ-XXX-N** [P{x}]: <original question> → Resolved as **D-010** in `vault.md` (v{X.Y}).`
4. **Cross-cutting check — DISCLOSED in Step 2b, never a separate prompt.** Some OQs legitimately affect 3+ docs (e.g., a tech-stack decision touches the `## Architecture` "Tech stack" line + a new ADR in `## Decisions` (both vault.md) + a constraint in `constraints.md`). For these:
   - Detect it BEFORE building the prompt, and write the plan into the answer option's
     destination disclosure: *"→ mendarat sebagai ADR baru di `vault.md ## Decisions` + cross-ref di
     `vault.md ## Architecture`, `constraints.md` (cross-cutting)."* Choosing the option IS the
     confirmation of that primary doc. The user re-routes via "Other" (`→ <file>.md`) or on the
     Step 2c diff summary. **Do NOT emit a "which doc is primary?" prompt.**
   - Skill writes the **primary entry** in full (e.g., new ADR `D-XXX` in `vault.md ## Decisions`).
   - Skill adds **cross-reference lines** in the other affected docs, format: `> Resolves OQ-{tag}: see {primary-doc.md}#{anchor or D-XXX}`. The cross-ref stays terse — no content duplication.
   - All entries point back to the OQ tag for audit trail.
   - Heuristic for cross-cutting: tech stack, multi-tenancy isolation, auth specifics, compliance items — these almost always touch ≥3 docs. Single-AC clarifications usually don't.
5. For `Promoted`, format the new entry per the target doc's existing convention:
   - `vault.md ## Decisions` (legacy `05-decisions.md`): ADR-lite per the `OUTPUT_MODE` of the vault (compact = 1-paragraph; full = multi-section). Set `**Status**: Accepted`, `**Date**: YYYY-MM`, `**Source**: resolve-oq session YYYY-MM-DD + <stakeholder/PIC if user named one>`. Cross-reference the resolved OQ tag in the Context line.
   - `model.md`: append constraint to relevant entity's DBML notes, or update the field-level validation table. Add comment `// Resolves OQ-DM-N`.
   - Other docs: append to the appropriate sub-section, with a `> Resolves OQ-{tag}` annotation.
6. Write the changes to the file(s) using `Edit`.
7. Legacy vaults only: also mark the roll-up entry in `00-index.md` `[x]` with the same pointer (layout-2 has no roll-up — the constraints.md line IS the entry).
8. **Run** `bash <plugin>/scripts/derive-vault-json.sh --vault <VAULT_DIR> --event '{"event":"oq-resolved","id":"OQ-XXX","at":"<iso>","action":"A"}'` — the script flips the OQ's `status` to `resolved` from the `[x]` checkbox, stamps `resolved_at`, recomputes `open_questions_summary`, and picks up the new ADR in `adrs[]` / changed entity in `entities[]` from the markdown.
9. Show the user a confirmation summary of the diff (target file(s), inline-vs-promoted, the new `D-XXX` if any). **This is narration, not a prompt** — but it is where a wrong destination is still correctable: if the user objects, re-land the entry and re-run the derive. No extra `AskUserQuestion`.

**If `Out of Scope`** (the ONE sanctioned second prompt on this path — a rationale is recorded state and may not be invented):

Ask the user for the rationale (1 sentence — why is this not in scope for the project?) with ONE
`AskUserQuestion` carrying ONE question. The rationale may **never** be defaulted, derived from the
OQ text, or inferred — an unasked `out_of_scope_reason` is an invariant-#5 breach. Same language
precedence as Step 2b; the strings below are the default rendering.

```
question: |
  Out of scope untuk: "{full OQ question text, verbatim}"  ({OQ tag}, dari {origin doc})

  Alasannya apa? Alasan ini masuk ke entri `## Out of Scope` dan terbaca di audit trail — jadi
  tulis yang bisa dipertanggungjawabkan, bukan "tidak perlu". Kalau alasannya di luar empat
  pilihan ini, pilih "Other" dan ketik sendiri: teks "Other" tercatat VERBATIM apa adanya,
  sedangkan memilih salah satu kategori di bawah mencatat kategori itu dalam bahasa isi vault.
  • Tekan Esc = BATALKAN penetapan out-of-scope ini DAN AKHIRI SELURUH walk: OQ tetap `[ ]` open, tidak ada perubahan file, skill lompat ke Step 3 (bump versi + Changelog) lalu keluar.
header: "out of scope"   # short; the OQ tag + question text ride THIS question's own body above — every follow-up question must carry them itself, never rely on a sibling question that may be omitted
multiSelect: false
options:
  - label: "Di luar scope rilis ini"
    description: "Tercatat sebagai: 'di luar scope rilis ini'. Entri pindah ke `## Out of Scope`
                  di {origin doc}, marker jadi `[~]`. Kalau ada nomor rilis/target spesifik,
                  pakai 'Other' supaya tercatat verbatim."
  - label: "Ditangani sistem/tim lain"
    description: "Tercatat sebagai: 'ditangani sistem/tim lain'. Entri pindah ke
                  `## Out of Scope` di {origin doc}, marker jadi `[~]`. Sebutkan sistem/tim-nya
                  lewat 'Other' kalau perlu jejak yang lebih spesifik."
  - label: "Sudah tidak relevan (requirement berubah)"
    description: "Tercatat sebagai: 'sudah tidak relevan — requirement berubah'. Entri pindah ke
                  `## Out of Scope` di {origin doc}, marker jadi `[~]`."
  - label: "Bukan tanggung jawab produk ini"
    description: "Tercatat sebagai: 'bukan tanggung jawab produk ini'. Entri pindah ke
                  `## Out of Scope` di {origin doc}, marker jadi `[~]`."
  # "Other" = tulis alasanmu sendiri; itu yang tercatat verbatim. Esc sudah dijelaskan di question
  #           text di atas (batal + walk berakhir) — konsisten dengan Esc di Step 2b, dan sengaja
  #           TIDAK ditinggal hanya di komentar ini: operator tidak membaca komentar YAML.
```

If the user presses Esc here, **nothing is recorded** — the OOS is abandoned, the OQ stays `[ ]`
open, and the walk ends per the Step-2b Esc semantics. Never fall back to a canned rationale.

Then:

1. The rationale is in hand (the chosen category, recorded per the recorded-language rule above, or
   the "Other" free text verbatim).
2. Move the OQ entry to the same doc's `## Out of Scope` section with format: `- <original question text>. (was OQ-XXX-N, declared OOS v{X.Y} on YYYY-MM-DD: <rationale>)`.
3. In the original `## Open Questions` section, mark the OQ `[~]` with a one-line pointer: `[~] **OQ-XXX-N** [P{x}]: <original question> → Out of Scope v{X.Y}: see Out of Scope section.`
4. Legacy vaults only: update the roll-up entry in `00-index.md` similarly.
5. **Run** `bash <plugin>/scripts/derive-vault-json.sh --vault <VAULT_DIR> --event '{"event":"oq-out-of-scope","id":"OQ-XXX","at":"<iso>","action":"C"}'` — the `[~]` marker derives `status: out_of_scope` and the summary recomputes.

**If `Defer`** (the ONE sanctioned second prompt on this path — who/when is recorded state and may not be invented):

There are TWO defer targets (per `vault-core.md §OQ status tracking`, `defer_to` field — a
closed two-value set with **no declared default**):

- **`defer_to: stakeholder`** — waiting on a human decision (legal review, PM, security, target date); also the only legal value in greenfield, where it is written explicitly rather than defaulted
- **`defer_to: binding`** — code-aware OQ; offered ONLY in brownfield context (vault.mode=existing AND repo signals present); resolved at `bind-codebase` phase against codebase-map

**The sub-target and the reason are collected in ONE `AskUserQuestion` CALL carrying TWO questions.**
The platform's 4-option cap is **per question**, not per call: `AskUserQuestion` takes a `questions`
array of 1–4 questions, each with its own ≤4 options plus its own automatic "Other". So the Defer
follow-up costs ONE round trip while collecting both values. *(Express-chain auto-defer carve-out, P3: the AUTO-defer of P2/P3 on the chain-routed express path supplies both fields mechanically — `defer_to: stakeholder` + the fixed reason format — with 0 prompts; invariant #5 governs answer CONTENT and an auto-defer invents none; the 2-prompt budget applies to the INTERACTIVE Defer only.)* **Neither field may ever be defaulted
or derived** — an unasked `deferred_reason` is an invariant-#5 breach. Apply this same
one-call-many-questions shape anywhere else a follow-up needs more than one value.

Q1 (`defer_to`) is present ONLY in brownfield (vault `mode: existing` AND repo signals). In
greenfield the call carries Q2 alone and `defer_to` is written EXPLICITLY as `stakeholder` by the
derive patch in step 5 below. **It is not a schema default — `vault-core.md §OQ status
tracking` declares none for `defer_to`** (it declares one only for `status`); `stakeholder` is the
single LEGAL value in that context, because `binding` means "resolved at `bind-codebase` against a
codebase-map" and greenfield has no repo to bind against. A determined value, not a derived answer.
Same language precedence as Step 2b.

Because Q1 disappears in greenfield, **Q2 carries the OQ tag and the verbatim question text in its
own body** — otherwise the greenfield operator is asked a bare *"alasan defer-nya apa?"* with no
question and no tag in front of it, which is exactly the keterangan rule-1 breach the contract
forbids. **Esc anywhere on this call abandons the Defer and ends the walk**; that consequence is
stated in Q2's operator-visible body below, not left to a YAML comment.

```
questions:
  - question: |            # ← Q1: OMIT this whole entry in greenfield / no repo signals
      Defer: "{full OQ question text, verbatim}"  ({OQ tag}, dari {origin doc})

      Siapa/apa yang akan menyelesaikan OQ ini? Pilihan ini tersimpan sebagai field `defer_to`
      di vault.json dan menentukan fase mana yang nanti menagihnya.
    header: "defer_to"     # short, per the Step-2b header guidance
    multiSelect: false
    options:
      - label: "stakeholder"
        description: "Menunggu keputusan manusia (PM / legal / security / bisnis). Tersimpan
                      `defer_to: stakeholder`; OQ tetap `[ ]` open dan ditagih lagi di run
                      `resolve-oq` berikutnya — bukan oleh fase otomatis mana pun."
      - label: "binding"
        description: "OQ ini bisa dijawab oleh KODE yang sudah ada. Tersimpan `defer_to: binding`;
                      fase `bind-codebase` yang akan mencocokkannya ke codebase-map dan
                      menyelesaikannya di sana. Hanya masuk akal di repo brownfield."
  - question: |            # ← Q2: ALWAYS present; it repeats the tag + question text itself, because Q1 (which carries them) is OMITTED in greenfield
      Defer: "{full OQ question text, verbatim}"  ({OQ tag}, dari {origin doc})

      Alasan defer-nya apa? Alasan ini masuk sebagai `**Deferred (v{X.Y})**: …` di entri OQ dan
      di entri OQ (constraints.md; legacy: + roll-up 00-index.md). Sebutkan PIC dan/atau tanggal target lewat "Other" kalau sudah
      ada — empat pilihan di bawah hanya kategorinya: teks "Other" tercatat VERBATIM apa adanya,
      sedangkan memilih salah satu kategori mencatat kategori itu dalam bahasa isi vault.
      • Tekan Esc = BATALKAN defer ini DAN AKHIRI SELURUH walk: tidak ada apa pun yang ditulis untuk OQ ini (tetap `[ ]` open, tanpa anotasi `**Deferred**`), skill lompat ke Step 3 lalu keluar.
    header: "alasan"       # short; Q2 carries the OQ tag + question text in its own body above
    multiSelect: false
    options:
      - label: "Menunggu keputusan stakeholder / PIC"
        description: "Tercatat sebagai: 'menunggu keputusan stakeholder / PIC' (dalam bahasa isi
                      vault). Kalau kamu sudah tahu SIAPA dan KAPAN, pakai 'Other' — mis.
                      'menunggu Bu Rina (Compliance), target 2026-08-15' — supaya who/when ikut
                      tercatat verbatim, bukan hilang."
      - label: "Menunggu review legal / compliance"
        description: "Tercatat sebagai: 'menunggu review legal / compliance' (dalam bahasa isi
                      vault). Tambahkan nama reviewer / tanggal target lewat 'Other' kalau sudah
                      ada — teks 'Other' itu yang tercatat verbatim."
      - label: "Butuh data / investigasi dulu"
        description: "Tercatat sebagai: 'butuh data / investigasi dulu' (dalam bahasa isi vault).
                      Pakai 'Other' kalau mau menyebut data apa dan siapa yang mengambilnya."
      - label: "Menunggu dependency teknis selesai"
        description: "Tercatat sebagai: 'menunggu dependency teknis selesai' (dalam bahasa isi
                      vault). Pakai 'Other' untuk menyebut dependency-nya (mis. 'menunggu API
                      partner v2 live')."
    # "Other" pada Q2 = tulis alasan/PIC/tanggal sendiri; HANYA teks itu yang tercatat verbatim.
```

**Esc on this follow-up abandons the Defer** — nothing is written, the OQ stays `[ ]` open with no
`**Deferred**` annotation, and the walk ends per the Step-2b Esc semantics. Never fall back to a
canned reason: a defer with an invented `deferred_reason` is worse than no defer.

1. The defer reason is now in hand from Q2 (the chosen category, recorded per the recorded-language
   rule above, or the "Other" free text verbatim) and `defer_to` from Q1 (or, in greenfield, the
   explicit `stakeholder` value — the only legal one there, not a schema default). **Do not ask
   again.**
2. Append to the OQ entry: `**Deferred (v{X.Y})**: <reason / PIC / target date>`.
3. Leave `[ ]` open (it's still an Open Question, just waiting).
4. Legacy vaults only: update the roll-up annotation in `00-index.md` so readers see the defer reason at-a-glance.
5. **Run** `bash <plugin>/scripts/derive-vault-json.sh --vault <VAULT_DIR> --event '{"event":"oq-deferred","id":"OQ-XXX","at":"<iso>","action":"B"}' --patch <tmp-patch>` where the patch is `{"open_questions":{"OQ-XXX":{"defer_to":"stakeholder"}}}` (or `"binding"` for the brownfield sub-target) — the `**Deferred**` annotation derives `status: deferred` + `deferred_reason`; `deferred_at` is script-stamped; the summary recomputes.

**If `Skip`** (slot `[2]`, or an empty "Other", or a bare override with no recommendation to accept):

1. No file changes. No derive run. The OQ stays `[ ]` open.
2. Track skipped count — surface in the Step 5 summary as "still open after this session".
3. No follow-up prompt of any kind, and **the walk continues to the next OQ** — Skip is this OQ only.

### Step 2d — Continue / end the walk

Move to the next OQ in the queue.

**Ending the walk is Esc, and it costs no option slot.** "Stop here, save progress, exit" is
reachable on EVERY per-OQ prompt (and on the Defer / Out-of-scope follow-ups) by pressing Esc, and
its meaning is stated in the question text of every prompt shape above — it is documented, not
folklore, and it is the same reading of Esc the plugin's two other `AskUserQuestion` surfaces
already use. On Esc: the current OQ is left untouched (counts as skipped) and the skill jumps
straight to Step 3, so the version bump + Changelog still record the round. Each derive is atomic,
so whatever was already applied is consistent on disk. **There is no typed end-the-walk sentinel** —
see Step 2b for why one would be a trap.

**Prompt budget per OQ (the collapse, stated as a rail):**

| Path | Prompts |
|---|---|
| Answer — recommendation, own text via "Other", or a bare `→ <file>.md` override | **1** |
| Skip (slot `[2]`) | **1** (the same prompt; nothing follows; the walk continues) |
| End the walk (Esc) | **1** (the same prompt; nothing follows) |
| Defer | **2** (choice + ONE follow-up CALL carrying both questions — sub-target and reason) |
| Out of scope | **2** (choice + rationale) |

Anything above these numbers on the common path is a regression back to the pre-collapse walk.
A Defer that costs 3 (sub-target and reason asked in separate calls) is that regression — the
platform's 4-option cap is per QUESTION, not per CALL.

## Step 3 — Update vault metadata

After the loop completes (or the user bails out with progress to save):

1. **Bump vault version** in the lock home (vault.md frontmatter `vault_version:`; legacy: `00-index.md` Vault Lock Status):
   - Small bump (vX.Y+1) for resolution-only rounds (e.g., v1.0 → v1.1) — vault version grammar per diff-vault's `references/diff-procedure.md` §Update vault metadata (single owner).
   - The bump is shared across the round — every OQ resolved/OOS/deferred in this session gets the same `v{X.Y}` marker.
2. **Append Changelog entry** to the vault Changelog (`vault.md ## Changelog`; legacy: `00-index.md`):

```markdown
### v{X.Y} ({YYYY-MM-DD})

Resolved {R} OQs via `resolve-oq` session.

- **Resolved** ({R} entries):
  - OQ-XXX-N → <1-line resolution summary> (see {target doc/section})
  - OQ-YYY-M → <...>
- **Out of Scope** ({O} entries):
  - OQ-ZZZ-K → <reason>
- **Deferred** ({D} entries):
  - OQ-AAA-P → <reason + PIC / target date>
- **Still open after this session**: {S}
```

3. **Update `Last updated`** date in `vault.md` (legacy: `00-index.md`) to today's date (`YYYY-MM-DD`).

## Step 4 — Self-check before exit

- [ ] Every resolved OQ marked `[x]` with a `→ Resolved v{X.Y}` pointer in its OQ line (constraints.md; legacy: origin doc AND the 00-index roll-up).
- [ ] Every Out of Scope OQ marked `[~]` and physically present in the target doc's `## Out of Scope` section.
- [ ] Every Deferred OQ still `[ ]` but with a `**Deferred (v{X.Y})**:` annotation.
- [ ] No OQ silently dropped: every queue item **that was presented** ended in resolve / OOS / defer / skip. On an Esc-terminated round the queue items after the Esc point were never presented — they are `unreached`, not dropped, and are reported as such in Step 5. Do NOT fail this check on them, and do NOT invent an outcome for them.
- [ ] Vault version bumped in Vault Lock Status section.
- [ ] Changelog entry written with accurate counts.
- [ ] `Last updated` date updated.
- [ ] If any resolution was `Promoted`, the target doc has the new entry (e.g., new ADR `D-XXX` exists in `vault.md ## Decisions`) — verify via grep that the cross-reference resolves.
- [ ] No invented answers. Every resolution traces to user input from this session. Skill never auto-fills "best practice" defaults.
- [ ] `vault.json.open_questions_summary.total` matches the count of OQ entries in the authored OQ surface (constraints.md; legacy: the 00-index roll-up) after the round.
- [ ] Every OQ marked `[x]` / `[~]` / Deferred in markdown has matching `status` (`resolved` / `out_of_scope` / `deferred`) in `vault.json.open_questions[]`.
- [ ] If any resolution was Promoted to a new ADR, `vault.json.adrs[]` contains the new entry.

## Step 5 — Present summary

Output to chat (no file generation needed at this step):

1. Summary stats: `{R} resolved · {O} out of scope · {D} deferred · {S} skipped (still open) · {N} unreached (walk ended before them) · {U} untouched (out of scope this round)`.
   - `{S}` = presented and skipped (slot `[2]`, an empty "Other", or the OQ the user was on when they pressed Esc).
   - `{N}` = **in the queue but never presented**, because the walk ended on Esc. Report it whenever it is > 0 and name the next tag so re-running resumes obviously: *"Walk diakhiri di {tag}; {N} OQ belum sempat ditanyakan — jalankan `resolve-oq` lagi untuk melanjutkan."* Zero on a completed walk; omit the bucket then.
   - `{U}` = filtered out by `RESOLUTION_SCOPE` (e.g. P2/P3 under `p1-only`) — a different thing from `{N}`, never merged with it.
2. New vault version: `v{X.Y}`.
3. Path to vault: `<VAULT_DIR>` (absolute).
4. If still-open count > 0: top 3 remaining P1 blockers (one-line each) with their tags.
5. Suggested next step: re-run `resolve-oq` after stakeholder follow-up. To lock the vault for sprint implementation, edit the lock home manually (vault.md frontmatter; legacy: 00-index.md Vault Lock Status) — set 🔒 LOCKED + locked_at/locked_by, append a Changelog entry.

After completion, if any OQs were deferred to binding, suggest:
- For brownfield: `bind-codebase <vault> --express` (the express-spine lane — auto-resolves deferred OQs from index/manifest probes, no scan needed; classic spine: `scan-codebase && bind-codebase <vault>`)
- For greenfield: warn the user — deferred OQs in greenfield have no resolution path (no binding phase will run)

Do NOT pad with "I have resolved..." preamble. Just report numbers and surface remaining blockers.
