-- Reproduzir depois de aplicar as migrations com `supabase test db`.
-- O teste de integração real deve executar a função com dois usuários admin
-- concorrentes e verificar o lock FOR UPDATE, a idempotência por operation_key,
-- RLS de leitura e a impossibilidade de alterar o histórico.
begin;
select plan(5);
select has_table('public', 'inventory_items');
select has_table('public', 'inventory_movements');
select has_function('public', 'register_inventory_movement');
select col_is_fk('public', 'inventory_movements', 'inventory_item_id');
select col_is_unique('public', 'inventory_movements', 'operation_key');
select * from finish();
rollback;
