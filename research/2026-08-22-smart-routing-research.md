# Research — Smart model routing + "agent swarm" untuk mega-sdd

**Tanggal:** 2026-08-22 · **Status:** riset + rekomendasi, belum ada keputusan gate
**Pertanyaan:** bisakah mega-sdd memilih model LLM per pekerjaan secara otomatis, dan memilih/mempersonifikasi agent yang tepat (swarm)?

---

## 0. Ringkasan 30 detik

1. **Sebagian besar "smart routing" sudah ada di mega-sdd** — tapi statis. `references/model-tiers.md` (rubrik haiku/sonnet/opus + katalog per role), `agents/*.md` `model:` pin per lens, `resolve-review-tier.sh` (router deterministik 6 sinyal risiko → minimal/standard/full). Yang belum: model **per unit** untuk `bolt-implementer` (sekarang `inherit`) dan **eskalasi** saat gagal.
2. **Persona tidak meningkatkan kebenaran.** Dua studi (EMNLP 2024; arXiv 2605.29420, 2026) menemukan efek agregat kecil (d<0.12), dan untuk domain teknis/science baseline justru lebih baik. Yang bekerja adalah **spesialisasi konteks + tool** (lens yang cuma lihat diff + aturan §B), bukan "berpura-pura jadi senior engineer". Mega-sdd sudah di jalur yang benar — reviewer lens-nya adalah spesialisasi konteks, bukan persona.
3. **Swarm berbasis role untuk coding itu anti-pattern** menurut Anthropic sendiri: multi-agent memakan **3–10× token**, dan pembagian per role (planner→implementer→tester) menciptakan "telephone game". Pembagian harus **per konteks yang bisa diisolasi** — yang persis bentuk `execute-bolts --all --parallel` (satu unit = satu konteks). Jangan bangun swarm baru; perbaiki router-nya.
4. **Mekanisme Claude Code yang tersedia**: `model:` di frontmatter agent (sonnet/opus/haiku/inherit/full id), alias `opusplan` (Opus untuk plan, Sonnet untuk eksekusi), `effortLevel` (low→max) di settings, `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` (default 20). Agent tool di build saat ini **punya parameter `model`** saat spawn (terlihat di schema tool sesi ini: sonnet/opus/haiku/fable) — tapi **belum terdokumentasi**; desain harus punya fallback kalau parameter itu tidak ada.

Rekomendasi: **satu router deterministik per unit** (perluas `resolve-review-tier.sh`, bukan script baru) yang mengeluarkan `{implementer_model, effort, panel_tier}` dari sinyal yang sudah ada, plus **cascade eskalasi** yang memakai gate anti-halu yang sudah ada sebagai sinyal kualitas. Nol persona. Nol swarm baru.

---

## 1. Apa yang sudah ada (grounded dari repo)

| Komponen | Status | Catatan |
|---|---|---|
| `references/model-tiers.md` | ada, v1.0 | Rubrik pemilihan tier + katalog ±22 role. Override chain CLI > project > user > catalog, **hanya untuk role non-panel**. |
| `agents/*-reviewer.md` `model:` | ada | security/code-quality/phase-advisor = opus; spec/standards/design/resolution-verifier = sonnet; domain-extractor = sonnet; **bolt-implementer = inherit** (satu-satunya). |
| `scripts/resolve-review-tier.sh` | ada, deterministik | 6 sinyal: path auth/authz glob, manifest dep, ≥4 target files, kosakata risiko EN+ID, constitution §B, frontmatter risk. Output JSON `{tier, signals_fired}`. |
| Review panel tier → jumlah lens | ada | minimal=1 lens, standard, full=4 lens + design lens kalau UI-bearing. Ini sudah "smart swarm sizing". |
| Paralel bolts | ada | `analyze-parallelism.sh` wave plan → `execute-bolts --all --parallel`. Pembagian per unit = per konteks. |
| Telemetry biaya | ada | `report-token-cost.sh`, marker per subagent. Bisa jadi feedback loop. |
| Eskalasi model saat gagal | **tidak ada** | Fix round memakai verifier, tapi model implementer tetap. |
| Model per unit untuk implementer | **tidak ada** | `inherit` = mengikuti sesi operator, sama untuk unit CRUD 1 file dan unit payment 6 file. |

Kesimpulan: gap-nya sempit dan terdefinisi. Ini bukan fitur baru, ini **melengkapi router yang sudah ada ke sisi implementer**.

---

## 2. Apa kata riset

**Model routing / cascade.** Pola yang terbukti: (a) *pre-routing* — klasifikasi murah memilih model termurah yang cukup; (b) *cascade* — jalankan model murah dulu, **verifier** menilai hasil, eskalasi ke model mahal hanya kalau gagal. Cluster-Route-Escalate (arXiv 2606.27457) mempertahankan ~97% akurasi model terkuat dengan biaya lebih rendah; RouteLLM dan panduan industri 2026 melaporkan 40–85% penghematan tergantung distribusi query. **Insight penting untuk mega-sdd:** cascade butuh "post-generation quality signal" — dan mega-sdd **sudah punya** sinyal itu gratis: acceptance test yang dieksekusi, L0 gates, postflight hard rules, panel lens. Kebanyakan sistem harus melatih classifier untuk ini; lo tinggal memakai exit code.

