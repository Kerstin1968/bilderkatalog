-- Bilderkatalog: Einrichtung der Datenbank in Supabase
-- Einmal komplett in den SQL Editor kopieren und auf "Run" klicken.
-- Das Skript kann gefahrlos mehrfach ausgeführt werden.

-- 1) Tabelle für die Werke
create table if not exists public.werke (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  werknummer    text not null,
  titel         text not null default '',
  kuenstler     text not null default '',
  jahr          integer,
  hoehe         numeric,
  breite        numeric,
  tiefe         numeric,
  technik       text not null default '',
  untergrund    text not null default '',
  materialien   text not null default '',
  signatur_pos  text not null default '',
  signatur      text not null default '',
  status        text not null default 'verfuegbar' check (status in ('verfuegbar','verkauft')),
  preis         numeric,
  besitzer      text not null default '',
  notizen       text not null default '',
  foto_pfad     text,
  thumb_pfad    text,
  erstellt      timestamptz not null default now(),
  geaendert     timestamptz not null default now()
);

-- Werknummer darf pro Person nur einmal vorkommen (Groß-/Kleinschreibung egal)
create unique index if not exists werke_werknummer_eindeutig
  on public.werke (user_id, lower(werknummer));

-- 2) Zugriffsschutz: Jede angemeldete Person sieht und ändert nur ihre eigenen Werke.
--    Ohne Anmeldung ist gar nichts sichtbar.
alter table public.werke enable row level security;

drop policy if exists "eigene Werke lesen"     on public.werke;
drop policy if exists "eigene Werke anlegen"   on public.werke;
drop policy if exists "eigene Werke aendern"   on public.werke;
drop policy if exists "eigene Werke loeschen"  on public.werke;

create policy "eigene Werke lesen"    on public.werke for select to authenticated using ((select auth.uid()) = user_id);
create policy "eigene Werke anlegen"  on public.werke for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "eigene Werke aendern"  on public.werke for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "eigene Werke loeschen" on public.werke for delete to authenticated using ((select auth.uid()) = user_id);

-- 3) Privater Speicherbereich für die Fotos (nicht öffentlich, max. 20 MB pro Datei, nur Bilder)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', false, 20971520, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false;

-- Fotos liegen im Ordner <Benutzer-ID>/...; nur die Besitzerin darf sie sehen, hochladen, ersetzen und löschen.
drop policy if exists "eigene Fotos lesen"     on storage.objects;
drop policy if exists "eigene Fotos hochladen" on storage.objects;
drop policy if exists "eigene Fotos aendern"   on storage.objects;
drop policy if exists "eigene Fotos loeschen"  on storage.objects;

create policy "eigene Fotos lesen" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "eigene Fotos hochladen" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "eigene Fotos aendern" on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "eigene Fotos loeschen" on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- 4) Kleine Funktion, mit der ein automatischer Wecker das kostenlose Projekt aktiv hält
--    (Supabase pausiert kostenlose Projekte nach 7 Tagen ohne Nutzung). Gibt keine Daten preis.
create or replace function public.lebenszeichen() returns text
language sql stable as $$ select 'ok'::text $$;
grant execute on function public.lebenszeichen() to anon, authenticated;
