-- Initial TRYP database schema

-- Profiles table linked to Supabase Auth users
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text,
  phone text unique,
  role text check (role in ('passenger', 'driver')) not null default 'passenger',
  avatar_url text,
  created_at timestamp with time zone default timezone('utc', now()) not null,
  updated_at timestamp with time zone default timezone('utc', now()) not null
);

-- Ride requests and active trips
create table if not exists public.rides (
  id uuid primary key default gen_random_uuid(),
  passenger_id uuid not null references public.profiles(id) on delete cascade,
  driver_id uuid references public.profiles(id) on delete set null,
  origin text not null,
  destination text not null,
  status text not null default 'requested',
  fare numeric(10,2),
  requested_at timestamp with time zone default timezone('utc', now()) not null,
  accepted_at timestamp with time zone,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  metadata jsonb
);

-- Driver documents for onboarding
create table if not exists public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  document_type text not null,
  document_url text not null,
  status text not null default 'pending',
  submitted_at timestamp with time zone default timezone('utc', now()) not null,
  reviewed_at timestamp with time zone
);

-- Basic indexes
create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_rides_status on public.rides(status);
create index if not exists idx_rides_passenger_id on public.rides(passenger_id);
create index if not exists idx_rides_driver_id on public.rides(driver_id);
