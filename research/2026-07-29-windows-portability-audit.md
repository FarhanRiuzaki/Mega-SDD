# Windows portability audit — mega-sdd v5.11.0

**Bottom line.** Enam hazard-class finder menyapu seluruh transitive closure plugin dan menghasilkan **27 temuan yang lolos refutation** — 4 `hang`, 7 `silent-wrong`, 13 `degraded`, 3 `cosmetic` — di mana kelas terparah bukan performa melainkan **gate yang diam-diam lolos**: tanpa Python yang benar-benar bisa dieksekusi, seluruh script lane (`derive-state.sh`, semua `validate-*.sh`, secret gate) keluar dengan exit 49 dan tidak ada satu pun halt clause yang cocok, sehingga bolt tetap jalan sementara moat-nya sudah mati. Dua skill punya jalur `hang` nyata yang bisa dihindari lewat flag (`generate-units` tanpa `--skip-pagerank` = ~36 menit di repo 10k file; `scan-codebase --shallow-scan` = 440 detik hashing sebelum gate spawn-cost bahkan dihitung), dan satu `hang` plugin-wide (`crlf-no-gitattributes`) masih menunggu satu perintah Git Bash untuk dipastikan. Tidak ada mesin Windows tersedia selama audit ini, jadi **setiap item bertag `NEEDS-WINDOWS` berstatus belum terbukti** dan dikumpulkan menjadi satu script di §4.

---

## Verdict per skill

**Basis kolom `worst severity`.** Kolom ini hanya menghitung temuan yang **spesifik untuk skill tersebut**. Empat temuan bertag `ALL` berlaku untuk **setiap baris** dan sengaja tidak dimasukkan ke skor per-baris supaya tabel tetap bisa membedakan:

| plugin-wide finding | severity | catatan |
| --- | --- | --- |
| `crlf-no-gitattributes` | hang | `NEEDS-WINDOWS`; kalau menyala, tidak ada satu pun skill yang jalan |
| `session-start-halfpython-setE-abort` | silent-wrong | **state C saja** |
| `run-hook-dispatcher-tax` | degraded | ~550–660 ms tax per hook fire |
| `tooling-install-windows-matrix-false` | degraded | dokumentasi, bukan runtime |

**Dua state yang harus dibedakan** (ini yang menentukan jawaban kolom ketiga):

- **State B — laptop terukur hari ini.** Tidak ada Python sama sekali; `python3` dan `python` sama-sama WindowsApps stub (exit 49), `py` tidak ada.
- **State C — setelah `/mega-sdd:install-deps` lewat route winget/python.org**, satu-satunya route tanpa PowerShell menurut `tool-matrix.yaml:47/53`. `python` nyata, `python3` **tetap** stub.

| skill | worst severity | can the team run it today? | why |
| --- | --- | --- | --- |
| `analyze` | — | Yes | tidak ada hazard Windows-spesifik yang ditemukan; hanya plugin-wide floor |
| `bind-codebase` | silent-wrong | Yes, with caveat: script lane mati di state B dan C | `scripts-hardcode-python3-no-resolver` — validator exit 49, tanpa halt clause |
| `detect-drift` | silent-wrong | Yes, with caveat: sama, script lane mati | `scripts-hardcode-python3-no-resolver` |
| `diff-vault` | degraded | Yes, with caveat: preflight bisa false-fail | `predictive-checks-bare-python3` |
| `emit-agents-md` | — | Yes | tidak ada hazard Windows-spesifik yang ditemukan |
| `emit-fsd` | degraded | Yes, with caveat: PDF lane halt dengan tuduhan salah | `md2pdf-python3-misattributed-halt` (+ `md2pdf-two-unbounded-chromium-launches`, `chain-execution-dep-remedy-missed-v531`) |
| `emit-prd` | degraded | Yes, with caveat: sama, PDF lane halt salah blame | `md2pdf-python3-misattributed-halt` |
| `emit-sit` | degraded | Yes, with caveat: sama, PDF lane halt salah blame | `md2pdf-python3-misattributed-halt` |
| `emit-uat` | degraded | Yes, with caveat: sama, PDF lane halt salah blame | `md2pdf-python3-misattributed-halt` |
| `execute-bolts` | hang | **No — will hang** begitu `ast-grep` terpasang; dan gate-nya sudah diam-diam lolos sejak state B | `preflight-astgrep-unbounded-twin` + `secret-gate-bypass-no-python3` + `boltartifacts-startswith-and-relpath-sep` |
| `extract-intelligence` | degraded | Yes, with caveat: Wave-3 gate false-fail kalau file CRLF | `crlf-frontmatter-prose-gate`, `extracted-kb-snapshot-hash-fanout` |
| `generate-intent` | degraded | Yes, with caveat: freshness preflight bayar fork tax tak diumumkan | `kb-freshness-hash-fanout` |
| `generate-units` | hang | **No — will hang** saat `precision_tier: ast`; Yes dengan `--skip-pagerank` atau tier `regex` | `pagerank-symbolgraph-ungated` — full-repo tree-sitter walk tanpa spawn-cost gate |
| `graph` | — | Yes | tidak ada hazard Windows-spesifik yang ditemukan |
| `install-deps` | degraded | Yes, with caveat: bound `timeout 10` mungkin longgar, dan matrix-nya salah soal Git Bash | `timeout-without-k-native-windows-child`, `tooling-install-windows-matrix-false` |
| `memory` | degraded | Yes, with caveat: preflight bisa false-fail | `predictive-checks-bare-python3` |
| `orchestrate-flow` | silent-wrong | Yes di state B (moat masih menolak); **No secara moat di state C** | `pretooluse-failclosed-wrong-discriminator`, `upe-command-v-python3-route-pick` |
| `resolve-oq` | degraded | Yes, with caveat: chain bisa dilewatkan dengan pesan yakin tapi salah | `predictive-checks-bare-python3` |
| `scan-codebase` | hang | Yes **kecuali** `--shallow-scan` — dengan flag itu **No, will hang** | `shallow-scan-hash-fanout` — 2.000 spawn hashing sebelum gate |
| `using-mega-sdd` | — | Yes | tidak ada hazard Windows-spesifik yang ditemukan |

Catatan dua baris yang gampang salah baca:

- `orchestrate-flow` disebut di `skills_affected` temuan pagerank, tapi verifier menilai framing sync-lane-nya **overstated**: `task-typing.md:169-181` menunjukkan Reconcile hanya menjalankan step 1–3 per unit dan baru masuk Steps 2–12 (yang memuat Step 7.5) untuk klaim BARU. Jadi jalur hang-nya lewat dispatch `generate-units`, bukan setiap sync.
- `scan-codebase` hanya hang pada opt-in eksplisit. `/mega-sdd:sync` memakai `--changed-only` (`commands/sync.md:13`), bukan `--shallow-scan`.

---

## Findings, ranked

### Severity: hang

---

### `pagerank-symbolgraph-ungated` — generate-units membangun ulang symbol graph tree-sitter se-repo tanpa spawn-cost gate

`hang` · `CONFIRMED-LOCALLY` · skills: `generate-units`, `scan-codebase`
**Corroborated by** `pagerank-tree-sitter-no-spawn-gate` dan `pagerank-unbounded-treesitter-respawn` — tiga finder menemukan situs yang sama secara independen, ketiganya CONFIRMED.

**Evidence** — `plugins/mega-sdd/skills/generate-units/references/pagerank-targeting.md:74`

```
- Symbol graph build: ~1s for repos <1000 files; ~5-10s for repos <10000 files
```

Pendukung di file yang sama: `:21` "Nodes = files in repo", `:25` build lewat capture `@name.reference.<kind>`, `:78` escape hatch `>50k files` → `--skip-pagerank`, `:82` cache di `<vault>/.internal/symbol-graph.json`, di-invalidate saat `codebase-map.md` diregenerasi.

**Yang terjadi di laptop kantor.** Step 7.5 menyala secara default kalau `codebase-map.md` bertanda `precision_tier: ast` (`skills/generate-units/SKILL.md:83`), dan `scan-procedure.md:169` menyatakan eksplisit bahwa capture `name.reference.<kind>` **tidak dipersist** oleh `scan-codebase`, jadi `generate-units` menjalankan ulang query yang sama — satu proses `tree-sitter query` **per file repo**. Tidak ada satu pun kata `spawn`, `per_spawn`, atau `220` di seluruh `skills/generate-units/`; spawn-cost gate v5.11.0 hanya mendarat di `scan-codebase` (`SKILL.md:52`, `scan-procedure.md:119`, `halts-flags-handoff.md:28`).

Aritmetika pada oracle 0,22 s/spawn:

| files in repo | wall clock | yang dijanjikan dokumen |
| --- | --- | --- |
| 272 | 60 s | — (ambang gate `scan-codebase`) |
| 1.000 | 220 s (3,7 mnt) | "~1s" (`:74`) |
| 2.000 | 440 s (7,3 mnt) | "~5-10s" |
| 10.000 | 2.200 s (36,7 mnt) | "~5-10s" |
| 50.000 | 11.000 s (3,06 jam) | baru di sini `--skip-pagerank` disarankan (`:78`) |

Dua hal yang memperburuk. Pertama, **prekondisinya terbalik**: tier `ast` hanya ada kalau tree-sitter terpasang, jadi menjalankan `/mega-sdd:install-deps` justru yang mempersenjatai hazard ini. Kedua, **N-mismatch**: gate `scan-codebase` menghitung `N = files that will actually be extracted (after the invalidation gate)` (`scan-procedure.md:138`), sementara symbol graph butuh total file repo — jadi scan inkremental lolos gate dengan estimasi ~2 detik lalu `generate-units` diam-diam membayar biaya penuh.

**Narrowing yang harus dibawa.** `precision_tier: ast` hanya distempel kalau grammar smoke test lulus (`scan-procedure.md:65`). `tree-sitter-cli` hasil winget polos tidak membawa grammar terkonfigurasi, jadi laptop seperti itu mendarat di `regex` dan Step 7.5 dilewati. "No — will hang" hanya benar di laptop yang grammar-nya sudah dikonfigurasi.

**Bagaimana dibuktikan.** Pembacaan rantai reachability end-to-end, bukan tebakan: `SKILL.md:83` (default-on untuk tier ast, `--skip-pagerank` default off) → `pagerank-targeting.md:21` (nodes = files in repo) → `scan-procedure.md:169` (capture tidak dipersist, `generate-units` menjalankan ulang query). Gate-absence diverifikasi ulang dengan regex yang benar (`grep -rn "Spawn-cost"` di seluruh plugin → hanya hit di `scan-codebase`). Fork count bersifat platform-invariant; wall clock adalah proyeksi dari oracle 0,22 s/spawn.

**Fix sketch.** Port spawn-cost gate `scan-codebase` ke Step 7.5 dengan N = **total file repo**, bukan file inkremental, dan tawarkan `--skip-pagerank` sebagai opsi di `AskUserQuestion` saat estimasi >60 s. Perbaiki tabel performa `:74` menjadi OS-conditional dan turunkan ambang `:78` dari `>50k files` ke titik di mana estimasi benar-benar melewati 60 s (~270 file di Windows). Perbaikan struktural yang lebih baik: persist capture `name.reference.*` saat walk `scan-codebase` sehingga graph menjadi produk sampingan dari walk yang sudah dianggarkan.

---

### `preflight-astgrep-unbounded-twin` — `run-preflight-scan.sh` menjalankan `ast-grep scan` se-repo per rule tanpa timeout

`hang` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`

**Evidence** — `plugins/mega-sdd/scripts/run-preflight-scan.sh:225`

```python
rr = subprocess.run([astgrep, "scan", "--rule", tmp_rule, "--json", cwd],
                    capture_output=True, text=True)
```

**Yang terjadi di laptop kantor.** Ini kembar identik dari panggilan yang **sudah dibatasi** di post-flight engine. `scripts/_lib/postflight_rules.py:547-548` byte-identical kecuali `timeout=120`, dan repo menulis alasannya sendiri di `:540-545`: *"BOUNDED, and the bound is load-bearing. This is a repo-wide ast-grep scan … An unbounded scan there is the same failure shape as the 2026-07-28 Windows hang: work with no ceiling in a path Claude Code waits on."* Plugin sudah mengadili bahwa panggilan ini butuh ceiling, lalu menerapkannya hanya di satu dari dua situs.

Loop-nya `for i, ry in enumerate(v2_rules)` (`:217`) — satu scan AST se-repo tak terbatas per Hard rule v2, per unit. Reachability-nya **wajib, bukan insidental**: `skills/execute-bolts/SKILL.md:59` menjadikan script ini panggilan Bash wajib untuk setiap unit dengan section `## Hard rules` tidak kosong, dan `:130` melarang melewatinya (*"NEVER skip it to save time"*). Pre-flight tidak bisa mencatat verdict `fail`, jadi scan yang macet memblokir run, bukan menghasilkan artefak salah.

Prekondisi yang lagi-lagi terbalik: `:211-216` keluar dengan exit 6 (`dep_missing`) kalau `ast-grep` tidak ada, jadi satu-satunya mesin Windows yang mencapai baris 225 adalah yang `/mega-sdd:install-deps`-nya berhasil.

**Dua narrowing jujur** yang tidak menggugurkan temuan: blast radius lebih kecil dari temuan gate-chain karena ini model-invoked, bukan hook-exec'd (`run-preflight-scan` muncul di `hooks/pre-tool-use` hanya di `:792/:807/:999` di dalam string prosa); dan loop-nya hanya menyala untuk unit bergrammar v2, yang menurut `validation-passes.md:68` bersifat either/or per unit.

**Bagaimana dibuktikan.** Pembacaan langsung `:211-226` dan pembandingan byte-per-byte dengan `postflight_rules.py:547-548`; grep negatif untuk dispatch dari hook direproduksi.

**Fix sketch.** Cerminkan sibling-nya persis: tambahkan `timeout=120` plus cabang `subprocess.TimeoutExpired`. Berbeda dari post-flight, pre-flight **tidak boleh** mencatat verdict `fail` — rule yang baseline-nya gagal ditangkap harus keluar dengan halt code `hard_rule` supaya run berhenti. Snapshot yang kehilangan `matched_files` sebuah rule adalah baseline palsu.

---

### `shallow-scan-hash-fanout` — invalidation gate `--shallow-scan` meng-hash setiap file satu spawn per file, sebelum dan tak terlihat oleh spawn-cost gate v5.11.0

