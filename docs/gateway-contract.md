# Gateway contract — apa yang gateway kantor harapkan dari plugin mega-sdd

**Status: KONTRAK (v7.3.1, keputusan pemilik plugin 2026-08-23 — `research/2026-08-23-v7-gate7b-trace-restore.md`).** Tim AI gateway memfilter sesi mega-sdd pada keluarga tag `mega-sdd-trace:*`. Keluarga tag ini plus **catatan sesi `mega-sdd-note:`** (8.7.0, §Catatan sesi di bawah) adalah **dua-duanya — dan cuma dua — artefak in-band yang plugin hasilkan; semua hitungan token / biaya / sesi ada di gateway.** Tidak ada telemetry.jsonl, marker hook, cost report, advisor, atau deteksi governance di sisi plugin (semuanya dihapus di v7.3.0 dan TIDAK kembali — catatan sesi cuma bawa fakta git, bukan hitungan apa pun).

## Daftar tag

| Tag | Format (verbatim, satu token per baris) | Muncul di | Emitter |
|---|---|---|---|
| `mega-sdd-trace:turn` | **baris PERTAMA**, verbatim | Satu kali per user prompt, HANYA di project ter-adopsi (ada `.mega-sdd/`); CWD non-SDD = hening total. Sejak v7.5.0 №G hook yang sama BOLEH menambahkan satu baris kedua (tawaran sync dari census kalimat "selesai" — pure shell, nol spawn), dan sejak 8.8.0 satu baris opsional "HEAD moved" (state anchor, lihat di bawah); filter gateway tetap key pada baris pertama | `hooks/user-prompt-submit` (pure shell, nol spawn) |
| `mega-sdd-trace:<skill>` | akhir announce line skill, dalam backtick | Setiap kali sebuah skill mega-sdd mulai (14 skill ber-announce) | announce line tiap `skills/*/SKILL.md` |
| `mega-sdd-trace:<skill>` / `mega-sdd-trace:execute-bolts:<unit-id>` | baris tunggal di dalam prompt dispatch | Setiap prompt subagent (bolt implementer, lens panel, verifier, deep-scan extractor, wave extractor) — subagent berjalan fresh-context sehingga tanpa baris ini tidak terlihat filter gateway | `scripts/build-dispatch-prompt.sh` (T1 + `inline_core`), controller (lens/verifier), template deep-scan/wave |

## Aturan

- Satu token, verbatim, tanpa varian; filter gateway: `contains "mega-sdd-trace"`, prefix-match untuk breakdown per fase/unit. Baris tambahan NON-tag (mis. tawaran sync №G) tidak pernah memakai prefix `mega-sdd-trace` — namespace tag tetap eksklusif.
- Tag TIDAK punya opt-out config — statusnya kontrak, bukan preferensi.
- `mega-sdd-trace:session` (marker per-sesi lama) dan deteksi governance v6.19.2 ("sesi mega-code wajib mega-sdd") TIDAK dikembalikan — deteksi sesi sepenuhnya urusan gateway memakai tag di atas.
- `publish-artifacts.sh` (Stop hook) tetap mengirim dokumen pipeline ke gateway dengan manifest `plugin_version` — itu output pipeline, bukan observability, dan bukan bagian dari kontrak tag ini.

## Baris kedua census (№G, v7.5.0)

Baris kedua dari `hooks/user-prompt-submit` hanya muncul kalau DUA kondisi terpenuhi sekaligus: (a) `.mega-sdd/codebase/.dirty-paths.jsonl` tidak kosong, DAN (b) prompt user match set keyword census pada word boundary — Udah/Sudah/Selesai/Beres/Kelar/Commit/Push/Merge[d]/Done/PR. Teks baris kedua, verbatim:

```
mega-sdd: user menyiratkan pekerjaan selesai dan ada perubahan kode ter-journal — TAWARKAN /mega-sdd:sync dalam SATU baris (jangan auto-invoke; kalau user menolak, lanjut tanpa mengungkit lagi).
```

