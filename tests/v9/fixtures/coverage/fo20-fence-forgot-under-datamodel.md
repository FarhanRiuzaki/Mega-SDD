# PRD: Tabungan Berjangka

## §1. Pembukaan Rekening
Nasabah membuka tabungan berjangka dari aplikasi.

## §2. Data Model
```dbml
Table account { id int [pk] }

## §3. Autodebet Bulanan
Autodebet WAJIB dijalankan tanggal 1 setiap bulan.

## §4. Pencairan
Pencairan sebelum jatuh tempo HARUS dikenai penalti 1%.

## §5. Notifikasi
Contoh payload:
```
{"type":"AUTODEBET_OK"}
```
