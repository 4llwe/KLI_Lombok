-- Japanese assessment alignment based on the licensed N4/N5 materials supplied by KLI.
-- Raw media remains private; do not place it under public/.
create table if not exists public.assessment_source_register(
 id uuid primary key default gen_random_uuid(), file_name text not null unique, sha256 text not null unique,
 level text not null, material_role text not null, file_type text not null,
 rights_status text not null check(rights_status in ('pending','licensed_user_attested','verified','restricted')),
 commercial_use_allowed boolean not null default false, license_reference text,
 source_owner text not null default 'The Japan Foundation / Japan Educational Exchanges and Services',
 created_at timestamptz not null default now()
);
alter table public.assessment_source_register enable row level security;
create policy japanese_sources_staff_read on public.assessment_source_register for select using(public.is_staff());
create policy japanese_sources_admin_manage on public.assessment_source_register for all using(public.current_role() in ('admin','superadmin')) with check(public.current_role() in ('admin','superadmin'));
create table if not exists public.assessment_sections(
 id uuid primary key default gen_random_uuid(), test_id uuid not null references public.assessment_tests(id) on delete cascade,
 code text not null, title text not null, score_group text not null, duration_minutes int,
 target_item_count int, task_taxonomy jsonb not null default '[]'::jsonb, sort_order int not null,
 source_alignment text, unique(test_id,code)
);
alter table public.assessment_sections enable row level security;
create policy assessment_sections_public_read on public.assessment_sections for select using(exists(select 1 from public.assessment_tests t where t.id=test_id and t.published));
create policy assessment_sections_staff_manage on public.assessment_sections for all using(public.current_role() in ('academic','admin','superadmin')) with check(public.current_role() in ('academic','admin','superadmin'));
alter table public.assessment_questions add column if not exists section_id uuid references public.assessment_sections(id) on delete set null;
alter table public.assessment_questions add column if not exists item_type text;
alter table public.assessment_questions add column if not exists source_register_id uuid references public.assessment_source_register(id) on delete restrict;
alter table public.assessment_questions add column if not exists randomize_options boolean not null default true;
insert into public.assessment_source_register(file_name,sha256,level,material_role,file_type,rights_status,commercial_use_allowed,license_reference) values
('N4Q1.mp3','48423daeb3bdfeb84c2289d00d265dcb70f2ede4383b13341b682d33b98c4035','N4','audio','mp3','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N4Q2.mp3','90a09b10de2258b62ee20bc29a5c13413a7428997f869c11c6c494197b9961e1','N4','audio','mp3','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N4Q3.mp3','69c9f384e9edba860bb833afd4f19893ffb81082726f969efd7a326a73f13c4f','N4','audio','mp3','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N4Q4.mp3','767d6337e21920e09df5e585bf6d9cbe593bce3c216154b3121d097f05b11bd7','N4','audio','mp3','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('1-N4G-Dokkai.pdf','da3bec0d70fef11aa9291b12d56a964b99064c77d1bac4dbe9f17d01c92f08a7','N4','booklet','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('2-N4L-Choukai.pdf','f2369b104b77f16067d4a0add17df4ab293f414e72f079ba35155fe8571cb514','N4','booklet','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('3-N4V-Moji-Goi.pdf','acda221ce269e6e60674ee9f340833eb18cf06a95425e97b0f3feed8fa5a66ec','N4','booklet','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N4R.pdf','9cbfae13f485f6cb9cbae58dab79efa9f840377016566adaacd41e9586ad9a08','N4','booklet','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N4answer.pdf','72b4e72cab02780f82653a3e1f08766f11ce698f77df8557d7971a2f48f452c1','N4','answer_key','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N4sheet.pdf','91506417b278712ffeb4fed7aa403c4cea33273be10b5364246fa48c4c641d48','N4','answer_sheet','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N5-kaitou.pdf','52f0afffbfdd6c76422f89f53e12f138f8540a707cedda728a676a001af3f829','N5','answer_key','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N5-mondai.pdf','df1bcb6e16629c68dba059b71a9f8b3dc7d4fc40dadb53f2b562fc8274b8f95f','N5','booklet','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.'),
('N5-script.pdf','0283a19da7b796a06955312180a8722f5e9e9a04e4650488b1128ab3acd0007e','N5','script','pdf','licensed_user_attested',true,'User confirmed written commercial permission on 2026-09-13; archive the license document before production publication.')
on conflict(file_name) do update set sha256=excluded.sha256,rights_status=excluded.rights_status,commercial_use_allowed=excluded.commercial_use_allowed,license_reference=excluded.license_reference;
insert into public.assessment_sections(test_id,code,title,score_group,duration_minutes,target_item_count,task_taxonomy,sort_order,source_alignment)
select id,'vocabulary','Language Knowledge — Vocabulary','language_knowledge_reading',30,35,'["kanji_reading","orthography","contextual_vocabulary","paraphrase","word_usage"]'::jsonb,1,'Licensed N4 2018 practice workbook structure' from public.assessment_tests where code='JP-N4-PLACEMENT'
on conflict(test_id,code) do update set duration_minutes=excluded.duration_minutes,target_item_count=excluded.target_item_count,task_taxonomy=excluded.task_taxonomy,source_alignment=excluded.source_alignment;
insert into public.assessment_sections(test_id,code,title,score_group,duration_minutes,target_item_count,task_taxonomy,sort_order,source_alignment)
select id,'grammar_reading','Language Knowledge — Grammar & Reading','language_knowledge_reading',60,35,'["sentence_grammar","sentence_composition","text_grammar","short_passage","medium_passage","information_retrieval"]'::jsonb,2,'Licensed N4 2018 practice workbook structure' from public.assessment_tests where code='JP-N4-PLACEMENT'
on conflict(test_id,code) do update set duration_minutes=excluded.duration_minutes,target_item_count=excluded.target_item_count,task_taxonomy=excluded.task_taxonomy,source_alignment=excluded.source_alignment;
insert into public.assessment_sections(test_id,code,title,score_group,duration_minutes,target_item_count,task_taxonomy,sort_order,source_alignment)
select id,'listening','Listening','listening',35,28,'["task_comprehension","point_comprehension","verbal_expressions_with_images","quick_response"]'::jsonb,3,'Licensed N4 2018 practice workbook structure' from public.assessment_tests where code='JP-N4-PLACEMENT'
on conflict(test_id,code) do update set duration_minutes=excluded.duration_minutes,target_item_count=excluded.target_item_count,task_taxonomy=excluded.task_taxonomy,source_alignment=excluded.source_alignment;
update public.assessment_questions q set section_id=s.id,item_type=coalesce(q.item_type,q.competency) from public.assessment_sections s,public.assessment_tests t where q.test_id=t.id and s.test_id=t.id and t.code='JP-N4-PLACEMENT' and s.code=case when q.competency='vocabulary' then 'vocabulary' when q.competency='listening' then 'listening' else 'grammar_reading' end;
create table if not exists public.japanese_reference_answer_keys(level text not null,section_code text not null,answers jsonb not null,source_file_name text not null references public.assessment_source_register(file_name),review_status text not null default 'second_review_required',primary key(level,section_code));
alter table public.japanese_reference_answer_keys enable row level security;
create policy japanese_keys_academic_read on public.japanese_reference_answer_keys for select using(public.current_role() in ('academic','admin','superadmin'));
insert into public.japanese_reference_answer_keys(level,section_code,answers,source_file_name) values
('N4','vocabulary','[3, 4, 1, 2, 4, 3, 4, 2, 1, 2, 3, 4, 1, 3, 4, 1, 2, 2, 3, 2, 1, 4, 3, 4, 1, 2, 2, 4, 1, 3, 3, 1, 3, 2, 4]'::jsonb,'N4answer.pdf'),
('N4','grammar_reading','[3, 4, 2, 1, 4, 1, 3, 4, 2, 4, 3, 2, 3, 1, 2, 1, 2, 3, 1, 4, 3, 1, 4, 2, 3, 4, 2, 3, 4, 3, 1, 2, 3, 4, 1]'::jsonb,'N4answer.pdf'),
('N4','listening','[1, 3, 2, 4, 3, 3, 3, 1, 1, 2, 4, 2, 2, 4, 3, 2, 2, 1, 3, 2, 1, 3, 3, 1, 2, 3, 2, 1]'::jsonb,'N4answer.pdf')
on conflict(level,section_code) do update set answers=excluded.answers,source_file_name=excluded.source_file_name;
comment on table public.japanese_reference_answer_keys is 'Internal licensed reference keys. Require independent second review before assigning to production question rows.';
