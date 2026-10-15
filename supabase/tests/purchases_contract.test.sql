-- Executar com `supabase test db` após aplicar as migrations.
begin;
select plan(8);
select has_table('public', 'suppliers');
select has_table('public', 'purchases');
select has_table('public', 'purchase_items');
select has_table('public', 'purchase_payments');
select has_function('public', 'create_purchase_draft');
select has_function('public', 'receive_purchase');
select has_function('public', 'register_purchase_payment');
select col_is_unique('public', 'purchase_items', 'receipt_operation_key');
select * from finish();
rollback;
