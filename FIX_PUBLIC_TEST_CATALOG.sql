-- Ensure public assessment cards appear for English, Japanese, and German.
-- Safe to run more than once in Supabase SQL Editor.

alter table public.assessment_tests enable row level security;

drop policy if exists tests_public_read on public.assessment_tests;
create policy tests_public_read on public.assessment_tests
for select using (published = true or public.is_staff());

grant select on table public.assessment_tests to anon, authenticated;

-- Publish any existing catalog tests.
update public.assessment_tests set published = true where published is distinct from true;

-- Guarantee at least one working placement test per language.
insert into public.assessment_tests(code,language,framework,level,test_type,title,description,duration_minutes,pass_score,published)
values
('EN-A1-QUICK-PLACEMENT','English','CEFR','A1','placement','English A1 Quick Placement','A short English foundation placement check.',10,70,true),
('JP-N5-QUICK-PLACEMENT','Japanese','JLPT','N5','placement','日本語 N5 クイックレベルチェック','ひらがな、基本表現、初級文法の短いレベルチェックです。',10,70,true),
('DE-A1-QUICK-PLACEMENT','German','CEFR','A1','placement','Deutsch A1 Kurz-Einstufung','Ein kurzer Einstufungstest für Wortschatz und Grundgrammatik.',10,70,true)
on conflict(code) do update set published=true;

insert into public.assessment_questions(test_id,prompt,options,correct_option,points,sort_order)
select t.id, q.prompt, q.options::jsonb, q.correct_option, 1, q.sort_order
from public.assessment_tests t
join (values
('EN-A1-QUICK-PLACEMENT',1,'Choose the correct morning greeting.','["Good morning","Good night","Goodbye","See you yesterday"]','Good morning'),
('EN-A1-QUICK-PLACEMENT',2,'Complete: My name ___ Rina.','["am","is","are","be"]','is'),
('EN-A1-QUICK-PLACEMENT',3,'Which question asks about origin?','["Where are you from?","How old is it?","What time is lunch?","Who is the book?"]','Where are you from?'),
('JP-N5-QUICK-PLACEMENT',1,'「わたし ___ がくせいです。」','["は","を","に","で"]','は'),
('JP-N5-QUICK-PLACEMENT',2,'「おはようございます」はいつ使いますか。','["朝","昼","夜","深夜"]','朝'),
('JP-N5-QUICK-PLACEMENT',3,'「日」の意味に最も近いものはどれですか。','["太陽・日","水","木","山"]','太陽・日'),
('DE-A1-QUICK-PLACEMENT',1,'Ergänzen Sie: Ich ___ Maria.','["heiße","heißt","heißen","bist"]','heiße'),
('DE-A1-QUICK-PLACEMENT',2,'Welche Begrüßung passt am Morgen?','["Guten Morgen","Gute Nacht","Auf Wiedersehen gestern","Bis Montagabend früh"]','Guten Morgen'),
('DE-A1-QUICK-PLACEMENT',3,'„Woher kommen Sie?“ fragt nach …','["Herkunft","Alter","Uhrzeit","Preis"]','Herkunft')
) as q(code,sort_order,prompt,options,correct_option) on q.code=t.code
where not exists (
  select 1 from public.assessment_questions existing
  where existing.test_id=t.id and existing.sort_order=q.sort_order
);

notify pgrst, 'reload schema';

select language, count(*) as published_tests
from public.assessment_tests
where published=true
group by language
order by language;
