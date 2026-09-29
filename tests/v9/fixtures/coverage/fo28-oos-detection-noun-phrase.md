# PRD: Asisten Virtual "Sahabat" — Mobile Banking

## 1. Latar Belakang
Call center menerima 40.000 pertanyaan per bulan; 60% di antaranya pertanyaan saldo dan mutasi.

## 2. Intent Perbankan

### 2.1 Cek Saldo
Pengguna menanyakan saldo; asisten WAJIB meminta PIN sebelum menampilkan saldo.

### 2.2 Riwayat Transaksi
Asisten menampilkan 10 transaksi terakhir; pengguna dapat meminta periode lain hingga 90 hari.

## 3. Out-of-Scope (OOS) Detection
Asisten WAJIB mengenali ucapan di luar layanan perbankan dan tidak pernah menjawabnya dengan tebakan.

### 3.1 Ambang Keyakinan
Ucapan dengan confidence intent di bawah 0,60 diklasifikasikan sebagai OOS.

### 3.2 Balasan Fallback
Asisten membalas dengan templat fallback dan menawarkan tiga intent terpopuler sebagai tombol.

### 3.3 Eskalasi ke Live Agent
Setelah dua ucapan OOS berturut-turut dalam satu sesi, percakapan dialihkan ke live agent (08.00–20.00 WIB).

### 3.4 Logging untuk Retraining
Setiap ucapan OOS disimpan dengan nomor rekening dan NIK dimasking, untuk bahan retraining mingguan.

## 4. Notifikasi Proaktif
Asisten mengirim pengingat tagihan H-3 sebelum jatuh tempo.