**Persona / role prompting.** "Personas in System Prompts Do Not Improve Performances of LLMs" (EMNLP Findings 2024): tidak ada peningkatan akurasi faktual yang konsisten; efek acak antar persona. Studi lanjutan 2026 (1.140 pertanyaan, 38 role): persona menaikkan "kedalaman" tapi **menurunkan kejelasan** (p<0.001), dan untuk domain technology/science baseline menang. Implikasi: "personifikasi agent" sebagai gimmick prompt jangan dibangun. Yang boleh: **role = kontrak konteks + tool** (apa yang dia lihat, apa yang boleh dia sentuh, apa yang harus dia hasilkan) — itu sudah bentuk `agents/*.md` lo.

**Multi-agent / swarm.** Anthropic ("When to use multi-agent systems"): multi-agent = 3–10× token; menang untuk riset paralel & isolasi konteks; **kalah untuk coding yang dipecah per peran** karena kehilangan konteks di tiap handoff. Prinsip: *context-centric decomposition* — pecah berdasarkan konteks yang bisa diisolasi, bukan berdasarkan jenis pekerjaan; "verify subagents" adalah pengecualian yang bagus (konteks minimal). Mega-sdd: unit = isolasi konteks ✔, reviewer = verify subagent ✔. Jangan tambah "PM agent / architect agent / QA agent" sebagai swarm.

---

## 3. Kemampuan Claude Code (dari docs resmi, Aug 2026)

- Frontmatter agent: `name, description, tools, disallowedTools, model, permissionMode, skills, memory, isolation, background, maxTurns`. `model:` = `sonnet|opus|haiku|inherit|<full id>`; alias global juga ada `best, fable, opusplan, sonnet[1m], opus[1m]`. **Tidak ada `effort:` per agent** yang terdokumentasi; `effortLevel` ada di settings (low/medium/high/xhigh/max).
- Agent tool runtime: docs **tidak** mendokumentasikan `model`/`effort` saat spawn. Namun schema Agent tool di build saat ini menyediakan `model` (sonnet/opus/haiku/fable). Perlakukan sebagai *available-but-undocumented*: pakai kalau ada, fallback ke frontmatter kalau tidak.
- Hook `updatedInput` di PreToolUse ada, tapi tidak dijelaskan apakah boleh menulis ulang input Agent — **jangan** bangun router di hook (rapuh, dan melawan prinsip "skill-dispatch only" lo).
- Paralel: `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` default 20, kedalaman 3; agent teams masih eksperimental. Peringatan resmi: token berlipat.
- Tidak ada "auto model" bawaan. `opusplan` = routing paling dekat yang resmi (Opus saat plan mode, Sonnet saat eksekusi).

---

## 4. Rekomendasi desain (tidak over-engineer)

### 4.1 Router per unit — perluas `resolve-review-tier.sh`, jangan bikin script baru

Output sekarang `{tier, signals_fired}`. Tambahkan dua field turunan dari sinyal yang **sama**:

| Sinyal (sudah ada) | panel_tier | implementer_model | effort |
|---|---|---|---|
| verify / ≤2 file, nol sinyal | minimal | haiku* atau sonnet | low/medium |
| default | standard | sonnet | high |
| ≥1 sinyal risiko (auth/payment/§B/≥4 file/risk:high) | full | opus | high/xhigh |

*haiku hanya kalau unit `task_type: verify` atau pure-config/migration 1 file — rubrik haiku lo sendiri ("≤2 file, output ≤1KB") jarang cocok untuk menulis kode; default aman = sonnet. Override chain tetap: `--model-tier=` flag > `config.yaml model_tiers:` > auto. Semua keputusan dicatat di bolt-report (`model_used`, `signals_fired`) — audit trail yang sama dengan review panel.

Mekanisme dispatch, dua lapis: (1) kalau Agent tool menerima `model`, controller melewatkannya; (2) fallback tanpa mekanisme baru: tiga file agent `bolt-implementer.md` (sonnet), `bolt-implementer-heavy.md` (opus), `bolt-implementer-lite.md` (haiku) — **body identik via satu sumber** (generate dari template saat release, di-pin test parity), controller memilih nama agent. Ini memakai fitur yang terdokumentasi saja.

### 4.2 Cascade eskalasi — pakai gate yang sudah ada sebagai sinyal kualitas

Aturan satu baris: **kalau bolt gagal acceptance/L0/panel dua kali berturut di tier N, attempt berikutnya naik satu tier** (sonnet→opus), dicatat `escalated_from`. Tidak ada classifier, tidak ada model tambahan — sinyalnya exit code yang sudah lo percaya. Ini pola cascade dari literatur tanpa biaya training. Batas: maksimal satu eskalasi per unit; `--no-escalate` untuk mematikan.

