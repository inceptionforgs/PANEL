const listenSessionsSql = """
create table if not exists public.listen_sessions (
  session_id text primary key,
  song_id uuid,
  song_title text,
  category text,
  ip text,
  country text,
  region text,
  city text,
  lat double precision,
  lon double precision,
  last_seen timestamptz not null default now(),
  started_at timestamptz not null default now()
);

alter table public.listen_sessions enable row level security;

drop policy if exists listen_sessions_anon_write on public.listen_sessions;
create policy listen_sessions_anon_write
  on public.listen_sessions for insert to anon with check (true);

drop policy if exists listen_sessions_anon_update on public.listen_sessions;
create policy listen_sessions_anon_update
  on public.listen_sessions for update to anon using (true) with check (true);

grant insert, update on public.listen_sessions to anon;
""";