`hang` · `CONFIRMED-LOCALLY` · skills: `scan-codebase`

**Evidence** — `plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md:111`

> This gate runs BEFORE tree-sitter / regex extraction below. When `--shallow-scan` flag is set AND a prior `codebase-map.md` exists in the project, the gate compares each source file's current sha256 to the `Last_Scanned_Sha256` column in prior `codebase-map.md` §2:

**Yang terjadi di laptop kantor.** Gate ini **prosa murni** — `grep -rn 'Last_Scanned_Sha256' scripts/ hooks/` tidak menghasilkan apa-apa, jadi MODEL yang mengeksekusinya, satu `sha256sum <file>` per file, tanpa instruksi batching di mana pun. Spawn-cost gate v5.11.0 secara struktural **tidak bisa melihat** biaya ini: `:138` mendefinisikan `N = files that will actually be extracted (after the invalidation gate)` — hashing terjadi sebelum N itu ada.

Repo 2.000 file dengan `--shallow-scan` dan 10 file berubah: gate mengestimasi 10 × 0,22 = 2,2 detik lalu lanjut diam-diam, padahal keputusan invalidasi itu sendiri sudah menghabiskan **2.000 spawn = 440 detik (7,3 menit)** yang tidak dianggarkan dan tidak diumumkan. Fast path yang dibangun untuk menghemat waktu justru menjadi langkah paling lambat dalam scan.

Verifier mencatat temuan ini bahkan **undersold**: di bawah EDR, satu spawn sha256 berharga sama ~220 ms dengan satu spawn tree-sitter, jadi gate membakar 2.000 spawn (440 s) untuk menghindari 1.990 spawn (438 s) — fast path Windows-nya net-zero sampai net-negatif.

**Bagaimana dibuktikan.** Fork count diukur pada 2.000 file `.py` generated: loop per-file `shasum -a 256 "$f"` = 2.000 spawn, 50.413 ms di macOS; batched `shasum -a 256 $D/*.py` = 1 spawn, 319 ms. Rasio 158×. Kelayakan batching dikonfirmasi ulang: `shasum -a 256 /tmp/_a /tmp/_b` menghasilkan dua digest dari satu proses.

**Fix sketch.** Ganti hash per-file dengan satu invocation batch atas daftar file yang sudah dienumerasi (`xargs -0` untuk N besar), dan **nyatakan batching itu eksplisit di prosanya** supaya model tidak regress ke loop. Selain itu, lipat jumlah hashing ke dalam estimasi spawn-cost gate supaya gate menganggarkan total spawn, bukan hanya spawn ekstraksi pasca-invalidasi.

---

### `crlf-no-gitattributes` — tidak ada `.gitattributes`; clone Git-for-Windows default memberi CRLF ke semua hook dan `run-hook.sh` mati sebelum mendispatch apa pun

`hang` · `NEEDS-WINDOWS` · skills: `ALL`

**Evidence** — `plugins/mega-sdd/hooks/run-hook.sh:13`

```bash
set -euo pipefail
```

**Yang terjadi di laptop kantor.** Opsi installer default Git for Windows adalah `core.autocrlf=true`, jadi `git clone` ke plugin cache menulis ulang setiap LF menjadi CRLF (heuristik text Git menandai semua file ini sebagai text; repo tidak punya `.gitattributes` untuk opt out). Baris 13 lalu diparse sebagai `set -e -u -o $'pipefail\r'` → `set: pipefail: invalid option name`, dan `run-hook.sh` keluar dengan RC=2 **tanpa mendispatch apa pun**.

Konsekuensinya bercabang dua, dan temuan ini parah di kedua cabang:

1. `PreToolUse`, `SessionStart`, `UserPromptExpansion`, `UserPromptSubmit`, `PreCompact` semuanya `"async": false` di `hooks/hooks.json`. Jika kontrak Claude Code memperlakukan `PreToolUse` exit 2 sebagai BLOCK, setiap tool call `Skill|Bash|Edit|Write` ditolak dan sesi mati merah → `hang`.
2. `PostToolUse`, `Stop`, `SubagentStop`, `PostToolUseFailure` `"async": true`, jadi kegagalannya **tak terlihat**: seluruh moat (dirty journal, postflight scan, batch-suite gate) menguap sementara model percaya dirinya masih tergate → `silent-wrong`.

Independen dari itu, `scripts/_lib/resolve-project-root.sh:36` kena syntax error keras di bawah CRLF (`_rpr_has_bound_vault() {`), sehingga `resolve_project_root` tidak terdefinisi untuk setiap script yang men-source-nya.

**Kenapa `NEEDS-WINDOWS` walau mekanismenya terbukti.** Yang terbukti lokal adalah **mekanismenya**, bukan **trigger-nya**. Fakta yang diasumsikan bersifat environmental — bahwa clone di plugin cache benar-benar menghasilkan CRLF — dan itu justru dibantah oleh oracle bahwa dua laptop berjalan normal di v5.9.0, yang hanya mungkin kalau `autocrlf=false/input`. Ini laten untuk **setiap laptop BARU** yang memakai default installer.

**Bagaimana dibuktikan (mekanisme).** `find . -name .gitattributes -not -path './.git/*'` → kosong; `grep -rlI $'\r' .` → kosong (repo 100% LF hari ini). Checkout `autocrlf=true` disimulasikan lalu dieksekusi di bawah bash 5.3 asli: `docker run --rm -v $SP/crlf:/w -w /w bash:5.3 bash -c 'bash hooks/run-hook.sh pre-tool-use; echo RC=$?'` → `line 13: set: pipefail: invalid option name` / `RC=2`. Delapan hook entry point terbukti **tanpa ekstensi**, jadi rule `*.sh` akan meleset semuanya.

**Discriminator Windows** — lihat check #2 di §4.

**Fix sketch.** Tambahkan `.gitattributes` di root repo dengan `* text=auto eol=lf` — **bukan** `*.sh text eol=lf`, karena `hooks/pre-tool-use`, `post-tool-use`, `session-start`, `stop`, `subagent-stop`, `pre-compact`, `user-prompt-submit`, `user-prompt-expansion` semuanya tanpa ekstensi. Perhatikan bahwa menambahkan `.gitattributes` **tidak** merenormalisasi checkout yang sudah ada: laptop terdampak harus re-clone plugin cache. Tambahkan pula suite check yang gagal kalau ada file tracked di bawah `plugins/mega-sdd/` mengandung `\r`.

---

### Severity: silent-wrong

---

### `scripts-hardcode-python3-no-resolver` — 85 dari 91 script hardcode `python3`; tak satu pun memakai `$MEGA_SDD_PY`, dan state engine front door mati dengan exit 49

`silent-wrong` · `CONFIRMED-LOCALLY` · skills: `mega-sdd`, `orchestrate-flow`, `bind-codebase`, `generate-units`, `execute-bolts`, `scan-codebase`, `detect-drift`, `extract-intelligence`, `sync`, `emit-prd`, `emit-fsd`, `emit-sit`, `emit-uat`
**Menyala di state B (hari ini) maupun state C.**

**Evidence** — `plugins/mega-sdd/scripts/derive-state.sh:55`

```bash
CWD="$CWD" JSON_ONLY="$JSON_ONLY" python3 <<'PYEOF'
```

**Yang terjadi di laptop kantor.** Sensus: 191 baris invocation `python3` di 92 file bawah `scripts/` + `hooks/`. Grep `MEGA_SDD_PY` di seluruh source plugin mengembalikan **tepat tiga file** — `scripts/_lib/resolve-python.sh` (definisinya), `scripts/fix-windows-path.sh`, dan `skills/install-deps/SKILL.md`. Nol validator, nol writer, nol probe script yang mengonsumsi resolver.

Akibatnya di state C: `install-deps` Step 2.5 melaporkan `python3 present` — probe terdokumentasinya benar-benar mencetak `Python 3.14.6`, rc=0 — sementara **seluruh script lane mati**.

Instans dengan reachability tertinggi: `commands/mega-sdd.md:16` menyuruh `Run: scripts/derive-state.sh --cwd=<root>` lalu `read .mega-sdd/state.json` pada **setiap** `/mega-sdd` polos. Script keluar 49, tidak mencetak apa pun ke stdout, dan tidak menulis `state.json`. Baik `commands/mega-sdd.md` maupun `skills/orchestrate-flow/references/routing-rules.md:20` tidak punya cabang untuk `derive-state` yang gagal — dan alternatif `--json-only` adalah heredoc `python3` yang sama. Tanpa state dan tanpa instruksi, model hanya punya satu jalan tersisa: mengarang posisi/vault/count yang justru dilarang di-probe manual (`routing-rules.md:20`: *"Read state.json; never re-probe by hand"*).

**Bagaimana dibuktikan.** Fixture bersih di state C: `derive-state.sh` rc=49, stdout nol, `state.json` **tidak ditulis**; `validate-preflight.sh` rc=49, padahal kontraknya sendiri (`:22`) hanya mengenal `0 = PASS/WARN; 1 = FATAL; 2 = error`. Ketiadaan recovery branch diverifikasi lebih luas dari yang dilakukan finder: halt taxonomy adalah **enum tertutup** yang dikunci ke exit code spesifik, dan satu-satunya aturan generik non-zero justru berbunyi "never halt" (`chain-execution.md:181`, `emit-uat/SKILL.md:109`).

**Koreksi sensus.** Klaim "every one of 91 scripts" salah: 85 dari 91 `scripts/*.sh` mengandung `python3`. Kuantifier universalnya keliru, temuannya tidak.

**Fix sketch.** Tambahkan preamble bersama yang men-source `scripts/_lib/resolve-python.sh`, halt dengan `mega_sdd_python_remedy` yang sudah ada saat resolver mengembalikan 1, dan mengekspos `$MEGA_SDD_PY` — lalu tulis ulang 191 invocation `python3` secara mekanis ke `$MEGA_SDD_PY` tanpa kutip. Terpisah dari itu, beri front door halt eksplisit untuk `derive-state` non-zero, supaya `state.json` yang tidak tertulis tidak pernah bisa dikarang.

---

### `secret-gate-bypass-no-python3` — L0 secret gate: fallback regex "never unscanned" itu sendiri `python3`, jadi AWS key hidup di diff bolt menghasilkan exit 49 dan tanpa halt

`silent-wrong` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`
**Menyala di state B (hari ini) maupun state C.**

**Evidence** — `plugins/mega-sdd/scripts/scan-secrets-code.sh:75`

```bash
CHANGED="$CHANGED" GITLEAKS_RC="$GITLEAKS_RC" python3 - <<'PYEOF'
```

**Yang terjadi di laptop kantor.** `gitleaks` dijaga jujur di `:28` dengan `command -v gitleaks` (tidak ada WindowsApps stub untuk gitleaks, jadi check itu benar), dan di laptop tanpa gitleaks script jatuh ke plugin regex set — yang diiklankan `code-gates.md:22` sebagai *"fallback regex set (never unscanned)"* dan `code-gates.md:36` sebagai *"a tool failure is a visible SKIP with a reason, never silently reported as clean"*.

**Kedua janji itu dipalsukan.** Engine fallback-nya adalah heredoc `python3` telanjang, jadi di laptop ini ia tidak mengemisi apa pun — bukan finding, bukan SKIP — dan keluar 49. Prosa konsumennya di `code-gates.md:51` hanya halt pada exit 1, dan **tidak ada aturan non-zero generik** di mana pun di `code-gates.md` (`:52`/`:53` juga menyebut kode spesifik). Exit 49 tidak cocok dengan klausa halt mana pun.

**Bagaimana dibuktikan.** Fixture git: commit A = `x=1`; commit B menambahkan `leak.py` berisi `AWS_KEY = "AKIAIOSFODNN7EXAMPLE"`.

- Interpreter nyata, gitleaks dilepas dari PATH → `{"engine":"fallback-regex", …, "rule":"aws-access-key","file":"leak.py","line":1, "total":1}`, **rc=1** (halt `secret_in_code`).
- Stub `python3`, tanpa gitleaks → stdout nol, **rc=49** → tidak ada halt clause yang cocok, bolt lanjut, kredensial ter-commit dan ter-ship.

Jalur refutasi yang paling menjanjikan sudah dicoba dan gagal: pencarian aturan halt non-zero generik satu level di atas (`skills/execute-bolts/SKILL.md`, `references/halt-protocol.md`, `halt-taxonomy.md`) tidak menemukan apa pun.

**Fix sketch.** Rutekan fallback lewat `$MEGA_SDD_PY`, dan saat tidak ada interpreter yang resolve, keluar dengan kode yang diperlakukan prosanya sebagai blocking — atau emisikan `{"skipped":true,"error":"no usable python interpreter"}` **dan** tambahkan klausa "gate could not run → halt" ke `code-gates.md`, supaya scanner yang tidak bisa jalan tidak pernah tidak-terbedakan dari diff yang bersih.

---

### `pretooluse-failclosed-wrong-discriminator` — fallback fail-closed didiskriminasi oleh "interpreter apa pun yang usable", jadi moat execute-bolts fail OPEN saat hanya `python3` yang stub

`silent-wrong` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`, `orchestrate-flow`, `mega-sdd`
**State C saja.** Di state B guard-nya bekerja benar.

**Evidence** — `plugins/mega-sdd/hooks/pre-tool-use:115`

```bash
    mega_sdd_python >/dev/null 2>&1 || PY_USABLE=0
```

**Yang terjadi di laptop kantor.** Parse JSON stdin di `:30` men-spawn `python3` secara spesifik, tidak dapat apa-apa (exit 49, stderr dibuang), dan jatuh ke blok fail-closed. Blok itu lalu mengajukan **pertanyaan yang salah** — `mega_sdd_python`, yang menyusuri `python3` → `python` → `py -3` dan dengan senang hati me-resolve `python`. `PY_USABLE` tetap 1, cabang deny dilewati, hook `exit 0`.

Hasilnya: `/mega-sdd:execute-bolts` **diizinkan** dengan `.validation-blockers.json` yang menyatakan FAIL — moat binding→units, CONFLICT gate, quality gates, dan anti-self-bypass guard semuanya lolos tanpa dievaluasi. Persis silent-death yang menurut komentar v5.4.0 di `:104-113` sudah diperbaiki. Guard-nya bukan hilang; **diskriminatornya** yang salah.

**Bagaimana dibuktikan.** Fixture dengan `.mega-sdd/.validation-blockers.json` = `{"status":"FAIL"}`:

