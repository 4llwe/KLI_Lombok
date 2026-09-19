# Multilingual website and public test catalog fix

## 1. Make public tests appear

Deploy the repository, then open Supabase → SQL Editor and run the complete contents of:

`FIX_PUBLIC_TEST_CATALOG.sql`

The SQL is rerunnable and will:
- restore public read access for published test cards;
- publish existing assessment tests;
- guarantee at least one working placement test for English, Japanese, and German;
- add starter questions only when they do not already exist;
- reload the PostgREST schema cache;
- show a final count of published tests per language.

Expected final verification rows include `English`, `Japanese`, and `German`, each with a count greater than zero.

## 2. Language switcher

Public pages now include an `ID / EN / JP / DE` switcher. The selected language is saved in the browser. The switcher covers Indonesian, English, Japanese, and German navigation and primary public-page content.

## 3. Deployment order

1. Extract this ZIP.
2. Upload and commit the extracted repository changes to GitHub `main`.
3. Wait for Netlify deployment to finish.
4. Run `FIX_PUBLIC_TEST_CATALOG.sql` in Supabase SQL Editor.
5. Hard-refresh the website and open `/tests.html`.
