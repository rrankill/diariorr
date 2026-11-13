insert into storage.buckets (id, name, public, allowed_mime_types)
values ('study-pdfs', 'study-pdfs', false, array['application/pdf'])
on conflict (id) do update
set public = false, allowed_mime_types = array['application/pdf'];

create table if not exists public.pdf_files (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  size bigint not null,
  storage_path text not null unique,
  user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.pdf_files enable row level security;

drop policy if exists "Authenticated users can list PDFs" on public.pdf_files;
create policy "Authenticated users can list PDFs"
on public.pdf_files for select to authenticated
using (true);

drop policy if exists "Users can register their own PDFs" on public.pdf_files;
create policy "Users can register their own PDFs"
on public.pdf_files for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can remove their own PDF records" on public.pdf_files;
create policy "Users can remove their own PDF records"
on public.pdf_files for delete to authenticated
using (auth.uid() = user_id);

drop policy if exists "Authenticated users can read PDF objects" on storage.objects;
create policy "Authenticated users can read PDF objects"
on storage.objects for select to authenticated
using (bucket_id = 'study-pdfs');

drop policy if exists "Users can upload their own PDF objects" on storage.objects;
create policy "Users can upload their own PDF objects"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'study-pdfs'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can delete their own PDF objects" on storage.objects;
create policy "Users can delete their own PDF objects"
on storage.objects for delete to authenticated
using (
  bucket_id = 'study-pdfs'
  and (storage.foldername(name))[1] = auth.uid()::text
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pdf_files'
  ) then
    alter publication supabase_realtime add table public.pdf_files;
  end if;
end
$$;
