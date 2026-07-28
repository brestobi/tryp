-- Migration: 20260728221000_passenger_and_fare_schema.sql
-- Updates profiles, rides, adds saved_places and fare_schemas tables for dynamic pricing & Paystack payments

-- 1. Extend public.profiles table with passenger setup & preference fields
alter table public.profiles
  add column if not exists email text,
  add column if not exists phone_number text,
  add column if not exists home_address text,
  add column if not exists work_address text,
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_phone text,
  add column if not exists preferred_payment text default 'Cash',
  add column if not exists wallet_balance numeric(10,2) default 150.00,
  add column if not exists rating numeric(3,2) default 5.00;

-- 2. Extend public.rides table for dynamic ride options, coordinates, and Paystack payments
alter table public.rides
  add column if not exists ride_type text default 'Economy',
  add column if not exists payment_method text default 'Cash',
  add column if not exists payment_status text default 'pending',
  add column if not exists payment_reference text,
  add column if not exists distance_km numeric(10,2),
  add column if not exists pickup_lat double precision,
  add column if not exists pickup_lng double precision,
  add column if not exists dest_lat double precision,
  add column if not exists dest_lng double precision;

-- 3. Dynamic Fare Calculation Schema table
create table if not exists public.fare_schemas (
  id text primary key default 'default',
  base_fare numeric(10,2) not null default 15.00,
  per_km_rate numeric(10,2) not null default 5.00,
  min_fare numeric(10,2) not null default 20.00,
  currency_symbol text not null default 'R',
  created_at timestamp with time zone default timezone('utc', now()) not null,
  updated_at timestamp with time zone default timezone('utc', now()) not null
);

-- Insert default fare schema (R15 base fare + R5/km)
insert into public.fare_schemas (id, base_fare, per_km_rate, min_fare, currency_symbol)
values ('default', 15.00, 5.00, 20.00, 'R')
on conflict (id) do update set
  base_fare = excluded.base_fare,
  per_km_rate = excluded.per_km_rate,
  min_fare = excluded.min_fare,
  updated_at = timezone('utc', now());

-- 4. User Saved Places table
create table if not exists public.saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  address text not null,
  lat double precision,
  lng double precision,
  created_at timestamp with time zone default timezone('utc', now()) not null
);

-- Index for fast saved places queries
create index if not exists idx_saved_places_user_id on public.saved_places(user_id);
