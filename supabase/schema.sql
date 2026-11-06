-- VHU Job Connect MVP schema for Supabase
create extension if not exists pgcrypto;

create type public.app_role as enum ('student','employer','admin');
create type public.job_status as enum ('pending','published','rejected','closed');
create type public.application_status as enum ('submitted','reviewing','interview','accepted','rejected','withdrawn');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 role public.app_role not null default 'student',
 full_name text, major text, year text, phone text, location text,
 talents text, skills text, experience text, education text, portfolio text,
 avatar_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- Create a role-scoped profile automatically when an auth account is created.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
declare requested_role public.app_role;
begin
  requested_role := case
    when new.raw_user_meta_data->>'role' = 'employer' then 'employer'::public.app_role
    else 'student'::public.app_role
  end;
  insert into public.profiles(id,role) values(new.id,requested_role)
  on conflict(id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create table public.employer_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 organization_name text not null, organization_type text, contact_name text, phone text,
 address text, description text, verified boolean not null default false,
 verification_status text not null default 'pending',
 created_at timestamptz not null default now()
);
create table public.jobs (
 id uuid primary key default gen_random_uuid(),
 employer_id uuid not null references auth.users(id) on delete cascade,
 title text not null, description text not null, requirements text,
 location text not null, employment_type text not null, salary_text text,
 schedule_text text, slots integer not null default 1 check(slots between 1 and 1000),
 status public.job_status not null default 'pending',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.applications (
 id uuid primary key default gen_random_uuid(),
 job_id uuid not null references public.jobs(id) on delete cascade,
 student_id uuid not null references auth.users(id) on delete cascade,
 status public.application_status not null default 'submitted',
 cover_note text, created_at timestamptz not null default now(),
 unique(job_id,student_id)
);
create table public.reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references auth.users(id) on delete cascade,
 job_id uuid references public.jobs(id) on delete cascade,
 employer_id uuid references auth.users(id) on delete cascade,
 reason text not null, details text, status text not null default 'open',
 created_at timestamptz not null default now()
);

create or replace function public.my_role()
returns public.app_role language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() $$;

alter table public.profiles enable row level security;
alter table public.employer_profiles enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.reports enable row level security;

create policy "profiles read self or admin" on public.profiles for select to authenticated
using (id=auth.uid() or public.my_role()='admin');
create policy "profiles insert self" on public.profiles for insert to authenticated
with check (id=auth.uid() and role in ('student','employer'));
create policy "profiles update self or admin" on public.profiles for update to authenticated
using (id=auth.uid() or public.my_role()='admin')
with check ((id=auth.uid() and role=public.my_role()) or public.my_role()='admin');

create policy "employer profiles visible" on public.employer_profiles for select to authenticated
using (true);
create policy "employer manages own profile" on public.employer_profiles for all to authenticated
using (user_id=auth.uid() or public.my_role()='admin')
with check ((user_id=auth.uid() and public.my_role()='employer') or public.my_role()='admin');

create policy "published jobs visible" on public.jobs for select to anon,authenticated
using (status='published' or employer_id=auth.uid() or public.my_role()='admin');
create policy "employer creates pending jobs" on public.jobs for insert to authenticated
with check (employer_id=auth.uid() and public.my_role()='employer' and status='pending');
create policy "employer updates own jobs or admin" on public.jobs for update to authenticated
using (employer_id=auth.uid() or public.my_role()='admin')
with check (employer_id=auth.uid() or public.my_role()='admin');
create policy "employer deletes own jobs or admin" on public.jobs for delete to authenticated
using (employer_id=auth.uid() or public.my_role()='admin');

create policy "student sees own applications, employer sees applicants, admin sees all" on public.applications
for select to authenticated using (
 student_id=auth.uid() or public.my_role()='admin' or
 exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid())
);
create policy "student applies to published jobs" on public.applications for insert to authenticated
with check (student_id=auth.uid() and public.my_role()='student' and
 exists(select 1 from public.jobs j where j.id=job_id and j.status='published'));
create policy "employer/admin updates application status" on public.applications for update to authenticated
using (public.my_role()='admin' or exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()))
with check (public.my_role()='admin' or exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()));

create policy "user creates report" on public.reports for insert to authenticated
with check (reporter_id=auth.uid());
create policy "reporter/admin reads report" on public.reports for select to authenticated
using (reporter_id=auth.uid() or public.my_role()='admin');
create policy "admin manages reports" on public.reports for update to authenticated
using (public.my_role()='admin') with check (public.my_role()='admin');

-- Create a public avatar bucket. Restrict uploads to a folder named with the user's auth UID.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy "avatar public read" on storage.objects for select using(bucket_id='avatars');
create policy "user uploads own avatar" on storage.objects for insert to authenticated
with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "user updates own avatar" on storage.objects for update to authenticated
using(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text)
with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

-- IMPORTANT: promote the first administrator manually from the Supabase SQL editor
-- after creating that user's account:
-- update public.profiles set role='admin' where id='AUTH_USER_UUID';
-- For the first employer, assign role='employer' through a trusted admin workflow.

-- Security hardening: employers cannot self-verify or publish their own jobs.
create or replace function public.protect_employer_verification()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() is not null and public.my_role() <> 'admin' then
    new.verified := old.verified;
    new.verification_status := old.verification_status;
  end if;
  return new;
end;
$$;
drop trigger if exists employer_verification_guard on public.employer_profiles;
create trigger employer_verification_guard before update on public.employer_profiles
for each row execute function public.protect_employer_verification();

create or replace function public.protect_job_moderation()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() is not null and public.my_role() <> 'admin' then
    if new.employer_id <> old.employer_id then
      raise exception 'Không được thay đổi chủ sở hữu tin tuyển dụng';
    end if;
    -- employers may only close their own job; publishing/rejecting is admin-only
    if new.status <> old.status and new.status <> 'closed' then
      new.status := old.status;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists job_moderation_guard on public.jobs;
create trigger job_moderation_guard before update on public.jobs
for each row execute function public.protect_job_moderation();

-- Restrict direct profile role changes. Role assignment is an admin-only operation.
create or replace function public.protect_profile_role()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() is not null and public.my_role() <> 'admin' then
    new.role := old.role;
  end if;
  return new;
end;
$$;
drop trigger if exists profile_role_guard on public.profiles;
create trigger profile_role_guard before update on public.profiles
for each row execute function public.protect_profile_role();

-- Fix: link jobs -> employer_profiles so the app can embed employer_profiles(organization_name,...)
-- (without this, the Jobs list query fails and shows nothing). Employers must save their profile before posting.
alter table public.jobs add constraint jobs_employer_profile_fkey
  foreign key (employer_id) references public.employer_profiles(user_id) on delete cascade;
