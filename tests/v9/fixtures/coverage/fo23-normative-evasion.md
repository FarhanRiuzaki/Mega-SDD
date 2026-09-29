# PRD: Mobile Banking

## 1. Ruang Lingkup
Transfer BI-FAST antar bank. Nasabah diwajibkan verifikasi OTP untuk nominal di atas Rp25.000.000.

## 2. Transfer
Nasabah dapat transfer BI-FAST. Limit harian MUST be Rp50.000.000.

## 3. Context
Per POJK 11/2022 the app MUST NOT store the full card PAN, and a session SHALL NOT outlive 5 minutes of inactivity.

## 4. Goals
Nasabah dapat membuat target tabungan (goal) dengan nominal dan tanggal target; autodebet mingguan MUST run every Monday 06:00 (TBC with Ops?)

## 5. Out of Scope
### 5.1 Transfer Valas
Tidak di v1.
### 5.2 Biaya Tarik Tunai Bank Lain
Tarik tunai di ATM bank lain dikenakan biaya Rp7.500 dan nasabah diharuskan menyetujui biaya di layar.
