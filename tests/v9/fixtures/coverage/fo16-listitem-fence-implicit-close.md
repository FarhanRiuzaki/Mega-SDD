# PRD: Transfer

## §3. Transfer API
1. Client mengirim request:
   ```json
   {"amount": 150000, "client_ref": "abc"}
2. Server membalas `200 OK` beserta `trx_id`.

## §4. Transfer Terjadwal
Transfer terjadwal WAJIB dieksekusi pukul 00:05 WIB.

## §5. Idempotensi
Request dengan client_ref yang sama dalam 24 jam HARUS ditolak.

## §6. Kode Error
```
E01 Saldo tidak cukup
```
