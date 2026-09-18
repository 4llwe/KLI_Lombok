# KLI Integrated Management System — Academic Release Candidate

Aplikasi Kahayangan Language Institute untuk layanan eksternal, pembelajaran, assessment, keuangan, dan operasi internal berbasis Netlify + Supabase.

## Cakupan

- Website marketing, pendaftaran, portal peserta, dan Operations Console.
- Supabase Auth, reset password, RLS, private storage, dan audit log.
- Kelas, materi, tugas, nilai, kehadiran, invoice, pembayaran, sertifikat, dan pengumuman.
- Email Resend, WhatsApp Business Cloud API, serta idempotensi notifikasi.
- Assessment Center untuk English, Japanese, dan German.

## Assessment Center

- 26 jenis assessment.
- 770 soal objektif orisinal setelah seluruh migrasi dijalankan, termasuk formulir IELTS Academic preparation empat keterampilan.
- 17 level descriptors.
- 91 tugas reading, listening, writing, dan speaking/skill sesuai blueprint.
- Blueprint untuk English CEFR A1–C2, Japanese JLPT N5–N1 + productive extension KLI, dan German CEFR A1–C2.
- IELTS, TOEFL, JLPT, Goethe readiness serta Kana–Kanji dan Ausbildung diagnostics.
- Randomisasi urutan item/opsi, timer, server-side scoring, private audio upload, rubrik analitik, dual rating, adjudikasi, dan riwayat attempt.
- Review content/level/bias/technical/psychometric, statistik kesulitan/daya pembeda, Cronbach alpha, dan validation gate.

## Status akademik yang benar

Konten source tersedia dan sistem quality assurance sudah diterapkan. Namun, tes tidak otomatis menjadi valid hanya karena jumlah soal lengkap. Secara default semua form tetap `academic_review` / `content_ready`. Form hanya boleh mendukung keputusan final setelah:

1. audio listening final diunggah;
2. minimal dua reviewer berbeda menyetujui content dan level;
3. pilot peserta unik selesai;
4. statistik item dan reliabilitas memenuhi kebijakan;
5. review psychometric disetujui; dan
6. status berubah menjadi `validated`.

Sebelum itu, antarmuka menandai hasil sebagai latihan/diagnostik dan bukan skor resmi.

## Deploy

Ikuti `DEPLOYMENT.md` dan jalankan migrasi `001` sampai `015` berurutan. Kredensial tidak disertakan.

## Kontak

- Email: kahayanganinstitute@gmail.com
- WhatsApp: +62 822-2742-0800
- Jl. Kecubung No. 20, Gomong Lama, Mataram, NTB 83125
