-- Etapa 08: vendas, encomendas, snapshots e baixa transacional de estoque.

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  order_number bigint generated always as identity,
  order_status text not null default 'draft' check (order_status in ('draft', 'confirmed', 'completed', 'cancelled')),
  fulfillment_status text not null default 'pending' check (fulfillment_status in ('pending', 'preparing', 'ready', 'delivered')),
  payment_status text not null default 'pending' check (payment_status in ('pending', 'partial', 'paid', 'refunded')),
  order_date timestamptz not null default timezone('utc', now()),
  confirmed_at timestamptz,
  scheduled_for timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  subtotal numeric(18,6) not null default 0 check (subtotal >= 0),
  discount_total numeric(18,6) not null default 0 check (discount_total >= 0),
  total_amount numeric(18,6) not null default 0 check (total_amount >= 0),
  estimated_cogs numeric(18,6),
  notes text,
  delivery_address_snapshot text,
  apartment_snapshot text,
  created_by uuid not null references auth.users(id) on delete restrict,
  confirmation_operation_key uuid unique,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_variant_id uuid not null references public.product_variants(id) on delete restrict,
  product_name_snapshot text,
  variant_name_snapshot text,
  quantity integer not null check (quantity > 0),
  unit_price_snapshot numeric(18,6),
  original_subtotal numeric(18,6),
  discount_allocated numeric(18,6) not null default 0,
  final_total numeric(18,6),
  recipe_version_id uuid references public.recipe_versions(id) on delete restrict,
  recipe_scale_snapshot numeric(18,6),
  estimated_unit_cost_snapshot numeric(18,6),
  estimated_total_cost_snapshot numeric(18,6),
  cost_status_snapshot text check (cost_status_snapshot in ('complete', 'partial', 'unknown')),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sale_item_ingredient_snapshots (
  id uuid primary key default gen_random_uuid(),
  sale_item_id uuid not null references public.sale_items(id) on delete restrict,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  ingredient_name_snapshot text not null,
  quantity_consumed numeric(18,6) not null check (quantity_consumed > 0),
  unit_cost_snapshot numeric(18,6),
  total_cost_snapshot numeric(18,6),
  cost_status text not null check (cost_status in ('known', 'unknown')),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sale_applied_promotions (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete restrict,
  promotion_id uuid references public.promotions(id) on delete restrict,
  promotion_name_snapshot text not null,
  bundle_quantity integer not null,
  bundle_price numeric(18,6) not null,
  discount_amount numeric(18,6) not null check (discount_amount >= 0),
  variant_ids_snapshot jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sale_adjustments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete restrict,
  adjustment_type text not null check (adjustment_type in ('manual_discount', 'cancellation', 'stock_reversal')),
  amount numeric(18,6) not null check (amount >= 0),
  reason text not null check (btrim(reason) <> ''),
  created_by uuid not null references auth.users(id) on delete restrict,
  operation_key uuid not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sale_status_history (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete restrict,
  order_status text not null,
  fulfillment_status text not null,
  payment_status text not null,
  reason text,
  changed_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sale_stock_reversals (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete restrict,
  original_movement_id uuid not null references public.inventory_movements(id) on delete restrict,
  reversal_movement_id uuid not null references public.inventory_movements(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  unique (original_movement_id)
);

create table if not exists public.sale_payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete restrict,
  amount numeric(18,6) not null check (amount > 0),
  paid_at timestamptz not null default timezone('utc', now()),
  payment_method text not null check (payment_method in ('pix', 'cash', 'card', 'other')),
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  operation_key uuid not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists sales_company_date_idx on public.sales(company_id, order_date desc);
create index if not exists sales_customer_date_idx on public.sales(customer_id, order_date desc);
create index if not exists sales_status_delivery_idx on public.sales(order_status, fulfillment_status, scheduled_for);
create index if not exists sale_items_sale_idx on public.sale_items(sale_id);
create index if not exists sale_items_variant_idx on public.sale_items(product_variant_id);
create index if not exists sale_snapshots_item_idx on public.sale_item_ingredient_snapshots(sale_item_id);
create index if not exists sale_history_idx on public.sale_status_history(sale_id, created_at desc);
create index if not exists sale_payments_sale_idx on public.sale_payments(sale_id, paid_at desc);

drop trigger if exists sales_set_updated_at on public.sales;
create trigger sales_set_updated_at before update on public.sales for each row execute function public.set_updated_at();

create or replace function public.prevent_confirmed_sale_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if old.order_status <> 'draft' and (
    new.company_id is distinct from old.company_id or new.customer_id is distinct from old.customer_id or
    new.scheduled_for is distinct from old.scheduled_for or new.subtotal is distinct from old.subtotal or
    new.discount_total is distinct from old.discount_total or new.total_amount is distinct from old.total_amount or
    new.estimated_cogs is distinct from old.estimated_cogs or new.delivery_address_snapshot is distinct from old.delivery_address_snapshot or
    new.apartment_snapshot is distinct from old.apartment_snapshot or new.notes is distinct from old.notes
  ) then raise exception using message = 'CONFIRMED_SALE_IMMUTABLE'; end if;
  return new;
end;
$$;
drop trigger if exists confirmed_sale_immutable on public.sales;
create trigger confirmed_sale_immutable before update on public.sales for each row execute function public.prevent_confirmed_sale_change();

create or replace function public.record_sale_status_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if old.order_status is distinct from new.order_status or old.fulfillment_status is distinct from new.fulfillment_status or old.payment_status is distinct from new.payment_status then
    insert into public.sale_status_history(sale_id, order_status, fulfillment_status, payment_status, reason, changed_by)
    values (new.id, new.order_status, new.fulfillment_status, new.payment_status, null, (select auth.uid()));
  end if;
  return new;
end;
$$;
drop trigger if exists sales_status_history on public.sales;
create trigger sales_status_history after update on public.sales for each row execute function public.record_sale_status_change();

alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.sale_item_ingredient_snapshots enable row level security;
alter table public.sale_applied_promotions enable row level security;
alter table public.sale_adjustments enable row level security;
alter table public.sale_status_history enable row level security;
alter table public.sale_stock_reversals enable row level security;
alter table public.sale_payments enable row level security;
revoke all on table public.sales, public.sale_items, public.sale_item_ingredient_snapshots, public.sale_applied_promotions, public.sale_adjustments, public.sale_status_history, public.sale_stock_reversals, public.sale_payments from anon, authenticated;
grant select on table public.sales, public.sale_items, public.sale_item_ingredient_snapshots, public.sale_applied_promotions, public.sale_adjustments, public.sale_status_history, public.sale_stock_reversals to authenticated;
grant select on table public.sale_payments to authenticated;

create policy "authorized admins manage sales" on public.sales for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read sale items" on public.sale_items for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read sale ingredient snapshots" on public.sale_item_ingredient_snapshots for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read sale promotions" on public.sale_applied_promotions for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read sale adjustments" on public.sale_adjustments for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read sale history" on public.sale_status_history for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read sale reversals" on public.sale_stock_reversals for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and profiles.role = 'admin'));
create policy "authorized admins read sale payments" on public.sale_payments for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));

