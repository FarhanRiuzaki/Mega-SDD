# PRD: Dompet Digital

## Top-up
Nasabah top-up saldo dari rekening bank atau virtual account.

Contoh request:

```bash
curl -X POST https://api.example.id/v1/topup \
  -d '{"amount": 50000, "source": "VA"}'

## Scheduled Transfers
Nasabah memilih tanggal, nominal dan rekening tujuan; transfer dieksekusi pukul 00:05 WIB pada tanggal itu.
Jika saldo kurang, transfer ditandai gagal dan nasabah menerima notifikasi.

## Withdrawal
Nasabah menarik saldo ke rekening bank terdaftar. Biaya Rp2.500 per penarikan, maksimal Rp10.000.000 per hari.

## Notifications
Contoh payload push:

```
{"title": "Top-up berhasil", "body": "Saldo bertambah Rp50.000"}
```

Contoh payload SMS:

```json
{"to": "+62812...", "text": "Top-up berhasil"}
```
