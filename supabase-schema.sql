-- Tapehead Pro — Phase C schema (run in Supabase SQL Editor)

-- Profiles (extends auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  contact text,
  avatar_url text,
  is_pro boolean default false,
  pro_until timestamptz,
  created_at timestamptz default now()
);

create table if not exists public.projects (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text default 'Untitled Session',
  lyrics text default '',
  bpm int default 120,
  pattern jsonb default '{}',
  kit text default 'trap',
  updated_at timestamptz default now()
);
create index if not exists projects_user_idx on public.projects(user_id);

create table if not exists public.feed_posts (
  id text primary key,
  user_id uuid references public.profiles(id) on delete set null,
  username text,
  avatar_url text,
  title text,
  lyrics text,
  bpm int default 120,
  kit text,
  pattern jsonb,
  created_at timestamptz default now()
);

create table if not exists public.likes (
  post_id text references public.feed_posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id bigserial primary key,
  post_id text references public.feed_posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  username text,
  body text not null,
  created_at timestamptz default now()
);

create table if not exists public.rooms (
  code text primary key,
  host_id uuid references public.profiles(id) on delete set null,
  title text,
  bpm int default 120,
  kit text,
  pattern jsonb,
  sections jsonb default '[]',
  updated_at timestamptz default now()
);

create table if not exists public.room_members (
  room_code text references public.rooms(code) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  username text,
  avatar_url text,
  joined_at timestamptz default now(),
  primary key (room_code, user_id)
);

create table if not exists public.room_vocals (
  id bigserial primary key,
  room_code text references public.rooms(code) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  username text,
  file_path text,
  file_url text,
  created_at timestamptz default now()
);

-- RLS
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.feed_posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_vocals enable row level security;

create policy "profiles read" on public.profiles for select using (true);
create policy "profiles upsert own" on public.profiles for all using (auth.uid() = id);

create policy "projects own" on public.projects for all using (auth.uid() = user_id);

create policy "feed read" on public.feed_posts for select using (true);
create policy "feed insert" on public.feed_posts for insert with check (auth.uid() = user_id);
create policy "feed update own" on public.feed_posts for update using (auth.uid() = user_id);

create policy "likes all auth" on public.likes for all using (auth.uid() = user_id);
create policy "likes read" on public.likes for select using (true);

create policy "comments read" on public.comments for select using (true);
create policy "comments insert" on public.comments for insert with check (auth.uid() = user_id);

create policy "rooms read" on public.rooms for select using (true);
create policy "rooms write auth" on public.rooms for all using (auth.uid() is not null);

create policy "members read" on public.room_members for select using (true);
create policy "members write" on public.room_members for all using (auth.uid() = user_id);

create policy "vocals read" on public.room_vocals for select using (true);
create policy "vocals write" on public.room_vocals for all using (auth.uid() = user_id);

-- Realtime
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.room_members;
alter publication supabase_realtime add table public.room_vocals;

-- Storage bucket (run in dashboard or via API): vocals (public read)
-- storage.objects policies: authenticated upload to folder user_id/*
