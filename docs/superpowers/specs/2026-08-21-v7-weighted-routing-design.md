# v7 Fase 1 — Weighted Routing (S/M/L) Design

**Tanggal:** 2026-08-21 · **Status:** DESIGN — menunggu approval gate Fase 1
**Basis:** `research/2026-08-21-v7-diet-audit.md` (baseline §4) + `research/2026-08-21-v7-gate0-decision.md` (arahan §3–§4)
**Prinsip:** tier gate = **mekanisme** (marker + short-circuit shell), bukan kalimat prose. Default saat ragu = **S** (kebalikan sekarang). Moat tidak disentuh: semua gate tetap utuh saat chain aktif.

---

## 1. Tabel keputusan S/M/L (masuk ke anchor, verbatim)

| Tier | Sinyal (cukup SATU yang kuat) | Yang jalan |
|---|---|---|
| **S — direct** (DEFAULT saat ragu) | Bug hunt / fix / debug / refactor lokal 1–3 file; pertanyaan tentang kode; prompt TIDAK menyebut PRD, vault, unit, bolt, spec, sync, binding, OQ; tidak ada artifact arg; prompt kontinuasi (`lanjut`, `ok`, `next`) TANPA marker chain sesi ini | **Tidak lewat pipeline.** Jawab seperti Claude Code biasa. Boleh baca vault read-only MAKS 1 file, HANYA bila prompt menyebut nama domain/entity yang ada di vault — tanpa ground, tanpa derive-state, tanpa status view. Nol script mega-sdd. Di akhir jawaban, kalau relevan, SATU baris tawaran: `mau masuk pipeline? → /mega-sdd` |
| **M — delta** | Prompt menyebut entity/flow/screen milik vault **DAN** meminta perubahan spec/fitur ("tambah field X di form Y", "ubah flow approval"); brief 1–2 kalimat yang match entity vault | Delta lane yang SUDAH ADA: `diff-vault --from-prompt` → re-bind claim-scoped → `generate-units --reconcile` → bolts stale/new. SATU konfirmasi. Skip advisor, analyze penuh, lint penuh, modules-summary, emit proposal. |
| **L — full** | Artifact arg (PRD/BRD file, legacy dir, vault); `--greenfield`; epic baru; `/mega-sdd` eksplisit; `sync` setelah banyak perubahan | Chain penuh seperti sekarang (express spine default). |

**Override user selalu menang:** `--weight=S|M|L` atau `--full` di front door; "skip SDD" / "just write the code" tetap dihormati (sudah ada).

Dua rail yang mengunci tabel ini jadi mekanisme, bukan janji:
1. **Model-side**: anchor tidak lagi punya klausa CWD-invoke (§2.1) — tanpa keyword M/L atau marker chain, tidak ada teks yang menyuruh model STOP-invoke.
2. **Hook-side**: gate scoped-chain (§3) tidak arm di sesi S — kalaupun model salah baca tabel, Edit/Write tier S tidak pernah di-block hook.

---

## 2. Perubahan model-side (anchor + front door + session-start)

### 2.1 `skills/using-mega-sdd/SKILL.md` (v3.3.3 → 4.0.0)

