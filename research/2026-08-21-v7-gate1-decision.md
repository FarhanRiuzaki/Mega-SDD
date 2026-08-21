# GATE Fase 1 (desain) — APPROVED, dengan 4 catatan

Desain diterima. Dua rail (model-side tanpa klausa CWD-invoke + hook-side marker) memang yang bikin tabel S/M/L jadi mekanisme. Jawaban risiko R1–R4 lalu catatan yang harus masuk sebelum implementasi.

## Jawaban R1–R4

- **[R1] Marker `chain_engaged` di `.gateguard-state.json`, ditulis PreToolUse Skill branch** — SETUJU. Koreksi lo benar: cursor ditulis tiap turn jadi tidak bermakna. Satu tambahan: `chain_engaged` cukup session-keyed, tidak perlu di-clear saat chain selesai (sesi yang sudah pakai pipeline boleh tetap ter-gate sampai sesi habis; sesi baru mulai un-armed).
- **[R2] Subagent session_id** — SETUJU verifikasi empiris + fallback OR (`.plan-pending` ATAU `agent_transcript_path` di stdin). Tulis hasil verifikasinya di research note, jangan cuma di komentar hook.
- **[R3] Jendela un-gated pasca-hotfix** — residual risk DITERIMA. Jaring pengaman yang gue pegang: FP_GUARD state-path always-on + re-derivation gate-time saat chain berikutnya masuk + full re-bind memang mendeteksi drift di file LOCKED. Catat ini eksplisit di CHANGELOG 7.0.0 sebagai perubahan perilaku.
- **[R4] `lanjut` lintas sesi** — SETUJU: factory-ledger ada + prompt kontinuasi → tawarkan `/mega-sdd --resume` satu baris, jangan auto-invoke.

## Catatan wajib sebelum implementasi

1. **Tier M harus dua langkah, ownership check-nya mekanis.** Tabel §1 bilang M = "menyebut entity/flow milik vault DAN minta perubahan spec". Model tidak tahu isi vault saat baca anchor — kalau dia harus "merasa" itu entity vault, kita balik ke prose-judgment yang tadi lo bilang tidak reliabel. Jadikan: (a) anchor hanya mengenali **keyword perubahan fitur/spec** ("tambah field", "ubah flow", "fitur baru", "ganti validasi", dsb.) → route ke front door; (b) front door Lane 1.3 yang sudah ada melakukan ownership check mekanis (grep `vault.json` — bukan 00-index, sesuai keputusan Fase 3) → match → lane M; **tidak match → turun ke S** dengan tawaran satu baris, bukan ASK. Ambiguitas multi-vault tetap ASK seperti sekarang.

2. **Session-start masih bayar ±22–26 spawn + C1 self-resolve yang menulis `vault.json` tanpa diminta.** Fase 1 boleh biarkan (scope fence lo jelas), tapi masuk ke daftar Fase 2 eksplisit: pindahkan blok C1 self-resolve 9-guard ke `ground.sh` (entry front door = saat user memang masuk pipeline), sehingga session-start hanya: install-front-door (debounced) + derive-state untuk satu baris notice + inject anchor. Session-start tidak boleh menulis artifact vault.

3. **Bukti after harus terukur, bukan hanya trace statis.** Setelah implementasi: jalankan hook harness dengan stdin Edit tier S di fixture project ter-adopsi dan hitung spawn nyata (`strace -f -e execve` / counter di run-hook.sh debug mode) — target 0 python spawn PreToolUse untuk path biasa, dan jumlah fork PostToolUse ≤ 2. Tempel angkanya di research note + test yang mengunci angka itu (tier-S no-gate test lo sudah ada di daftar; tambah assertion spawn count).

4. **Hard rule baru di anchor harus punya bentuk negatif eksplisit.** Selain "berlaku untuk M/L saja", tulis satu kalimat larangan: "Tier S: JANGAN invoke skill `mega-sdd:*`, JANGAN buka `/mega-sdd`, JANGAN propose sync." Audit lo menunjukkan kalimat positif kalah dari kalimat imperatif lain; larangan eksplisit lebih tahan buldoser.

## Hal kecil

- `--weight=S` di front door: OK sebagai escape hatch; jangan bikin alias lain.
- Bump 7.0.0 di commit Fase 1, CHANGELOG tumbuh di Fase 2/3 — OK.
- Tests: sweep KEDUA tree + `.github/workflows`, seperti Fase 0.
- Satu commit untuk model-side (anchor/front door/session-start) dan satu untuk hook-side — supaya bisa di-bisect kalau ada regresi di kantor.

Lanjut implementasi Fase 1. Berhenti lagi di akhir dengan: trace after (statis + spawn terukur), daftar file berubah, hasil test kedua tree.
