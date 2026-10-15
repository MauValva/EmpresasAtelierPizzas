-- Etapa 05: ingredientes e controle de estoque compartilhado.

create table if not exists public.inventory_items (
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

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  movement_type text not null check (movement_type in ('opening_balance', 'manual_in', 'manual_out', 'adjustment')),
  quantity_delta numeric(18,3) not null check (quantity_delta <> 0),
  unit_cost_snapshot numeric(18,6) not null default 0 check (unit_cost_snapshot >= 0),
  total_cost_snapshot numeric(18,6) not null default 0,
  previous_quantity numeric(18,3) not null,
  resulting_quantity numeric(18,3) not null,
  reason text not null check (btrim(reason) <> ''),
  source_type text not null default 'manual' check (source_type in ('opening', 'manual', 'adjustment', 'purchase', 'sale', 'reversal')),
  source_id uuid,
  created_by uuid not null references auth.users(id) on delete restrict,
  operation_key uuid unique,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists inventory_items_name_trgm_idx on public.inventory_items using gin (name gin_trgm_ops);
create index if not exists inventory_items_category_idx on public.inventory_items(category);
create index if not exists inventory_items_status_idx on public.inventory_items(is_active, current_quantity, minimum_quantity);
create index if not exists inventory_movements_item_created_idx on public.inventory_movements(inventory_item_id, created_at desc);
create index if not exists inventory_movements_created_by_idx on public.inventory_movements(created_by);

drop trigger if exists inventory_items_set_updated_at on public.inventory_items;
create trigger inventory_items_set_updated_at before update on public.inventory_items for each row execute function public.set_updated_at();

alter table public.inventory_items enable row level security;
alter table public.inventory_movements enable row level security;

revoke all on table public.inventory_items from anon, authenticated;
revoke all on table public.inventory_movements from anon, authenticated;
grant select on table public.inventory_items to authenticated;
grant insert (name, category, unit, minimum_quantity, is_active, notes) on table public.inventory_items to authenticated;
grant update (name, category, unit, minimum_quantity, is_active, notes) on table public.inventory_items to authenticated;
grant select on table public.inventory_movements to authenticated;

drop policy if exists "authorized admins read inventory items" on public.inventory_items;
create policy "authorized admins read inventory items"
on public.inventory_items for select to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));

drop policy if exists "authorized admins create inventory items" on public.inventory_items;
create policy "authorized admins create inventory items"
on public.inventory_items for insert to authenticated
with check (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));

drop policy if exists "authorized admins update inventory metadata" on public.inventory_items;
create policy "authorized admins update inventory metadata"
on public.inventory_items for update to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'))
with check (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));

create or replace function public.prevent_inventory_unit_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.unit is distinct from old.unit and exists (select 1 from public.inventory_movements where inventory_item_id = old.id) then
    raise exception using message = 'UNIT_IMMUTABLE_AFTER_MOVEMENT';
  end if;
  return new;
end;
$$;

drop trigger if exists inventory_items_unit_immutable on public.inventory_items;
create trigger inventory_items_unit_immutable before update on public.inventory_items for each row execute function public.prevent_inventory_unit_change();

drop policy if exists "authorized admins read inventory movements" on public.inventory_movements;
create policy "authorized admins read inventory movements"
on public.inventory_movements for select to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));

create or replace function public.register_inventory_movement(
  p_inventory_item_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_unit_cost numeric default null,
  p_reason text default null,
  p_operation_key uuid default null
)
returns public.inventory_movements
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  item public.inventory_items;
  existing public.inventory_movements;
  movement public.inventory_movements;
  previous numeric(18,3);
  delta numeric(18,3);
  resulting numeric(18,3);
  previous_cost numeric(18,6);
  applied_cost numeric(18,6);
  new_average numeric(18,6);
  reason_text text := btrim(coalesce(p_reason, ''));
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_inventory_item_id is null then raise exception using message = 'INVENTORY_ITEM_REQUIRED'; end if;
  if p_movement_type not in ('opening_balance', 'manual_in', 'manual_out', 'adjustment') then raise exception using message = 'INVALID_MOVEMENT_TYPE'; end if;
  if p_quantity is null or p_quantity < 0 or (p_movement_type <> 'adjustment' and p_quantity = 0) then raise exception using message = 'QUANTITY_MUST_BE_NON_NEGATIVE'; end if;
  if reason_text = '' then raise exception using message = 'REASON_REQUIRED'; end if;
  if p_unit_cost is not null and p_unit_cost < 0 then raise exception using message = 'UNIT_COST_MUST_BE_NON_NEGATIVE'; end if;

  if p_operation_key is not null then
    select * into existing from public.inventory_movements where operation_key = p_operation_key;
    if found then return existing; end if;
  end if;

  select * into item from public.inventory_items where id = p_inventory_item_id for update;
  if not found then raise exception using message = 'INVENTORY_ITEM_NOT_FOUND'; end if;
  if not item.is_active then raise exception using message = 'INVENTORY_ITEM_INACTIVE'; end if;

  previous := item.current_quantity;
  previous_cost := item.average_unit_cost;

  if p_movement_type = 'adjustment' then
    delta := p_quantity - previous;
    if delta = 0 then raise exception using message = 'ADJUSTMENT_HAS_NO_DIFFERENCE'; end if;
    applied_cost := previous_cost;
    new_average := previous_cost;
  elsif p_movement_type = 'manual_out' then
    delta := -p_quantity;
    applied_cost := previous_cost;
    new_average := previous_cost;
  else
    delta := p_quantity;
    applied_cost := coalesce(p_unit_cost, previous_cost, 0);
    -- Entradas sobre saldo zero ou negativo adotam o custo da entrada.
    -- Isso evita custo médio negativo ou distorcido após regularizar um saldo negativo.
    if previous > 0 and previous + p_quantity > 0 then
      new_average := ((previous * previous_cost) + (p_quantity * applied_cost)) / (previous + p_quantity);
    else
      new_average := applied_cost;
    end if;
  end if;

  resulting := previous + delta;
  update public.inventory_items
  set current_quantity = resulting, average_unit_cost = greatest(new_average, 0), updated_at = timezone('utc', now())
  where id = item.id;

  insert into public.inventory_movements (inventory_item_id, movement_type, quantity_delta, unit_cost_snapshot, total_cost_snapshot, previous_quantity, resulting_quantity, reason, source_type, created_by, operation_key)
  values (item.id, p_movement_type, delta, applied_cost, delta * applied_cost, previous, resulting, reason_text, case when p_movement_type = 'opening_balance' then 'opening' when p_movement_type = 'adjustment' then 'adjustment' else 'manual' end, (select auth.uid()), p_operation_key)
  returning * into movement;
  return movement;
end;
$$;

revoke all on function public.register_inventory_movement(uuid, text, numeric, numeric, text, uuid) from public, anon, authenticated;
grant execute on function public.register_inventory_movement(uuid, text, numeric, numeric, text, uuid) to authenticated;
