-- Consultas somente leitura para validar a migration 010.
select p.oid::regprocedure as function_signature,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('create_recipe_atomic', 'update_recipe_atomic')
order by p.oid::regprocedure::text;

select table_name, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee = 'authenticated'
  and table_name in ('recipes', 'recipe_ingredients', 'product_variants')
order by table_name, privilege_type;
