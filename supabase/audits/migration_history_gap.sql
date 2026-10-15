/* Complemento mínimo, somente leitura, para fechar a auditoria 003-005. */
select
  to_regclass('supabase_migrations.schema_migrations') as relation_name,
  has_table_privilege(current_user, 'supabase_migrations.schema_migrations', 'SELECT') as can_select;

select
  version::text as stored_version,
  name,
  length(version::text) as version_length
from supabase_migrations.schema_migrations
order by version::text;

/* Metadados ausentes no snapshot antigo: somente as colunas geradas. */
select
  n.nspname as schema_name,
  c.relname as table_name,
  a.attname as column_name,
  a.attgenerated as generated_kind,
  pg_get_expr(ad.adbin, ad.adrelid) as generation_expression
from pg_catalog.pg_attribute a
join pg_catalog.pg_class c on c.oid = a.attrelid
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
left join pg_catalog.pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
where n.nspname = 'public'
  and c.relname in ('purchase_items', 'sales')
  and a.attname in ('total_cost', 'order_number')
  and a.attnum > 0
  and not a.attisdropped
order by c.relname, a.attnum;

/* ACL efetiva dos wrappers; não presume que a ausência de authenticated prove a aplicação da 006. */
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  p.proacl,
  has_function_privilege('public', p.oid, 'EXECUTE') as public_execute,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('register_purchase_inventory_movement', 'register_sale_stock_movement', 'receive_purchase', 'confirm_sale')
order by p.proname, pg_get_function_identity_arguments(p.oid);
