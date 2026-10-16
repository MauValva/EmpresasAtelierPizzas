-- Testes de contrato da reconstrução Fase 1.
-- Executar em banco de desenvolvimento com pgTAP habilitado.

begin;
select plan(15);

select has_table('public', 'profiles', 'profiles existe');
select has_table('public', 'companies', 'companies existe');
select has_table('public', 'customers', 'customers existe');
select has_table('public', 'products', 'products existe');
select has_table('public', 'product_variants', 'product_variants existe');
select has_table('public', 'sales', 'sales existe');
select has_table('public', 'sale_items', 'sale_items existe');
select has_table('public', 'sale_payments', 'sale_payments existe');
select has_table('public', 'inventory_items', 'inventory_items existe');
select has_table('public', 'inventory_movements', 'inventory_movements existe');
select has_table('public', 'recipes', 'recipes existe');
select has_table('public', 'recipe_ingredients', 'recipe_ingredients existe');
select has_table('public', 'expenses', 'expenses existe');
select has_table('public', 'expense_stock_entries', 'expense_stock_entries existe');
select col_is_unique('public', 'inventory_movements', 'operation_key', 'movimentações são idempotentes');

select * from finish();
rollback;