Baris ini TIDAK memakai prefix `mega-sdd-trace` (namespace tag eksklusif; filter gateway tetap key pada baris pertama).

## Baris "HEAD moved" (state anchor, 8.8.0)

Baris opsional berikutnya dari `hooks/user-prompt-submit`, SETELAH baris census (kalau ada). Muncul sekali per perpindahan HEAD per sesi: session-start nyatet HEAD yang dilihat sesi ini di ring per-worktree (`<gitdir>/mega-sdd-seen`, isinya cuma `<session_id> <sha> <branch>`), terus tiap prompt hook ngebandingin HEAD sekarang (baca builtin `.git/HEAD` + loose ref — nol spawn, nol fork). Beda sha atau beda branch → satu baris ini, verbatim kecuali tiga slot:

```
mega-sdd: HEAD moved this session (<old8> -> <new8>, <branch>) — the session-start state block is outdated; re-check memory/vault claims against code at HEAD.
```

Satu varian: kalau branch berpindah dan ref branch barunya cuma ada di `packed-refs` (umum setelah `gc` + checkout), sha barunya nggak dibaca per prompt, jadi slot kedua berisi nama branch: `(<old8> -> <branch>)`.

Baris ini buat MODEL (biar klaim memory/vault dicek ulang ke kode di HEAD), bukan data audit gateway; nggak pakai prefix `mega-sdd-trace`. `staleness_notice: false` di `.mega-sdd/config.yaml` mematikannya. Spec: `docs/superpowers/specs/2026-09-25-state-anchor-design.md` §7. Catatan sesi di bawah tetap cuma dicetak di SessionStart — baris ini nggak mengubah kontrak `mega-sdd-note`.

## Catatan sesi (`mega-sdd-note:`) — 8.7.0

Gateway udah pegang seluruh percakapan (dia proxy-nya, semua ke-log di Langfuse → ClickHouse). Yang dia NGGAK bisa tau: percakapan itu terjadi di **repo / branch / commit mana**. Catatan sesi nutup persis celah itu — satu baris di context sesi, lewat jalur yang sama dengan tag `:turn` (stdout hook → context → request body → log). "Lagi ngerjain apa" disusun gateway dari percakapan + tool call yang udah dia simpan; plugin nggak ngirim ulang apa yang udah ada di log. Spec: `docs/superpowers/specs/2026-09-21-session-note-gateway-design.md`.

**Bentuk baris** — persis satu baris, urutan key tetap, `key=value` dipisah spasi, nggak ada value kosong / berspasi:

```
mega-sdd-note: repo=<project_id> branch=<branch> head=<sha7> dir=<work_dir> sdd=<0|1> v=<plugin_version>
```

| Key | Isi | Kalau nggak ada |
|---|---|---|
| `repo` | remote `origin` ter-normalisasi — aturan SAMA PERSIS dengan `project_id` publisher (kredensial/userinfo dibuang, port dibuang, bentuk scp `host:path` → `host/path`, skema + `.git` dipotong) | tanpa remote / bukan repo git → `local/<dir>`; gagal whitelist → `invalid` |
| `branch` | nama branch; git nyetak `HEAD` kalau detached | `none` (repo unborn / bukan repo) |
| `head` | 7 karakter pertama sha HEAD | `none` |
| `dir` | basename root repo (atau cwd) — nggak pernah path penuh | `unknown` |
| `sdd` | `1` kalau ada `.mega-sdd/` di cwd atau parent-nya (project ter-adopsi) | `0` |
| `v` | versi plugin mega-sdd | `unknown` |

