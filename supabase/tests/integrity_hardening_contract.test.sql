begin;
select plan(8);

select has_function('public', 'validate_shared_expense_allocation', array['jsonb'], 'shared allocation validator exists');
select has_function('public', 'register_purchase_payment', array['uuid','numeric','text','text','uuid'], 'hardened purchase payment exists');
select has_function('public', 'create_expense', array['uuid','text','text','numeric','date','date','date','text','jsonb','boolean','uuid'], 'hardened expense function exists');
select is(has_function_privilege('public', 'public.validate_shared_expense_allocation(jsonb)', 'EXECUTE'), false, 'allocation validator is not public');
select is(has_function_privilege('anon', 'public.register_purchase_payment(uuid,numeric,text,text,uuid)', 'EXECUTE'), false, 'anon cannot register purchase payment');
select is(has_function_privilege('authenticated', 'public.register_purchase_payment(uuid,numeric,text,text,uuid)', 'EXECUTE'), true, 'authenticated can reach authorized purchase payment function');
select is(has_function_privilege('anon', 'public.create_expense(uuid,text,text,numeric,date,date,date,text,jsonb,boolean,uuid)', 'EXECUTE'), false, 'anon cannot create expenses');
select is(has_function_privilege('authenticated', 'public.create_expense(uuid,text,text,numeric,date,date,date,text,jsonb,boolean,uuid)', 'EXECUTE'), true, 'authenticated can reach authorized expense function');

select * from finish();
rollback;