create or replace function public.create_sale_draft(
  p_company_id uuid,
  p_customer_id uuid,
  p_scheduled_for timestamptz,
  p_delivery_address text,
  p_apartment text,
  p_notes text,
  p_items jsonb
)
returns public.sales language plpgsql security definer set search_path = public, pg_temp as $$
declare sale_record public.sales; sale_item record; item_count integer := 0; company_check boolean;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select is_active into company_check from public.companies where id = p_company_id;
  if coalesce(company_check, false) = false then raise exception using message = 'ACTIVE_COMPANY_REQUIRED'; end if;
  if not exists (select 1 from public.customers where id = p_customer_id and is_active) then raise exception using message = 'ACTIVE_CUSTOMER_REQUIRED'; end if;
  insert into public.sales(company_id, customer_id, scheduled_for, delivery_address_snapshot, apartment_snapshot, notes, created_by)
  values (p_company_id, p_customer_id, p_scheduled_for, nullif(btrim(coalesce(p_delivery_address, '')), ''), nullif(btrim(coalesce(p_apartment, '')), ''), nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid())) returning * into sale_record;
  for sale_item in select * from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as x(product_variant_id uuid, quantity integer)
  loop
    item_count := item_count + 1;
    if sale_item.quantity is null or sale_item.quantity <= 0 or not exists (select 1 from public.product_variants pv join public.products p on p.id = pv.product_id where pv.id = sale_item.product_variant_id and pv.is_active and p.company_id = p_company_id and p.is_active) then raise exception using message = 'SALE_ITEM_INVALID'; end if;
    insert into public.sale_items(sale_id, product_variant_id, quantity) values (sale_record.id, sale_item.product_variant_id, sale_item.quantity);
  end loop;
  if item_count = 0 then raise exception using message = 'SALE_WITHOUT_ITEMS'; end if;
  return sale_record;
