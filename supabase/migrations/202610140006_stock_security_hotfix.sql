-- Hotfix de segurança do estoque.
-- Não altera migrations históricas. Aplicar somente após reconciliar o histórico remoto.

-- Os wrappers são detalhes internos de receive_purchase/confirm_sale.
-- SECURITY DEFINER não substitui controle de EXECUTE: authenticated não deve
-- conseguir invocá-los diretamente.
revoke all on function public.register_purchase_inventory_movement(uuid, numeric, numeric, text, uuid, uuid) from public, anon, authenticated;
revoke all on function public.register_sale_stock_movement(uuid, numeric, numeric, text, uuid, uuid) from public, anon, authenticated;

-- Defesa em profundidade para compras: o movimento precisa corresponder a um
-- item real da compra e à chave de recebimento gerada para aquele item.
create or replace function public.register_purchase_inventory_movement(
  p_inventory_item_id uuid,
  p_quantity numeric,
  p_unit_cost numeric,
  p_reason text,
  p_operation_key uuid,
  p_purchase_id uuid
)
returns public.inventory_movements
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  movement public.inventory_movements;
begin
  if p_operation_key is null then
    raise exception using message = 'PURCHASE_OPERATION_KEY_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.purchases p
    join public.purchase_items pi on pi.purchase_id = p.id
    where p.id = p_purchase_id
      and p.status in ('draft', 'ordered')
      and pi.inventory_item_id = p_inventory_item_id
      and pi.quantity = p_quantity
      and pi.unit_cost = p_unit_cost
      and pi.receipt_operation_key = p_operation_key
  ) then
    raise exception using message = 'PURCHASE_MOVEMENT_ORIGIN_INVALID';
  end if;

  movement := public.register_inventory_movement(
    p_inventory_item_id,
    'manual_in',
    p_quantity,
    p_unit_cost,
    p_reason,
    p_operation_key
  );

  update public.inventory_movements
  set source_type = 'purchase', source_id = p_purchase_id
  where id = movement.id;

  select * into movement
  from public.inventory_movements
  where id = movement.id;

  return movement;
end;
$$;

-- Defesa em profundidade para vendas: o movimento precisa corresponder a um
-- snapshot de ingrediente criado durante a confirmação daquela venda.
create or replace function public.register_sale_stock_movement(
  p_inventory_item_id uuid,
  p_quantity numeric,
  p_unit_cost numeric,
  p_reason text,
  p_operation_key uuid,
  p_sale_id uuid
)
returns public.inventory_movements
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  movement public.inventory_movements;
begin
  if p_operation_key is null then
    raise exception using message = 'SALE_OPERATION_KEY_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.sale_item_ingredient_snapshots sis
    join public.sale_items si on si.id = sis.sale_item_id
    join public.sales s on s.id = si.sale_id
    where s.id = p_sale_id
      and s.order_status = 'draft'
      and sis.inventory_item_id = p_inventory_item_id
      and sis.quantity_consumed = p_quantity
      and coalesce(sis.unit_cost_snapshot, 0) = coalesce(p_unit_cost, 0)
  ) then
    raise exception using message = 'SALE_MOVEMENT_ORIGIN_INVALID';
  end if;

  movement := public.register_inventory_movement(
    p_inventory_item_id,
    'manual_out',
    p_quantity,
    p_unit_cost,
    p_reason,
    p_operation_key
  );

  update public.inventory_movements
  set source_type = 'sale', source_id = p_sale_id
  where id = movement.id;

  select * into movement
  from public.inventory_movements
  where id = movement.id;

  return movement;
end;
$$;

-- As funções-pai pertencem ao fluxo autorizado e continuam disponíveis.
grant execute on function public.receive_purchase(uuid) to authenticated;
grant execute on function public.confirm_sale(uuid, numeric, text, jsonb, uuid) to authenticated;

