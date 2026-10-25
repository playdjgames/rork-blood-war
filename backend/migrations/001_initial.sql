-- Blood War initial schema

create table if not exists players (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'Lord'
);

create table if not exists alliances (
 id uuid primary key default gen_random_uuid(),
 code text not null unique,
 name text not null,
 owner_user_id uuid not null references players(user_id),
 created_at timestamptz not null default now()
);

create table if not exists alliance_members (
 alliance_id uuid not null references alliances(id) on delete cascade,
 user_id uuid not null references players(user_id) on delete cascade,
 role text not null default 'member',
 joined_at timestamptz not null default now(),
 primary key (alliance_id, user_id)
);

create table if not exists alliance_posts (
 id uuid primary key default gen_random_uuid(),
 alliance_id uuid not null references alliances(id) on delete cascade,
 author_user_id uuid not null references players(user_id),
 text text not null,
 created_at timestamptz not null default now()
);

create table if not exists holds (
 x int not null,
 y int not null,
 owner_alliance_id uuid references alliances(id),
 power int not null default 800,
 shield_until timestamptz,
 primary key (x, y)
);