end;
$$;

create or replace function public.register_sale_stock_movement(p_inventory_item_id uuid, p_quantity numeric, p_unit_cost numeric, p_reason text, p_operation_key uuid, p_sale_id uuid)
returns public.inventory_movements language plpgsql security definer set search_path = public, pg_temp as $$
declare movement public.inventory_movements;
begin
  movement := public.register_inventory_movement(p_inventory_item_id, 'manual_out', p_quantity, p_unit_cost, p_reason, p_operation_key);
  update public.inventory_movements set source_type = 'sale', source_id = p_sale_id where id = movement.id;
  select * into movement from public.inventory_movements where id = movement.id;
  return movement;
end;
$$;

create or replace function public.confirm_sale(p_sale_id uuid, p_manual_discount numeric default 0, p_discount_reason text default null, p_pricing jsonb default '{"items": [], "promotions": []}'::jsonb, p_operation_key uuid default null)
returns public.sales language plpgsql security definer set search_path = public, pg_temp as $$
declare sale_record public.sales; sale_item record; priced jsonb; applied_promotion record; promotion_record public.promotions; variant_record record; recipe_ingredient record; quantity_consumed numeric; ingredient_cost numeric; total_cogs numeric := 0; any_unknown boolean := false; item_unknown boolean; base_subtotal numeric := 0; final_subtotal numeric := 0; item_discount_total numeric := 0; promotion_discount_total numeric := 0; item_count integer := 0;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select * into sale_record from public.sales where id = p_sale_id for update;
  if not found then raise exception using message = 'SALE_NOT_FOUND'; end if;
  if sale_record.order_status = 'confirmed' or sale_record.order_status = 'completed' then return sale_record; end if;
  if sale_record.order_status <> 'draft' then raise exception using message = 'SALE_NOT_DRAFT'; end if;
  if p_manual_discount < 0 or p_manual_discount > 0 and nullif(btrim(coalesce(p_discount_reason, '')), '') is null then raise exception using message = 'MANUAL_DISCOUNT_REASON_REQUIRED'; end if;
  if p_manual_discount > 0 and p_manual_discount > coalesce((select sum((value->>'final_total')::numeric) from jsonb_array_elements(coalesce(p_pricing->'items', '[]'::jsonb))), 0) then raise exception using message = 'MANUAL_DISCOUNT_EXCEEDS_TOTAL'; end if;

  for sale_item in select si.* from public.sale_items si where si.sale_id = p_sale_id order by si.created_at, si.id
  loop
    item_count := item_count + 1;
    priced := (select value from jsonb_array_elements(coalesce(p_pricing->'items', '[]'::jsonb)) where value->>'sale_item_id' = sale_item.id::text limit 1);
    if priced is null then raise exception using message = 'SALE_PRICING_INCOMPLETE'; end if;
    if (priced->>'quantity')::integer <> sale_item.quantity then raise exception using message = 'SALE_PRICING_QUANTITY_INVALID'; end if;
    select pv.*, p.company_id, p.name as product_name, p.is_active as product_active into variant_record from public.product_variants pv join public.products p on p.id = pv.product_id where pv.id = sale_item.product_variant_id for update;
    if not found or not variant_record.is_active or not variant_record.product_active or variant_record.company_id <> sale_record.company_id then raise exception using message = 'SALE_VARIANT_INVALID'; end if;
    if abs(variant_record.price - (priced->>'unit_price_snapshot')::numeric) > 0.000001 then raise exception using message = 'SALE_PRICING_STALE_RETRY'; end if;
    if (priced->>'final_total')::numeric < 0 or (priced->>'original_subtotal')::numeric < 0 then raise exception using message = 'SALE_TOTAL_INVALID'; end if;
    if coalesce((priced->>'discount_allocated')::numeric, 0) < 0 or abs((priced->>'original_subtotal')::numeric - coalesce((priced->>'discount_allocated')::numeric, 0) - (priced->>'final_total')::numeric) > 0.000001 then raise exception using message = 'SALE_ITEM_DISCOUNT_INVALID'; end if;
    base_subtotal := base_subtotal + (priced->>'original_subtotal')::numeric;
    final_subtotal := final_subtotal + (priced->>'final_total')::numeric;
    item_discount_total := item_discount_total + coalesce((priced->>'discount_allocated')::numeric, 0);
    update public.sale_items set product_name_snapshot = variant_record.product_name, variant_name_snapshot = variant_record.name, unit_price_snapshot = variant_record.price, original_subtotal = (priced->>'original_subtotal')::numeric, discount_allocated = coalesce((priced->>'discount_allocated')::numeric, 0), final_total = (priced->>'final_total')::numeric, recipe_version_id = variant_record.recipe_version_id, recipe_scale_snapshot = variant_record.recipe_scale where id = sale_item.id;
    item_unknown := false;
    if variant_record.recipe_version_id is null then
      any_unknown := true;
      item_unknown := true;
      update public.sale_items set cost_status_snapshot = 'unknown', estimated_unit_cost_snapshot = null, estimated_total_cost_snapshot = null where id = sale_item.id;
      continue;
    end if;
    ingredient_cost := 0;
    for recipe_ingredient in select rvi.*, ii.name, ii.average_unit_cost from public.recipe_version_ingredients rvi join public.inventory_items ii on ii.id = rvi.inventory_item_id where rvi.recipe_version_id = variant_record.recipe_version_id
    loop
      quantity_consumed := recipe_ingredient.quantity_base * variant_record.recipe_scale * sale_item.quantity;
      if recipe_ingredient.average_unit_cost is null or recipe_ingredient.average_unit_cost <= 0 then any_unknown := true; item_unknown := true; insert into public.sale_item_ingredient_snapshots(sale_item_id, inventory_item_id, ingredient_name_snapshot, quantity_consumed, unit_cost_snapshot, total_cost_snapshot, cost_status) values (sale_item.id, recipe_ingredient.inventory_item_id, recipe_ingredient.name, quantity_consumed, null, null, 'unknown');
      else ingredient_cost := ingredient_cost + recipe_ingredient.average_unit_cost * recipe_ingredient.quantity_base * variant_record.recipe_scale; insert into public.sale_item_ingredient_snapshots(sale_item_id, inventory_item_id, ingredient_name_snapshot, quantity_consumed, unit_cost_snapshot, total_cost_snapshot, cost_status) values (sale_item.id, recipe_ingredient.inventory_item_id, recipe_ingredient.name, quantity_consumed, recipe_ingredient.average_unit_cost, recipe_ingredient.average_unit_cost * quantity_consumed, 'known'); end if;
      perform public.register_sale_stock_movement(recipe_ingredient.inventory_item_id, quantity_consumed, coalesce(recipe_ingredient.average_unit_cost, 0), 'Venda #' || sale_record.order_number::text || ' confirmada', gen_random_uuid(), p_sale_id);
    end loop;
    update public.sale_items set estimated_unit_cost_snapshot = case when ingredient_cost > 0 then ingredient_cost else null end, estimated_total_cost_snapshot = case when ingredient_cost > 0 then ingredient_cost * sale_item.quantity else null end, cost_status_snapshot = case when ingredient_cost > 0 and not item_unknown then 'complete' when ingredient_cost > 0 then 'partial' else 'unknown' end where id = sale_item.id;
    total_cogs := total_cogs + ingredient_cost * sale_item.quantity;
  end loop;
  if item_count = 0 or abs(base_subtotal - coalesce((select sum((value->>'original_subtotal')::numeric) from jsonb_array_elements(coalesce(p_pricing->'items', '[]'::jsonb))), 0)) > 0.000001 then raise exception using message = 'SALE_PRICING_TOTAL_INVALID'; end if;
  if final_subtotal - p_manual_discount < 0 then raise exception using message = 'SALE_TOTAL_INVALID'; end if;
  for applied_promotion in select * from jsonb_to_recordset(coalesce(p_pricing->'promotions', '[]'::jsonb)) as x(promotion_id uuid, promotion_name_snapshot text, bundle_quantity integer, bundle_price numeric, discount_amount numeric, variant_ids_snapshot jsonb)
  loop
    select * into promotion_record from public.promotions where id = applied_promotion.promotion_id and company_id = sale_record.company_id and is_active for share;
    if not found or promotion_record.bundle_quantity <> applied_promotion.bundle_quantity or abs(promotion_record.bundle_price - applied_promotion.bundle_price) > 0.000001 or applied_promotion.discount_amount < 0 then raise exception using message = 'SALE_PROMOTION_INVALID'; end if;
    promotion_discount_total := promotion_discount_total + applied_promotion.discount_amount;
    insert into public.sale_applied_promotions(sale_id, promotion_id, promotion_name_snapshot, bundle_quantity, bundle_price, discount_amount, variant_ids_snapshot) values (p_sale_id, applied_promotion.promotion_id, applied_promotion.promotion_name_snapshot, applied_promotion.bundle_quantity, applied_promotion.bundle_price, greatest(applied_promotion.discount_amount, 0), coalesce(applied_promotion.variant_ids_snapshot, '[]'::jsonb));
  end loop;
  if abs(item_discount_total - promotion_discount_total - p_manual_discount) > 0.000001 then raise exception using message = 'SALE_DISCOUNT_TOTAL_INVALID'; end if;
  update public.sales set subtotal = base_subtotal, discount_total = greatest(base_subtotal - final_subtotal, 0) + p_manual_discount, total_amount = final_subtotal - p_manual_discount, estimated_cogs = case when any_unknown then null else total_cogs end, order_status = 'confirmed', confirmed_at = timezone('utc', now()), confirmation_operation_key = coalesce(p_operation_key, gen_random_uuid()), updated_at = timezone('utc', now()) where id = p_sale_id returning * into sale_record;
  if p_manual_discount > 0 then insert into public.sale_adjustments(sale_id, adjustment_type, amount, reason, created_by, operation_key) values (p_sale_id, 'manual_discount', p_manual_discount, btrim(p_discount_reason), (select auth.uid()), coalesce(p_operation_key, gen_random_uuid())); end if;
  return sale_record;
