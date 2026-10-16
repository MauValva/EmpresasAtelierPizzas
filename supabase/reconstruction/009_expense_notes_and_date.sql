-- Fase 2.7: observações e validação de data em gastos.
-- Aplicar manualmente depois de 008_sales_essential_flows.sql.
-- Não executa alterações remotamente.

create or replace function public.create_expense(
  p_company_id uuid,
  p_description text,
  p_category text,
  p_amount numeric,
  p_expense_date date,
  p_stock_entries jsonb default '[]'::jsonb,
  p_operation_key uuid default null,
  p_notes text default null
)
returns public.expenses
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expense public.expenses;
  v_entry jsonb;
  v_total_stock numeric := 0;
  v_quantity numeric;
  v_unit_cost numeric;
  v_item uuid;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if coalesce(p_expense_date, current_date) > (timezone('America/Sao_Paulo', now()))::date then raise exception using message = 'EXPENSE_DATE_IN_FUTURE'; end if;
  if p_operation_key is not null then
    select * into v_expense from public.expenses where operation_key = p_operation_key;
    if found then return v_expense; end if;
  end if;
  if jsonb_typeof(coalesce(p_stock_entries, '[]'::jsonb)) <> 'array' then raise exception using message = 'INVALID_STOCK_ENTRIES'; end if;
  for v_entry in select * from jsonb_array_elements(coalesce(p_stock_entries, '[]'::jsonb)) loop
    v_item := (v_entry->>'inventory_item_id')::uuid;
    v_quantity := (v_entry->>'quantity')::numeric;
    v_unit_cost := (v_entry->>'unit_cost')::numeric;
    if v_item is null or v_quantity is null or v_quantity <= 0 or v_unit_cost is null or v_unit_cost < 0 then raise exception using message = 'INVALID_STOCK_ENTRY'; end if;
    if not exists (select 1 from public.inventory_items where id = v_item and is_active) then raise exception using message = 'INVENTORY_ITEM_NOT_FOUND'; end if;
    v_total_stock := v_total_stock + v_quantity * v_unit_cost;
  end loop;
  if v_total_stock > p_amount then raise exception using message = 'STOCK_ENTRIES_EXCEED_EXPENSE'; end if;

  insert into public.expenses(company_id, description, category, amount, expense_date, notes, operation_key, created_by)
  values (p_company_id, btrim(p_description), p_category, p_amount, coalesce(p_expense_date, current_date), nullif(btrim(p_notes), ''), p_operation_key, auth.uid())
  returning * into v_expense;

  for v_entry in select * from jsonb_array_elements(coalesce(p_stock_entries, '[]'::jsonb)) loop
    v_item := (v_entry->>'inventory_item_id')::uuid;
    v_quantity := (v_entry->>'quantity')::numeric;
    v_unit_cost := (v_entry->>'unit_cost')::numeric;
    insert into public.expense_stock_entries(expense_id, inventory_item_id, quantity, unit_cost, operation_key)
    values (v_expense.id, v_item, v_quantity, v_unit_cost, gen_random_uuid());
    perform public.register_inventory_movement(v_item, 'expense', v_quantity, v_unit_cost, 'expense', v_expense.id, gen_random_uuid(), p_description);
  end loop;
  return v_expense;
end;
$$;

revoke all on function public.create_expense(uuid, text, text, numeric, date, jsonb, uuid, text) from public;
grant execute on function public.create_expense(uuid, text, text, numeric, date, jsonb, uuid, text) to authenticated;