| Baris skrg | Sekarang | Menjadi |
|---|---|---|
| `:4` description | berakhir "…or the CWD shows `.mega-sdd/` signals" | Klausa CWD **dihapus** dari description. Census keyword EN+ID tetap (mereka sinyal M/L yang sah). |
| `:13` When this applies | trigger (a) typed verb, (b) keyword, **(c) CWD shows SDD signals** | (c) **dihapus sebagai trigger invoke**. Keberadaan `.mega-sdd/` = sinyal **status** saja (baris notice session-start), bukan alasan STOP-invoke. Trigger tinggal (a) + (b), dan keduanya dirutekan lewat tabel S/M/L (keyword M/L → invoke; keyword absen → S). |
| `:15-17` Auto-trigger | "CWD signal strong AND SDD intent (or empty/continuation prompt) → propose /mega-sdd" | Auto-propose HANYA untuk M/L. Prompt kontinuasi (`lanjut`/`ok`/`next`) auto-propose HANYA bila marker chain sesi ini armed (§3.1) — di sesi S, `lanjut` berarti lanjut kerjaan inline. Carve-out "fix this bug does NOT auto-trigger" jadi redundan (S adalah default), tapi satu kalimatnya dipertahankan sebagai contoh tier S. |
| `:19-21` front door | "Any SDD lane phrase → front door … when unsure, ASK" | Tetap, dengan satu perubahan: **when unsure → tier S + tawaran satu baris**, bukan ASK round-trip. (ASK dipertahankan hanya untuk ambiguitas M-vs-L pada multi-PRD routing — divergensinya mahal.) |
| `:23-25` Hard rule | "For any trigger above: STOP, invoke…" | Ditulis ulang: **berlaku untuk tier M/L saja.** Tier S dilarang invoke skill pipeline — teks eksplisit: "Tier S: jangan invoke skill mega-sdd; kerjakan inline." Default route when unsure `orchestrate-flow` → dihapus (default when unsure = S). |
| `:59` maintenance lane | "after ANY out-of-pipeline change → `/mega-sdd:sync`" | Dilunakkan: "sync **ditawarkan** saat entry M/L berikutnya (front door menampilkannya dari change_signal); TIDAK diwajibkan setelah hotfix/edit inline." |
| `:82-89` red-flags table | 4 baris mempermalukan kerja inline | **Dihapus seluruhnya** (di bawah ANCHOR-CORE; tidak ter-inject, tapi loadable — tetap dihapus supaya skill yang di-load penuh tidak melawan tabel S/M/L). |
| (baru) | — | Tabel S/M/L §1 masuk di dalam ANCHOR-CORE, menggantikan §When-this-applies lama + Auto-trigger. |

Estimasi ukuran core injected: sekarang 3.417 B (~854 tok); after ≈ 3,4–3,8 KB (tabel menambah, klausa yang dihapus mengurangi) — **injeksi anchor bukan sumber penghematan; penghematannya = tidak masuk pipeline + nol spawn**. Angka final diukur saat implementasi (tests/anchor-diet pin di-update).

### 2.2 `commands/mega-sdd.md`

- Tambah `--weight=S|M|L` + `--full` di argument-hint + satu paragraf "Weight override": `--weight=S` → jangan jalankan Lane 0/1, jawab inline (escape hatch kalau user terlanjur ketik `/mega-sdd` untuk pertanyaan kecil); `--weight=M` → paksa delta lane; `--weight=L`/`--full` → chain penuh.
- Lane 0 step 2 staleness bullet: tetap (front door = entry M/L by definition — di sinilah sync memang pantas ditawarkan, sesuai gate-0 §4.3).
- Lane 1 step 3 (free-text → delta lane) = implementasi tier M yang sudah ada; diberi label "M" saja, nol perubahan logika.

### 2.3 `hooks/session-start`

- **Blok slim "MANDATORY development workflow" (no-signal CWD, v5.2.6) DIHAPUS utuh** — CWD tanpa sinyal SDD kembali exit silent. (`install-front-door.sh` heal tetap; 1 spawn murah, Fase 2 boleh debounce.)
- Staleness notice (dua situs: digest leg + bash fallback leg) di-reword jadi notice-only: `mega-sdd: codebase moved since last scan (N write(s)) — sync tersedia saat masuk lane M/L (/mega-sdd).` Tidak ada lagi imperatif "reconciles map → drift → binding → units" yang mendorong model mem-propose sync di sesi S. Dirty journal tetap mencatat (murah, jujur — keputusan gate 0).
- Compaction slim re-injection: ikut bentuk baru Hard rule (M/L-scoped) otomatis (awk mengambil section yang sama).

---

## 3. Perubahan hook-side (mekanisme tier gate)

### 3.1 Marker "chain aktif" — dua syarat, nol file baru, satu koreksi dari gate 0

Keputusan gate 0: `factory-ledger.json` presence AND `.turn-usage-cursor-<sid>`. **Temuan saat desain detail:** cursor ditulis hook Stop **tiap turn di project ter-adopsi, sesi apapun** (termasuk sesi bug-hunt murni) — jadi AND-nya nyaris tereduksi ke factory-ledger saja sejak turn ke-2, dan niat lo ("sesi ini memang pakai mega-sdd") tidak tercapai. Varian yang mekanis benar, tetap tanpa mekanisme baru:

> **armed** ⇔ `.mega-sdd/factory-ledger.json` ada (project ini menjalankan chain) **AND** `.gateguard-state.json` punya flag `chain_engaged` untuk `session_id` sekarang.

