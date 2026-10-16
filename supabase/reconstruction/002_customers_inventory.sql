-- Clientes compartilhados e estoque aproximado.

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  phone text,
  phone_normalized text,
  apartment text,
  address text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  category text,
  unit text not null check (unit in ('g', 'ml', 'un')),
  current_quantity numeric(18,3) not null default 0,
  average_unit_cost numeric(18,6) not null default 0 check (average_unit_cost >= 0),
  minimum_quantity numeric(18,3) not null default 0 check (minimum_quantity >= 0),
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  movement_type text not null check (movement_type in ('opening', 'manual_in', 'manual_out', 'sale', 'expense', 'adjustment')),
  quantity_delta numeric(18,3) not null check (quantity_delta <> 0),
  unit_cost_snapshot numeric(18,6) not null default 0 check (unit_cost_snapshot >= 0),
  total_cost_snapshot numeric(18,6) not null default 0 check (total_cost_snapshot >= 0),
  previous_quantity numeric(18,3) not null,
  resulting_quantity numeric(18,3) not null,
  source_type text not null default 'manual',
  source_id uuid,
  reason text,
  created_by uuid not null references auth.users(id) on delete restrict,
  operation_key uuid not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create index customers_name_idx on public.customers(name);
create index customers_phone_idx on public.customers(phone_normalized) where phone_normalized is not null;
create index inventory_items_name_idx on public.inventory_items(name);
create index inventory_items_status_idx on public.inventory_items(is_active, current_quantity, minimum_quantity);
create index inventory_movements_item_created_idx on public.inventory_movements(inventory_item_id, created_at desc);
create index inventory_movements_source_idx on public.inventory_movements(source_type, source_id);

create trigger customers_set_updated_at before update on public.customers
for each row execute function public.set_updated_at();
create trigger inventory_items_set_updated_at before update on public.inventory_items
for each row execute function public.set_updated_at();
