# Security & Operations Baseline

- Wajibkan MFA untuk role instructor, academic, admin, finance, executive, dan superadmin.
- Review akses staf setiap bulan dan nonaktifkan akun keluar maksimal 24 jam.
- Jangan mencatat token, kata sandi, bukti transfer, atau service key ke log aplikasi.
- Rotasi token WhatsApp, Resend, dan service role sesuai kebijakan insiden serta pergantian personel.
- Simpan bukti pembayaran maksimal sesuai kebutuhan pembukuan dan hukum; hapus melalui prosedur terkontrol.
- Aktifkan backup Supabase, lakukan restore drill berkala, dan dokumentasikan RPO/RTO.
- Pantau kegagalan fungsi, lonjakan autentikasi, perubahan role, verifikasi pembayaran, dan penerbitan sertifikat.
- Audit log harus bersifat append-only untuk staf biasa. Hanya superadmin yang menangani koreksi melalui prosedur resmi.
- Sebelum setiap rilis: jalankan `npm run check`, uji RLS lintas role, tes fungsi pada staging, lalu smoke test produksi.
- Insiden: batasi akses, rotasi kredensial, simpan bukti, nilai dampak, beri notifikasi sesuai hukum, dan lakukan post-incident review.