end;
$$;

create or replace function public.advance_sale_status(p_sale_id uuid, p_order_status text default null, p_fulfillment_status text default null)
returns public.sales language plpgsql security definer set search_path = public, pg_temp as $$
declare sale_record public.sales;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select * into sale_record from public.sales where id = p_sale_id for update;
  if not found then raise exception using message = 'SALE_NOT_FOUND'; end if;
  if sale_record.order_status = 'cancelled' then raise exception using message = 'SALE_ALREADY_CANCELLED'; end if;
  if p_order_status is not null and p_order_status not in ('confirmed', 'completed', 'cancelled') then raise exception using message = 'ORDER_STATUS_INVALID'; end if;
  if p_fulfillment_status is not null and p_fulfillment_status not in ('pending', 'preparing', 'ready', 'delivered') then raise exception using message = 'FULFILLMENT_STATUS_INVALID'; end if;
  if p_order_status = 'completed' and sale_record.fulfillment_status <> 'delivered' then raise exception using message = 'SALE_NOT_DELIVERED'; end if;
  update public.sales set order_status = coalesce(p_order_status, order_status), fulfillment_status = coalesce(p_fulfillment_status, fulfillment_status), completed_at = case when p_order_status = 'completed' then timezone('utc', now()) else completed_at end, cancelled_at = case when p_order_status = 'cancelled' then timezone('utc', now()) else cancelled_at end, updated_at = timezone('utc', now()) where id = p_sale_id returning * into sale_record;
  return sale_record;
