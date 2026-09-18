# Deployment Produksi KLI — Netlify + Supabase

## 1. Supabase

1. Buat proyek staging, kemudian proyek production terpisah.
2. Jalankan migrasi secara berurutan:
   1. `001_core.sql`
   2. `002_assessment_engine.sql`
   3. `003_production_hardening.sql`
   4. `004_academic_assessment.sql`
   5. `005_original_stimuli.sql`
   6. `006_extended_item_bank.sql`
   7. `007_specialist_assessments.sql`
   8. `008_psychometric_governance.sql`
   9. `009_rater_audio_quality.sql`
   10. `010_assessment_security_gates.sql`
3. Aktifkan email/password, verifikasi email, dan MFA untuk semua akun internal.
4. Atur Site URL serta redirect URL untuk `/reset-password.html`.
5. Uji RLS menggunakan akun student, instructor, academic, finance, admin, executive, dan superadmin.

## 2. Netlify

- Publish directory: `public`
- Functions directory: `netlify/functions`
- Node runtime: 22+
- Masukkan seluruh variabel `.env.example` melalui Environment variables.
- Jangan menaruh service role key, token WhatsApp, atau API key email di browser/repository.

## 3. Assessment release workflow

1. Academic mengunggah rekaman listening yang telah diperiksa melalui Operations Console.
2. Reviewer pertama mencatat review `content`; reviewer kedua mencatat review `level`.
3. Perbaiki semua keputusan `revision_required`.
4. Setujui konten setelah dashboard menunjukkan jumlah item, tugas, kompetensi, dan audio lengkap.
5. Gunakan tes dalam mode pilot; hasil belum boleh menetapkan level final.
6. Kumpulkan sedikitnya 30 peserta unik per form; target yang disarankan 100+.
7. Jalankan kalkulasi item dan reliabilitas.
8. Lakukan review `psychometric`, analisis bias, dan standard setting.
9. Validasi hanya bila reliabilitas ≥0,70 dan bukti lain mendukung intended use.
10. Arsipkan form bermasalah; jangan mengubah item pada form tervalidasi tanpa versi baru.

## 4. Pembayaran

Isi `BANK_NAME`, `BANK_ACCOUNT_NUMBER`, dan `BANK_ACCOUNT_HOLDER`. Bukti transfer disimpan di bucket privat `payment-proofs`. Hanya Finance/Admin/Superadmin yang dapat memverifikasi; semua keputusan dicatat di audit log.

## 5. Email dan WhatsApp

- Resend: `RESEND_API_KEY`, `EMAIL_FROM`, `ADMIN_EMAIL`.
- WhatsApp Business Cloud: token, Phone Number ID, nomor admin, dan template yang disetujui.
- Verifikasi SPF, DKIM, dan DMARC.
- Tabel `notification_events` mencegah pengiriman ganda dan menyimpan status delivery.

## 6. Acceptance test

- Pendaftaran → placement/pilot → review hasil → penawaran → invoice → pembayaran → enrollment.
- Login, verifikasi email, reset password, MFA staf, logout, dan suspensi akun.
- Upload/download privat untuk bukti transfer, rekaman speaking, dan audio listening.
- Penilaian rubrik, dual rating, adjudikasi, riwayat hasil, statistik item, dan quality gate.
- RLS lintas akun: peserta A tidak boleh membaca data peserta B.
- Backup/restore, audit log, error monitoring, rate limiting, mobile, WCAG AA, sitemap, dan domain.

## 7. Go-live gate

Gunakan `COMMERCIAL_READINESS.md`. Source code dapat dideploy setelah konfigurasi, tetapi tes hanya boleh dipasarkan sebagai latihan/diagnostik sampai review manusia, audio final, pilot, dan validasi empiris selesai.
