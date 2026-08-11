-- Long distance trip listings posted by drivers
create table if not exists public.long_distance_trips (
  id            uuid primary key default gen_random_uuid(),
  driver_id     uuid not null references public.profiles(id) on delete cascade,
  origin        text not null,
  destination   text not null,
  departure_at  timestamptz not null,
  seats_available int not null default 4 check (seats_available between 1 and 8),
  seats_booked    int not null default 0,
  price_per_seat  numeric(10,2) not null,
  notes         text,
  status        text not null default 'active'
                  check (status in ('active','completed','cancelled')),
  created_at    timestamptz not null default now()
);

-- Passenger bookings for long distance trips
create table if not exists public.long_distance_bookings (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.long_distance_trips(id) on delete cascade,
  passenger_id  uuid not null references public.profiles(id) on delete cascade,
  seats         int not null default 1,
  amount_paid   numeric(10,2) not null,
  payment_method text not null default 'Paystack Card',
  status        text not null default 'pending'
                  check (status in ('pending','confirmed','cancelled')),
  created_at    timestamptz not null default now()
);

-- Row-level security
alter table public.long_distance_trips enable row level security;
alter table public.long_distance_bookings enable row level security;

-- Drivers can manage their own trips
create policy "drivers_manage_own_ld_trips"
  on public.long_distance_trips
  for all
  using (driver_id = auth.uid())
  with check (driver_id = auth.uid());

-- Anyone authenticated can view active trips
create policy "passengers_view_active_ld_trips"
  on public.long_distance_trips
  for select
  using (status = 'active');

-- Passengers manage their own bookings
create policy "passengers_manage_own_bookings"
  on public.long_distance_bookings
  for all
  using (passenger_id = auth.uid())
  with check (passenger_id = auth.uid());

-- Drivers can see bookings for their trips
create policy "drivers_view_trip_bookings"
  on public.long_distance_bookings
  for select
  using (
    trip_id in (
      select id from public.long_distance_trips where driver_id = auth.uid()
    )
  );
