# Roadmap produk profesional

## Prinsip prioritas

1. Trust dan data resmi sebelum promosi berbayar.
2. Funnel pendaftaran dan pembayaran sebelum dashboard analitik kompleks.
3. Source of truth akademik sebelum otomatisasi laporan.
4. RBAC, audit log, backup, dan privasi sejak awal.
5. Setiap fase memiliki acceptance criteria dan tidak dianggap selesai hanya karena UI tersedia.

## Phase 0 — Discovery dan governance (1–2 minggu)

- Validasi badan hukum, izin, NPSN, status akreditasi, alamat, kontak, merek, rekening.
- Tetapkan program, level, kurikulum, harga, jadwal, aturan kehadiran, penilaian, refund.
- Petakan peran: calon peserta, peserta, wali, pengajar, akademik, admin, keuangan, pimpinan, superadmin.
- Data classification, retention, incident response, RACI.

**Gate:** data resmi disetujui pimpinan; kebijakan akademik dan transaksi terdokumentasi.

## Phase 1 — Marketing & trust foundation (2–4 minggu)

- Domain, email, halaman program, pengajar, legalitas, jadwal/biaya, FAQ.
- Placement-test lead funnel dan CRM pipeline.
- SEO technical, analytics, consent, accessibility baseline.
- Design system responsif.

**Gate:** calon peserta dapat memahami program dan mengirim permintaan; semua klaim terverifikasi.

## Phase 2 — Commerce MVP (4–6 minggu)

- Account, verification, RBAC.
- Application, enrollment, class capacity.
- Invoice, payment gateway, webhook idempotency, receipt, refund workflow.
- Email/WhatsApp transactional notification.
- Admin enrollment console dan audit log.

**Gate:** transaksi sandbox lulus end-to-end; rekonsiliasi pembayaran akurat; tidak ada data kartu tersimpan.

## Phase 3 — Student Learning Portal (4–6 minggu)

- Kalender, materi, presensi, tugas, submission, nilai, feedback.
- Progress report dan support ticket.
- Sertifikat bernomor dan QR verification.

**Gate:** satu kelas pilot dapat berjalan tanpa spreadsheet paralel.

## Phase 4 — Academic & Business System (6–8 minggu)

- Curriculum mapping, learning outcomes, rubric, moderation.
- Scheduling pengajar/ruang, payroll input, CRM, finance reporting.
- Executive KPIs dengan definisi metric dan drill-down.
- Quality assurance dan intervention workflow.

**Gate:** laporan akademik/keuangan direkonsiliasi dengan sumber transaksi dan aktivitas kelas.

## Phase 5 — Commercial hardening (2–4 minggu)

- Penetration test, load test, restore drill, observability, runbook.
- Legal review, UAT, training staf, SLA support.
- Staged rollout, incident channel, launch checklist.

**Gate:** sign-off keamanan, hukum, akademik, keuangan, dan operasional.

## KPI produk

- Visit → lead conversion
- Lead → placement completion
- Placement → paid enrollment
- Payment success/failure
- Class fill rate
- Attendance and completion
- Learning outcome attainment
- Retention/re-enrollment
- Refund rate
- Support response/resolution time
- Instructor utilization
- Revenue and receivables by program
