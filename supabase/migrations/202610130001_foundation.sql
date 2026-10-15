-- Etapa 02: perfis autorizados, empresas e configurações globais.
-- A migration não cria usuários Auth; o primeiro administrador é criado manualmente.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'admin' check (role = 'admin'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  is_active boolean not null default true,
  color text not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  description text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists profiles_role_idx on public.profiles(role);
create index if not exists companies_active_name_idx on public.companies(is_active, name);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists companies_set_updated_at on public.companies;
create trigger companies_set_updated_at before update on public.companies for each row execute function public.set_updated_at();
drop trigger if exists app_settings_set_updated_at on public.app_settings;
create trigger app_settings_set_updated_at before update on public.app_settings for each row execute function public.set_updated_at();

insert into public.companies (name, slug, color)
values
  ('Atelier do Pão', 'atelier-do-pao', '#D5A66D'),
  ('Pizzas do Condomínio', 'pizzas-do-condominio', '#81B5D9')
on conflict (slug) do update set name = excluded.name, color = excluded.color, is_active = true;

insert into public.app_settings (key, value, description)
values (
  'shared_expense_allocation',
  '{"atelier_do_pao": 50, "pizzas_do_condominio": 50}'::jsonb,
  'Percentuais futuros para rateio de despesas compartilhadas. Não calcula valores nesta etapa.'
)
on conflict (key) do nothing;

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.app_settings enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.companies from anon, authenticated;
revoke all on table public.app_settings from anon, authenticated;
grant select on table public.profiles to authenticated;
grant select on table public.companies to authenticated;
grant select on table public.app_settings to authenticated;

drop policy if exists "authorized users read own profile" on public.profiles;
create policy "authorized users read own profile"
on public.profiles for select to authenticated
using ((select auth.uid()) = id and role = 'admin');

drop policy if exists "authorized users read active companies" on public.companies;
create policy "authorized users read active companies"
on public.companies for select to authenticated
using (
  is_active = true
  and exists (
    select 1 from public.profiles
    where profiles.id = (select auth.uid()) and profiles.role = 'admin'
  )
);

drop policy if exists "authorized users read app settings" on public.app_settings;
create policy "authorized users read app settings"
on public.app_settings for select to authenticated
using (
  exists (
    select 1 from public.profiles
    where profiles.id = (select auth.uid()) and profiles.role = 'admin'
  )
);
