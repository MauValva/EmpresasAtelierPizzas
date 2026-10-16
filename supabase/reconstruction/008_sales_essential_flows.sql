-- Fase 2.4.1: descontos, pagamento retroativo e edição transacional de pedidos abertos.
-- Aplicar manualmente depois de 007_seed.sql no projeto Supabase já reconstruído.
-- Não recria tabelas e não remove dados.

create or replace function public.create_sale_with_terms(
  p_company_id uuid,
  p_customer_id uuid,
  p_record_type text,
  p_scheduled_for timestamptz,
  p_items jsonb,
  p_discount numeric default 0,
  p_notes text default null,
  p_payment_method text default null,
  p_payment_operation_key uuid default null,
  p_paid_at timestamptz default null,
  p_operation_key uuid default null
)
returns public.sales
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sale public.sales;
  v_paid_at timestamptz;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_record_type not in ('order', 'sale') then raise exception using message = 'INVALID_RECORD_TYPE'; end if;
  if p_discount is null or p_discount < 0 then raise exception using message = 'INVALID_DISCOUNT'; end if;
  if p_paid_at is not null and p_paid_at > timezone('utc', now()) then raise exception using message = 'PAYMENT_DATE_IN_FUTURE'; end if;
  if p_record_type = 'order' and (p_customer_id is null or p_scheduled_for is null) then raise exception using message = 'ORDER_CUSTOMER_AND_DATE_REQUIRED'; end if;
  if p_record_type = 'sale' and (p_payment_method is null or p_payment_operation_key is null) then raise exception using message = 'PAYMENT_REQUIRED'; end if;

  select * into v_sale from public.create_sale(p_company_id, p_customer_id, 'order', p_scheduled_for, p_items, p_notes, null, null, p_operation_key);
  if v_sale.status <> 'open' then return v_sale; end if;
  if p_discount > v_sale.subtotal then raise exception using message = 'DISCOUNT_EXCEEDS_SUBTOTAL'; end if;
  update public.sales set discount_total = p_discount, total_amount = v_sale.subtotal - p_discount where id = v_sale.id returning * into v_sale;

  if p_record_type = 'sale' then
    select * into v_sale from public.finalize_sale(v_sale.id, p_payment_method, p_payment_operation_key);
    v_paid_at := coalesce(p_paid_at, timezone('utc', now()));
    update public.sale_payments set paid_at = v_paid_at where sale_id = v_sale.id;
    update public.sales set paid_at = v_paid_at, transaction_date = v_paid_at where id = v_sale.id returning * into v_sale;
  end if;
  return v_sale;
end;
$$;

create or replace function public.update_open_sale(
  p_sale_id uuid,
  p_company_id uuid,
  p_customer_id uuid,
  p_scheduled_for timestamptz,
  p_items jsonb,
  p_discount numeric default 0,
  p_notes text default null
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
  if p_customer_id is null or p_scheduled_for is null then raise exception using message = 'ORDER_CUSTOMER_AND_DATE_REQUIRED'; end if;
  if p_discount is null or p_discount < 0 then raise exception using message = 'INVALID_DISCOUNT'; end if;
  select * into v_sale from public.sales where id = p_sale_id for update;
  if not found then raise exception using message = 'SALE_NOT_FOUND'; end if;
  if v_sale.record_type <> 'order' or v_sale.status <> 'open' then raise exception using message = 'ONLY_OPEN_ORDERS_CAN_BE_EDITED'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception using message = 'SALE_ITEMS_REQUIRED'; end if;

  delete from public.sale_items where sale_id = p_sale_id;
  for v_item in select * from jsonb_array_elements(p_items) loop
    select pv.id, pv.name as variant_name, pv.price, p.name as product_name
    into v_variant
    from public.product_variants pv join public.products p on p.id = pv.product_id
    where pv.id = (v_item->>'product_variant_id')::uuid and pv.is_active and p.is_active and p.company_id = p_company_id;
    if not found then raise exception using message = 'PRODUCT_VARIANT_NOT_FOUND'; end if;
    v_quantity := (v_item->>'quantity')::integer;
    if v_quantity is null or v_quantity <= 0 then raise exception using message = 'INVALID_QUANTITY'; end if;
    v_unit_price := coalesce((v_item->>'unit_price')::numeric, v_variant.price);
    if v_unit_price < 0 then raise exception using message = 'INVALID_PRICE'; end if;
    insert into public.sale_items(sale_id, product_variant_id, product_name_snapshot, variant_name_snapshot, quantity, unit_price_snapshot, subtotal)
    values (p_sale_id, v_variant.id, v_variant.product_name, v_variant.variant_name, v_quantity, v_unit_price, v_quantity * v_unit_price);
    v_subtotal := v_subtotal + (v_quantity * v_unit_price);
  end loop;
  if p_discount > v_subtotal then raise exception using message = 'DISCOUNT_EXCEEDS_SUBTOTAL'; end if;
  update public.sales set company_id = p_company_id, customer_id = p_customer_id, scheduled_for = p_scheduled_for, notes = p_notes, subtotal = v_subtotal, discount_total = p_discount, total_amount = v_subtotal - p_discount where id = p_sale_id returning * into v_sale;
  return v_sale;
end;
$$;

create or replace function public.finalize_sale_with_date(
  p_sale_id uuid,
  p_payment_method text,
  p_payment_operation_key uuid,
  p_paid_at timestamptz default null
)
returns public.sales
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sale public.sales;
  v_paid_at timestamptz;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_paid_at is not null and p_paid_at > timezone('utc', now()) then raise exception using message = 'PAYMENT_DATE_IN_FUTURE'; end if;
  select * into v_sale from public.sales where id = p_sale_id;
  if not found then raise exception using message = 'SALE_NOT_FOUND'; end if;
  if v_sale.status = 'paid' then return v_sale; end if;
  select * into v_sale from public.finalize_sale(p_sale_id, p_payment_method, p_payment_operation_key);
  v_paid_at := coalesce(p_paid_at, timezone('utc', now()));
  update public.sale_payments set paid_at = v_paid_at where sale_id = p_sale_id;
  update public.sales set paid_at = v_paid_at, transaction_date = v_paid_at where id = p_sale_id returning * into v_sale;
  return v_sale;
end;
$$;

revoke all on function public.create_sale_with_terms(uuid, uuid, text, timestamptz, jsonb, numeric, text, text, uuid, timestamptz, uuid) from public;
revoke all on function public.update_open_sale(uuid, uuid, uuid, timestamptz, jsonb, numeric, text) from public;
revoke all on function public.finalize_sale_with_date(uuid, text, uuid, timestamptz) from public;
grant execute on function public.create_sale_with_terms(uuid, uuid, text, timestamptz, jsonb, numeric, text, text, uuid, timestamptz, uuid) to authenticated;
grant execute on function public.update_open_sale(uuid, uuid, uuid, timestamptz, jsonb, numeric, text) to authenticated;
grant execute on function public.finalize_sale_with_date(uuid, text, uuid, timestamptz) to authenticated;