**Kapan muncul:** SessionStart (`startup|resume|clear|compact`), HANYA di sesi yang lewat gateway (`ANTHROPIC_BASE_URL` ter-set di env proses — blok `env` settings.json disuntik ke proses hook). Sesi vanilla: hening total, nol spawn `git`, nol token. Muncul di CWD MANA PUN, termasuk repo yang belum adopsi mega-sdd — itu intinya. Tag `:turn` tetap cuma di project ter-adopsi; aturan "non-SDD = hening" di tabel atas berlaku buat TAG, bukan buat catatan ini. Nggak ada opt-out config (statusnya kontrak, sama seperti tag). Emitter: `hooks/session-note` — pure shell, maksimal 2 spawn `git`, nol python / network / file yang ditulis.

**Namespace sengaja beda:** `mega-sdd-note:` TIDAK mengandung substring `mega-sdd-trace`. Catatan ini nyala juga di repo non-SDD — kalau numpang prefix tag, filter sesi mega-sdd (`contains "mega-sdd-trace"`) bakal salah ngitung. Namespace tag tetap eksklusif.

**Jaminan sanitasi** (isi `.git/config` = input nggak dipercaya yang masuk ke context model): `repo` itu *persis atau `invalid`* — cuma `[A-Za-z0-9._/~-]`, ≤ 200 karakter, nggak pernah ditulis ulang secara lossy (id yang ke-mangle bakal mecah satu repo jadi dua); `branch`/`dir` lossy — karakter di luar `[A-Za-z0-9._/-]` jadi `_`, dipotong 100 / 64; cuma baris PERTAMA output git yang dibaca (nggak mungkin ada baris kedua hasil suntikan); kredensial di remote nggak pernah ikut.

**Aturan parse buat gateway:**
- Parse `key=value` **per key, bukan per posisi** — key baru bisa nambah (additive); yang nggak dikenal di-ignore.
- **Kemunculan TERAKHIR di satu input yang menang** — sesi hasil `resume`/`compact` bawa baris lama di atas baris baru.
- **Potong pakai charset kontrak, JANGAN pakai "sampai newline" atau `\S+`** (dikoreksi 8.7.1 — resep 8.7.0 rapuh). Kalau `input` disimpan sebagai JSON, newline jadi dua karakter `\n` dan akhir string jadi `"}` → key terakhir kebaca `v=8.7.0\n\nSessionStart` atau `v=8.7.0"},` (diuji terhadap trace kantor asli). Value dijamin cuma berisi `A-Z a-z 0-9 . _ / ~ + -` — nggak pernah backslash, kutip, atau spasi — jadi resep ini benar di bentuk mentah maupun JSON. Barisnya juga TIDAK di awal baris (di depannya ada prefix `SessionStart:<source> hook success: `), jadi jangan anchor ke `^`. Letaknya di pesan `user` PERTAMA main-thread, bukan di system prompt. Nama kolom (`input`) sesuaikan skema kalian:

  ```
  extractAll(input, 'mega-sdd-note: ((?:[a-z_]+=[A-Za-z0-9._/~+-]+ ?)+)')[-1]  AS note,
  extract(note, '(?:^| )repo=([^ ]+)')    AS repo,
  extract(note, '(?:^| )branch=([^ ]+)')  AS branch,
  extract(note, '(?:^| )head=([^ ]+)')    AS head,
  extract(note, '(?:^| )dir=([^ ]+)')     AS dir,
  extract(note, '(?:^| )sdd=([01])')      AS sdd,
  extract(note, '(?:^| )v=([^ ]+)')       AS plugin_version
  ```

- `repo` == `project_id` di manifest publisher buat repo yang sama → kunci join audit sesi ↔ artefak yang di-publish. `repo=invalid` dan `repo=local/<dir>` itu non-identitas yang jujur — jangan pernah di-merge.
- Request subagent (sidechain) mulai dari context kosong → TIDAK bawa baris ini. Atribusikan lewat pengelompokan sesi yang gateway udah pakai: Claude Code ngirim header `x-claude-code-session-id` di tiap request (terdokumentasi di LLM-gateway protocol-nya) kalau gateway nge-log header; kalau nggak, window per-NIP yang sekarang.
- `sdd=0` tanpa satu pun `mega-sdd-trace:*` di sesi itu = kerja di luar pipeline — sinyal governance yang dulu dicari v6.19.2, sekarang bisa diturunin tanpa marker sesi.

