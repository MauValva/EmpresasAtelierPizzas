-- Pedidos, vendas, pagamentos e baixa aproximada de ingredientes.

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete restrict,
  order_number bigint generated always as identity unique,
  record_type text not null check (record_type in ('order', 'sale')),
  status text not null check (status in ('open', 'paid', 'cancelled')),
  transaction_date timestamptz not null default timezone('utc', now()),
  scheduled_for timestamptz,
  subtotal numeric(18,6) not null default 0 check (subtotal >= 0),
  discount_total numeric(18,6) not null default 0 check (discount_total >= 0),
  total_amount numeric(18,6) not null default 0 check (total_amount >= 0),
  notes text,
  paid_at timestamptz,
  cancelled_at timestamptz,
  operation_key uuid unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check ((record_type = 'order' and status in ('open', 'cancelled')) or (record_type = 'sale' and status in ('paid', 'cancelled'))),
  check (record_type = 'order' or scheduled_for is null)
);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_variant_id uuid not null references public.product_variants(id) on delete restrict,
  product_name_snapshot text not null,
  variant_name_snapshot text not null,
  quantity integer not null check (quantity > 0),
  unit_price_snapshot numeric(18,6) not null check (unit_price_snapshot >= 0),
  subtotal numeric(18,6) not null check (subtotal >= 0),
  unit_cost_snapshot numeric(18,6),
  total_cost_snapshot numeric(18,6),
  created_at timestamptz not null default timezone('utc', now())
);

create table public.sale_payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null unique references public.sales(id) on delete restrict,
  amount numeric(18,6) not null check (amount > 0),
  payment_method text not null check (payment_method in ('pix', 'cash', 'card', 'other')),
  paid_at timestamptz not null default timezone('utc', now()),
  operation_key uuid not null unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now())
);

create index sales_company_date_idx on public.sales(company_id, transaction_date desc);
create index sales_type_status_idx on public.sales(record_type, status, transaction_date desc);
create index sales_customer_date_idx on public.sales(customer_id, transaction_date desc);
create index sale_items_sale_idx on public.sale_items(sale_id);
create index sale_items_variant_idx on public.sale_items(product_variant_id);
create index sale_payments_paid_at_idx on public.sale_payments(paid_at desc);

create trigger sales_set_updated_at before update on public.sales
for each row execute function public.set_updated_at();

create or replace function public.register_inventory_movement(
  p_inventory_item_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_unit_cost numeric default null,
  p_source_type text default 'manual',
  p_source_id uuid default null,
  p_operation_key uuid default null,
  p_reason text default null
)
returns public.inventory_movements
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_existing public.inventory_movements;
  v_item public.inventory_items;
  v_delta numeric(18,3);
  v_cost numeric(18,6);
  v_total numeric(18,6);
  v_resulting numeric(18,3);
  v_average numeric(18,6);
  v_movement public.inventory_movements;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_operation_key is null then raise exception using message = 'OPERATION_KEY_REQUIRED'; end if;
  select * into v_existing from public.inventory_movements where operation_key = p_operation_key;
  if found then return v_existing; end if;
  select * into v_item from public.inventory_items where id = p_inventory_item_id for update;
  if not found then raise exception using message = 'INVENTORY_ITEM_NOT_FOUND'; end if;
  if p_quantity is null or (p_movement_type = 'adjustment' and p_quantity = 0) or (p_movement_type <> 'adjustment' and p_quantity <= 0) then raise exception using message = 'INVALID_MOVEMENT_QUANTITY'; end if;

  v_delta := case
    when p_movement_type in ('manual_out', 'sale') then -abs(p_quantity)
    when p_movement_type in ('opening', 'manual_in', 'expense') then abs(p_quantity)
    when p_movement_type = 'adjustment' then p_quantity
    else null
  end;
  if v_delta is null then raise exception using message = 'INVALID_MOVEMENT_TYPE'; end if;
  v_cost := coalesce(p_unit_cost, v_item.average_unit_cost);
  if v_cost < 0 then raise exception using message = 'INVALID_UNIT_COST'; end if;
  v_resulting := v_item.current_quantity + v_delta;
  v_total := abs(v_delta) * case when v_delta > 0 then v_cost else v_item.average_unit_cost end;
  if v_delta > 0 and v_resulting > 0 then
    v_average := ((v_item.current_quantity * v_item.average_unit_cost) + (v_delta * v_cost)) / v_resulting;
  else
    v_average := v_item.average_unit_cost;
  end if;

  insert into public.inventory_movements(inventory_item_id, movement_type, quantity_delta, unit_cost_snapshot, total_cost_snapshot, previous_quantity, resulting_quantity, source_type, source_id, reason, created_by, operation_key)
  values (p_inventory_item_id, p_movement_type, v_delta, case when v_delta > 0 then v_cost else v_item.average_unit_cost end, v_total, v_item.current_quantity, v_resulting, p_source_type, p_source_id, p_reason, auth.uid(), p_operation_key)
  returning * into v_movement;

  update public.inventory_items set current_quantity = v_resulting, average_unit_cost = greatest(v_average, 0) where id = p_inventory_item_id;
  return v_movement;
end;
$$;

