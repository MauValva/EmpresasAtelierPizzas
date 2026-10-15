-- Etapa 06: fornecedores, compras, recebimento e pagamentos preparatórios.

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  contact_name text,
  phone text,
  email text,
  document_number text,
  address text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  company_id uuid references public.companies(id) on delete restrict,
  purchase_date date not null default current_date,
  received_at timestamptz,
  received_by uuid references auth.users(id) on delete restrict,
  status text not null default 'draft' check (status in ('draft', 'ordered', 'received', 'cancelled')),
  payment_status text not null default 'pending' check (payment_status in ('pending', 'partial', 'paid')),
  notes text,
  subtotal numeric(18,6) not null default 0 check (subtotal >= 0),
  additional_costs numeric(18,6) not null default 0 check (additional_costs >= 0),
  discount numeric(18,6) not null default 0 check (discount >= 0),
  total_amount numeric(18,6) not null default 0 check (total_amount >= 0),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_cost numeric(18,6) not null check (unit_cost >= 0),
  total_cost numeric(18,6) generated always as (quantity * unit_cost) stored,
  receipt_operation_key uuid not null default gen_random_uuid() unique,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.purchase_payments (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete restrict,
  amount numeric(18,6) not null check (amount > 0),
  paid_at timestamptz not null default timezone('utc', now()),
  payment_method text not null check (payment_method in ('pix', 'cash', 'card', 'other')),
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  operation_key uuid not null default gen_random_uuid() unique,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists suppliers_name_idx on public.suppliers(name);
create index if not exists suppliers_active_idx on public.suppliers(is_active);
create index if not exists purchases_date_status_idx on public.purchases(purchase_date desc, status);
create index if not exists purchases_supplier_idx on public.purchases(supplier_id, purchase_date desc);
create index if not exists purchase_items_purchase_idx on public.purchase_items(purchase_id);
create index if not exists purchase_items_inventory_idx on public.purchase_items(inventory_item_id);
create index if not exists purchase_payments_purchase_idx on public.purchase_payments(purchase_id, paid_at desc);

drop trigger if exists suppliers_set_updated_at on public.suppliers;
create trigger suppliers_set_updated_at before update on public.suppliers for each row execute function public.set_updated_at();
drop trigger if exists purchases_set_updated_at on public.purchases;
create trigger purchases_set_updated_at before update on public.purchases for each row execute function public.set_updated_at();

create or replace function public.recalculate_purchase_totals()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  purchase_id_value uuid := coalesce(new.purchase_id, old.purchase_id);
begin
  update public.purchases p
  set subtotal = coalesce((select sum(total_cost) from public.purchase_items where purchase_id = purchase_id_value), 0),
      total_amount = greatest(coalesce((select sum(total_cost) from public.purchase_items where purchase_id = purchase_id_value), 0) + p.additional_costs - p.discount, 0),
      updated_at = timezone('utc', now())
  where p.id = purchase_id_value;
  return coalesce(new, old);
end;
$$;

drop trigger if exists purchase_items_recalculate_totals on public.purchase_items;
create trigger purchase_items_recalculate_totals after insert or update or delete on public.purchase_items for each row execute function public.recalculate_purchase_totals();

create or replace function public.prevent_received_purchase_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if old.status = 'received' and (
    new.supplier_id is distinct from old.supplier_id or
    new.company_id is distinct from old.company_id or
    new.purchase_date is distinct from old.purchase_date or
    new.received_at is distinct from old.received_at or
    new.received_by is distinct from old.received_by or
    new.status is distinct from old.status or
    new.notes is distinct from old.notes or
    new.subtotal is distinct from old.subtotal or
    new.additional_costs is distinct from old.additional_costs or
    new.discount is distinct from old.discount or
    new.total_amount is distinct from old.total_amount or
    new.created_by is distinct from old.created_by
  ) then
    raise exception using message = 'RECEIVED_PURCHASE_IMMUTABLE';
  end if;
  return new;
end;
$$;

drop trigger if exists purchases_received_immutable on public.purchases;
create trigger purchases_received_immutable before update on public.purchases for each row execute function public.prevent_received_purchase_change();

create or replace function public.prevent_received_purchase_item_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare purchase_status text;
begin
  select status into purchase_status from public.purchases where id = coalesce(new.purchase_id, old.purchase_id);
  if purchase_status = 'received' then raise exception using message = 'RECEIVED_PURCHASE_ITEMS_IMMUTABLE'; end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists purchase_items_received_immutable on public.purchase_items;
create trigger purchase_items_received_immutable before insert or update or delete on public.purchase_items for each row execute function public.prevent_received_purchase_item_change();

alter table public.suppliers enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.purchase_payments enable row level security;

revoke all on table public.suppliers, public.purchases, public.purchase_items, public.purchase_payments from anon, authenticated;
grant select, insert, update on table public.suppliers to authenticated;
grant select, insert, update on table public.purchases to authenticated;
grant select, insert, update, delete on table public.purchase_items to authenticated;
grant select on table public.purchase_payments to authenticated;

create policy "authorized admins manage suppliers" on public.suppliers for all to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'))
with check (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));
create policy "authorized admins manage purchases" on public.purchases for all to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'))
with check (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));
create policy "authorized admins manage purchase items" on public.purchase_items for all to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'))
with check (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));
create policy "authorized admins read purchase payments" on public.purchase_payments for select to authenticated
using (exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin'));

-- Wrapper que reutiliza o cálculo transacional da Etapa 05 e apenas anota a origem.
create or replace function public.register_purchase_inventory_movement(
  p_inventory_item_id uuid,
  p_quantity numeric,
  p_unit_cost numeric,
  p_reason text,
  p_operation_key uuid,
  p_purchase_id uuid
)
returns public.inventory_movements
language plpgsql security definer set search_path = public, pg_temp as $$
declare movement public.inventory_movements;
begin
  movement := public.register_inventory_movement(p_inventory_item_id, 'manual_in', p_quantity, p_unit_cost, p_reason, p_operation_key);
  update public.inventory_movements
  set source_type = 'purchase', source_id = p_purchase_id
  where id = movement.id;
  select * into movement from public.inventory_movements where id = movement.id;
  return movement;
end;
$$;

create or replace function public.receive_purchase(p_purchase_id uuid)
returns public.purchases
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  purchase_record public.purchases;
  purchase_item record;
  item_count integer := 0;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select * into purchase_record from public.purchases where id = p_purchase_id for update;
  if not found then raise exception using message = 'PURCHASE_NOT_FOUND'; end if;
  if purchase_record.status = 'received' then return purchase_record; end if;
  if purchase_record.status = 'cancelled' then raise exception using message = 'CANCELLED_PURCHASE'; end if;

  for purchase_item in
    select pi.*, ii.name as item_name, ii.unit as item_unit
    from public.purchase_items pi join public.inventory_items ii on ii.id = pi.inventory_item_id
    where pi.purchase_id = p_purchase_id
    order by pi.created_at, pi.id
  loop
    item_count := item_count + 1;
    if purchase_item.quantity <= 0 or purchase_item.unit_cost < 0 then raise exception using message = 'INVALID_PURCHASE_ITEM'; end if;
    perform public.register_purchase_inventory_movement(purchase_item.inventory_item_id, purchase_item.quantity, purchase_item.unit_cost, 'Compra ' || p_purchase_id::text || ' recebida', purchase_item.receipt_operation_key, p_purchase_id);
  end loop;
  if item_count = 0 then raise exception using message = 'PURCHASE_WITHOUT_ITEMS'; end if;

  update public.purchases set status = 'received', received_at = timezone('utc', now()), received_by = (select auth.uid()), updated_at = timezone('utc', now()) where id = p_purchase_id returning * into purchase_record;
  return purchase_record;
end;
$$;

create or replace function public.create_purchase_draft(
  p_supplier_id uuid,
  p_company_id uuid,
  p_purchase_date date,
  p_notes text,
  p_additional_costs numeric,
  p_discount numeric,
  p_items jsonb
)
returns public.purchases
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  purchase_record public.purchases;
  purchase_item record;
  item_count integer := 0;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_supplier_id is null or not exists (select 1 from public.suppliers where id = p_supplier_id and is_active) then raise exception using message = 'ACTIVE_SUPPLIER_REQUIRED'; end if;
  if coalesce(p_additional_costs, 0) < 0 or coalesce(p_discount, 0) < 0 then raise exception using message = 'PURCHASE_COST_INVALID'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then raise exception using message = 'PURCHASE_ITEMS_INVALID'; end if;

  insert into public.purchases (supplier_id, company_id, purchase_date, notes, additional_costs, discount, created_by)
  values (p_supplier_id, p_company_id, coalesce(p_purchase_date, current_date), nullif(btrim(coalesce(p_notes, '')), ''), coalesce(p_additional_costs, 0), coalesce(p_discount, 0), (select auth.uid()))
  returning * into purchase_record;

  for purchase_item in select * from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as x(inventory_item_id uuid, quantity numeric, unit_cost numeric)
  loop
    item_count := item_count + 1;
    if purchase_item.inventory_item_id is null or not exists (select 1 from public.inventory_items where id = purchase_item.inventory_item_id and is_active) then raise exception using message = 'ACTIVE_INVENTORY_ITEM_REQUIRED'; end if;
    if purchase_item.quantity is null or purchase_item.quantity <= 0 or purchase_item.unit_cost is null or purchase_item.unit_cost < 0 then raise exception using message = 'PURCHASE_ITEM_VALUES_INVALID'; end if;
    insert into public.purchase_items (purchase_id, inventory_item_id, quantity, unit_cost) values (purchase_record.id, purchase_item.inventory_item_id, purchase_item.quantity, purchase_item.unit_cost);
  end loop;
  if item_count = 0 then raise exception using message = 'PURCHASE_WITHOUT_ITEMS'; end if;
  select * into purchase_record from public.purchases where id = purchase_record.id;
  return purchase_record;
end;
$$;

create or replace function public.register_purchase_payment(
  p_purchase_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_notes text default null,
  p_operation_key uuid default null
)
returns public.purchase_payments
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  purchase_record public.purchases;
  payment public.purchase_payments;
  operation_payment public.purchase_payments;
  paid_total numeric;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where profiles.id = (select auth.uid()) and profiles.role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception using message = 'PAYMENT_AMOUNT_INVALID'; end if;
  if p_payment_method not in ('pix', 'cash', 'card', 'other') then raise exception using message = 'PAYMENT_METHOD_INVALID'; end if;
  if p_operation_key is not null then
    select * into operation_payment from public.purchase_payments where operation_key = p_operation_key;
    if found then return operation_payment; end if;
  end if;
  select * into purchase_record from public.purchases where id = p_purchase_id for update;
  if not found then raise exception using message = 'PURCHASE_NOT_FOUND'; end if;
  paid_total := coalesce((select sum(amount) from public.purchase_payments where purchase_id = p_purchase_id), 0);
  if paid_total + p_amount > purchase_record.total_amount then raise exception using message = 'PAYMENT_EXCEEDS_BALANCE'; end if;
  insert into public.purchase_payments (purchase_id, amount, payment_method, notes, created_by, operation_key)
  values (p_purchase_id, p_amount, p_payment_method, nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid()), p_operation_key)
  returning * into payment;
  update public.purchases set payment_status = case when paid_total + p_amount = total_amount then 'paid' else 'partial' end, updated_at = timezone('utc', now()) where id = p_purchase_id;
  return payment;
end;
$$;

revoke all on function public.register_purchase_inventory_movement(uuid, numeric, numeric, text, uuid, uuid) from public, anon, authenticated;
revoke all on function public.receive_purchase(uuid) from public, anon, authenticated;
revoke all on function public.create_purchase_draft(uuid, uuid, date, text, numeric, numeric, jsonb) from public, anon, authenticated;
revoke all on function public.register_purchase_payment(uuid, numeric, text, text, uuid) from public, anon, authenticated;
grant execute on function public.register_purchase_inventory_movement(uuid, numeric, numeric, text, uuid, uuid) to authenticated;
grant execute on function public.receive_purchase(uuid) to authenticated;
grant execute on function public.create_purchase_draft(uuid, uuid, date, text, numeric, numeric, jsonb) to authenticated;
grant execute on function public.register_purchase_payment(uuid, numeric, text, text, uuid) to authenticated;
