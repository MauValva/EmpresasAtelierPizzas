-- Cenários de negócio da reconstrução Fase 1.
-- Requer banco Supabase de desenvolvimento e pgTAP. O usuário criado aqui
-- existe apenas dentro da transação de teste e é revertido ao final.

begin;
select plan(16);

create temporary table phase1_context (
  user_id uuid,
  company_id uuid,
  inventory_item_id uuid,
  no_recipe_item_id uuid,
  recipe_id uuid,
  variant_id uuid,
  no_recipe_variant_id uuid
);

do $$
declare
  v_user uuid := gen_random_uuid();
  v_company uuid;
  v_item uuid := gen_random_uuid();
  v_no_recipe_item uuid := gen_random_uuid();
  v_recipe uuid := gen_random_uuid();
  v_product uuid := gen_random_uuid();
  v_no_recipe_product uuid := gen_random_uuid();
  v_variant uuid := gen_random_uuid();
  v_no_recipe_variant uuid := gen_random_uuid();
begin
  insert into auth.users(id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values (v_user, 'authenticated', 'authenticated', 'phase1-test@example.com', '', timezone('utc', now()), timezone('utc', now()), timezone('utc', now()));
  insert into public.profiles(id, display_name, role) values (v_user, 'Fase 1 Teste', 'admin');
  perform set_config('request.jwt.claim.sub', v_user::text, true);

  insert into public.companies(name, slug, color) values ('Fase 1', 'fase-1-teste', '#123456') returning id into v_company;
  insert into public.inventory_items(id, name, unit, current_quantity, average_unit_cost) values (v_item, 'Farinha teste', 'g', 0, 0);
  insert into public.inventory_items(id, name, unit) values (v_no_recipe_item, 'Embalagem teste', 'un');
  insert into public.recipes(id, company_id, name, yield_quantity, yield_unit) values (v_recipe, v_company, 'Receita teste', 10, 'un');
  insert into public.recipe_ingredients(recipe_id, inventory_item_id, quantity_base) values (v_recipe, v_item, 4000);
  insert into public.products(id, company_id, name) values (v_product, v_company, 'Pão teste');
  insert into public.products(id, company_id, name) values (v_no_recipe_product, v_company, 'Produto sem receita');
  insert into public.product_variants(id, product_id, name, price, recipe_id) values (v_variant, v_product, 'Unidade', 10, v_recipe);
  insert into public.product_variants(id, product_id, name, price) values (v_no_recipe_variant, v_no_recipe_product, 'Unidade', 5);
  insert into phase1_context values (v_user, v_company, v_item, v_no_recipe_item, v_recipe, v_variant, v_no_recipe_variant);
  perform public.register_inventory_movement(v_item, 'opening', 10000, 2, 'opening', null, gen_random_uuid(), 'Saldo inicial');
end;
$$;

do $$
declare
  c record;
  v_order public.sales;
  v_sale public.sales;
  v_before integer;
  v_after integer;
  v_summary jsonb;
  v_qty numeric;
  v_avg numeric;
  v_duplicate_id uuid;
  v_cancel_failed boolean := false;
begin
  select * into c from phase1_context;

  select count(*) into v_before from public.inventory_movements;
  select * into v_order from public.create_sale(c.company_id, null, 'order', timezone('utc', now()), jsonb_build_array(jsonb_build_object('product_variant_id', c.variant_id, 'quantity', 2)), 'Pedido de teste');
  select count(*) into v_after from public.inventory_movements;
  perform ok(v_order.record_type = 'order' and v_order.status = 'open' and v_before = v_after, 'pedido aberto não movimenta estoque');

  select * into v_sale from public.create_sale(c.company_id, null, 'sale', null, jsonb_build_array(jsonb_build_object('product_variant_id', c.no_recipe_variant_id, 'quantity', 1)), 'Venda direta', 'pix', gen_random_uuid());
  perform ok(v_sale.record_type = 'sale' and v_sale.status = 'paid', 'venda direta é criada como paga');
  perform ok(not exists (select 1 from public.inventory_movements where source_id = v_sale.id), 'produto sem receita não movimenta estoque');

  select * into v_sale from public.create_sale(c.company_id, null, 'sale', null, jsonb_build_array(jsonb_build_object('product_variant_id', c.variant_id, 'quantity', 2)), 'Venda com receita', 'cash', gen_random_uuid());
  select current_quantity into v_qty from public.inventory_items where id = c.inventory_item_id;
  perform ok(v_qty = 9200, 'venda desconta ingredientes conforme rendimento');
  perform ok((select total_cost_snapshot from public.sale_items where sale_id = v_sale.id limit 1) = 1600, 'venda congela custo histórico');

  select * into v_order from public.create_sale(c.company_id, null, 'order', null, jsonb_build_array(jsonb_build_object('product_variant_id', c.variant_id, 'quantity', 1)), 'Pedido conversível');
  select count(*) into v_before from public.inventory_movements where source_type = 'sale' and source_id in (select id from public.sale_items where sale_id = v_order.id);
  perform public.finalize_sale(v_order.id, 'card', gen_random_uuid());
  select count(*) into v_after from public.inventory_movements where source_type = 'sale' and source_id in (select id from public.sale_items where sale_id = v_order.id);
  perform public.finalize_sale(v_order.id, 'card', gen_random_uuid());
  perform ok(v_after > v_before and (select count(*) from public.sale_payments where sale_id = v_order.id) = 1, 'conversão de pedido é idempotente');

  perform public.create_expense(c.company_id, 'Compra de farinha', 'paes', 100, current_date, jsonb_build_array(jsonb_build_object('inventory_item_id', c.inventory_item_id, 'quantity', 10, 'unit_cost', 4)));
  select current_quantity, average_unit_cost into v_qty, v_avg from public.inventory_items where id = c.inventory_item_id;
  perform ok(v_qty > 0 and v_avg > 2, 'gasto com estoque atualiza quantidade e custo médio');

  select count(*) into v_before from public.inventory_movements;
  perform public.create_expense(c.company_id, 'Energia', 'administrativo', 50, current_date, '[]'::jsonb);
  select count(*) into v_after from public.inventory_movements;
  perform ok(v_before = v_after, 'gasto sem estoque não movimenta estoque');

  perform public.create_sale(c.company_id, null, 'sale', null, jsonb_build_array(jsonb_build_object('product_variant_id', c.variant_id, 'quantity', 100000)), 'Venda negativa permitida', 'pix', gen_random_uuid());
  perform ok((select current_quantity < 0 from public.inventory_items where id = c.inventory_item_id), 'saldo negativo não bloqueia venda');

  perform public.register_inventory_movement(c.no_recipe_item_id, 'adjustment', -2, 0, 'adjustment', null, gen_random_uuid(), 'Ajuste simples');
  perform ok((select current_quantity = -2 from public.inventory_items where id = c.no_recipe_item_id), 'ajuste manual aceita saldo negativo');

  select id into v_duplicate_id from public.register_inventory_movement(c.no_recipe_item_id, 'manual_in', 3, 1, 'manual', null, '00000000-0000-0000-0000-000000000123'::uuid, 'Operação repetida');
  select count(*) into v_before from public.inventory_movements where operation_key = '00000000-0000-0000-0000-000000000123'::uuid;
  perform public.register_inventory_movement(c.no_recipe_item_id, 'manual_in', 3, 1, 'manual', null, '00000000-0000-0000-0000-000000000123'::uuid, 'Operação repetida');
  perform ok(v_before = 1 and v_duplicate_id is not null, 'movimentação repetida retorna a operação original');

  select public.get_summary(current_date, current_date, c.company_id) into v_summary;
  perform ok((v_summary->>'revenue')::numeric > 0 and (v_summary ? 'profit'), 'resumo usa data de pagamento e calcula lucro');
  perform ok((v_summary->>'operating_expenses')::numeric = 50, 'custo de estoque não é descontado duas vezes como gasto operacional');

  begin
    perform public.cancel_open_sale(v_sale.id);
  exception when others then
    v_cancel_failed := true;
  end;
  perform ok(v_cancel_failed, 'venda paga não pode ser cancelada silenciosamente');

  perform ok((select count(*) from pg_policies where schemaname = 'public' and tablename in ('sales', 'inventory_items', 'expenses')) >= 3, 'RLS está configurado nos módulos principais');
  perform ok(position('for update' in lower(pg_get_functiondef('public.register_inventory_movement(uuid,text,numeric,numeric,text,uuid,uuid,text)'::regprocedure))) > 0, 'movimentação usa lock para concorrência');
end;
$$;

select * from finish();
rollback;
