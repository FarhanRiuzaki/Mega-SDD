# PRD — Company Profile Mini

**Versi:** 1.0 · **Status:** FINAL · **Tanggal:** 2026-09-10 · **Sumber:** rekonstruksi skenario feedback tim (Igoo0, 2026-08-23: "3 screen statis") untuk baseline v8 P0. Ini fixture pengukuran, bukan produk nyata.

## Latar belakang

Sebuah unit kerja butuh halaman profil publik yang sederhana: siapa mereka, apa layanannya, dan cara menghubungi. Tidak ada login, tidak ada dashboard, tidak ada integrasi eksternal. Tujuannya satu — pengunjung bisa membaca profil dan mengirim pesan.

## Tujuan

- Pengunjung membaca profil dan daftar layanan dalam satu kunjungan.
- Pengunjung bisa mengirim pesan lewat form kontak; pesan tersimpan agar bisa dibaca admin lewat database (tidak ada UI admin di rilis ini).

## Ruang lingkup

Tiga halaman publik + satu form. Di luar lingkup: autentikasi, panel admin, notifikasi email, multi-bahasa, CMS.

## Halaman Beranda

Judul organisasi, tagline satu kalimat, ringkasan tiga layanan utama (judul + satu paragraf per layanan, konten statis dari file konfigurasi), tombol menuju halaman Kontak. Responsif di 375px dan desktop.

## Halaman Tentang Kami

Profil singkat (dua–tiga paragraf statis), daftar tim (nama + peran, statis dari konfigurasi, tanpa foto), dan tautan kembali ke Beranda.

## Halaman Kontak

Form dengan field: nama (wajib, ≤100 karakter), email (wajib, format email valid), pesan (wajib, ≤2000 karakter). Saat dikirim: validasi sisi server, simpan ke tabel `contact_messages`, tampilkan pesan sukses di halaman yang sama. Gagal validasi → tampilkan error per field, isi form tidak hilang.

## Data model

```dbml
Table contact_messages {
  id integer [pk]
  name varchar(100) [not null]
  email varchar(255) [not null]
  message text [not null]
  created_at timestamp [not null]
}
```

## Alur

### F-U-001: Kirim pesan kontak

1. Pengunjung membuka Halaman Kontak.
2. Mengisi nama, email, pesan → klik Kirim.
3. Server memvalidasi tiga field.
4. Valid → simpan `contact_messages` → tampilkan "Pesan terkirim".
5. Tidak valid → tampilkan error per field, form tetap terisi.

**Definition of Done**
- [ ] Pesan valid tersimpan dengan `created_at`.
- [ ] Email tidak valid ditolak dengan pesan error di field email.
- [ ] Form tetap terisi setelah gagal validasi.

## Non-functional

| Kategori | Requirement |
|---|---|
| Performa | Halaman statis termuat < 2 detik di koneksi 3G. |
| Aksesibilitas | Semua field form berlabel; navigasi keyboard berfungsi. |
| Keamanan | Input form di-escape saat ditampilkan; tidak ada HTML mentah dari pengunjung. |

## Open questions

- Tidak ada — PRD FINAL. Konten statis (nama organisasi, layanan, tim) diambil dari file konfigurasi placeholder; isi final diganti tim sendiri.
