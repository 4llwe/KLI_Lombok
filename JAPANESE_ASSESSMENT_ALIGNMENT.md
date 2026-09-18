# Japanese Assessment Alignment

## Implemented

- Registered every supplied N4/N5 PDF and MP3 with SHA-256 integrity metadata.
- Stored source files outside `public/` under `supabase/seed-assets/japanese/licensed-reference/`.
- Added N4 sections: Vocabulary (30 minutes, 35 items), Grammar & Reading (60 minutes, 35 items), and Listening (35 minutes, 28 items).
- Added the N4 task taxonomy and an internal answer-key register.
- Preserved KLI productive writing/speaking tasks as a separate KLI extension.
- N5 materials are registered as structural references only until a complete, current form and listening package are supplied.

## Production gates

1. Archive the written commercial-use license in KLI's legal repository and update `license_reference`.
2. A second Japanese academic reviewer must independently verify all answer keys.
3. Upload media only to the private `assessment-assets` bucket; never copy these files into `public/`.
4. Confirm booklet/audio synchronization in a supervised staging attempt.
5. Continue to label KLI results as diagnostic/readiness evidence and avoid claims of JLPT affiliation, endorsement, or official score equivalence.

## Audio QA

The four N4 MP3 files are valid stereo 44.1 kHz/128 kbps files. Durations are 12:51, 14:51, 4:32, and 6:02. Production copies have been true-peak normalized to -1.0 dBTP (tolerance +/-0.05 dB), 48 kHz stereo, 192 kbps MP3 while preserving timing and program dynamics. Originals remain in the licensed reference directory for audit.