**Terkonfirmasi di lapangan (2026-09-21):** barisnya kelihatan di trace Langfuse kantor — laptop Windows + Git Bash, repo ter-adopsi (`sdd=1`), plugin 8.7.0 — di pesan `user` pertama tepat setelah blok anchor; `branch` dan `head` cocok dengan blok `gitStatus` native Claude Code di trace yang sama; `dir` = root repo walau cwd-nya subfolder; nama folder ≠ nama repo (itu sebabnya identitas = `repo`, bukan `dir`). Artinya env hook kantor memang bawa `ANTHROPIC_BASE_URL`. Belum ada sampel: repo non-adopsi (`sdd=0`), header `x-claude-code-session-id`, latensi SessionStart di Windows + CrowdStrike.

**Yang udah ada di log TANPA plugin (bukan kontrak, best-effort):** system prompt Claude Code sendiri udah bawa working directory, `Current branch`, `Git user`, daftar `Status:` dan 5 `Recent commits:` (blok `gitStatus`). Gateway boleh nambang dari situ buat "lagi ngerjain apa" — tapi itu prosa internal Claude Code (format bisa berubah antar versi, cuma ada kalau cwd repo git, snapshot awal sesi) dan TIDAK berisi remote URL. Yang jadi pegangan tetap `mega-sdd-note`; simpan hasil tambang native di kolom terpisah.

**Blind spot yang diterima (v1):** commit manual / pindah branch di luar Claude di tengah sesi nggak tercatat (baris cuma dicetak di SessionStart). Baris delta per-prompt = lever yang ditunda, dibangun hanya kalau data gateway nunjukin itu beneran bolong.

## Publisher (Stop hook)

- **Gate publish:** leg publisher di Stop hook jalan hanya kalau `.mega-sdd/vaults/` ada ATAU `.mega-sdd/graph.json` ada — vault sentinel `_codebase` meng-cover project tahap scan (belum ber-vault, sudah ber-graph/codemap).
- **Field manifest** (`manifest.json`, entry root PERTAMA di tar.gz): `{schema: "mega-sdd-publish/1", project_id (git remote ter-normalisasi — kredensial/userinfo dibuang, port ssh dibuang, `.git` dipotong; tanpa remote → `local/<work_dir>`), vault, git_head, generated_at, files (map path→sha256), graph_meta, work_dir (basename saja), plugin_version}`.
- **Perilaku:** fail-open by contract (kegagalan network/kredensial exit 0, tidak pernah blokir pipeline) + sha-self-debounce via `.mega-sdd/.publish-state.json` (hanya file yang sha-nya berubah yang dikirim; manifest selalu FULL, gateway self-heal via respons `{"missing":[...]}`).

Pin test: `tests/session-note/test-session-note.sh` (catatan sesi: grammar, sanitasi, hening vanilla, budget git, wiring, dan a14 — resep parse DI DOKUMEN INI dibaca lalu diuji terhadap output hook asli dalam bentuk mentah + dua bentuk JSON; normalizer `repo` di-pin ke `project_id` publisher lewat corpus bersama `tests/fixtures/project-id-corpus.tsv` — sisi python: `tests/publisher/test-publish-artifacts.sh` r3d), `tests/surface/test-p9-audit-phase1.sh` (kelengkapan announce + template), `tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` + `plugins/mega-sdd/tests/moat/test-dispatch-prompt-cascade.sh` (tag di prompt/inline_core), `tests/weighted-routing/test-tier-s-hooks.sh` (echo turn = 0 fork; non-SDD hening).
