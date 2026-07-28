-- Migration: 20260728221500_driver_schema_updates.sql
-- Adds driver vehicle details, banking info, and verification status to profiles & driver tables

alter table public.profiles
  add column if not exists id_number text,
  add column if not exists license_number text,
  add column if not exists operating_city text default 'Johannesburg',
  add column if not exists driver_status text default 'pending' check (driver_status in ('pending', 'under_review', 'approved', 'rejected')),
  add column if not exists vehicle_make text,
  add column if not exists vehicle_model text,
  add column if not exists vehicle_year text,
  add column if not exists vehicle_color text,
  add column if not exists vehicle_plate text,
  add column if not exists vehicle_category text default 'TRYP Go',
  add column if not exists bank_name text,
  add column if not exists bank_account_number text,
  add column if not exists bank_branch_code text,
  add column if not exists bank_account_holder text;

-- Create index on driver status
create index if not exists idx_profiles_driver_status on public.profiles(driver_status);
