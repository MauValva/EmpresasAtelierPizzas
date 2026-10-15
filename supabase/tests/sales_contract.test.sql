begin;
select plan(10);

select has_table('public', 'sales', 'sales table exists');
select has_table('public', 'sale_items', 'sale items table exists');
select has_table('public', 'sale_item_ingredient_snapshots', 'ingredient snapshots table exists');
select has_table('public', 'sale_stock_reversals', 'stock reversals table exists');
select has_table('public', 'sale_payments', 'payment preparation table exists');
select has_function('public', 'create_sale_draft', array['uuid','uuid','timestamp with time zone','text','text','text','jsonb'], 'draft function exists');
select has_function('public', 'confirm_sale', array['uuid','numeric','text','jsonb','uuid'], 'confirmation function exists');
select has_function('public', 'advance_sale_status', array['uuid','text','text'], 'status function exists');
select has_function('public', 'cancel_sale', array['uuid','boolean','text','uuid'], 'cancellation function exists');
select has_column('public', 'sales', 'confirmation_operation_key', 'idempotency key exists');

select * from finish();
rollback;
