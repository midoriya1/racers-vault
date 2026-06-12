# Supabase Setup for Racers Vault

Use this when you want the app database and spot photo storage to run on Supabase instead of Firebase.

## 1. Create the Supabase project

1. Go to https://supabase.com/dashboard
2. Create a new project.
3. Open **Project Settings > API**.
4. Copy:
   - **Project URL**
   - **anon public key**

## 2. Enable email login

1. Open **Authentication > Providers**.
2. Enable **Email**.
3. For fast local testing, you can temporarily turn off **Confirm email**.
4. Save.

The app now uses email/password accounts so users keep their garage across installs and devices.

## 3. Create tables and storage

Open **SQL Editor** in Supabase and run this:

```sql
create table if not exists public.profiles (
  id text primary key,
  username text not null,
  country text not null,
  city text not null,
  bio text not null default '',
  avatar_url text,
  trust_score integer not null default 70,
  trust_strikes integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.spots (
  id text primary key,
  user_id text not null references public.profiles(id) on delete cascade,
  spotter text not null,
  city text not null,
  country text not null,
  category text not null default 'Cars',
  car_name text not null,
  rarity text not null,
  points integer not null,
  caption text not null default '',
  media_url text,
  image_hash text,
  perceptual_hash text,
  capture_source text not null default 'unknown',
  trust_score integer not null default 50,
  verification_status text not null default 'unverified',
  ai_confidence double precision not null default 0,
  recognition_note text not null default '',
  vehicle_make text not null default '',
  vehicle_model text not null default '',
  vehicle_generation text not null default '',
  year_range text not null default '',
  body_type text not null default '',
  privacy_plate_detected boolean not null default false,
  privacy_face_detected boolean not null default false,
  synthetic_image_risk double precision not null default 0,
  manipulation_risk double precision not null default 0,
  location_integrity text not null default 'profile-fallback',
  security_notes text not null default '',
  blur_status text not null default 'not_needed',
  likes integer not null default 0,
  comments integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.spots enable row level security;

alter table public.profiles
add column if not exists bio text not null default '';

alter table public.profiles
add column if not exists avatar_url text;

alter table public.profiles
add column if not exists trust_score integer not null default 70;

alter table public.profiles
add column if not exists trust_strikes integer not null default 0;

alter table public.spots
add column if not exists category text not null default 'Cars';

alter table public.spots
add column if not exists image_hash text;

alter table public.spots
add column if not exists perceptual_hash text;

alter table public.spots
add column if not exists capture_source text not null default 'unknown';

alter table public.spots
add column if not exists trust_score integer not null default 50;

alter table public.spots
add column if not exists verification_status text not null default 'unverified';

alter table public.spots
add column if not exists ai_confidence double precision not null default 0;

alter table public.spots
add column if not exists recognition_note text not null default '';

alter table public.spots
add column if not exists vehicle_make text not null default '';

alter table public.spots
add column if not exists vehicle_model text not null default '';

alter table public.spots
add column if not exists vehicle_generation text not null default '';

alter table public.spots
add column if not exists year_range text not null default '';

alter table public.spots
add column if not exists body_type text not null default '';

alter table public.spots
add column if not exists privacy_plate_detected boolean not null default false;

alter table public.spots
add column if not exists privacy_face_detected boolean not null default false;

alter table public.spots
add column if not exists synthetic_image_risk double precision not null default 0;

alter table public.spots
add column if not exists manipulation_risk double precision not null default 0;

alter table public.spots
add column if not exists location_integrity text not null default 'profile-fallback';

alter table public.spots
add column if not exists security_notes text not null default '';

alter table public.spots
add column if not exists blur_status text not null default 'not_needed';

create unique index if not exists spots_image_hash_unique
on public.spots (image_hash)
where image_hash is not null;

create index if not exists spots_perceptual_hash_idx
on public.spots (perceptual_hash)
where perceptual_hash is not null;

create index if not exists spots_user_created_at_idx
on public.spots (user_id, created_at desc);

create or replace function public.hex_hamming_distance(
  left_hash text,
  right_hash text
)
returns integer
language plpgsql
immutable
as $$
declare
  i integer;
  left_digit integer;
  right_digit integer;
  xor_value integer;
  distance integer := 0;
begin
  if left_hash is null
    or right_hash is null
    or length(left_hash) <> length(right_hash)
    or length(left_hash) = 0 then
    return 64;
  end if;

  for i in 1..length(left_hash) loop
    left_digit := strpos('0123456789abcdef', lower(substr(left_hash, i, 1))) - 1;
    right_digit := strpos('0123456789abcdef', lower(substr(right_hash, i, 1))) - 1;

    if left_digit < 0 or right_digit < 0 then
      return 64;
    end if;

    xor_value := left_digit # right_digit;
    distance := distance + substr('0112122312232334', xor_value + 1, 1)::integer;
  end loop;

  return distance;
end;
$$;

create or replace function public.prevent_near_duplicate_spot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.perceptual_hash is not null
    and exists (
      select 1
      from public.spots
      where perceptual_hash is not null
        and public.hex_hamming_distance(new.perceptual_hash, perceptual_hash) <= 6
      limit 1
    ) then
    raise exception 'This photo looks too similar to an existing spot.';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_near_duplicate_spot_trigger on public.spots;

create trigger prevent_near_duplicate_spot_trigger
before insert on public.spots
for each row execute function public.prevent_near_duplicate_spot();

create or replace function public.increment_spot_likes(
  target_spot_id text,
  delta integer
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.spots
  set likes = greatest(0, likes + delta)
  where id = target_spot_id;
$$;

create or replace function public.increment_spot_comments(
  target_spot_id text,
  delta integer
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.spots
  set comments = greatest(0, comments + delta)
  where id = target_spot_id;
$$;

create or replace function public.count_recent_user_actions(
  target_table text,
  target_user_column text,
  target_user_id text,
  window_start timestamptz
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  action_count integer;
begin
  if target_table not in ('spots', 'comments', 'reports') then
    raise exception 'Unsupported action table: %', target_table;
  end if;

  if target_user_column not in ('user_id', 'reporter_id') then
    raise exception 'Unsupported user column: %', target_user_column;
  end if;

  execute format(
    'select count(*) from public.%I where %I = $1 and created_at >= $2',
    target_table,
    target_user_column
  )
  into action_count
  using target_user_id, window_start;

  return action_count;
end;
$$;

create table if not exists public.likes (
  user_id text not null references public.profiles(id) on delete cascade,
  spot_id text not null references public.spots(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id)
);

create table if not exists public.follows (
  follower_id text not null references public.profiles(id) on delete cascade,
  following_id text not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.comments (
  id text primary key default gen_random_uuid()::text,
  spot_id text not null references public.spots(id) on delete cascade,
  user_id text not null references public.profiles(id) on delete cascade,
  username text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists comments_user_created_at_idx
on public.comments (user_id, created_at desc);

create table if not exists public.reports (
  id text primary key default gen_random_uuid()::text,
  spot_id text not null references public.spots(id) on delete cascade,
  reporter_id text not null references public.profiles(id) on delete cascade,
  type text not null default 'other',
  reason text not null,
  details text not null default '',
  suggested_car_name text not null default '',
  priority text not null default 'low',
  status text not null default 'open',
  moderation_note text not null default '',
  reviewer_id text references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists reports_reporter_created_at_idx
on public.reports (reporter_id, created_at desc);

alter table public.reports
add column if not exists type text not null default 'other';

alter table public.reports
add column if not exists details text not null default '';

alter table public.reports
add column if not exists suggested_car_name text not null default '';

alter table public.reports
add column if not exists priority text not null default 'low';

alter table public.reports
add column if not exists moderation_note text not null default '';

alter table public.reports
add column if not exists reviewer_id text references public.profiles(id) on delete set null;

alter table public.reports
add column if not exists reviewed_at timestamptz;

create or replace function public.queue_suspicious_spot_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  auto_priority text;
  auto_details text;
begin
  if new.capture_source <> 'gallery'
    and new.trust_score >= 70
    and new.verification_status not in (
      'authenticity-review',
      'gallery-review',
      'location-review',
      'metadata-review',
      'privacy-review'
    ) then
    return new;
  end if;

  auto_priority := case
    when new.trust_score < 45 then 'high'
    when new.capture_source = 'gallery' then 'medium'
    else 'low'
  end;

  auto_details := concat_ws(
    ' ',
    'Automatic originality review.',
    'Source=' || coalesce(new.capture_source, 'unknown') || '.',
    'Trust=' || new.trust_score || '.',
    'Status=' || coalesce(new.verification_status, 'unverified') || '.'
  );

  insert into public.reports (
    spot_id,
    reporter_id,
    type,
    reason,
    details,
    priority,
    status
  )
  values (
    new.id,
    new.user_id,
    'authenticity',
    'Automatic originality review',
    auto_details,
    auto_priority,
    'open'
  );

  return new;
end;
$$;

drop trigger if exists queue_suspicious_spot_report_trigger on public.spots;

create trigger queue_suspicious_spot_report_trigger
after insert on public.spots
for each row execute function public.queue_suspicious_spot_report();

create table if not exists public.moderators (
  user_id text primary key references public.profiles(id) on delete cascade,
  note text not null default '',
  created_at timestamptz not null default now()
);

alter table public.likes enable row level security;
alter table public.follows enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;
alter table public.moderators enable row level security;

create or replace function public.current_user_is_moderator()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.moderators
    where user_id = auth.uid()::text
  );
$$;

grant execute on function public.current_user_is_moderator() to authenticated;

create or replace function public.penalize_reported_spot(
  target_spot_id text,
  moderation_reason text default 'Report confirmed by moderator.'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user_id text;
begin
  if not public.current_user_is_moderator() then
    raise exception 'Only moderators can penalize spots.';
  end if;

  select user_id
  into target_user_id
  from public.spots
  where id = target_spot_id;

  if target_user_id is null then
    return;
  end if;

  update public.spots
  set points = 0,
      trust_score = 0,
      verification_status = 'moderation-confirmed',
      security_notes = trim(
        coalesce(security_notes, '') || ' ' || moderation_reason
      )
  where id = target_spot_id;

  update public.profiles
  set trust_strikes = trust_strikes + 1,
      trust_score = greatest(0, trust_score - 15),
      updated_at = now()
  where id = target_user_id;
end;
$$;

grant execute on function public.penalize_reported_spot(text, text) to authenticated;

drop policy if exists "Profiles are readable" on public.profiles;
drop policy if exists "Users can create own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Spots are readable" on public.spots;
drop policy if exists "Users can create own spots" on public.spots;
drop policy if exists "Users can update own spots" on public.spots;

create policy "Profiles are readable"
on public.profiles for select
using (true);

create policy "Users can create own profile"
on public.profiles for insert
with check (id = auth.uid()::text);

create policy "Users can update own profile"
on public.profiles for update
using (id = auth.uid()::text)
with check (id = auth.uid()::text);

create policy "Spots are readable"
on public.spots for select
using (true);

create policy "Users can create own spots"
on public.spots for insert
with check (
  user_id = auth.uid()::text
  and capture_source in ('camera', 'gallery')
  and synthetic_image_risk < 0.65
  and manipulation_risk < 0.65
  and trust_score >= 45
  and exists (
    select 1
    from public.profiles
    where id = auth.uid()::text
      and trust_score >= 20
      and (trust_score >= 50 or capture_source = 'camera')
  )
  and public.count_recent_user_actions(
    'spots',
    'user_id',
    auth.uid()::text,
    now() - interval '1 hour'
  ) < 20
);

create policy "Users can update own spots"
on public.spots for update
using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);

insert into storage.buckets (id, name, public)
values ('spot-media', 'spot-media', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('profile-media', 'profile-media', true)
on conflict (id) do update set public = true;

drop policy if exists "Spot media is readable" on storage.objects;
drop policy if exists "Users can upload own spot media" on storage.objects;
drop policy if exists "Users can update own spot media" on storage.objects;
drop policy if exists "Profile media is readable" on storage.objects;
drop policy if exists "Users can upload own profile media" on storage.objects;
drop policy if exists "Users can update own profile media" on storage.objects;
drop policy if exists "Likes are readable" on public.likes;
drop policy if exists "Users can create own likes" on public.likes;
drop policy if exists "Users can delete own likes" on public.likes;
drop policy if exists "Follows are readable" on public.follows;
drop policy if exists "Users can create own follows" on public.follows;
drop policy if exists "Users can delete own follows" on public.follows;
drop policy if exists "Comments are readable" on public.comments;
drop policy if exists "Users can create own comments" on public.comments;
drop policy if exists "Reports are private to reporters" on public.reports;
drop policy if exists "Moderators can read reports" on public.reports;
drop policy if exists "Users can create own reports" on public.reports;
drop policy if exists "Moderators can update reports" on public.reports;
drop policy if exists "Users can read own moderator status" on public.moderators;

create policy "Spot media is readable"
on storage.objects for select
using (bucket_id = 'spot-media');

create policy "Users can upload own spot media"
on storage.objects for insert
with check (
  bucket_id = 'spot-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own spot media"
on storage.objects for update
using (
  bucket_id = 'spot-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'spot-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Profile media is readable"
on storage.objects for select
using (bucket_id = 'profile-media');

create policy "Users can upload own profile media"
on storage.objects for insert
with check (
  bucket_id = 'profile-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own profile media"
on storage.objects for update
using (
  bucket_id = 'profile-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'profile-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Likes are readable"
on public.likes for select
using (true);

create policy "Users can create own likes"
on public.likes for insert
with check (user_id = auth.uid()::text);

create policy "Users can delete own likes"
on public.likes for delete
using (user_id = auth.uid()::text);

create policy "Follows are readable"
on public.follows for select
using (true);

create policy "Users can create own follows"
on public.follows for insert
with check (follower_id = auth.uid()::text);

create policy "Users can delete own follows"
on public.follows for delete
using (follower_id = auth.uid()::text);

create policy "Comments are readable"
on public.comments for select
using (true);

create policy "Users can create own comments"
on public.comments for insert
with check (
  user_id = auth.uid()::text
  and length(trim(body)) between 1 and 500
  and public.count_recent_user_actions(
    'comments',
    'user_id',
    auth.uid()::text,
    now() - interval '10 minutes'
  ) < 30
);

create policy "Reports are private to reporters"
on public.reports for select
using (reporter_id = auth.uid()::text);

create policy "Moderators can read reports"
on public.reports for select
using (public.current_user_is_moderator());

create policy "Users can create own reports"
on public.reports for insert
with check (
  reporter_id = auth.uid()::text
  and length(trim(reason)) between 1 and 500
  and length(trim(details)) <= 1500
  and public.count_recent_user_actions(
    'reports',
    'reporter_id',
    auth.uid()::text,
    now() - interval '1 hour'
  ) < 10
);

create policy "Moderators can update reports"
on public.reports for update
using (public.current_user_is_moderator())
with check (public.current_user_is_moderator());

create policy "Users can read own moderator status"
on public.moderators for select
using (user_id = auth.uid()::text);
```

To make your account a moderator, first create/sign in to your app account, then run this in Supabase SQL Editor with your profile id:

```sql
insert into public.moderators (user_id, note)
values ('YOUR_PROFILE_ID', 'founder')
on conflict (user_id) do update set note = excluded.note;
```

## 4. Run the app with Supabase

Keep your recognizer backend running:

```powershell
cd "D:\car vault\car_vault\backend\recognizer"
npm.cmd run dev
```

For a physical Android phone connected by USB:

```powershell
cd "D:\car vault\car_vault"
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse tcp:8787 tcp:8787
flutter run -d 54499200380 `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY `
  --dart-define=RECOGNIZER_URL=http://127.0.0.1:8787/recognize-car
```

Replace `54499200380` with your device id if Flutter shows a different one.

## Notes

- Do not put the Supabase anon key into `backend/recognizer/.env`; it is passed to Flutter with `--dart-define`.
- The anon key is safe to ship in an app only when Row Level Security policies are correct.
- Google and Apple login can be added later on top of the same `profiles` and `spots` tables.
