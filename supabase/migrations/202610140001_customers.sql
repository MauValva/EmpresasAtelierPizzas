-- Etapa 04: cadastro global de clientes.

create extension if not exists pg_trgm;

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  phone text,
  phone_normalized text,
  apartment text,
  address text,
  notes text,
  marketing_consent boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists customers_name_trgm_idx on public.customers using gin (name gin_trgm_ops);
create index if not exists customers_phone_normalized_idx on public.customers(phone_normalized) where phone_normalized is not null;
create index if not exists customers_active_name_idx on public.customers(is_active, name);

drop trigger if exists customers_set_updated_at on public.customers;
create trigger customers_set_updated_at before update on public.customers for each row execute function public.set_updated_at();

alter table public.customers enable row level security;

revoke all on table public.customers from anon, authenticated;
grant select, insert, update on table public.customers to authenticated;

drop policy if exists "authorized admins read customers" on public.customers;
create policy "authorized admins read customers"
on public.customers for select to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));

drop policy if exists "authorized admins create customers" on public.customers;
create policy "authorized admins create customers"
on public.customers for insert to authenticated
with check (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));

drop policy if exists "authorized admins update customers" on public.customers;
create policy "authorized admins update customers"
on public.customers for update to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'))
with check (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));