`chain_engaged` ditulis oleh **pre-tool-use Skill branch** — branch yang HANYA fire saat sebuah skill `mega-sdd:*` di-dispatch (itu definisi chain activity; branch-nya self-scoped sejak dulu). `.gateguard-state.json` sudah ada, sudah session-keyed, sudah ditulis-dibaca hook yang sama (LRU 500 entri) — kita menambah satu field, bukan satu file. Urutan aman: PreToolUse fire SEBELUM skill jalan, jadi marker armed sebelum Edit/Write pertama milik chain.

- Sesi S di project ter-adopsi: tidak pernah ada dispatch `mega-sdd:*` → tidak pernah armed → gate scoped lewat.
- Sesi chain lintas-kompaksi/sesi baru: user `lanjut` → tabel M/L (marker? belum) — `lanjut` tanpa marker = S… **kecuali** front door/`--resume` dipakai atau keyword M/L lain hadir; begitu skill di-dispatch, marker armed lagi. Trade-off ini disengaja: chain resume selalu lewat dispatch skill, jadi jendela tanpa-gate hanya SEBELUM chain benar-benar disentuh kembali.
- Subagent bolt (Edit/Write dari bolt-implementer): asumsi = hook stdin subagent membawa `session_id` sesi utama (konsisten dengan GateGuard session-keyed yang hari ini bekerja saat bolts). **Diverifikasi empiris saat implementasi** (test harness hook); kalau ternyata beda, fallback: armed juga saat `.plan-pending` ada ATAU field `agent_transcript_path` hadir di stdin.

### 3.2 `hooks/pre-tool-use` — split always-on vs chain-scoped (per gate 0 §3)

| Guard | Sekarang | v7 |
|---|---|---|
| FP_GUARD forged-verdict (Write/Edit ke path state mega-sdd, L772-849) | python spawn tiap Edit/Write | **ALWAYS-ON** (moat), + fast-path shell: substring check `".mega-sdd"` / nama file state di raw stdin SEBELUM spawn python; tidak match → exit 0 tanpa spawn; tidak bisa ekstrak → fall through ke python (fail-closed, pola short-circuit existing). Edit bug-fix biasa: **0 spawn**. |
| Bash tamper greps (L938-1040, 12 pola) | tiap Bash call | **Split:** pola yang menarget file state mega-sdd (`.validation-blockers.json` dkk.) ALWAYS-ON dengan fast-path substring yang sama; pola non-state-path → chain-scoped (armed only). |
| GateGuard LOCKED-check (L855-931) | tiap Edit/Write | **Chain-scoped** (armed only) — keputusan gate 0. |
| Skill-branch gates (scope-flag :220, factory backward-dispatch :279, predictive-preflight :335, aggregator blocker :499-519, custom-map :709-743) | fire saat skill mega-sdd di-dispatch | Tetap — sudah self-scoped (dispatch skill = chain activity). Nol perubahan. |
| Handoff gate (Branch 1a :382-419) | baca state hasil Stop | **Gate-time recompute (§3.4).** |

### 3.3 `hooks/post-tool-use` — fan-out scoped

- Dirty-journal append (L549-570): **tetap always-on** (keputusan gate 0 — murah, jujur; konsumennya notice + sync M/L).
- 3 validator undebounced + path-glob validator dispatch + 4 project-wide scanner first-per-HEAD (L867-950, :954, :919): **chain-scoped** (armed only). Justifikasi moat: audit §0 temuan #2 — aggregator PreToolUse me-recompute semua state ini di gate-time; fan-out ini early-warning, bukan penjaga. Saat chain aktif, perilaku identik hari ini.
- Telemetry rows: tidak disentuh Fase 1 (Fase 2).

### 3.4 Handoff-validation → gate-time (gate 0 §2, "tidak boleh demote ke advisory")

Sekarang: Stop mendeteksi `handoff:` di teks assistant → jalankan `validate-handoff-yaml.sh` → tulis `.handoff-validation-state.json`; PreToolUse Branch 1a mem-block dispatch skill berikutnya kalau FAIL. Celahnya: derivasi hidup di Stop (satu-satunya state gate yang tidak di-recompute at gate), dan menghalangi diet Stop.

v7: **Branch 1a me-recompute sendiri** — saat skill `mega-sdd:*` di-dispatch, baca last assistant message dari `transcript_path` (python tail-parse yang sama dengan leg fallback Stop), kalau mengandung `handoff:` → jalankan `validate-handoff-yaml.sh` fresh, tulis state, lalu putuskan block/pass dari hasil SEGAR (pola S4/S5/S6). Biaya: satu python + satu validator per dispatch skill mega-sdd (jarang; chain-only). Leg Stop-nya dihapus di **Fase 2** (satu fase transisi dua-penulis, state file sama, idempotent).

