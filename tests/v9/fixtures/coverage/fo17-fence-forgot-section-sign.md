# PRD — Transfer Dana

## §1. Transfer Antar Rekening
Nasabah dapat transfer ke rekening sesama bank.

Contoh request:
```json
{ "amount": 150000, "to": "1234567890" }

## §2. Transfer Terjadwal
Transfer terjadwal WAJIB dieksekusi pukul 00:05 WIB dan HARUS gagal-aman bila saldo kurang.

## §3. Limit Harian
Limit harian MUST be Rp50.000.000 per nasabah.

## §4. Notifikasi
Setiap debit memicu push notification. Contoh payload:
```
{ "type": "DEBIT", "amount": 150000 }
```
