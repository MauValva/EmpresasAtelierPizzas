-- Verificação somente leitura das migrations incrementais 009, 010 e 011.
-- Não executa DDL, DML, DROP, GRANT ou REVOKE.

-- 009: coluna notes e as duas assinaturas de create_expense.
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'expenses'
  and column_name = 'notes';

select p.oid::regprocedure as function_signature,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_expense'
order by p.oid::regprocedure::text;

-- 010: funções transacionais de receitas e permissões.
select p.oid::regprocedure as function_signature,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('create_recipe_atomic', 'update_recipe_atomic')
order by p.oid::regprocedure::text;

select table_name, privilege_type
from information_schema.table_privileges
where grantee = 'authenticated'
  and table_schema = 'public'
  and table_name in ('recipes', 'recipe_ingredients', 'product_variants')
order by table_name, privilege_type;

-- 011: função de correção absoluta, assinatura, grant e objetos-base.
select to_regprocedure('public.register_inventory_adjustment(uuid,numeric,numeric,uuid,text)') as expected_function,
       has_function_privilege('authenticated', 'public.register_inventory_adjustment(uuid,numeric,numeric,uuid,text)', 'EXECUTE') as authenticated_can_execute;

select p.oid::regprocedure as function_signature,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'register_inventory_adjustment';

select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('inventory_items', 'inventory_movements')
  and column_name in ('current_quantity', 'quantity_delta', 'previous_quantity', 'resulting_quantity', 'operation_key')
order by table_name, ordinal_position;