### 3.5 `hooks/user-prompt-submit`

- Trace tag `mega-sdd-trace:turn`: tetap (kontrak gateway/Langfuse).
- Transcript scan compaction-advisor (O(panjang sesi) TIAP prompt): **chain-scoped** (armed only) — sesi S: 0 scan. (Syarat lama "vault with units exists" tetap sebagai syarat tambahan.)

### 3.6 `hooks/stop` + `hooks/subagent-stop`

- Tambah **pure-shell short-circuit non-mega-sdd** di paling atas (pola persis pre-tool-use/user-prompt-submit L52-73): project tanpa `.mega-sdd/` ancestor → exit 0 tanpa python. Menutup 1-2 python spawn per turn di SEMUA project non-SDD (temuan audit §3.3).
- Isi Stop lain tidak disentuh Fase 1 (dietnya Fase 2, setelah §3.4 mendarat).

### 3.7 Yang TIDAK dilakukan Fase 1 (scope fence)

Tidak ada script dihapus/di-merge (Fase 2). Tidak ada perubahan vault (Fase 3). Tidak ada rename state-file. Tidak ada fungsi weight di `derive-state.sh` — tabel S/M/L murni model-side dan hook tidak butuh weight (hook pakai marker); menambah field weight ke state.json = mekanisme tanpa konsumen (no-gimmick).

---

## 4. Bukti — trace statis after vs before (baseline audit §4)

| Langkah (skenario bug-hunt, project ter-adopsi) | BEFORE (audit §4) | AFTER (desain ini) |
|---|---|---|
| SessionStart | anchor core ~930 tok + ~22-26 spawn; Win 5,5-8s blocking | Anchor core tetap ter-inject (~850-950 tok, diukur ulang); spawn sama (derive-state utk status line tetap — dia yang bikin notice jujur). CWD non-SDD: blok slim MANDATORY hilang → 0 injeksi. |
| UserPromptSubmit per prompt | 2 python + transcript scan O(sesi); Win ~1,3-1,8s/prompt | Trace tag saja (~6 tok); **0 transcript scan** (marker off). Win ~0,2-0,4s. |
| Routing model-side | Klausa :13(c) + Hard rule :25 menarik ke front door → 4,1k tok command + status view + konfirmasi + sync lane ±60,6k tok | Tabel S/M/L: tier S → **tidak ada invoke, tidak ada front door, nol script**. Tawaran 1 baris opsional. |
| ground.sh → derive-state → symbol-index → status view | ~10-14 spawn + 4-5k tok | **Tidak jalan** (tier S). |
| PreToolUse per Edit/Write | 3 python spawn blocking; GateGuard deny bila file LOCKED (+1-3k tok); Win 1,5-2,5s/call | Marker un-armed: FP_GUARD fast-path substring → **0 spawn** utk path biasa; GateGuard skip; Bash: pola state-path only via substring → ~0 spawn. Win <0,1s/call. |
| PostToolUse per Edit | 10-18 fork background (3 validator undebounced + glob validators) | Journal append saja (~1-2 fork). |
| Stop per turn | 1-2 python + scans | mega-sdd project: tetap (diet Fase 2); non-SDD project: **0 spawn** (short-circuit baru). |
| Ekor sesi | change_signal buatan sendiri → sesi berikutnya propose sync ±60k tok | Notice satu baris; sync ditawarkan hanya saat entry M/L. |
| **Total bug-hunt** | **±30-65k tok + 15-25 mnt (jalur pipeline); jalur "patuh" pun ±930 tok + 9-14 dtk/1,5-3 mnt spawn tax + deny + sync tail** | **≈ anchor injection saja (<1k tok), nol script mega-sdd, nol block, nol sync tail.** Target prompt asli terpenuhi by construction; diverifikasi ulang dengan trace statis yang sama sesudah implementasi. |

Chain M/L: perilaku dan biaya **identik hari ini** (semua gate armed, fan-out jalan, GateGuard aktif).

---

## 5. Daftar file yang disentuh