### 4.3 "Persona" → ganti istilah jadi *context pack* per lens

Jangan tulis "You are a senior security engineer". Yang menaikkan kualitas adalah **apa yang dilihat**: lens security sudah menerima constitution §B + pack security idioms + diff; itu spesialisasi yang benar. Kalau mau "personifikasi" lebih jauh, bentuknya: per-framework lens context (Laravel vs Next.js idiom slice — sudah ada di framework-conventions), per-domain rule slice (dari KB regulatory rules), dan **tool allowlist** per agent (sudah ada). Tidak ada yang perlu dibangun selain memastikan slice-nya benar.

### 4.4 Swarm → tidak ada swarm baru; tune yang ada

Biarkan paralelisme per unit (wave plan). Tambahkan satu rail: **concurrency cap dari config** (`parallel_max: N`, default 4) karena default Claude Code 20 subagent × satu bolt-implementer 80 turn = ledakan token di Windows kantor. Jangan tambah agent orkestrator kedua.

### 4.5 Ukur sebelum percaya

Telemetry sudah ada. Definisikan satu eksperimen: `sample-prd-clinic.md` end-to-end, arm A = `inherit` (hari ini), arm B = router 4.1 + cascade 4.2. Metrik: token total, jumlah attempt, panel findings P1, waktu. Kalau B tidak hemat ≥25% token dengan kualitas panel setara, jangan ship.

---

## 5. Yang sebaiknya TIDAK dilakukan

- Router berbasis "model menilai sendiri kesulitan unit" — melanggar rail A5 lo (deterministic evidence, never model self-assessment) dan terbukti tidak reliabel (prose carve-out kasus Fase 0).
- Persona prompt per agent — bukti menunjukkan nol manfaat akurasi, biaya kejelasan.
- Swarm role-based (PM/architect/QA agents) — 3–10× token, telephone game.
- Router di hook via `updatedInput` — tidak terdokumentasi untuk Agent, melawan "skill-dispatch only".
- Classifier ML untuk routing — overkill; sinyal lo sudah deterministik dan sudah dipakai panel.

---

## 6. Prompt untuk Claude Code (gate desain, setelah Fase 3 selesai)

```
Baca research/2026-08-22-smart-routing-research.md. Rancang "per-unit model routing + cascade" untuk execute-bolts dengan batasan:
- Perluas scripts/resolve-review-tier.sh agar output menambah implementer_model + effort (turunan sinyal yang SAMA; tabel §4.1). Tidak ada script baru.
- Dispatch: cek apakah Agent tool di build ini menerima parameter `model`; kalau ya pakai, kalau tidak → varian agent file (lite/std/heavy) dari satu template, parity-pinned. Dokumentasikan mana yang terpakai.
- Cascade: gagal 2× di tier N → attempt berikut tier N+1, maksimal sekali, tercatat di bolt-report, `--no-escalate` untuk mematikan.
- Tambah `parallel_max` di config.yaml (default 4) untuk --parallel.
- Tidak ada persona prompt. Tidak ada agent baru selain varian implementer. Tidak ada perubahan gate anti-halu.
- Rencana eksperimen A/B pada sample-prd-clinic.md dengan metrik token/attempt/findings; kriteria ship ≥25% hemat token dengan kualitas panel setara.
Output: desain ≤2 halaman + daftar file yang disentuh + risiko. Berhenti di gate, jangan implement.
```

---

## Sumber

- Claude Code docs: [Subagents](https://code.claude.com/docs/en/sub-agents.md) · [Model config & aliases](https://code.claude.com/docs/en/model-config.md) · [Agents / concurrency](https://code.claude.com/docs/en/agents.md) · [Hooks](https://code.claude.com/docs/en/hooks.md) · [Settings](https://code.claude.com/docs/en/settings-reference.md)
- Anthropic, [When to use multi-agent systems (and when not to)](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)
- [Personas in System Prompts Do Not Improve Performances of LLMs (EMNLP Findings 2024)](https://aclanthology.org/2024.findings-emnlp.888/) · [When Does Persona Prompting Actually Help? (arXiv 2605.29420)](https://arxiv.org/html/2605.29420v1)
- [Cluster, Route, Escalate: Cascaded Framework for Cost-Aware LLM Serving (arXiv 2606.27457)](https://arxiv.org/html/2606.27457) · [LLM Model Routing in 2026 (Digital Applied)](https://www.digitalapplied.com/blog/llm-model-routing-2026-cost-quality-optimization-engineering-guide) · [LLM Routing and Model Cascades (TianPan)](https://tianpan.co/blog/2025-11-03-llm-routing-model-cascades) · [AI Agent Model Routing Strategies (Zylos)](https://zylos.ai/research/2026-03-02-ai-agent-model-routing/)
- Repo: `plugins/mega-sdd/references/model-tiers.md`, `agents/*.md`, `scripts/resolve-review-tier.sh`, `skills/execute-bolts/references/review-panel.md`