create or replace function public.create_sale(
  p_company_id uuid,
  p_customer_id uuid,
  p_record_type text,
  p_scheduled_for timestamptz,
  p_items jsonb,
  p_notes text default null,
  p_payment_method text default null,
  p_payment_operation_key uuid default null,
  p_operation_key uuid default null
)
returns public.sales
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sale public.sales;
  v_item jsonb;
  v_variant record;
  v_quantity integer;
  v_unit_price numeric(18,6);
  v_subtotal numeric(18,6) := 0;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_record_type not in ('order', 'sale') then raise exception using message = 'INVALID_RECORD_TYPE'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception using message = 'SALE_ITEMS_REQUIRED'; end if;
  if p_record_type = 'sale' and (p_payment_method is null or p_payment_operation_key is null) then raise exception using message = 'PAYMENT_REQUIRED'; end if;
  if p_operation_key is not null then
    select * into v_sale from public.sales where operation_key = p_operation_key;
    if found then return v_sale; end if;
  end if;

  insert into public.sales(company_id, customer_id, record_type, status, scheduled_for, notes, operation_key, created_by)
  values (p_company_id, p_customer_id, 'order', 'open', case when p_record_type = 'order' then p_scheduled_for else null end, p_notes, p_operation_key, auth.uid())
  returning * into v_sale;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select pv.id, pv.name as variant_name, pv.price, p.name as product_name
    into v_variant
    from public.product_variants pv
    join public.products p on p.id = pv.product_id
    where pv.id = (v_item->>'product_variant_id')::uuid and pv.is_active and p.is_active and p.company_id = p_company_id;
    if not found then raise exception using message = 'PRODUCT_VARIANT_NOT_FOUND'; end if;
    v_quantity := (v_item->>'quantity')::integer;
    if v_quantity is null or v_quantity <= 0 then raise exception using message = 'INVALID_QUANTITY'; end if;
    v_unit_price := coalesce((v_item->>'unit_price')::numeric, v_variant.price);
    if v_unit_price < 0 then raise exception using message = 'INVALID_PRICE'; end if;
    insert into public.sale_items(sale_id, product_variant_id, product_name_snapshot, variant_name_snapshot, quantity, unit_price_snapshot, subtotal)
    values (v_sale.id, v_variant.id, v_variant.product_name, v_variant.variant_name, v_quantity, v_unit_price, v_quantity * v_unit_price);
    v_subtotal := v_subtotal + (v_quantity * v_unit_price);
  end loop;

  update public.sales set subtotal = v_subtotal, total_amount = v_subtotal where id = v_sale.id returning * into v_sale;
  if p_record_type = 'sale' then
    select * into v_sale from public.finalize_sale(v_sale.id, p_payment_method, p_payment_operation_key);
  end if;
  return v_sale;
end;
$$;

create or replace function public.finalize_sale(
  p_sale_id uuid,
  p_payment_method text,
  p_payment_operation_key uuid
)
returns public.sales
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sale public.sales;
  v_item record;
  v_recipe record;
  v_ingredient record;
  v_consumed numeric;
  v_unit_cost numeric;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then raise exception using message = 'SALE_NOT_FOUND'; end if;
  if v_sale.status = 'paid' then return v_sale; end if;
  if v_sale.record_type <> 'order' or v_sale.status <> 'open' then raise exception using message = 'SALE_NOT_OPEN'; end if;
  if p_payment_method not in ('pix', 'cash', 'card', 'other') or p_payment_operation_key is null then raise exception using message = 'PAYMENT_REQUIRED'; end if;

  for v_item in select si.*, pv.recipe_id, pv.recipe_portions from public.sale_items si join public.product_variants pv on pv.id = si.product_variant_id where si.sale_id = p_sale_id order by si.created_at, si.id loop
    if v_item.recipe_id is null then continue; end if;
    select * into v_recipe from public.recipes where id = v_item.recipe_id and is_active for share;
    if not found then continue; end if;
    for v_ingredient in select ri.*, ii.average_unit_cost from public.recipe_ingredients ri join public.inventory_items ii on ii.id = ri.inventory_item_id where ri.recipe_id = v_item.recipe_id loop
      v_consumed := v_ingredient.quantity_base * v_item.recipe_portions * v_item.quantity / v_recipe.yield_quantity;
      v_unit_cost := v_ingredient.average_unit_cost;
      perform public.register_inventory_movement(v_ingredient.inventory_item_id, 'sale', v_consumed, null, 'sale', v_item.id, gen_random_uuid(), 'Venda #' || v_sale.order_number);
    end loop;
  end loop;

  update public.sale_items si set unit_cost_snapshot = costs.unit_cost, total_cost_snapshot = costs.total_cost
  from (
    select si.id, coalesce(sum(im.total_cost_snapshot), 0) / nullif(si.quantity, 0) as unit_cost, coalesce(sum(im.total_cost_snapshot), 0) as total_cost
    from public.sale_items si join public.inventory_movements im on im.source_type = 'sale' and im.source_id = si.id
    where si.sale_id = p_sale_id group by si.id, si.quantity
  ) costs where si.id = costs.id;

  insert into public.sale_payments(sale_id, amount, payment_method, operation_key, created_by)
  values (p_sale_id, v_sale.total_amount, p_payment_method, p_payment_operation_key, auth.uid())
  on conflict (sale_id) do nothing;

  update public.sales set record_type = 'sale', status = 'paid', paid_at = timezone('utc', now()), transaction_date = timezone('utc', now()) where id = p_sale_id returning * into v_sale;
  return v_sale;
end;
$$;

create or replace function public.cancel_open_sale(p_sale_id uuid)
returns public.sales
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_sale public.sales;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  update public.sales set status = 'cancelled', cancelled_at = timezone('utc', now()) where id = p_sale_id and record_type = 'order' and status = 'open' returning * into v_sale;
  if not found then raise exception using message = 'ONLY_OPEN_ORDERS_CAN_BE_CANCELLED'; end if;
  return v_sale;
end;
$$;
