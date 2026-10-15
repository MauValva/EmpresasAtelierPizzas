-- Contratos de segurança executáveis com `supabase test db` em banco local.
-- Não executar no Supabase remoto.

begin;
select plan(22);

select has_table('public', 'profiles', 'profiles existe');
select has_table('public', 'inventory_movements', 'ledger de estoque existe');
select has_table('public', 'purchases', 'compras existem');
select has_table('public', 'sales', 'vendas existem');
select has_table('public', 'sale_payments', 'pagamentos de venda existem');
select has_table('public', 'expenses', 'despesas existem');

select is(has_function_privilege('public', 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'wrapper de compra não é público');
select is(has_function_privilege('anon', 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'anon não executa wrapper de compra');
select is(has_function_privilege('authenticated', 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'authenticated não executa wrapper de compra');
select is(has_function_privilege('public', 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'wrapper de venda não é público');
select is(has_function_privilege('anon', 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'anon não executa wrapper de venda');
select is(has_function_privilege('authenticated', 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'authenticated não executa wrapper de venda');
select is(has_function_privilege('authenticated', 'public.receive_purchase(uuid)', 'EXECUTE'), true, 'receive_purchase permanece disponível');
select is(has_function_privilege('authenticated', 'public.confirm_sale(uuid,numeric,text,jsonb,uuid)', 'EXECUTE'), true, 'confirm_sale permanece disponível');

select is((select relrowsecurity from pg_class where oid = 'public.inventory_movements'::regclass), true, 'RLS ativa no ledger');
select is((select relrowsecurity from pg_class where oid = 'public.sales'::regclass), true, 'RLS ativa em vendas');
select is((select relrowsecurity from pg_class where oid = 'public.sale_payments'::regclass), true, 'RLS ativa em pagamentos');
select is((select relrowsecurity from pg_class where oid = 'public.expenses'::regclass), true, 'RLS ativa em despesas');

select is((select prosecdef from pg_proc where oid = 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)'::regprocedure), true, 'wrapper de compra é SECURITY DEFINER');
select is((select prosecdef from pg_proc where oid = 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)'::regprocedure), true, 'wrapper de venda é SECURITY DEFINER');
select is((select prosecdef from pg_proc where oid = 'public.receive_purchase(uuid)'::regprocedure), true, 'receive_purchase é SECURITY DEFINER');
select is((select prosecdef from pg_proc where oid = 'public.confirm_sale(uuid,numeric,text,jsonb,uuid)'::regprocedure), true, 'confirm_sale é SECURITY DEFINER');

select * from finish();
rollback;
