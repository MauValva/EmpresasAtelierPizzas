-- Fase 3.2: troca da unidade de peso do estoque de g para kg.
-- Aplicar manualmente no SQL Editor, depois de 013_total_profit.sql.
-- Esta migration converte quantidades e custos unitários existentes; os totais
-- financeiros permanecem inalterados. Não executar automaticamente pelo app.

begin;

alter table public.inventory_items drop constraint if exists inventory_items_unit_check;
alter table public.recipes drop constraint if exists recipes_yield_unit_check;

-- Converte receitas antes de trocar a unidade dos ingredientes.
update public.recipe_ingredients ri
set quantity_base = ri.quantity_base / 1000
from public.inventory_items ii
where ii.id = ri.inventory_item_id
  and ii.unit = 'g';

update public.recipes
set yield_quantity = yield_quantity / 1000,
    yield_unit = 'kg'
where yield_unit = 'g';

update public.inventory_movements im
set quantity_delta = im.quantity_delta / 1000,
    previous_quantity = im.previous_quantity / 1000,
    resulting_quantity = im.resulting_quantity / 1000,
    unit_cost_snapshot = im.unit_cost_snapshot * 1000
from public.inventory_items ii
where ii.id = im.inventory_item_id
  and ii.unit = 'g';

update public.expense_stock_entries ese
set quantity = ese.quantity / 1000,
    unit_cost = ese.unit_cost * 1000
from public.inventory_items ii
where ii.id = ese.inventory_item_id
  and ii.unit = 'g';

update public.inventory_items
set current_quantity = current_quantity / 1000,
    minimum_quantity = minimum_quantity / 1000,
    average_unit_cost = average_unit_cost * 1000,
    unit = 'kg'
where unit = 'g';

alter table public.inventory_items
  add constraint inventory_items_unit_check check (unit in ('kg', 'ml', 'un'));
alter table public.recipes
  add constraint recipes_yield_unit_check check (yield_unit in ('kg', 'ml', 'un'));

-- As funções da migration 010 precisam aceitar kg. A definição é preservada e
-- somente a validação da unidade é atualizada, mantendo grants e segurança.
do $$
declare
  v_function record;
  v_definition text;
begin
  for v_function in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('create_recipe_atomic', 'update_recipe_atomic')
  loop
    v_definition := pg_get_functiondef(v_function.oid);
    v_definition := replace(
      v_definition,
      'p_yield_unit not in (''g'', ''ml'', ''un'')',
      'p_yield_unit not in (''kg'', ''ml'', ''un'')'
    );
    execute v_definition;
  end loop;
end;
$$;

commit;
