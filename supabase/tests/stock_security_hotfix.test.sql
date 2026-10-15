begin;
select plan(8);

select has_function('public', 'register_inventory_movement', array['uuid','text','numeric','numeric','text','uuid'], 'base inventory movement function exists');
select has_function('public', 'register_purchase_inventory_movement', array['uuid','numeric','numeric','text','uuid','uuid'], 'purchase wrapper exists');
select has_function('public', 'register_sale_stock_movement', array['uuid','numeric','numeric','text','uuid','uuid'], 'sale wrapper exists');
select has_function('public', 'receive_purchase', array['uuid'], 'purchase parent function exists');
select has_function('public', 'confirm_sale', array['uuid','numeric','text','jsonb','uuid'], 'sale parent function exists');
select is(has_function_privilege('authenticated', 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'authenticated cannot execute purchase wrapper directly');
select is(has_function_privilege('authenticated', 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE'), false, 'authenticated cannot execute sale wrapper directly');
select is(has_function_privilege('authenticated', 'public.receive_purchase(uuid)', 'EXECUTE'), true, 'authenticated can execute authorized purchase parent');

select * from finish();
rollback;