- State A (baseline macOS) → deny.
- State B (WindowsApps saja) → deny, reason `mega-sdd gate (fail-closed): no usable python3 interpreter…` — **guard benar**.
- State C (`pyreal:WindowsApps`) → **output KOSONG, rc=0** — fail-open, execute-bolts diizinkan.

`scripts/_lib/resolve-python.sh:92-98` dibaca langsung: laddernya melooping `for cand in python3 python`, menolak hit alias, dan mengembalikan `MEGA_SDD_PY=python` — nama yang tidak pernah di-spawn hook ini.

**Fix sketch.** Resolve interpreter **sebelum** parse dan jalankan parse lewat `$MEGA_SDD_PY`; atau gate fallback-nya pada apakah nama `python3` **secara spesifik** usable. Diskriminator harus cocok dengan command yang benar-benar gagal.

---

### `upe-command-v-python3-route-pick` — arm moat UserPromptExpansion memilih route parse dengan `command -v python3`; stub memenangkan route, gate fail open, dan fallback `sed`-nya jadi unreachable

`silent-wrong` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`, `orchestrate-flow`, `mega-sdd`
**Route-pick-nya menyala di state B (hari ini); konsekuensi "kedua arm terbuka" butuh state C.**

**Evidence** — `plugins/mega-sdd/hooks/user-prompt-expansion:19`

```bash
if command -v python3 >/dev/null 2>&1; then
```

**Yang terjadi di laptop kantor.** `command -v python3` mengembalikan RC=0 terhadap AppExecLink 0-byte — **presence != usability**. Hook mengambil cabang python, `python3 -c` hanya menulis ke stderr dan keluar 49, `CWD` kembali kosong, dan `:28` `[ -n "$CWD" ] || exit 0` mengakhiri. Fallback `sed` yang ditulis di `:26` **persis untuk kasus ini** adalah dead code di Windows — ia hanya bisa jalan di mesin yang `python3`-nya benar-benar absen dari PATH, yang justru dijamin tidak pernah terjadi oleh WindowsApps alias.

Akibatnya `/mega-sdd:execute-bolts` atau front door `/mega-sdd` mengekspansi normal walau `.validation-blockers.json` berkata FAIL. Ini arm defense-in-depth yang ada justru karena jalur `/command` melewati `PreToolUse`.

**Koreksi penting terhadap klaim finder.** Klaim *"BOTH arms of the moat are open on this laptop"* **salah untuk state B**: `PreToolUse` masih menolak di state B (terbukti di temuan sebelumnya). Hari ini ini murni kehilangan defense-in-depth. Konsekuensi kedua-arm baru muncul di state C.

**Bagaimana dibuktikan.** Fixture status FAIL, prompt `/mega-sdd:execute-bolts`: baseline → `{"decision": "block", "reason": "mega-sdd gate: binding/units validation state does not attest PASS …"}`; state B → kosong; state C → kosong. Route-pick sendiri: `PATH=$S/WindowsApps:$PATH sh -c 'command -v python3 >/dev/null 2>&1; echo rc=$?'` → `rc=0`.

**Fix sketch.** Source `scripts/_lib/resolve-python.sh` dan bercabang pada `mega_sdd_python` (pakai `$MEGA_SDD_PY` untuk parse), atau **buang cabang python sepenuhnya** — hook ini hanya butuh `cwd`, yang sudah dihasilkan ekstraksi `sed` yang ada.

---

### `session-start-halfpython-setE-abort` — `session-start` mengemisi NOL byte saat `python` bekerja tapi `python3` adalah stub; routing anchor hilang diam-diam setiap sesi

`silent-wrong` · `CONFIRMED-LOCALLY` · skills: `ALL`
**State C saja.** Di state B guard-nya bekerja benar dan justru mengemisi peringatan.

**Evidence** — `plugins/mega-sdd/hooks/session-start:250`

```bash
SELF_RESOLVE_NOTICES=$(CWD="$cwd" TELEMETRY_FILE="$TELEMETRY_FILE" python3 <<'PYEOF' 2>/dev/null
```

**Yang terjadi di laptop kantor.** Prekondisinya adalah tujuan yang plugin ini **dokumentasikan sendiri** untuk tim ini: `tool-matrix.yaml:47` menyatakan route scoop tidak bisa di-bootstrap tanpa PowerShell dan menyuruh jatuh ke baris winget serta *"verify with `python`, not `python3`"*; `:53` menyatakan installer itu mengirim `python.exe`/`py.exe` dan **tidak pernah** `python3.exe`, sehingga `python3` **tetap** jatuh ke stub.

Di state itu `resolve-python.sh` mengembalikan 0 (ia me-resolve `python`), jadi early-exit guard di `:196-215` — guard yang komentarnya sendiri berbunyi *"Observed on a Windows 11 corporate laptop 2026-07-28: session-start produced 0 bytes"* — **dilewati**. Eksekusi lalu mencapai `:250` yang hardcode `python3`. Di bawah `set -euo pipefail` (`:5`), command substitution yang gagal membatalkan hook di tengah jalan.

User tidak melihat apa pun: tidak ada anchor, tidak ada warning, tidak ada error. Claude Code tidak pernah tahu mega-sdd ada, jadi setiap permintaan SDD dijawab inline alih-alih dirutekan lewat gated phase.

**Bagaimana dibuktikan.** Harness stub AppExecLink (stderr message + exit 49) dengan fixture sebagai **process CWD**:

| state | stdout | rc |
| --- | --- | --- |
| A — baseline macOS | 3.724 byte | 0 |
| B — WindowsApps saja | 4.570 byte (guard menyala, anchor + `PY_WARN` diemisi) | 0 |
| C — `pyreal:WindowsApps` | **0 byte** | **49** |

`set -e` pada versi bash yang benar-benar dideploy (bukan bash 3.2 macOS) dikonfirmasi: `docker run --rm bash:5.3 -c 'set -euo pipefail; V=$(sh -c "exit 49"); echo REACHED'` → tidak ada `REACHED`, rc=49.

**Fix sketch.** Source `resolve-python.sh` sekali di puncak `session-start` dan ganti setiap `python3` telanjang dengan `$MEGA_SDD_PY` tanpa kutip; alternatifnya, buat early-exit guard menguji **nama `python3` secara spesifik** — nama yang benar-benar di-spawn sisa file itu — bukan "interpreter apa pun yang usable".

---

### `boltartifacts-startswith-and-relpath-sep` — `find_unit_for_target` membandingkan abspath backslash dengan cwd forward-slash; gate `provenance_missing` permanen inert di Windows

`silent-wrong` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`

**Evidence** — `plugins/mega-sdd/scripts/validate-bolt-artifacts.sh:985`

```python
rel_target_from_cwd = os.path.relpath(abs_target, cwd) if abs_target.startswith(cwd) else None
```

**Yang terjadi di laptop kantor.** Dua defect separator independen dalam satu baris.

1. `cwd` tiba **sudah** dinormalisasi ke forward-slash: `hooks/post-tool-use` menulis ulang `CWD="${CWD//\\//}"` dan `FILE_PATH="${FILE_PATH//\\//}"` di bawah `case "${OSTYPE:-}" in msys*|cygwin*|win32*)`, dan `resolve-project-root.sh` menerapkan normalisasi yang sama lalu berhitung murni dengan parameter expansion. Jadi `cwd = C:/Users/me/proj`. Tapi `abs_target = os.path.abspath(target_path)` di Python Windows **native** adalah `ntpath.abspath`, yang menormalisasi ke **backslash**. `.startswith('C:/Users/me/proj')` karenanya selalu False → `rel_target_from_cwd` selalu None → `find_unit_for_target` selalu `(None, None)` → Check 1 di `:1033` tidak pernah jalan.
2. Bahkan setelah `startswith` diperbaiki, blok perbandingan di `:1012-1015` tetap gagal: `os.path.relpath` mengembalikan `src\Models\User.php` sementara frontmatter unit `target_files:` mendeklarasikan POSIX `src/Models/User.php`.

File sumber yang dimodifikasi bolt **tanpa** trailer provenance `Generated by mega-sdd execute-bolts` lolos diam-diam — salah satu dari lima invariant (no fabrication / traceable bolt output) padam tanpa error di mana pun.

**Bagaimana dibuktikan.** Oracle string Windows dijalankan langsung:

```
ntpath.normpath('C:/Users/me/proj/src/Models/User.php') -> C:\Users\me\proj\src\Models\User.php
.startswith('C:/Users/me/proj')                          -> False
ntpath.relpath(...)                                      -> src\Models\User.php
```

Rantainya diverifikasi penuh, bukan hanya aritmetikanya. Dispatch-nya hidup: `hooks/post-tool-use:725` memanggil script lewat `run_validator_and_emit`, yang badannya (`:678`) adalah `bash "$validator" --cwd="$PROJECT_ROOT" --file-path="$FILE_PATH" --quiet >/dev/null 2>&1 || true` — stdout **dan** stderr dibuang, rc ditelan, jadi inertness-nya diam secara struktural. Ini bukan situs yang sudah diperbaiki: file yang sama sudah menerapkan idiom rumah `.replace(os.sep, "/")` di `:97`, `:182`, dan `:353` — `:985` justru situs yang terlewat oleh sweep `os.sep`. Dan tidak ada checker lain: `grep -rn provenance_missing` hanya mengembalikan file ini (`:5`, `:1023`, `:1042`).

**Fix sketch.** Terapkan idiom rumah yang sudah dipakai di `hooks/pre-tool-use:765` dan `scripts/build-locked-index.sh:51` — normalisasi **kedua** sisi sekali: hitung `abs_target`, lalu `rel = os.path.relpath(abs_target, cwd)` tanpa syarat, diikuti `if os.sep != "/": rel = rel.replace(os.sep, "/")`. Buang guard `startswith` sepenuhnya; tangkap `ValueError` untuk kasus lintas-drive. Tambahkan pin test yang memberi cwd forward-slash dengan abspath backslash.

---

### `xargs-word-splits-changed-paths` — path yang berubah dilewatkan `xargs` (word-split pada spasi) dan `core.quotepath=off` dihilangkan — persis dua defect yang sibling-nya dokumentasikan sudah diperbaiki

`silent-wrong` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`

**Evidence** — `plugins/mega-sdd/scripts/run-code-scan.sh:39`

```bash
if ! printf '%s\n' "$CHANGED" | xargs semgrep scan --config "$CONFIG" --json --quiet --timeout 60 >"$TMP" 2>/dev/null; then
```

**Yang terjadi di laptop kantor.** Delimiter default `xargs` adalah whitespace, bukan newline, dan ia juga menginterpretasi quote serta backslash. File bernama `src/My Component.tsx` — rutin di codebase JS/TS dan .NET, dan nyaris universal di Windows — diserahkan ke semgrep sebagai **dua argumen tak berwujud**. Baris `:31` juga membuang `-c core.quotepath=off`.

Ini situs yang terlewat, bukan kelas baru: sibling `scan-secrets-code.sh` membawa komentar S7-GATES-9 eksplisit di `:63-70` yang menyatakan path harus tiba lewat env, jangan pernah lewat argv, karena *"an unquoted $CHANGED word-split paths with spaces, and each half failed open() → the file was SILENTLY unscanned at the gate that promises never unscanned"*, dan menerapkan `git -c core.quotepath=off` di `:70`. `run-code-scan.sh` tidak punya keduanya.

**Koreksi mekanisme yang load-bearing untuk perbaikannya.** Kedua paruh gagal lewat jalur **berbeda**:

- **Paruh spasi**: `xargs` memecah → semgrep RC=2 `Invalid scanning root: src/My` → `:42` mencucinya menjadi `{"skipped": true, … "scan NOT performed"}` exit 0. Skip-nya terlihat dan tercatat di bolt-report → paruh ini sendirian hanya `degraded`.
- **Paruh non-ASCII**: **tidak pernah mencapai `xargs` atau `:42`**. Dengan quotepath default, `git diff` mengemisi literal `"src/na\303\257ve.py"`, yang gagal uji `[ -f "$f" ]` di `:31` dan **dibuang** dari `CHANGED`. Kalau itu satu-satunya file berubah, `CHANGED` menjadi kosong dan `:33` mengemisi `{"skipped": false, "reason": "no changed files", "findings": []}` — `skipped:` **FALSE**, sebuah klaim positif "sudah discan dan bersih" atas file yang baru saja dimodifikasi. Ini paruh artefak-yang-salah-secara-afirmatif dan alasan severity-nya `silent-wrong`.

**Bagaimana dibuktikan.** `printf '%s\n' 'src/My Component.tsx' | xargs bash -c 'echo argc=$#; …' _` → `argc=2` / `arg=[src/My]` / `arg=[Component.tsx]`; semgrep nyata atas argumen terpecah → RC=2, `Invalid scanning root: src/My`. Repo sekali-pakai dengan `src/naïve.py` termodifikasi: `git diff --name-only --diff-filter=ACMR` → `"src/na\303\257ve.py"`; menjalankan loop `[ -f "$f" ]` persis dari `:31` → `CHANGED` **kosong**; dengan `-c core.quotepath=off` → `src/naïve.py` dan `CHANGED` benar.

**Fix sketch.** **Kedua remedy wajib.** Membuang `xargs` menutup paruh spasi tapi **tidak** paruh quotepath; menambahkan `core.quotepath=off` menutup paruh quotepath tapi **tidak** paruh spasi. Pembaca yang hanya menambal `xargs` akan salah menyatakan kelas ini tertutup. Adopsi pola sibling secara utuh: tambahkan `-c core.quotepath=off` ke `git diff` di `:31`, buang `xargs`, dan lewatkan daftar ber-newline ke semgrep lewat environment variable atau targets file. Berhenti juga memetakan exit non-zero semgrep ke `"skipped": true` tanpa membedakan "invocation buruk" dari "tool tidak tersedia".

---

### Severity: degraded

---

### `gate-chain-unbounded-git-blocking-hook` — `git()` di `validate-bolt-artifacts.sh` tanpa timeout, dan `--recompute` menyebar `git grep` se-repo secara linear di dalam blocking PreToolUse hook

`degraded` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`, `orchestrate-flow`, `mega-sdd`

**Evidence** — `plugins/mega-sdd/scripts/validate-bolt-artifacts.sh:123`

```python
def git(*a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)
```

**Yang terjadi di laptop kantor.** Helper ini tidak punya `timeout=`, berbeda dari `scripts/_lib/dep_manifest.py:33` yang memakai `timeout=30` dengan komentar eksplisit *"git is normally fast, but this runs inside hook-invoked validators"*. Disiplinnya diterapkan di sana dan terlewat di sini — dan **di sinilah** situs yang benar-benar duduk di blocking hook: `hooks/pre-tool-use:447` menjalankan `--postflight-scan --recompute` di dalam `PreToolUse`, `async: false`, pada setiap dispatch `Skill: mega-sdd:execute-bolts`.

**Aritmetika terkoreksi** (angka finder inflated ~3,4× karena mengukur konfigurasi yang sudah gagal). Instrumentasi `find_decl_line` terhadap pohon 1.049 file repo ini:

| kondisi | spawn | wall (macOS) |
| --- | --- | --- |
| simbol **absen** (gate sudah FAILING) | 4 | 0,517 s |
| simbol **ada** (repo sehat, short-circuit) | 1 | 0,120 s |

Di repo sehat setiap SIGNATURE rule kena, jadi 30 unit × 3 rule ≈ **90 spawn (~20 detik EDR tax)**, bukan 305 spawn (~67 detik). Himpunan unitnya juga dibatasi, bukan tak terbatas: `walk_unit_commits(git, PREFIX, 300)` di `:458` membatasi `bolted` ke unit yang muncul di 300 commit terakhir.

Yang tetap nyata: kerja blocking tanpa batas yang **skalanya ikut ukuran pohon**, tanpa ceiling hook eksplisit — `hooks/hooks.json` tidak memuat string `timeout` sama sekali (0 kemunculan), jadi yang berlaku adalah default 600 detik. Limb kedua juga bertahan secara aritmetika: jalur agregat ast-grep dibatasi **hanya per rule** (`postflight_rules.py:548` `timeout=120`), jadi `units × rules × 120 s` adalah ceiling-nya di hook blocking yang sama.

**Kenapa bukan `hang`.** Tidak ada mekanisme hang sejati di term git: `grep`/`show`/`diff`/`rev-parse` semuanya lokal, non-networked, dan terminate. Cabang fail-open pada 600 detik tetap merupakan unknown yang diakui finder sendiri.

**Bagaimana dibuktikan.** PATH-shim penghitung spawn terhadap fixture git nyata (10 unit → 105 spawn; 30 unit → 305 spawn, linear) pada konfigurasi failing; lalu instrumentasi ulang `find_decl_line` yang mengoreksi angka ke konfigurasi sehat. Bound-absence dan reachability dibaca langsung.

**Fix sketch.** Beri `git()` `timeout=` (30 detik, menyamai `dep_manifest.py`) dan fail **CLOSED** pada `TimeoutExpired`, seperti yang sudah dilakukan `postflight_rules.py` untuk ast-grep. Terpisah, batasi fan-out recompute: memoise `find_decl_line` per simbol lintas unit (simbol yang sama di-grep ulang sekali per rule hari ini), dan beri seluruh pass `--recompute` anggaran agregat, bukan hanya per rule. Deklarasikan `timeout` eksplisit pada entry `PreToolUse` di `hooks.json` supaya ceiling-nya angka yang disengaja, bukan 600 detik warisan.

---

### `timeout-without-k-native-windows-child` — bound exec-probe v5.9.0 adalah `timeout 10` tanpa `-k`; GNU timeout mengirim SIGTERM lalu MENUNGGU

`degraded` · `NEEDS-WINDOWS` · skills: `install-deps`
**Corroborated by** `install-deps-timeout-no-kill`, `timeout-without-kill-after`, dan `install-deps-timeout-no-kill-fallback` — **empat finder** menemukan situs yang sama.

**Evidence** — `plugins/mega-sdd/skills/install-deps/SKILL.md:284`

> 12. NEVER run a `verify_cmd` unbounded … Bound with `timeout 10`, and treat exit 124 as `present`/`verified`, never `missing`.

`timeout <n>` muncul **tepat tiga kali** di seluruh plugin — `SKILL.md:70`, `:163`, `:284` — semuanya prosa yang diketik model, dan **tak satu pun membawa `-k`**.

**Yang terjadi di laptop kantor.** Kontrak GNU timeout: pada expiry kirim sinyal (default SIGTERM), lalu **TUNGGU** sampai child mati. `-k <dur>` yang mengeskalasi ke SIGKILL. Tool yang diprobe adalah binary Windows **native** (`semgrep.exe`, `ast-grep.exe`, `tree-sitter.exe`, `node.exe` di balik `mmdc`), dan di MSYS2/Cygwin `kill()` terhadap proses non-MSYS tidak lewat emulasi sinyal POSIX. Kalau SIGTERM tidak mendarat, bound yang **terbaca** 10 detik tidak memberikan ceiling apa pun — dan kegagalannya diam, karena exit code-nya mengklaim bound sudah menyala.

**Kenapa `degraded`, bukan `hang` — dan ini menyelesaikan perselisihan antar-finder.** Verifikasi terhadap **sumber primer** (cygwin.com `kill` docs; `git-for-windows/msys2-runtime` PR#15, PR#16, commit `c967bd8`) menunjukkan MSYS2 menangani SIGTERM ke child non-MSYS dengan menyuntikkan thread yang menjalankan `ExitProcess`, lalu **eskalasi ke `TerminateProcess` setelah ~10 detik**, sekaligus membunuh child yang ter-spawn. Jadi SIGTERM **mendarat**; worst case adalah delay ~10 detik yang terbatas, bukan hang tak terbatas. Paruh semantik GNU (tanpa `-k` → menunggu) tetap CONFIRMED dan sepenuhnya diterima oleh pembacaan `degraded` ini; tidak ada konflik nyata — **mechanism CONFIRMED, consequence degraded**.

**Sub-klaim yang dibuang, supaya tidak difile ulang.** Limb "`timeout` mungkin tidak ada / ter-shadow `C:\Windows\System32\timeout.exe`" **direfutasi**: Git for Windows 2.55.0 mengirim MSYS2 coreutils termasuk `timeout.exe` di `/usr/bin`, dan Git Bash menaruh `/usr/bin` di depan Windows PATH warisan (alasan yang sama kenapa `/usr/bin/find` menang atas `System32 find.exe`).

**Bagaimana dibuktikan (mekanisme, bukan trigger Windows).** Terhadap GNU coreutils asli:

```
timeout (GNU coreutils) 9.7
timeout 2       vs child yang mengabaikan SIGTERM -> rc=124 elapsed=30   <- bound melapor 124 tapi menunggu 30 s
timeout -k 1 2  vs child yang sama                -> rc=137 elapsed=3    <- -k yang benar-benar menghentikan
```

Busybox 1.37 mereproduksi (rc=0, elapsed=30). **Yang tidak terbukti** adalah premis Windows-nya: apakah `kill()` MSYS2 benar-benar menjangkau `.exe` native. Lihat check #3 di §4.

**Fix sketch.** Ubah ketiga situs prosa menjadi `timeout -k 2 10 <verify_cmd>` supaya expiry mengeskalasi ke SIGKILL, dan perluas peta exit code supaya 137 (SIGKILL) diperlakukan sama dengan 124 (`present` dengan catatan slow-verify, tidak pernah `missing`).

---

### `md2pdf-python3-misattributed-halt` — `md2pdf.sh` menjaga pandoc tapi tidak `python3`; PDF lane mati di dalam pandoc dan skill halt `pdf_render_failed`, menyalahkan tool yang salah

`degraded` · `CONFIRMED-LOCALLY` · skills: `emit-prd`, `emit-fsd`, `emit-sit`, `emit-uat`

**Evidence** — `plugins/mega-sdd/scripts/md2pdf.sh:78`

```bash
IN="$IN" python3 - "$WORK/doc.md" <<'PY'
```

**Yang terjadi di laptop kantor.** `pandoc` **bisa** dipasang di laptop ini (tool-matrix membawa route winget, `JohnMacFarlane.Pandoc`), jadi guard `command -v pandoc` di `:56` lolos dan eksekusi lanjut. Step (1) — transformasi frontmatter-ke-code-block — adalah `python3` telanjang tanpa guard yang menulis `$WORK/doc.md`. Tanpa `python3` yang usable ia keluar 49 dan `doc.md` tidak pernah dibuat. Script ini **tidak punya `set -e`** (`:27` hanya `set -uo pipefail`), jadi ia lanjut: probe mermaid mem-grep file yang tidak ada, lalu pandoc diserahi input yang hilang dan mati dengan backtrace uncaught-exception Haskell mentah.

Exit code-nya **1** — dan `emit-prd/SKILL.md:86` memetakan persis itu ke `halt pdf_render_failed`, sementara exit 2 adalah kode terdokumentasi untuk "pandoc absent". Jadi user di-halt dengan diagnosis yang menunjuk pandoc (yang terpasang dan baik-baik saja) plus GHC stack trace, tanpa menyebut `python3` sama sekali. Salah-atribusi ini dikuatkan kedua kalinya oleh halt taxonomy sendiri: `references/halt-protocol.md:250` mendefinisikan `pdf_render_failed` sebagai *"pandoc exited non-zero"* dan meresepkan **memasang pandoc** — satu-satunya tool yang hadir dan bekerja.

**Bagaimana dibuktikan.** Dijalankan dengan pandoc benar-benar terpasang:

```
PATH=WindowsApps:/opt/homebrew/bin:/usr/bin:/bin bash scripts/md2pdf.sh $F/doc.md $F/doc.pdf --toc
-> Python was not found; run without arguments to install from the Microsoft Store...
   grep: .../doc.md: No such file or directory
   pandoc: Uncaught exception ... withBinaryFile: does not exist
   rc=1
```

**Fix sketch.** Jaga transformasinya dengan `resolve-python.sh` dan keluar dengan kode "dependency absent" (2) yang **menyebut `python3`** — atau jadikan step (1) fence frontmatter berbasis `sed` murni sehingga PDF lane tidak punya dependensi Python sama sekali.

---

### `md2pdf-two-unbounded-chromium-launches` — dua proses headless Chromium diluncurkan tanpa timeout, di jalur Mermaid yang hard rule proyek ini bikin tak terhindarkan

`degraded` · `NEEDS-WINDOWS` · skills: `emit-prd`, `emit-fsd`, `emit-sit`, `emit-uat`

**Evidence** — `plugins/mega-sdd/scripts/md2pdf.sh:94`

```bash
if mmdc -p "$PUP" -i "$WORK/doc.md" -o "$WORK/doc-svg.md" -e svg --backgroundColor white >/dev/null 2>&1; then
```

Peluncuran kedua ada di `:123-124` (`"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf=…`). Tidak satu pun membawa ceiling.

**Yang terjadi di laptop kantor.** Peluncuran Chromium bukan satu spawn — ia mem-fork browser, GPU, zygote, network-service, dan proses renderer, semuanya di-hook CrowdStrike di ~220 ms. Terukur warm di macOS: `mmdc` pada dokumen dua diagram 2,14 detik; `chrome --print-to-pdf` pada halaman satu elemen 3,06 detik. **Aritmetika terkoreksi: ~60–80 detik per dokumen** di Windows (dua peluncuran × pengali spawn 12×), lebih buruk pada FSD 30 diagram — tapi **terminate**.

Perhatikan asimetrinya: setiap kegagalan **lain** di sini degradasi dengan anggun dan berisik (`mmdc` absen → WARN + pertahankan code block, `:100`; Chrome absen → HTML fallback exit 3, `:117`; Chrome print gagal → HTML fallback, `:128`). Ketidakhadiran dan kegagalan ditangani; **hang tidak**.

Reachability tinggi dan dimandatkan: `:89` bergate pada `grep -q '^```mermaid'`, dan proyek ini membawa hard rule dari user bahwa **setiap** process/flow yang digenerate harus Mermaid, jadi gate itu efektif selalu benar untuk PRD/FSD/SIT/UAT (`emit-fsd:136`, `emit-prd:86`, `emit-sit:95`, `emit-uat:99`).

**Satu mekanisme yang direfutasi total, jangan difile ulang.** Klaim bahwa puppeteer tanpa `executablePath` akan mencoba **mengunduh** Chromium saat launch dan menggantung di balik proxy TLS: sejak Puppeteer v19 browser diambil oleh langkah postinstall saat `npm install`, bukan lazily saat launch. mermaid-cli 11.x mengirim Puppeteer 23.x, yang `launch()`-nya **melempar** seketika saat browser tidak ditemukan. Unduhan yang di-blackhole proxy akan menggagalkan `npm install -g @mermaid-js/mermaid-cli`, sehingga `mmdc` tidak akan ada di PATH sama sekali dan `:90` mengambil cabang WARN. **Tidak ada runtime download branch untuk macet.** Mekanisme (b) — Chrome yang dikelola korporat macet pada `--headless=new` — murni spekulasi tanpa bukti.

**Bagaimana dibuktikan.** Kedua peluncuran di-time secara lokal dengan bentuk invocation persis dari script. Bound-absence dibaca: `grep -n timeout scripts/md2pdf.sh` tidak menghasilkan hit di `:94` atau `:123`. Bandingkan `scripts/verify-mermaid.sh:117`, yang **membatasi** node oracle-nya dengan `timeout=90` — disiplinnya ada di keluarga mermaid dan tidak diterapkan ke dua peluncuran Chromium.

**Fix sketch.** Bungkus kedua peluncuran dengan ceiling eksplisit (`mmdc` ~120 detik, Chrome ~60 detik) dan rutekan timeout ke **jalur graceful yang sama** yang sudah diambil kasus absent — WARN + pertahankan code block untuk `mmdc`, HTML fallback untuk Chrome — supaya renderer yang macet berdegradasi persis seperti yang hilang.

---

### `semgrep-timeout-is-per-rule-per-file` — `--timeout 60` adalah limit per-rule-per-file semgrep, 12× lebih longgar dari default-nya sendiri, dengan semua output ditelan

`degraded` · `CONFIRMED-LOCALLY` · skills: `execute-bolts`
Terkait tapi **terpisah** dari `semgrep-config-auto-network-unbounded` di bawah: yang ini terkonfirmasi lokal dan **platform-agnostic**; yang itu `NEEDS-WINDOWS` dan unreachable hari ini.

**Evidence** — `plugins/mega-sdd/scripts/run-code-scan.sh:39` (baris yang sama dengan temuan `xargs`)

```bash
if ! printf '%s\n' "$CHANGED" | xargs semgrep scan --config "$CONFIG" --json --quiet --timeout 60 >"$TMP" 2>/dev/null; then
```

**Yang terjadi di laptop kantor.** Flag-nya terbaca seperti safety bound padahal bukan. Help semgrep 1.166.0 sendiri: `--timeout=DOUBLE (absent=5.)  Maximum time to spend running a rule on a single file in seconds.` Jadi `--timeout 60` tidak membatasi run pada 60 detik — ia **menaikkan** ceiling per-rule-per-file dari 5 detik ke 60 detik, yaitu **12× lebih permisif dari default**. Tidak ada wrapper `timeout`, tidak ada `--max-memory`, tidak ada wall-clock limit di mana pun pada invocation itu.

Default pendamping `--timeout-threshold=3` membuat worst-case per file 3 × 60 = 180 detik; bolt yang menyentuh ~20 file berubah berbatas ~3.600 detik (~60 menit) versus ~300 detik (~5 menit) pada default semgrep. Ini **worst-case bound, bukan runtime terukur**. Semua progress dan error dibuang oleh `>"$TMP" 2>/dev/null`, jadi user tidak melihat apa pun.

**Kenapa `degraded`, bukan `hang`.** Angka ~3.600 detik tidak pernah diobservasi, dan dibatasi dua hal: script ini hanya jalan lewat Bash tool Claude Code yang punya wall clock sendiri, dan cabang TLS korporat membuat fetch registry **gagal** alih-alih jalan lama. Perhatikan pula defect-nya **tidak Windows-spesifik**: semantik timeout semgrep identik di macOS, dan baik EDR tax ~220 ms maupun divergensi bash 5.3 tidak ada di rantai kausalnya.

**Bagaimana dibuktikan.** Semantik otoritatif diambil dari tool-nya sendiri, dijalankan lokal: `semgrep --version` → `1.166.0`; help mengonfirmasi `--timeout=DOUBLE (absent=5.)` dan `--timeout-threshold=INT (absent=3)`. Wiring gate dari `skills/execute-bolts/references/code-gates.md:23` (`| 4 | SAST | scripts/run-code-scan.sh | semgrep | SKIP (note) |`).

**Fix sketch.** Bungkus invocation dengan wall-clock bound sungguhan berikut kill-after (`timeout -k 15 300 semgrep …`, dengan caveat Git Bash pada temuan `timeout` di atas), turunkan `--timeout 60` kembali ke default atau lebih rendah, dan berhenti membuang stderr — tangkap ke field `reason` pada skip supaya stall bisa didiagnosis alih-alih tak terlihat.

---

### `semgrep-config-auto-network-unbounded` — `--config auto` adalah fetch jaringan ke registry semgrep tanpa wall-clock bound; kegagalan tool ditangani anggun, hang tidak

`degraded` · `NEEDS-WINDOWS` · skills: `execute-bolts`
**Unreachable di seluruh armada terukur hari ini** — latent, bukan menyala.

**Evidence** — `plugins/mega-sdd/scripts/run-code-scan.sh:39`, dengan `:14` `CONFIG="auto"` sebagai default.

**Yang terjadi di laptop kantor.** Reachability caveat lebih dulu, dinyatakan jujur: `:26` short-circuit ke skip anggun saat `command -v semgrep` gagal, dan semgrep berbasis Python — `tool-matrix.yaml` merutekan `os: windows-bash` **eksklusif** lewat `pipx install semgrep` dengan catatan *"Windows route via pipx (Python-based; no winget/scoop semgrep pkg)"*. Oracle menyatakan tidak ada Python sama sekali dan Store diblokir, jadi baris 39 **tidak dieksekusi di satu pun mesin armada terukur**; `:26` keluar lebih dulu, dengan alasan yang terlihat.

Kalau rantai `interpreter → pipx → semgrep` pernah lengkap: `--config auto` bukan ruleset lokal, ia me-resolve rule dari registry semgrep lewat jaringan, dan tidak ada yang membatasi itu. `--timeout 60` tidak menolong (lihat temuan sebelumnya). Di balik proxy TLS-inspecting Bank Mega — inspeksi yang sama yang permanen merusak source msstore winget — handshake yang di-blackhole **stall** alih-alih menolak. Agravasi kecil: `xargs` tanpa `-n` bisa memecah set file besar menjadi beberapa invocation semgrep, masing-masing me-resolve ulang `--config auto` dan membayar round trip registry lagi.

**Bagaimana dibuktikan.** Tidak bisa dikonfirmasi dari kotak ini: semgrep tidak terpasang, dan failure mode-nya spesifik pada proxy TLS korporat yang tidak ada di mesin dev. Pembacaan kode menetapkan bentuknya (`:14`, `:26`, `:39`, `:40-43`). Lihat check #5 di §4.

**Fix sketch.** Default-kan `CONFIG` ke ruleset lokal yang di-vendor (atau `p/default` yang di-fetch sekali lalu di-cache) alih-alih `auto`, tambahkan `--metrics=off` dan wrapper wall-clock eksplisit di seluruh pipeline, dan rutekan expiry wall-clock ke cabang `skipped:true` yang **sama** dengan yang diambil kegagalan, supaya registry yang macet berdegradasi persis seperti yang offline. Tambahkan `-n 100` ke `xargs` supaya config di-resolve sejumlah terbatas kali.

---

### `full-suite-inherited-stdin-no-timeout` — `run-full-suite.sh` menjalankan seluruh test suite tanpa wall-clock bound; sibling writer-nya menjaga keduanya

`degraded` · `NEEDS-WINDOWS` · skills: `execute-bolts`, `orchestrate-flow`, `mega-sdd`

**Evidence** — `plugins/mega-sdd/scripts/run-full-suite.sh:196`

```bash
( cd "$CWD" && eval "$RUNNER" ) >"$LOG_FILE" 2>&1
```

**Yang terjadi di laptop kantor.** Bukti barisnya benar verbatim dan guard sibling-nya nyata: `scripts/run-acceptance-tests.sh:29` mendokumentasikan kontraknya (*"`</dev/null`, bounded timeout (default 120s, `--timeout=<sec>`), cwd=project root"*) dan mengimplementasikannya di `:175`/`:187` dengan `stdin=subprocess.DEVNULL` + `timeout=timeout_s`. `run-full-suite.sh`, yang ditulis untuk keluarga gate yang sama, tidak mewarisi satu pun.

**Mekanisme PRIMER-nya direfutasi, dan ini penting.** Claude Code **tidak** menyerahkan descriptor yang blocking ke Bash tool — ia menyerahkan `/dev/null`. Terukur di tool ini sendiri: `fstat(0)` rdev = `0x3000002`, dan `os.fstat(0).st_rdev == os.stat('/dev/null').st_rdev` → True; `( read -r X )` telanjang kembali seketika dengan nilai kosong alih-alih blocking. Jadi `npm test` yang bertanya, `npx … Ok to proceed?`, dan jest watch semuanya mendapat EOF seketika, persis seperti yang akan diberikan `</dev/null`. Proof finder hanya "hang" karena mereka menyuplai stdin blocking mereka sendiri.

**Limb yang bertahan** lebih lemah tapi nyata: **benar-benar tidak ada wall-clock bound** di `:196`, jadi runner yang deadlock karena alasan **non-stdin** (socket listening yang diblokir EDR, child yang macet) tidak pernah kembali — dan doktrin repo sendiri di `postflight_rules.py:540-545` menyebut kerja tanpa ceiling di jalur yang ditunggu Claude Code sebagai bentuk hang 2026-07-28. Reachability-nya model-invoked: `execute-bolts SKILL.md` dan `hooks/pre-tool-use:519` menyuruh agent menjalankan script ini untuk melewati gate B2, dan flag `--runner=` (`:35`) melebarkan permukaan ke command string apa pun dari operator.

**Fix sketch.** Tambahkan `</dev/null` di `:196` (murah, dan menyamakan kontrak dengan sibling walau harness sudah memberi `/dev/null`) dan bungkus runner dengan ceiling ber-`--suite-timeout` eksplisit (default longgar, mis. 1800 detik), mencatat status `timeout` yang diperlakukan sebagai RED, tidak pernah green. Jangan biarkan bound menghasilkan artefak B2 yang lulus — suite yang tidak selesai belum terbukti hijau.

---

### `run-hook-dispatcher-tax` — `run-hook.sh` membayar 4 spawn proses yang bisa dihindari pada setiap hook fire

`degraded` · `CONFIRMED-LOCALLY` · skills: `ALL`

**Evidence** — `plugins/mega-sdd/hooks/run-hook.sh:20`

```bash
SCRIPT_DIR="$(cd "$(dirname "$self")" && pwd)"
```

**Yang terjadi di laptop kantor.** Setiap dispatch hook membayar, sebelum kerja apa pun terjadi: satu exec `dirname`, subshell command-substitution `$(cd … && pwd)`, dan di `:35` `case "$(uname -s 2>/dev/null || echo "")"` — subshell kedua plus exec `uname`.

**Aritmetika terkoreksi.** Oracle mendefinisikan ~220 ms sebagai biaya **satu** iterasi `$(dirname …)` (11,0 s / 50), yang **sudah** membundel fork subshell MSYS2 **dan** exec-nya. Menghitung fork dan exec sebagai dua event 220 ms terpisah adalah double-counting terhadap unit oracle sendiri. Tax realistis: `$(dirname)` ~220 ms + `$(cd && pwd)` fork-only (builtin, tanpa exec) ~110–220 ms + `$(uname -s || echo)` ~220 ms = **~550–660 ms**, bukan 880 ms. Terhadap biaya badan hook terukur (2 external exec ≈ 440 ms), rasio sebenarnya **~1,25–1,5×** — jadi judul asli "twice what the hook body costs" **tidak benar**.

Permukaan blocking-nya nyata: `PostToolUse`, `Stop`, dan `SubagentStop` `async: true` sehingga tax-nya bukan latency yang dirasakan user, tapi `PreToolUse` (matcher `Skill|Bash|Edit|Write`), `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, dan `PreCompact` semuanya `async: false` — setiap prompt dan sebagian besar tool call membayarnya secara sinkron.

Keempat spawn bisa dihapus **tanpa perubahan perilaku**: `${self%/*}` menggantikan `dirname`+`cd`+`pwd`, dan probe `uname` hanya ada untuk menjaga cabang yang tidak bisa dieksekusi — tidak ada file `.ps1` yang dikirim di `hooks/` (`ls hooks/*.ps1` → tidak ada match) dan PowerShell diblokir kebijakan.

**Bagaimana dibuktikan.** PATH shim wrapper penghitung exec, mendispatch hook no-op: `sort $SPAWN_TALLY | uniq -c` → `2 bash / 1 dirname / 1 uname` (`pwd` dan `cd` benar tidak terhitung sebagai builtin; `bash` kedua adalah hook yang didispatch di `:44`, yaitu kerja, bukan tax). `hooks.json` diparse (bukan di-grep) untuk memastikan pembagian async.

**Fix sketch.** Set `SCRIPT_DIR` dengan parameter expansion memakai pola slash-guard yang sudah disahkan repo ini di `hooks/post-tool-use` (`case "$0" in */*) SC_DIR="${0%/*}" ;; *) SC_DIR="." ;; esac`), dan **hapus** probe `uname` bersama cabang powershell yang unreachable alih-alih menukarnya dengan `$OSTYPE` — `$OSTYPE` bernilai `msys` di Git Bash dan **tidak** akan cocok dengan token `MINGW*|MSYS*|CYGWIN*` yang ada, sehingga substitusi naif diam-diam mengubah cabang mana yang match. Menghapus membuang keempat spawn; menukar hanya membuang tiga dan berisiko mengubah perilaku.

---

### `predictive-checks-bare-python3` — katalog predictive-checks menyuruh model menjalankan enam `python3 -c` telanjang, melewati guard stub WindowsApps milik plugin sendiri

`degraded` · `CONFIRMED-LOCALLY` · skills: `orchestrate-flow`, `diff-vault`, `resolve-oq`, `execute-bolts`, `memory`

**Evidence** — `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md:177`

> command: `python3 -c "import json; v=json.load(open('<vault-path>/vault.json')); print(sum(1 for oq in v.get('open_questions', []) if oq.get('status') != 'resolved'))"` · expected: non-zero count · on_fail: "All OQs in vault are already resolved. resolve-oq is a no-op."

Defect yang sama di `:154` (`vault_version_parseable`, `fatal: yes`), `:170`, `:227` (`units_depends_on_dag_acyclic`, `fatal: yes`), `:234`, `:320`. Dikonsumsi per `SKILL.md:60`.

**Yang terjadi di laptop kantor.** `python3` resolve ke AppExecLink 0-byte, jadi keenam command menghasilkan stdout **KOSONG** dan exit non-zero, untuk vault yang benar-benar sehat.

**Efek pasti yang dominan** adalah dua check `fatal: yes` (`:154`, `:227`) yang salah mengemisi `predictive_check_failed` dan **MENGHENTIKAN seluruh chain** pada vault sehat, menyalahkan *"current vault.json malformed"* dan *"Cycle detected in unit depends_on graph"*. Kerja terblokir dengan alasan salah.

**Framing yang dikoreksi.** Klaim "moat terbuka diam-diam" di anchor `:177` **tidak bertahan**: `chain-execution.md` §Predictive preflight loop mendefinisikan `fatal: no` sebagai *"accumulate warning (surface to user before chain start)"* — ia **tidak** membuang skill dari chain, jadi `resolve-oq` tetap jalan dan OQ tak terselesaikan tetap muncul lewat skill-nya sendiri. Moat anti-fabrication (binding CONFLICT gate, execute-bolts gates, recomputed B1 postflight) ditegakkan oleh script di tempat lain, bukan oleh katalog preflight ini. Tidak ada artefak salah yang dihasilkan → `degraded`, bukan `silent-wrong`.

Sub-klaim yang bertahan: `on_fail` di `:170` menyerahkan saran destruktif dari false negative — *"Regenerate vault via generate-intent --refresh"* — dan `--refresh` **bukan flag `generate-intent`** (hanya ada di `generate-units`), jadi remedy-nya pun tak bisa dipanggil. Catat juga bahwa command `:227` adalah "skeleton" yang mencetak `ok` tanpa syarat, sehingga verdict dunia-nyatanya ganda-tak-bermakna.

**Bagaimana dibuktikan.** `grep -c 'python3 -c'` → 6; `grep -c 'resolve-python|mega_sdd_python|MEGA_SDD_PY'` di file yang sama → 0. Repro dengan shim stub terhadap vault berisi 2 OQ terbuka + 1 resolved: interpreter nyata → `rc=0 stdout=[2]`; stub → `rc=49 stdout=[]`; `command -v python3` → rc=0 untuk stub.

**Fix sketch.** Ganti keenam command string dengan bentuk sourced-resolver yang sudah dipakai di `install-deps/SKILL.md:83` — `bash -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/_lib/resolve-python.sh" && mega_sdd_python && $MEGA_SDD_PY -c "…"'` — dan tambahkan rail tingkat-katalog bahwa exit non-zero dari resolver berarti **SKIP check dengan warning**, tidak pernah diperlakukan sebagai kondisi yang dicek itu gagal. Perbaiki juga `:172` ke flag yang benar-benar ada.

---

### `crlf-frontmatter-prose-gate` — gate prosa memakai `grep -q '^---$'`, yang tidak bisa mencocokkan fence frontmatter CRLF dan false-fail Wave-3 gate

`degraded` · `CONFIRMED-LOCALLY` · skills: `extract-intelligence`

**Evidence** — `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md:297`

```bash
head -1 "$f" | grep -q '^---$' || { echo "MISSING frontmatter in $f"; GATE=1; }
```

**Yang terjadi di laptop kantor.** Anchor `$` mengikat setelah karakter terakhir pada baris, dan dengan CRLF karakter itu adalah `\r`, bukan `-`. File domain knowledge-base mana pun yang baris pertamanya `---\r\n` karenanya melaporkan `MISSING frontmatter` dan menyetel `GATE=1` padahal frontmatter-nya hadir dan well-formed. Model lalu menghentikan Wave 3 atau men-dispatch ulang agent untuk "memperbaiki" frontmatter yang sudah benar.

**Reachability-nya independen dari `crlf-no-gitattributes`** — ini file KB di repo **user**, jadi CRLF datang dari checkout Windows mana pun atau dari pengetikan manual, bukan hanya dari clone plugin cache.

**Bagaimana dibuktikan.** Diverifikasi pada **kedua** grep, termasuk yang benar-benar relevan (GNU, yaitu Git Bash):

```
printf -- '---\r\ntitle: x\r\n---\r\n' > crlf.md
head -1 crlf.md | grep -q '^---$'                       -> NO-MATCH (BSD, macOS)
docker run --rm bash:5.3 … head -1 /crlf.md | grep -q "^---$"  -> NO-MATCH (GNU)
```

**Dua koreksi terhadap klaim pendukung**, yang tidak mengubah verdict tapi wajib dibawa:

1. Sitasi `validate-pack.sh:200` sebagai "contoh yang benar" berada **di dalam komentar** — implementasi hidupnya dikonversi ke bash builtin pada speedup pack-lint v4.60.0. Jadi "plugin sudah benar di tempat lain" **belum terbukti**, dan situs itu sendiri mungkin perlu dicek.
2. **Jebakan pada fix sketch-nya:** remedy `grep -qE '^---[[:space:]]*$'` **match di GNU grep tapi TIDAK di macOS BSD grep** (terukur pada keduanya). Remedy-nya benar untuk deployment target, tapi **regression test yang ditulis di mesin dev akan gagal** — pin test ke pola dengan `\r` eksplisit, atau jalankan di bawah GNU grep.

**Fix sketch.** Ubah polanya ke `grep -qE '^---[[:space:]]*$'` dengan caveat test di atas. Memperbaiki `.gitattributes` root (temuan `crlf-no-gitattributes`) menghilangkan trigger-nya, tapi baris ini tetap harus toleran karena user bisa menulis file KB secara manual di Windows.

---

### `tooling-install-windows-matrix-false` — platform matrix memberi tahu tim bahwa script/validator Git Bash bekerja dan WSL adalah jalur Windows yang direkomendasikan — satu klaim salah, satunya diblokir kebijakan

`degraded` · `CONFIRMED-LOCALLY` · skills: `install-deps`, `ALL`

**Evidence** — `plugins/mega-sdd/references/tooling-install.md:13`

> | **Windows + Git Bash (MINGW)** | ✅ | ✅ *if a USABLE interpreter resolves* — `resolve-python.sh` walks `python3` → `python` → `py -3` … | ✅ same condition | …

**Yang terjadi di laptop kantor.** Sel "Scripts/validators ✅ same condition" **salah secara faktual**, dan ini kalimat yang dibaca team lead sebelum rollout. Ladder `resolve-python.sh` dikonsumsi tepat tiga file di seluruh plugin; 91 script men-spawn nama literal `python3`, jadi "a usable interpreter resolves" **tidak** berarti script lane bekerja: di route winget ia me-resolve `python` dan setiap validator tetap keluar 49.

Verifikasi menemukan temuan ini bahkan **undersold**: baris yang sama juga menyatakan *"Moat enforcement ✅ even WITHOUT python3"*, yang dibuktikan salah di state C oleh `pretooluse-failclosed-wrong-discriminator`. Jadi halaman ini membawa jaminan palsu tentang **security control**, bukan sekadar galat tabel kapabilitas.

Dua defect pendukung di halaman yang sama: `:12` melabeli **Windows + WSL** *"Full support — the recommended Windows path"*, dan WSL diblokir kebijakan perusahaan ini — jadi rekomendasi utama halaman itu unreachable; `:90` memagari seluruh blok install Windows sebagai ```` ```powershell ````, dan tiga command pertamanya adalah route scoop yang bootstrap-nya menurut tool-matrix sendiri butuh PowerShell. User di kotak tanpa PowerShell diarahkan ke dua jalan buntu dan satu jaminan palsu sebelum mencapai baris winget di `:98-99` — satu-satunya yang benar-benar bisa mereka jalankan.

**Bagaimana dibuktikan.** Ketiga string tersitasi diverifikasi verbatim. Falsifikasi sel scripts/validators di state C: `bash -c '. scripts/_lib/resolve-python.sh && mega_sdd_python'` → rc=0 (me-resolve `python`), sementara `derive-state.sh` → rc=49 tanpa `state.json` dan `validate-preflight.sh` → rc=49.

**Fix sketch.** Koreksi baris Git-Bash supaya menyatakan script/validator membutuhkan **nama literal `python3`** (❌ sampai script mengadopsi `$MEGA_SDD_PY`), turunkan baris WSL dengan catatan "blocked on locked-down corporate images", dan pagari ulang `:90` sebagai ```` ```bash ```` dengan command winget lebih dulu.

---

### `kb-freshness-hash-fanout` — preflight freshness KB `generate-intent` meng-hash setiap file sumber legacy satu spawn per file

`degraded` · `CONFIRMED-LOCALLY` · skills: `generate-intent`, `extract-intelligence`

**Evidence** — `plugins/mega-sdd/skills/generate-intent/references/kb-submode.md:26`

> 2. For each `<repo-relative-path>` in the map, compute the current sha256 of that file in the legacy source codebase.

**Yang terjadi di laptop kantor.** Mekanisme hashing tak-terbatch yang sama dengan invalidation gate `scan-codebase`. Header section-nya berbunyi *"KB freshness preflight (advisory, OPT-IN)"* (`:21`), tapi **tidak ada flag yang menggate-nya** — tidak ada toggle freshness di tabel flag `SKILL.md`, dan `SKILL.md:48` mencantumkan freshness preflight sebagai bagian prosedur Mode B. Trigger-nya `:1` "If the snapshot exists" — dan `extract-intelligence` Step 5.5 **selalu** menulis snapshot itu — jadi pada rantai biasa `extract-intelligence → generate-intent --kb` ia berjalan tanpa syarat. Kata "OPT-IN" itu **basi dan menyesatkan secara material** tentang kapan biaya itu dibayar. Step 4 juga eksplisit "DO NOT halt", jadi ini biaya menit-menit untuk check yang tidak pernah menghentikan apa pun.

**Aritmetika terkoreksi — jangan bawa angka finder.** N **bukan** "seluruh legacy codebase". `shared-snapshot-schema.md:114` mendefinisikan map sebagai *"every source file consumed by the extraction waves (captured at extraction time)"*, dan enumerasi yang diandalkan finder bersifat **agregat saja**: `wave-dispatch-templates.md:187-188` membuat Wave 0 mengenumerasi *"top-level dirs, file types, total file count, total size, language breakdown"* ke `.scan-meta.json` — hitungan dan breakdown, bukan daftar path per-file. `:313` justru memandatkan kebalikan dari full walk: *"Provide explicit file lists in the dispatch prompt, not read all .php in /workflow/"*. Jadi N adalah gabungan sitasi `_source:` lintas wave berskop — realistis **ratusan rendah** di repo legacy 2.000 file, yaitu **~44–110 detik**, bukan 440 detik / 7,3 menit.

**Bagaimana dibuktikan.** Pencarian flag mengonfirmasi tidak ada opt-in toggle. Aritmetika fork memakai pengukuran per-file vs batched 158× dari `shallow-scan-hash-fanout`. Kelayakan batching: `shasum -a 256 /tmp/_a /tmp/_b` → dua digest, satu proses.

**Fix sketch.** Batch komputasi hash menjadi satu invocation atas daftar key map, sama dengan perbaikan gate `scan-codebase`. Koreksi header "OPT-IN" supaya mencerminkan bahwa ia berjalan kapan pun snapshot ada — atau tambahkan flag opt-in sungguhan yang sudah dijanjikan header itu, supaya check advisory yang tidak pernah halt tidak diam-diam memakan waktu menit.

---

### `extracted-kb-snapshot-hash-fanout` — `extract-intelligence` menulis snapshot freshness KB dengan meng-hash setiap file sumber satu spawn per file

`degraded` · `CONFIRMED-LOCALLY` · skills: `extract-intelligence`, `generate-intent`

**Evidence** — `plugins/mega-sdd/skills/extract-intelligence/SKILL.md:213`

```
2. Compute current sha256 for each source file.
```

**Yang terjadi di laptop kantor.** Ini **paruh writer** dari mekanisme tak-terbatch yang sama: Step 5.5 (`:211-227`) mengumpulkan *"every source file enumerated during waves 1-4"* di `:212` dan membangun `source_files_sha256_map` di `:213`, satu spawn per file, tanpa instruksi batching — cocok dengan paruh reader di `kb-submode.md`. Reachability-nya tanpa syarat (Step 5.5 berjalan setelah Wave 5 pada setiap ekstraksi).

Yang paling tajam dari temuan ini: **himpunan file identik di-hash dua kali** dalam satu rantai `extract → generate-intent --kb` — sekali oleh writer, sekali oleh reader.

Tim sudah mengenali biaya ini persis satu file di sebelahnya: `shared-snapshot-schema.md:66`/`:105` mendokumentasikan bahwa `source_files_sha256_map` ditulis **KOSONG** untuk tipe `codebase-map` justru karena itu write-only cost, sementara tetap terisi untuk `extracted-kb` karena *"its generate-intent freshness check reads it, path-by-path"*. Jadi penghapusan **tidak tersedia** di sini dan batching adalah remedy yang benar — tapi batching tidak pernah diterapkan.

**Aritmetika terkoreksi.** Sama seperti paruh reader: N adalah gabungan sitasi `_source:`, ratusan rendah, **~44–110 detik**, bukan 440 detik. Angka "~14,6 menit total fork tax" untuk rantai `extract → generate-intent --kb` karenanya **~2–5× terlalu tinggi**.

**Bagaimana dibuktikan.** Pembacaan langsung blok Step 5.5 dan sitasi kontras di `shared-snapshot-schema.md`. Pencarian prosedur hash-batching yang bisa dipakai ulang: `grep -rn 'shasum|sha256sum'` di seluruh plugin hanya menemukan `tests/state/test-certify-artifact.sh` dan `diff-vault/references/diff-procedure.md:18` (single-file) — **tidak ada** prosedur batched yang bisa direferensikan.

**Fix sketch.** Batch hash menjadi satu invocation atas daftar path terkumpul saat membangun `source_files_sha256_map`, dan **nyatakan batching itu eksplisit di step-nya** supaya model tidak mengemisi loop. Pertimbangkan agar kedua paruh berbagi satu prosedur batched-hash terdokumentasi, karena writer dan reader meng-hash himpunan yang sama.

---

### Severity: cosmetic

---

### `treesitter-ref-unbounded-invocation-prose` — `tree-sitter-integration.md` mendokumentasikan invocation per-file dengan tabel "murah" dan tanpa spawn bound

`cosmetic` · `CONFIRMED-LOCALLY` · skills: `scan-codebase`

**Evidence** — `plugins/mega-sdd/skills/scan-codebase/references/tree-sitter-integration.md:81`

```
tree-sitter query queries/tags-<lang>.scm <file> --captures
```

**Yang terjadi di laptop kantor.** Spawn-cost gate ditambahkan ke `references/scan-procedure.md` — reference yang **berbeda**. File ini, di bawah heading `## Invocation / For each detected language in the repo`, tidak punya cross-reference ke gate dan tidak punya estimasi `N × per_spawn`. Pembaca kemudian menemui `:126` *"| Tree-sitter | ~2-5s (incremental, sub-ms per file) | ~50MB peak |"* dan `:129` *"Tree-sitter is FASTER on typical repos AND more precise"* — keduanya salah di laptop kantor dengan faktor ~220×.

**Kenapa hanya `cosmetic`, bukan hang.** Premis "model memuat file ini dan mendapat loop tanpa gate" **salah**. Progressive disclosure memuat reference **sebagai tambahan** atas `SKILL.md` induknya, tidak pernah menggantikan — dan `scan-codebase/SKILL.md:52` membawa gate lengkapnya **inline** di induk yang selalu resident: *"tree-sitter invokes one process per FILE while regex/ripgrep invokes one per LANGUAGE, a ~1000x difference … ~220 ms/spawn measured: a 2,000-file repo is ~7.3 min … Estimate N × per_spawn before extracting and, above 60 s, ASK before proceeding."* Gate itu diulang ketiga kalinya di `halts-flags-handoff.md:28`. Jadi gate wajibnya **ada dalam konteks** kapan pun `:81` ada.

Ini persis asimetri yang membuat temuan pagerank bertahan dan yang ini tidak: `generate-units/SKILL.md:83` tidak punya bahasa spawn sama sekali; `scan-codebase/SKILL.md:52` punya semuanya. Yang tersisa adalah **tabel performa basi yang mengontradiksi induknya sendiri** ~220×.

**Bagaimana dibuktikan.** Gate-absence di file ini dikonfirmasi ulang dengan regex yang benar-benar bekerja (grep finder aslinya vacuous — alternasi BRE tanpa `-E`): `grep -nE 'spawn|220|0\.22|per_spawn|process per'` → nol hit. Sitasi `:129` (bukan `:130`) dikoreksi.

**Fix sketch.** Tambahkan satu baris forward reference di `:81` — "BOUNDED: run the Spawn-cost gate in `scan-procedure.md` before this loop; this is one process per FILE" — dan buat tabel performa `:126` OS-conditional (POSIX ~sub-ms/file; windows-bash ~220 ms/file di bawah endpoint security), supaya tidak ada pembaca file ini sendirian yang bisa menyimpulkan loop-nya murah.

---

### `verify-mermaid-command-v-python3` — `verify-mermaid.sh` memprobe `python3` dengan `command -v` dan membangun SKIP JSON-nya dengan `python3`

`cosmetic` · `CONFIRMED-LOCALLY` · skills: `extract-intelligence`, `generate-intent`

**Evidence** — `plugins/mega-sdd/scripts/verify-mermaid.sh:54`

```bash
command -v python3 >/dev/null 2>&1 || emit_skip "python3 not found — opt-in render check skipped (heuristic gate still applies)"
```

**Yang terjadi di laptop kantor.** Stub memenuhi `command -v`, jadi cabang SKIP yang dimaksudkan tidak pernah menyala — dan bahkan kalaupun menyala, `emit_skip` di `:45` membangun JSON-nya dengan `python3 -c`, sehingga escape hatch-nya sendiri rusak. Eksekusi lanjut ke kerja `python3` sungguhan dan script keluar **2** — kode ERROR — alih-alih 0 yang dijanjikan header-nya sendiri (`:20` *"Exit: 0 = PASS/SKIP"*) dan `references/mermaid-emission-rules.md:28`, serta meninggalkan `.mega-sdd/.mermaid-render-state.json` sepanjang 1 byte.

**Kenapa `cosmetic`.** Blast radius terbatas dan diverifikasi ulang secara independen: ini script CI/on-demand opt-in tanpa caller otomatis di pipeline, dan grep se-repo **tidak menemukan konsumen** `.mermaid-render-state.json`, jadi artefak kosongnya inert. Dicantumkan karena ini **instans `command -v python3` terakhir yang tersisa** di pohon — kelas defect yang sama dengan dua bypass gate di atas, duduk di kode yang kebetulan belum penting.

**Bagaimana dibuktikan.** State stub → stderr `Python was not found…`, **rc=2**; `wc -c` state file → 1 (finder menyebut 0; terukur 1, tidak material). Baseline macOS → `{"status":"PASS","checked_file":"t.md","block_count":1,…}` rc=0.

**Fix sketch.** Ganti probe `command -v python3` dengan `mega_sdd_python` dari `resolve-python.sh`, dan buat `emit_skip` membangun JSON-nya dengan `printf` alih-alih `python3` supaya jalur SKIP tidak punya dependensi interpreter.

---

### `chain-execution-dep-remedy-missed-v531` — envelope halt `predictive_check_failed` hanya menyodorkan brew/cargo/npm, tanpa pointer `/mega-sdd:install-deps`

`cosmetic` · `CONFIRMED-LOCALLY` · skills: `orchestrate-flow`, `scan-codebase`, `emit-fsd`

**Evidence** — `plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md:159`

> next_action: "Install tree-sitter (brew install tree-sitter OR cargo install tree-sitter-cli OR npm install -g tree-sitter-cli) then re-run. Alternatively, run scan-codebase with --engine=regex flag to bypass tree-sitter."

**Yang terjadi di laptop kantor.** Dari tiga route install-nya, `brew` tidak ada di Windows sama sekali, `cargo` butuh toolchain Rust yang tidak dibawa image, dan `npm` satu-satunya yang mungkin bekerja — tidak ada yang menyebut winget atau scoop, dan berbeda dari 17 file lain yang membawanya, file ini menghilangkan escape hatch `/mega-sdd:install-deps` sepenuhnya. Rilis v5.3.1 menyapu baris remedy itu ke sepuluh consumer skill justru supaya tidak ada pesan dep-gap yang menelantarkan user; file ini terlewat.

**Kenapa `cosmetic`, bukan degraded — empat alasan independen.**

1. Ini **bukan** template remedy hidup: `:159` berada di dalam fence ```` ```yaml ```` yang baris pertamanya komentar `# Example predictive_check_failed envelope:` — ia mengilustrasikan **bentuk** envelope untuk pembaca.
2. Envelope yang digambarkannya **tidak pernah bisa diemisi seperti tertulis**: check yang dipakainya, `tree_sitter_present`, bersifat `fatal: no` (`predictive-checks.md:65`), dan `chain-execution.md` sendiri menyatakan `fatal: no` mengakumulasi WARNING sementara hanya `fatal: yes` yang mengemisi `predictive_check_failed`.
3. `on_fail` otoritatif untuk check yang sama **sudah** membawa route yang hilang itu: `predictive-checks.md:62` berakhir dengan *"— OR run `/mega-sdd:install-deps` for auto-install"*.
4. Bahkan diambil apa adanya, string itu berakhir dengan escape hatch yang hidup dan bekerja di baris yang sama — *"run scan-codebase with --engine=regex flag to bypass tree-sitter"* — jadi tidak ada user Windows yang telantar dengan "dua command mati".

**Yang bertahan** adalah co-site `emit-fsd`: `skills/emit-fsd/SKILL.md:142` adalah emisi yang benar-benar hidup (`md2pdf.sh` exit 2 → pandoc absent) yang teksnya macOS-only, *"Run: brew install pandoc"*, padahal file yang sama tahu pointer install-deps untuk `mmdc` di `:48`. Itu miss doc-hygiene nyata, tapi pada baris log warn-and-continue di jalur fallback yang sudah diterima, di mana `FSD.md` sudah lengkap.

**Bagaimana dibuktikan.** `grep -c 'install-deps' chain-execution.md` → 0; `grep -n 'install-deps' skills/emit-fsd/SKILL.md` → hanya `:48`. Pembacaan refutasi pada `:155-161`, `:140-152`, dan `predictive-checks.md:58-66`.

**Fix sketch.** Tambahkan klausa remedy standar ke `emit-fsd/SKILL.md:142` — "— or run `/mega-sdd:install-deps` for auto-install" — menyamai `predictive-checks.md:62` verbatim, dan buang atau kualifikasi `brew`/`cargo` sebagai macOS/Rust-only. Lebih baik lagi: buat kedua situs mensitasi `references/tooling-install.md` sebagai pemilik tunggal route install alih-alih meng-inline salinan keempat.

---

## What only the office laptop can settle

Enam temuan bertag `NEEDS-WINDOWS` dan satu open lead bergantung pada mekanisme yang **tidak bisa direproduksi dari macOS**. Berikut satu script Git Bash yang dijalankan sekali. **Tidak ada PowerShell di mana pun.** Jalankan di Git Bash, di dalam project mega-sdd, lalu kirim balik seluruh output.

```bash
#!/usr/bin/env bash
# mega-sdd Windows portability discriminators — run ONCE in Git Bash.
# Copy-paste the whole block. Send back the entire output.
echo "=== mega-sdd windows discriminators — $(date) ==="

echo; echo "--- CHECK 1: Python state (settles state B vs state C) ---"
command -v python3 || echo "  python3: NOT on PATH"
python3 -V 2>&1 | head -1
command -v python  || echo "  python: NOT on PATH"
python  -V 2>&1 | head -1
command -v py || echo "  py: NOT on PATH"

echo; echo "--- CHECK 2: CRLF in the plugin cache (crlf-no-gitattributes) ---"
for d in ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/; do
  echo "  cache: $d"
  git -C "$d" config --get core.autocrlf || echo "    core.autocrlf: (unset)"
  file "$d/plugins/mega-sdd/hooks/run-hook.sh" 2>/dev/null || \
    file "$d/hooks/run-hook.sh" 2>/dev/null
done

echo; echo "--- CHECK 3: timeout binary + SIGTERM delivery to a native .exe ---"
type -a timeout
timeout --version 2>&1 | head -1
echo "  timing 'timeout 3 cmd //c ping -n 30 127.0.0.1' ..."
time timeout 3 cmd //c "ping -n 30 127.0.0.1 >nul"; echo "  rc=$?"

echo; echo "--- CHECK 4: mmdc launch (md2pdf-two-unbounded-chromium-launches) ---"
if command -v mmdc >/dev/null 2>&1; then
  printf '```mermaid\ngraph TD; A-->B;\n```\n' > /tmp/_ms_test.md
  time mmdc -i /tmp/_ms_test.md -o /tmp/_ms_test.svg >/dev/null 2>&1; echo "  rc=$?"
else
  echo "  mmdc absent — check not applicable"
fi

echo; echo "--- CHECK 5: semgrep registry fetch (semgrep-config-auto-network-unbounded) ---"
if command -v semgrep >/dev/null 2>&1; then
  echo 'var x = 1;' > /tmp/_ms_test.js
  time semgrep scan --config auto --json --quiet --timeout 60 /tmp/_ms_test.js >/dev/null 2>&1
  echo "  rc=$?"
else
  echo "  semgrep absent — expected on this fleet; check not applicable"
fi

echo; echo "--- CHECK 6: B1 recompute gate wall time (gate-chain-unbounded-git-blocking-hook) ---"
if [ -d .mega-sdd ]; then
  time bash "$CLAUDE_PLUGIN_ROOT/scripts/validate-bolt-artifacts.sh" \
       --cwd="$PWD" --postflight-scan --recompute --quiet; echo "  rc=$?"
else
  echo "  not inside a mega-sdd project — skip"
fi

echo; echo "--- CHECK 7: OPEN LEAD (not a filed finding) — MSYS path conversion ---"
cd ~ && FOO="$(pwd)" python -c "import os; d=os.environ['FOO']; print(d, os.path.isdir(d))" 2>&1

echo; echo "=== done ==="
```

Arti tiap hasil:

| # | hasil | artinya |
| --- | --- | --- |
| 1 | `python3` ada tapi `python3 -V` menulis "Python was not found" / exit 49 | stub WindowsApps. Kalau `python -V` mencetak versi asli → **state C**, temuan `session-start-halfpython-setE-abort` dan `pretooluse-failclosed-wrong-discriminator` **menyala**. Kalau keduanya stub → **state B**. |
| 2 | `core.autocrlf` = `true` **atau** `file` menyebut `with CRLF line terminators` | `crlf-no-gitattributes` **hidup di laptop itu** — prioritas tertinggi, tidak ada yang jalan. `false`/`input` + `ASCII text` → tidak menyala di sini, tetap laten untuk laptop baru. |
| 3 | `timeout` resolve ke `/usr/bin/timeout` **dan** kembali ~3 detik dengan `rc=124` | bound `timeout 10` nyata; batas SIGTERM ke child native bekerja. Berjalan mendekati 30 detik → SIGTERM tidak mendarat, ketiga situs prosa butuh `timeout -k 2 10`. Kalau `timeout` justru `/c/Windows/System32/timeout.exe` → bound-nya inoperatif (walau ini dianggap tidak mungkin). |
| 4 | `mmdc` tidak kembali dalam ~60 detik | ada stall renderer nyata. Kembali dalam beberapa detik → biaya normal, konsisten dengan pembacaan `degraded`. |
| 5 | tidak kembali dalam ~120 detik | terblokir pada fetch registry, dan `--timeout 60` terbukti tidak membatasi run. Umumnya check ini tidak berlaku (tidak ada semgrep tanpa Python). |
| 6 | wall time dan apakah dispatch `/mega-sdd:execute-bolts` tetap lanjut setelah hook stall | menjawab cabang fail-open pada ceiling 600 detik yang masih terbuka. |
| 7 | mencetak `False` | seluruh kelas `--cwd="$(pwd)"` (11 situs prosa) **hidup** dan harus difile sebagai temuan baru: setiap command kelas `/mega-sdd:analyze` diam-diam men-scan nol file. `True` → konversi MSYS2 memitigasinya. |

---

## Refuted

Empat temuan mati saat refutation; jangan difile ulang.

| id | kenapa mati |
| --- | --- |
| `fixwindowspath-dollar0-backslash` | Seluruh mekanismenya adalah cabang `*)` di `scripts/fix-windows-path.sh:40`, dan cabang itu **unreachable di setiap call site**. 27 dari 27 referensi `${CLAUDE_PLUGIN_ROOT}` di `skills/`, `commands/`, `agents/`, `hooks.json` langsung diikuti `/` literal yang diketik di markdown, 0 diikuti `\`. Worst case adalah path campuran yang tetap match `*/*`. |
| `scriptdir-dollar0-not-normalized` | Mati pada premis yang sama, dua kali. Bentuk `$0` yang diklaim tidak pernah terjadi (call site menulis `/` literal), dan bahkan jika `cd` gagal, `cd … 2>/dev/null && pwd` short-circuit sehingga `SCRIPT_DIR` menjadi **KOSONG** (`/_lib/…`), bukan `.`. Rantai konsekuensinya butuh `cd .`. Fakta lapangan menguatkan: dua laptop kantor bekerja di v5.9.0 — kalau `SCRIPT_DIR` kolaps untuk 44 script, praktis tidak ada yang resolve. |
| `scoop-only-remedy-unreachable` | Tidak ada verdict yang dikembalikan — dibuang menurut evidence rule. |
| `pkg-mgr-halt-remedy-routes-to-wsl` | Halt yang membawa teks itu **tidak bisa menyala** di target: `halt-protocol.md:196` mensyaratkan `PKG_MGR=none`, dan winget **hadir serta usable** di image ini (inspeksi TLS hanya merusak **source** msstore, alasan remedy yang di-ship memakai `--source winget`). Refutasi kedua yang independen: "(Windows native)" adalah istilah teknis yang didefinisikan plugin di `os-detection.md:135` sebagai *"no WSL, no git-bash"*, sedangkan tim ini **di Git Bash** — jadi cabang itu secara konstruksi tidak menyasar mereka. |

**Sub-klaim yang gugur saat verifikasi** — ini yang paling mungkin difile ulang, jadi dicatat eksplisit:

- **Puppeteer runtime-download branch** (`md2pdf-two-unbounded-chromium-launches`): sejak v19 browser diambil saat `npm install` postinstall; `launch()` melempar, tidak mengunduh. Tidak ada network wait untuk dimasuki.
- **Limb "`timeout` mungkin absen / ter-shadow System32"**: Git for Windows mengirim `/usr/bin/timeout.exe` dan menaruh `/usr/bin` di depan Windows PATH.
- **"Kedua arm moat terbuka hari ini"** (`upe-command-v-python3-route-pick`): `PreToolUse` **masih menolak** di state B. Konsekuensi dua-arm butuh state C.
- **`chain-execution.md:159` sebagai template remedy hidup**: ia di dalam fence `# Example … envelope:` dan menggambarkan halt yang check `fatal: no`-nya tidak bisa sebabkan.
- **"Plugin sudah benar di tempat lain" pada `validate-pack.sh:200`**: pola `[[:space:]]` yang disitasi ada **di dalam komentar**; implementasi hidupnya dikonversi ke bash builtin di v4.60.0.

**Satu sub-klaim yang masih TERBUKA di bawah id yang direfutasi** — jangan hilang: refuter `fixwindowspath-dollar0-backslash` secara eksplisit **tidak** membersihkan ini. Glob bootstrap bash-only di `scripts/fix-windows-path.sh:110-113` hanya memprobe `$_home/AppData/Local/Programs/Python/Python3*` dan `/c/Python3*`, sementara `resolve-python.sh:116` (`mega_sdd_python_remedy`) mengarahkan user Windows ke scoop (*"di Windows pilih route scoop (`scoop install python`), satu-satunya package manager yang menghasilkan perintah `python3` berfungsi"*), yang meng-install ke `~/scoop/apps/python/current` — tidak ada di daftar itu. Ini defect terpisah yang butuh temuannya sendiri.

---

## Coverage and limits

### Yang disapu

| hazard class | cakupan |
| --- | --- |
| `hang` | Grep-first di seluruh pohon plugin lalu baca situs hit. `subprocess.(run\|Popen\|check_output\|call\|check_call)` se-repo → 17 call site, 6 unbounded, keenamnya diperiksa. Setiap token `timeout` di `*.py`/`*.sh`/hooks. Tool eksternal berat per nama (semgrep, ast-grep, tree-sitter, gitleaks, pandoc, mmdc, npx/npm, uv, ripgrep). Loop prosa per-file. Loop `while .*read`. `git log`. Panggilan jaringan (`urlopen`, `curl`, `wget`, `requests`). |
| `spawn` | `find … -exec cmd {} \;` (NOL hit se-pohon). Prosa per-file/per-item. Prosa hash sha256 per-file. `symbol-graph`, `precision_tier`, `Last_Scanned_Sha256`. Empiris: PATH shim 38 wrapper penghitung exec terhadap `run-hook.sh`, `post-tool-use` on-project, `certify-artifact.sh`; per-file vs batched sha256 atas 2.000 file. |
| `paths` | `case "$VAR" in */…)` glob; `[ -x ]` pada file yang di-ship (`git ls-files -s` → 101×100755, 17×100644, tak satu pun dari 17 pernah diuji `[ -x ]`); symlink (`^120000` → nol); MAX_PATH (worst case 154 char); nama device reserved; `cd` ke path berspasi; `mktemp`/`/tmp`; write-then-rename (25 situs, semua `tmp + os.replace`). Verifikasi lewat `ntpath` sebagai oracle string Windows. |
| `toolchain` | 238 baris grep `python3` / 191 baris invocation di 92 file, disilangkan dengan `grep -rln MEGA_SDD_PY` (3 file). 24 situs `command -v <tool>` di `scripts/` + `hooks/`. Semua hit powershell/pwsh/wsl + `find . -name '*.ps1'`. 10 tool id `tool-matrix.yaml` dilacak ke situs invocation dan prosa konsumen exit code-nya. Metode: harness stub AppExecLink + dua layout PATH (state B dan C). |
| `shell` | Divergensi bash 3.2 vs 5.3 disapu **statis dan empiris**: 102 file ber-`set -u` di-grep untuk setiap konstruk divergen, lalu **differential run** 85 `scripts/*.sh` + 8 hook di bawah bash 5.3 (docker, `env -i`) versus bash 3.2 macOS, mencari `unbound variable` / `bad substitution`. Nol hit di kedua sisi; harness divalidasi dengan canary yang sengaja rusak. Bentuk coreutils MSYS (`sed -i`, `date`, `stat`, `grep -P`, `base64 -w`, `find -printf`, `sort`, `mktemp`, `xargs`, `realpath`). Encoding: audit CRLF se-repo + simulasi checkout `autocrlf=true` dieksekusi di bawah bash 5.3 asli. |
| `prose` | Instruction plane (SKILL.md, `references/*.md`, `agents/*.md`, `commands/*.md`) disapu untuk: pipeline `| head`; `python3 -c`/`-m`; asumsi `~/`; `/tmp`/`mktemp`; `timeout`; WSL/PowerShell; "for each file"/"per source file"; flag yang tidak ada di MSYS; ambang skala numerik (`100k`, `50k`, `>N files`); probe jaringan (`ping -`, `curl -`); string remedy package manager. |

### Sensus scale-bound (skill mana yang punya batas numerik)

- **BOUNDED**: `scan-codebase` (spawn-cost gate + `>100k files` + `--force-large`), `generate-units` (`>50k` → `--skip-pagerank`, tapi terkalibrasi macOS), `detect-drift` (`>10k files`, advisory lunak), `extract-intelligence` (`--max-parallel`, hard cap 8), `execute-bolts` (batch/fan-out cap).
- **UNBOUNDED tapi dinilai non-hazardous** karena operasi terberatnya berskala dengan jumlah **artefak** (vault doc, claim, OQ, unit), bukan ukuran repo, sehingga tidak mengalikan spawn tax 220 ms: `analyze`, `diff-vault`, `emit-agents-md`, `emit-fsd`, `emit-prd`, `emit-sit`, `emit-uat`, `generate-intent`, `graph`, `install-deps`, `memory`, `resolve-oq`, `using-mega-sdd`.

### Yang TIDAK dibaca

- **24 `plugins/mega-sdd/references/*.md`, 31 `commands/*.md`, dan 8 `agents/*.md` tidak dibaca utuh** — hanya baris yang kena grep plus konteks sekitarnya. `agents/*.md` di-skim untuk prosa berbentuk eksekusi: hanya dua hit, keduanya non-executing.
- **111 `skills/*/references/*.md` tidak dibaca ujung ke ujung.** Disapu dengan grep bertarget (semua fenced block bash/sh/shell plus command ber-backtick) dan hanya situs hit yang dibaca. **Prosa yang mendeskripsikan perilaku shell secara naratif dalam bahasa Indonesia tanpa code fence akan terlewat oleh sweep itu.**
- Pohon `tests/` tidak dibaca kecuali untuk menemukan fixture builder. `skills/scan-codebase/references/deep-scan-prompts.md` hanya dilihat pada satu baris hit. Pack konvensi framework di `references/framework-conventions/` tidak diaudit.
- `scripts/_lib/*.py` hanya diperiksa untuk encoding/BOM dan penggunaan `subprocess` timeout, **bukan** untuk portabilitas tingkat Python.
- **BOM: tidak ada penanganan BOM sama sekali di plugin** (setiap reader membuka dengan `encoding="utf-8"`, tidak pernah `utf-8-sig`), dan BOM akan membuat `md.startswith("---")` gagal sehingga frontmatter batal diam-diam. Tidak ada temuan diajukan karena sumber BOM realistis tidak bisa ditegakkan (PowerShell diblokir; Notepad default tanpa BOM sejak 2019; dokumen vault digenerate plugin). Layak dicek kalau ada yang mengingest dokumen turunan Excel/CSV.
- Codepage `cmd` / mojibake pada output Indonesia dan emoji: tidak bisa diuji dari macOS, tidak ada temuan diajukan.

### Open leads untuk follow-up

1. **Kelas `--cwd="$(pwd)"`** (11 situs prosa: `commands/analyze.md:68`, `analyze-parallelism.md:19`, `lint-units.md:25`, `list-modules.md:19`, `migrate-paths.md:29/52`, `replay.md:19`, `skills/analyze/SKILL.md:24`, `wave-dispatch-templates.md:264/437/454`). Ia menyerahkan bentuk MSYS `/c/Users/me/proj` ke Python Windows native lewat env var; terbukti lokal bahwa `ntpath.normpath(ntpath.join('/c/Users/me/proj','.mega-sdd'))` → `\c\Users\me\proj\.mega-sdd`, di-resolve terhadap drive saat ini. Kalau konversi MSYS2 tidak berlaku, setiap command kelas `/mega-sdd:analyze` diam-diam men-scan **nol file** dan validator melaporkan project bersih. Tidak ada `cygpath` maupun `pwd -W` di seluruh repo. Ini **check bernilai tertinggi** — check #7 di §4.
2. **Script per-unit `execute-bolts` belum pernah diukur di bawah spawn shim** (`run-preflight-scan.sh`, `check-anchor-freshness.sh`, `run-postflight-scan.sh`, `run-acceptance-tests.sh`). `execute-bolts SKILL.md:58/59/73/86` memanggilnya **sekali per unit**, jadi `N_units × internal_spawns` adalah pengali nyata yang belum terukur.
3. **`bind-codebase` tidak punya batas numerik di mana pun**, sementara kedua tetangga chain-nya punya. Operasi terberatnya adalah verifikasi anchor per-claim plus subagent phase-advisor yang disuruh mem-Grep `codebase-map` on-disk penuh; dikalkulasi ~1 spawn per claim (~200 claim ≈ 44 detik) dan disimpulkan degraded-at-worst, jadi sengaja tidak difile. Dikonfirmasi bahwa `bind-codebase` **tidak** menjalankan ulang tree-sitter (`implementation-state.md:48`), yang justru akan membuatnya hang.

### Batasan yang harus dinyatakan terus terang

**Tidak ada mesin Windows yang tersedia selama audit ini.** Setiap item bertag `NEEDS-WINDOWS` — `crlf-no-gitattributes`, `timeout-without-k-native-windows-child`, `md2pdf-two-unbounded-chromium-launches`, `semgrep-config-auto-network-unbounded`, `full-suite-inherited-stdin-no-timeout` — **belum terbukti**. Yang terbukti untuk item-item itu adalah mekanismenya (lewat docker bash 5.3, GNU coreutils asli, dan `ntpath` sebagai oracle string Windows), **bukan** trigger-nya di laptop yang sebenarnya.

Semua angka wall-clock Windows adalah **proyeksi**: fork count diukur dan bersifat platform-invariant, timing-nya macOS, dan pengali 0,22 detik/spawn diambil dari oracle deployment (terukur 2026-07-28). Temuan bertag `CONFIRMED-LOCALLY` berarti mekanisme dan reachability-nya dibuktikan di mesin dev, bukan bahwa konsekuensinya diobservasi di laptop kantor.

Terakhir: satu pengukuran dari sweep `shell` **tidak valid dan tidak disitasi di mana pun** — loop CRLF per-hook awal menangkap `$?` setelah `| head -4`, sehingga nilai `EXIT=0`-nya mencerminkan `head`, bukan hook. Temuan `crlf-no-gitattributes` bersandar pada pengukuran bersih `bash hooks/run-hook.sh pre-tool-use >/dev/null 2>&1; echo $?` → 2 dan pada teks stderr-nya.

---

## Addendum — dua hal yang diverifikasi orchestrator di luar sweep

Ditambahkan setelah refutation pass. Keduanya dieksekusi, bukan disimpulkan.

### A. `crlf-no-gitattributes`: satu dari dua mata rantai sekarang tertutup

Temuan itu bertumpu pada asumsi environmental *"`git clone` ke plugin cache benar-benar
menghasilkan CRLF"*. Setengah dari asumsi itu kini terbukti di mesin dev:

| langkah | perintah | hasil |
| --- | --- | --- |
| jalur install **adalah** git clone | `git -C ~/.claude/plugins/marketplaces/mega-sdd remote -v` | `origin https://github.com/FarhanRiuzaki/Mega-SDD.git` — `.git/` ada; `cache/mega-sdd/<versi>/` diturunkan dari sini |
| clone tidak meng-override apa pun | `git -C … config --get core.autocrlf` | **unset** → mewarisi config global/system mesin |
| repo tidak meng-override apa pun | `find . -name .gitattributes` | kosong |

Jadi rantainya tinggal satu variabel: nilai `core.autocrlf` global di laptop itu. Tidak ada
lapisan lain di antaranya. Check #2 di §4 menyelesaikannya.

Efek CRLF juga direproduksi independen di bash 3.2 (macOS), bukan hanya bash 5.3, dengan
tiga kerusakan berbeda dari satu file: `set -u\r` → `set: -: invalid option`;
`case "$1" in\r` → syntax error; dan terminator heredoc `PYEOF\r` tidak pernah cocok dengan
`<<'PYEOF'`. Yang terakhir relevan karena plugin ini punya **124 heredoc di 87 file**.

### B. Kenapa `preflight-astgrep-unbounded-twin` selamat dari v5.10.0 — test-nya buta

Ini koreksi atas pekerjaan sendiri, bukan temuan finder. `tests/hooks/bounded-subprocess.test.sh`
ditulis di v5.10.0 justru untuk mencegah kelas ini, dan sejak itu selalu hijau. Alasannya:

```
tests/hooks/bounded-subprocess.test.sh:38   glob.glob(os.path.join(lib, "*.py"))
```

Matcher-nya hanya menyapu `scripts/_lib/*.py`. Seluruh Python yang tertanam sebagai heredoc di
dalam `scripts/*.sh` tidak pernah diparse. Hitungan sebenarnya:

```
subprocess.run( di scripts/*.sh          : 13
tanpa timeout= pada baris yang sama      : 12
```

Dua belas situs, termasuk `run-preflight-scan.sh:225` yang jadi temuan `hang` di atas.
Sisanya sebagian besar `git` (cepat dalam praktik) — kecuali
`run-acceptance-tests.sh:175` dan `:187`, yang menjalankan **perintah test milik user**
(`shell=True`) tanpa ceiling; itu layak dinilai terpisah.

Pelajarannya sejajar dengan `no silent caps`: sebuah guard yang cakupannya lebih sempit dari
kelas yang diklaimnya dijaga akan **melaporkan hijau selamanya**. Perbaikan test harus
mendahului atau menyertai perbaikan `run-preflight-scan.sh`, kalau tidak situs berikutnya lolos
dengan cara yang sama.

Angka-angka di bagian ini: `wc`/`grep` atas tree v5.11.0 pada 2026-07-29.
