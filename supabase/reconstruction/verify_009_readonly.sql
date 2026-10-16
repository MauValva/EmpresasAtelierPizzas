-- Consultas somente leitura para validar a migration 009 no SQL Editor.
select p.oid::regprocedure as function_signature,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_expense'
order by p.oid::regprocedure::text;

select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'expenses'
  and column_name in ('notes', 'expense_date', 'operation_key')
order by ordinal_position;

select routine_name, grantee, privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'create_expense'
  and grantee = 'authenticated';