end;
$$;

create or replace function public.cancel_sale(p_sale_id uuid, p_return_stock boolean, p_reason text, p_operation_key uuid)
returns public.sales language plpgsql security definer set search_path = public, pg_temp as $$
declare sale_record public.sales; stock_movement record; reversal public.inventory_movements; existing_adjustment public.sale_adjustments;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select * into sale_record from public.sales where id = p_sale_id for update;
  if not found then raise exception using message = 'SALE_NOT_FOUND'; end if;
  if sale_record.order_status = 'cancelled' then return sale_record; end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then raise exception using message = 'CANCELLATION_REASON_REQUIRED'; end if;
  if sale_record.order_status = 'draft' then update public.sales set order_status = 'cancelled', cancelled_at = timezone('utc', now()), updated_at = timezone('utc', now()) where id = p_sale_id returning * into sale_record; return sale_record; end if;
  if p_return_stock then
    for stock_movement in select * from public.inventory_movements where source_type = 'sale' and source_id = p_sale_id order by created_at
    loop
      if not exists (select 1 from public.sale_stock_reversals where original_movement_id = stock_movement.id) then
        reversal := public.register_inventory_movement(stock_movement.inventory_item_id, 'manual_in', abs(stock_movement.quantity_delta), stock_movement.unit_cost_snapshot, 'Reversão da venda #' || sale_record.order_number::text, gen_random_uuid());
        update public.inventory_movements set source_type = 'reversal', source_id = p_sale_id where id = reversal.id;
        insert into public.sale_stock_reversals(sale_id, original_movement_id, reversal_movement_id, created_by) values (p_sale_id, stock_movement.id, reversal.id, (select auth.uid()));
      end if;
    end loop;
  end if;
  insert into public.sale_adjustments(sale_id, adjustment_type, amount, reason, created_by, operation_key) values (p_sale_id, case when p_return_stock then 'stock_reversal' else 'cancellation' end, case when p_return_stock then 0 else sale_record.total_amount end, btrim(p_reason), (select auth.uid()), coalesce(p_operation_key, gen_random_uuid())) on conflict (operation_key) do nothing;
  update public.sales set order_status = 'cancelled', cancelled_at = timezone('utc', now()), updated_at = timezone('utc', now()) where id = p_sale_id returning * into sale_record;
  return sale_record;
end;
$$;

revoke all on function public.create_sale_draft(uuid, uuid, timestamptz, text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.register_sale_stock_movement(uuid, numeric, numeric, text, uuid, uuid) from public, anon, authenticated;
revoke all on function public.confirm_sale(uuid, numeric, text, jsonb, uuid) from public, anon, authenticated;
revoke all on function public.advance_sale_status(uuid, text, text) from public, anon, authenticated;
revoke all on function public.cancel_sale(uuid, boolean, text, uuid) from public, anon, authenticated;
grant execute on function public.create_sale_draft(uuid, uuid, timestamptz, text, text, text, jsonb) to authenticated;
grant execute on function public.register_sale_stock_movement(uuid, numeric, numeric, text, uuid, uuid) to authenticated;
grant execute on function public.confirm_sale(uuid, numeric, text, jsonb, uuid) to authenticated;
grant execute on function public.advance_sale_status(uuid, text, text) to authenticated;
grant execute on function public.cancel_sale(uuid, boolean, text, uuid) to authenticated;
