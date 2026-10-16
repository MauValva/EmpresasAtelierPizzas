-- Hotfix: correção de estoque usa saldo final, calculado no banco sob lock.
-- Aplicar manualmente no SQL Editor após confirmar o backup/ambiente correto.

create or replace function public.register_inventory_adjustment(
  p_inventory_item_id uuid,
  p_target_quantity numeric,
  p_unit_cost numeric default null,
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
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_operation_key is null then raise exception using message = 'OPERATION_KEY_REQUIRED'; end if;
  if p_target_quantity is null or p_target_quantity < 0 then raise exception using message = 'INVALID_TARGET_QUANTITY'; end if;

  select * into v_existing from public.inventory_movements where operation_key = p_operation_key;
  if found then return v_existing; end if;

  select * into v_item from public.inventory_items where id = p_inventory_item_id for update;
  if not found then raise exception using message = 'INVENTORY_ITEM_NOT_FOUND'; end if;
  v_delta := p_target_quantity - v_item.current_quantity;
  if v_delta = 0 then raise exception using message = 'NO_ADJUSTMENT_NEEDED'; end if;

  return public.register_inventory_movement(
    p_inventory_item_id,
    'adjustment',
    v_delta,
    p_unit_cost,
    'manual',
    null,
    p_operation_key,
    coalesce(nullif(trim(p_reason), ''), 'Ajuste manual')
  );
end;
$$;

revoke all on function public.register_inventory_adjustment(uuid, numeric, numeric, uuid, text) from public;
grant execute on function public.register_inventory_adjustment(uuid, numeric, numeric, uuid, text) to authenticated;
