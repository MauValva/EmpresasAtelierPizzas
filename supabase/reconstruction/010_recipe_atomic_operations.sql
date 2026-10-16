-- Fase 3.1: criação e edição transacional de receitas.
-- Aplicar manualmente depois de 009_expense_notes_and_date.sql.
-- Não altera receitas, vendas ou movimentações existentes até ser executada.

create or replace function public.create_recipe_atomic(
  p_company_id uuid,
  p_product_variant_id uuid,
  p_name text,
  p_yield_quantity numeric,
  p_yield_unit text,
  p_notes text,
  p_items jsonb
)
returns public.recipes
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_recipe public.recipes;
  v_variant_company uuid;
  v_entry jsonb;
  v_item uuid;
  v_quantity numeric;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_company_id is null or btrim(coalesce(p_name, '')) = '' then raise exception using message = 'INVALID_RECIPE'; end if;
  if p_yield_quantity is null or p_yield_quantity <= 0 then raise exception using message = 'INVALID_YIELD'; end if;
  if p_yield_unit not in ('g', 'ml', 'un') then raise exception using message = 'INVALID_YIELD_UNIT'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_items, '[]'::jsonb)) = 0 then raise exception using message = 'RECIPE_ITEMS_REQUIRED'; end if;
  if exists (select 1 from jsonb_array_elements(p_items) item group by (item->>'inventory_item_id') having count(*) > 1) then raise exception using message = 'DUPLICATE_RECIPE_INGREDIENT'; end if;

  if p_product_variant_id is not null then
    select p.company_id into v_variant_company
    from public.product_variants pv join public.products p on p.id = pv.product_id
    where pv.id = p_product_variant_id and pv.is_active and p.is_active;
    if not found or v_variant_company <> p_company_id then raise exception using message = 'PRODUCT_VARIANT_COMPANY_MISMATCH'; end if;
    if exists (select 1 from public.product_variants where id = p_product_variant_id and recipe_id is not null) then raise exception using message = 'VARIANT_ALREADY_HAS_RECIPE'; end if;
  end if;

  for v_entry in select * from jsonb_array_elements(p_items) loop
    v_item := (v_entry->>'inventory_item_id')::uuid;
    v_quantity := (v_entry->>'quantity_base')::numeric;
    if v_item is null or v_quantity is null or v_quantity <= 0 then raise exception using message = 'INVALID_RECIPE_INGREDIENT'; end if;
    if not exists (select 1 from public.inventory_items where id = v_item and is_active) then raise exception using message = 'INVENTORY_ITEM_NOT_FOUND'; end if;
  end loop;

  insert into public.recipes(company_id, name, yield_quantity, yield_unit, notes)
  values (p_company_id, btrim(p_name), p_yield_quantity, p_yield_unit, nullif(btrim(p_notes), ''))
  returning * into v_recipe;

  insert into public.recipe_ingredients(recipe_id, inventory_item_id, quantity_base)
  select v_recipe.id, (item->>'inventory_item_id')::uuid, (item->>'quantity_base')::numeric
  from jsonb_array_elements(p_items) item;

  if p_product_variant_id is not null then
    update public.product_variants set recipe_id = v_recipe.id where id = p_product_variant_id;
  end if;
  return v_recipe;
end;
$$;

create or replace function public.update_recipe_atomic(
  p_recipe_id uuid,
  p_company_id uuid,
  p_product_variant_id uuid,
  p_name text,
  p_yield_quantity numeric,
  p_yield_unit text,
  p_notes text,
  p_items jsonb
)
returns public.recipes
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_recipe public.recipes;
  v_variant_company uuid;
  v_entry jsonb;
  v_item uuid;
  v_quantity numeric;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_recipe_id is null or p_company_id is null or btrim(coalesce(p_name, '')) = '' then raise exception using message = 'INVALID_RECIPE'; end if;
  if p_yield_quantity is null or p_yield_quantity <= 0 then raise exception using message = 'INVALID_YIELD'; end if;
  if p_yield_unit not in ('g', 'ml', 'un') then raise exception using message = 'INVALID_YIELD_UNIT'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_items, '[]'::jsonb)) = 0 then raise exception using message = 'RECIPE_ITEMS_REQUIRED'; end if;
  if exists (select 1 from jsonb_array_elements(p_items) item group by (item->>'inventory_item_id') having count(*) > 1) then raise exception using message = 'DUPLICATE_RECIPE_INGREDIENT'; end if;

  select * into v_recipe from public.recipes where id = p_recipe_id for update;
  if not found then raise exception using message = 'RECIPE_NOT_FOUND'; end if;
  if v_recipe.company_id <> p_company_id then raise exception using message = 'RECIPE_COMPANY_MISMATCH'; end if;
  if p_product_variant_id is not null then
    select p.company_id into v_variant_company
    from public.product_variants pv join public.products p on p.id = pv.product_id
    where pv.id = p_product_variant_id and pv.is_active and p.is_active;
    if not found or v_variant_company <> p_company_id then raise exception using message = 'PRODUCT_VARIANT_COMPANY_MISMATCH'; end if;
    if exists (select 1 from public.product_variants where id = p_product_variant_id and recipe_id is not null and recipe_id <> p_recipe_id) then raise exception using message = 'VARIANT_ALREADY_HAS_RECIPE'; end if;
  end if;
  for v_entry in select * from jsonb_array_elements(p_items) loop
    v_item := (v_entry->>'inventory_item_id')::uuid;
    v_quantity := (v_entry->>'quantity_base')::numeric;
    if v_item is null or v_quantity is null or v_quantity <= 0 then raise exception using message = 'INVALID_RECIPE_INGREDIENT'; end if;
    if not exists (select 1 from public.inventory_items where id = v_item and is_active) then raise exception using message = 'INVENTORY_ITEM_NOT_FOUND'; end if;
  end loop;

  update public.recipes set company_id = p_company_id, name = btrim(p_name), yield_quantity = p_yield_quantity, yield_unit = p_yield_unit, notes = nullif(btrim(p_notes), '') where id = p_recipe_id returning * into v_recipe;
  delete from public.recipe_ingredients where recipe_id = p_recipe_id;
  insert into public.recipe_ingredients(recipe_id, inventory_item_id, quantity_base)
  select p_recipe_id, (item->>'inventory_item_id')::uuid, (item->>'quantity_base')::numeric
  from jsonb_array_elements(p_items) item;
  update public.product_variants set recipe_id = null where recipe_id = p_recipe_id;
  if p_product_variant_id is not null then update public.product_variants set recipe_id = p_recipe_id where id = p_product_variant_id; end if;
  return v_recipe;
end;
$$;

revoke all on function public.create_recipe_atomic(uuid, uuid, text, numeric, text, text, jsonb) from public;
revoke all on function public.update_recipe_atomic(uuid, uuid, uuid, text, numeric, text, text, jsonb) from public;
grant execute on function public.create_recipe_atomic(uuid, uuid, text, numeric, text, text, jsonb) to authenticated;
grant execute on function public.update_recipe_atomic(uuid, uuid, uuid, text, numeric, text, text, jsonb) to authenticated;
