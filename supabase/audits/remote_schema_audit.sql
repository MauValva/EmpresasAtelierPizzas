/*
  Auditoria remota somente leitura das migrations 003, 004 e 005.
  Execute este arquivo inteiro no SQL Editor do Supabase.
  Não contém DDL, DML, RPC de negócio ou SQL dinâmico.
*/

with expected(object_name, object_kind) as (
  values
    ('suppliers','table'), ('purchases','table'), ('purchase_items','table'), ('purchase_payments','table'),
    ('products','table'), ('recipes','table'), ('recipe_versions','table'), ('recipe_version_ingredients','table'),
    ('product_variants','table'), ('product_variant_direct_costs','table'), ('promotions','table'), ('promotion_eligible_variants','table'),
    ('sales','table'), ('sale_items','table'), ('sale_item_ingredient_snapshots','table'), ('sale_applied_promotions','table'),
    ('sale_adjustments','table'), ('sale_status_history','table'), ('sale_stock_reversals','table'), ('sale_payments','table'),
    ('register_purchase_inventory_movement','function'), ('receive_purchase','function'), ('create_purchase_draft','function'), ('register_purchase_payment','function'),
    ('validate_variant_recipe_company','function'), ('publish_recipe_version','function'), ('create_recipe_draft','function'), ('create_recipe_version','function'),
    ('prevent_confirmed_sale_change','function'), ('prevent_published_recipe_ingredient_change','function'), ('prevent_published_recipe_version_change','function'),
    ('prevent_received_purchase_change','function'), ('prevent_received_purchase_item_change','function'), ('recalculate_purchase_totals','function'), ('record_sale_status_change','function'),
    ('create_sale_draft','function'), ('register_sale_stock_movement','function'), ('confirm_sale','function'), ('advance_sale_status','function'), ('cancel_sale','function')
), relevant_tables as (select object_name from expected where object_kind = 'table')
select jsonb_build_object(
  'audit_scope', jsonb_build_object('schema', 'public', 'migrations', jsonb_build_array('202610140003_purchases','202610140004_catalog','202610140005_sales'), 'read_only', true),
  'tables', coalesce((select jsonb_agg(to_jsonb(x) order by x.table_name) from (
    select c.relname as table_name, c.relkind, c.relnamespace::regnamespace::text as schema_name,
           c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced, c.relacl
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p') and c.relname in (select object_name from relevant_tables)
  ) x), '[]'::jsonb),
  'columns', coalesce((select jsonb_agg(to_jsonb(x) order by x.table_name, x.ordinal_position) from (
    select c.table_name, c.ordinal_position, c.column_name, c.data_type, c.udt_schema, c.udt_name,
           c.is_nullable, c.column_default, c.character_maximum_length, c.numeric_precision, c.numeric_scale,
           c.is_generated, c.generation_expression
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name in (select object_name from relevant_tables)
  ) x), '[]'::jsonb),
  'constraints', coalesce((select jsonb_agg(to_jsonb(x) order by x.table_name, x.constraint_name) from (
    select tc.table_name, tc.constraint_name, tc.constraint_type, pg_get_constraintdef(con.oid, true) as definition
    from information_schema.table_constraints tc
    join pg_constraint con on con.conname = tc.constraint_name and con.connamespace = 'public'::regnamespace and con.conrelid = (tc.table_schema || '.' || tc.table_name)::regclass
    where tc.table_schema = 'public' and tc.table_name in (select object_name from relevant_tables)
  ) x), '[]'::jsonb),
  'indexes', coalesce((select jsonb_agg(to_jsonb(x) order by x.table_name, x.index_name) from (
    select t.relname as table_name, i.relname as index_name, i.relkind, ix.indisunique, ix.indisprimary,
           case when ix.indisprimary then 'primary_key' when con.contype = 'u' then 'unique_constraint' else 'explicit' end as index_kind,
           pg_get_indexdef(i.oid) as definition
    from pg_index ix join pg_class i on i.oid = ix.indexrelid join pg_class t on t.oid = ix.indrelid join pg_namespace n on n.oid = t.relnamespace
    left join pg_constraint con on con.conindid = i.oid and con.contype in ('p','u')
    where n.nspname = 'public' and t.relname in (select object_name from relevant_tables)
  ) x), '[]'::jsonb),
  'policies', coalesce((select jsonb_agg(to_jsonb(x) order by x.table_name, x.policy_name) from (
    select schemaname as schema_name, tablename as table_name, policyname as policy_name, permissive, roles, cmd, qual as using_expression, with_check
    from pg_policies where schemaname = 'public' and tablename in (select object_name from relevant_tables)
  ) x), '[]'::jsonb),
  'functions', coalesce((select jsonb_agg(to_jsonb(x) order by x.function_name, x.identity_arguments) from (
    select p.oid, n.nspname as schema_name, p.proname as function_name, pg_get_function_identity_arguments(p.oid) as identity_arguments,
           pg_get_function_result(p.oid) as return_type, l.lanname as language, p.prosecdef as security_definer,
           p.proconfig as configuration, pg_get_functiondef(p.oid) as definition, p.proacl
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace join pg_language l on l.oid = p.prolang
    where n.nspname = 'public' and p.proname in (select object_name from expected where object_kind = 'function')
  ) x), '[]'::jsonb),
  'function_grants', coalesce((select jsonb_agg(to_jsonb(x) order by x.function_name, x.identity_arguments, x.grantee, x.privilege_type) from (
    select p.proname as function_name, pg_get_function_identity_arguments(p.oid) as identity_arguments,
           coalesce(grantee.rolname, 'PUBLIC') as grantee, grants.privilege_type, grants.is_grantable
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) grants
    left join pg_roles grantee on grantee.oid = grants.grantee
    where n.nspname = 'public' and p.proname in (select object_name from expected where object_kind = 'function')
  ) x), '[]'::jsonb),
  'triggers', coalesce((select jsonb_agg(to_jsonb(x) order by x.table_name, x.trigger_name) from (
    select n.nspname as schema_name, c.relname as table_name, t.tgname as trigger_name, not t.tgenabled = 'D' as enabled, pg_get_triggerdef(t.oid, true) as definition
    from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace
    where not t.tgisinternal and n.nspname = 'public' and c.relname in (select object_name from relevant_tables)
  ) x), '[]'::jsonb),
  'table_grants', coalesce((select jsonb_agg(to_jsonb(x) order by x.table_name, x.grantee, x.privilege_type) from (
    select c.relname as table_name, coalesce(grantee.rolname, 'PUBLIC') as grantee, grants.privilege_type, grants.is_grantable
    from pg_class c join pg_namespace n on n.oid = c.relnamespace cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) grants
    left join pg_roles grantee on grantee.oid = grants.grantee
    where n.nspname = 'public' and c.relkind in ('r','p') and c.relname in (select object_name from relevant_tables)
  ) x), '[]'::jsonb),
  'migration_history', case
    when to_regclass('supabase_migrations.schema_migrations') is null then jsonb_build_object('status','unavailable','reason','relation_not_found','rows',jsonb_build_array())
    when not has_table_privilege(current_user, 'supabase_migrations.schema_migrations', 'SELECT') then jsonb_build_object('status','unavailable','reason','select_privilege_not_available','rows',jsonb_build_array())
    else jsonb_build_object('status','available','rows',coalesce((select jsonb_agg(to_jsonb(x) order by x.version) from (select version::text as version, name from supabase_migrations.schema_migrations) x), '[]'::jsonb))
  end,
  'seed_checks', jsonb_build_object(
    'companies', coalesce((select jsonb_agg(to_jsonb(x) order by x.slug) from (select slug, is_active, color from public.companies where slug in ('atelier-do-pao','pizzas-do-condominio')) x), '[]'::jsonb),
    'shared_expense_allocation_setting', coalesce((select jsonb_agg(jsonb_build_object('key', key, 'value', value)) from public.app_settings where key = 'shared_expense_allocation'), '[]'::jsonb),
    'note', 'Somente presença e valores de configuração esperados; nenhum dado operacional é retornado.'
  ),
  'expected_objects', (select jsonb_agg(jsonb_build_object('name', object_name, 'kind', object_kind) order by object_kind, object_name) from expected)
);