| # | File | Perubahan |
|---|---|---|
| 1 | `skills/using-mega-sdd/SKILL.md` | rewrite §2.1 (description, tabel S/M/L, Hard rule M/L, maintenance lane, hapus red-flags) |
| 2 | `commands/mega-sdd.md` | `--weight`/`--full`, paragraf override, label M di Lane 1.3 |
| 3 | `hooks/session-start` | hapus blok slim MANDATORY; reword staleness notice (2 situs) |
| 4 | `hooks/pre-tool-use` | `chain_engaged` writer di Skill branch; scoping GateGuard + Bash non-state; FP_GUARD/Bash fast-path substring; Branch 1a gate-time recompute |
| 5 | `hooks/post-tool-use` | fan-out validator chain-scoped; journal tetap |
| 6 | `hooks/user-prompt-submit` | transcript scan chain-scoped |
| 7 | `hooks/stop`, `hooks/subagent-stop` | pure-shell short-circuit non-SDD |
| 8 | `skills/orchestrate-flow/references/routing-rules.md` | cross-ref tabel S/M/L (seperlunya) |
| 9 | `README.md` | bagian routing ditulis ulang (S/M/L + default S) |
| 10 | `CHANGELOG.md` | entry 7.0.0 (breaking: routing default inverted; entry tumbuh di Fase 2/3) |
| 11 | `.claude-plugin/plugin.json` + `marketplace.json` (root) | 7.0.0, sinkron |
| 12 | tests | baru: tier-S no-gate (Edit tanpa marker lolos tanpa spawn gate), armed-gate mutation-proof (marker on → GateGuard/validator fire persis seperti hari ini), handoff gate-time recompute, Stop/SubagentStop short-circuit, `chain_engaged` writer; update: tests/anchor-diet pin, tests yang mengasumsi always-on (disweep saat implementasi, KEDUA tree) |

## 6. Risiko yang di-surface (jawab di gate ini)

1. **[R1] Marker varian** — gue mengganti AND-cursor (gate 0) dengan AND-`chain_engaged` karena cursor terbukti tidak berarti "sesi ini pakai mega-sdd" (§3.1). Setuju?
2. **[R2] Subagent session_id** — asumsi §3.1 diverifikasi empiris saat implementasi; kalau gagal, fallback `.plan-pending`/`agent_transcript_path` OR-condition. Setuju fallback-nya?
3. **[R3] Jendela un-gated pasca-hotfix** — antara chain session berakhir dan chain berikutnya, edit manual di file LOCKED tidak di-deny GateGuard (by design keputusan gate 0); jaring pengaman = re-derivation gate-time saat chain berikutnya masuk + FP_GUARD state-path yang tetap always-on. Konfirmasi terima residual risk ini.
4. **[R4] `lanjut` lintas sesi** — sesi baru melanjutkan chain butuh keyword M/L / front door / `--resume` (marker belum armed). Satu baris di anchor: "chain sebelumnya terdeteksi (factory-ledger) + prompt kontinuasi → tawarkan `/mega-sdd --resume`, jangan auto-invoke". Setuju?

---

## 7. Implementation amendments (recorded during build, reported at phase close)

1. **§3.1 armed = `chain_engaged(session_id)` SAJA — AND-`factory-ledger.json` DIBUANG.** Lubang yang ketemu saat implementasi: ledger baru tercipta di handoff fase PERTAMA, jadi seluruh chain greenfield pertama (generate-intent menulis vault) akan berjalan un-armed di bawah kondisi AND — fan-out validator PostToolUse diam persis saat vault pertama ditulis. `chain_engaged` sendirian: arm sejak dispatch skill pertama (lebih ketat untuk moat), identik untuk tier S (sesi bug-hunt tidak pernah dispatch skill). Presence factory-ledger tetap dipakai model-side untuk tawaran `--resume` (R4).
2. **§2.3 no-signal CWD: BUKAN bisu total — satu baris `mega-sdd-trace:session` bertahan.** Blok slim MANDATORY dihapus sesuai gate-1, tapi marker session adalah kontrak deteksi governance gateway kantor (v6.19.2, hard check per NIP window — specs/2026-08-17-artifact-publisher-gateway.md §2); bisu total akan false-flag semua sesi non-SDD di bawah warn→block. Satu token, nol teks routing. Opt-out lama (.mega-sdd-routing-off / MEGA_SDD_ROUTING) obsolete.
3. **`--full` BUKAN alias weight-L.** `--full` sudah berarti profile switch (lawan `--lean`, tranche E). Sesuai catatan gate-1 "jangan bikin alias lain": satu-satunya flag weight adalah `--weight=S|M|L`.
