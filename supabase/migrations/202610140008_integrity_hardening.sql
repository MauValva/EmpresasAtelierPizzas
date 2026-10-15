-- Hardening incremental da Etapa 12 / Fase B2.
-- Não altera migrations históricas e não deve ser aplicado antes de 006 e 007.

create or replace function public.validate_shared_expense_allocation(p_allocation jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare allocation_total numeric; invalid_key text;
begin
  if jsonb_typeof(coalesce(p_allocation, '{}'::jsonb)) <> 'object' then
    raise exception using message = 'ALLOCATION_OBJECT_REQUIRED';
  end if;
  if exists (select 1 from jsonb_each_text(coalesce(p_allocation, '{}'::jsonb)) where value::numeric < 0) then
    raise exception using message = 'ALLOCATION_PERCENTAGE_INVALID';
  end if;
  select key into invalid_key from jsonb_object_keys(coalesce(p_allocation, '{}'::jsonb)) as key
  where not exists (select 1 from public.companies where slug = key and is_active) limit 1;
  if invalid_key is not null then raise exception using message = 'ALLOCATION_COMPANY_INVALID'; end if;
  allocation_total := coalesce((select sum(value::numeric) from jsonb_each(coalesce(p_allocation, '{}'::jsonb))), 0);
  if abs(allocation_total - 100) > 0.000001 then raise exception using message = 'ALLOCATION_MUST_TOTAL_100'; end if;
end;
$$;

create or replace function public.register_purchase_payment(p_purchase_id uuid, p_amount numeric, p_payment_method text, p_notes text default null, p_operation_key uuid default null)
returns public.purchase_payments language plpgsql security definer set search_path = public, pg_temp as $$
declare purchase_record public.purchases; payment public.purchase_payments; operation_payment public.purchase_payments; paid_total numeric; generated_operation_key uuid;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception using message = 'PAYMENT_AMOUNT_INVALID'; end if;
  if p_payment_method not in ('pix', 'cash', 'card', 'other') then raise exception using message = 'PAYMENT_METHOD_INVALID'; end if;
  generated_operation_key := coalesce(p_operation_key, gen_random_uuid());
  select * into operation_payment from public.purchase_payments pp where pp.operation_key = generated_operation_key;
  if found then return operation_payment; end if;
  select * into purchase_record from public.purchases where id = p_purchase_id for update;
  if not found then raise exception using message = 'PURCHASE_NOT_FOUND'; end if;
  if purchase_record.status = 'cancelled' then raise exception using message = 'CANCELLED_PURCHASE'; end if;
  paid_total := coalesce((select sum(amount) from public.purchase_payments where purchase_id = p_purchase_id), 0);
  if paid_total + p_amount > purchase_record.total_amount then raise exception using message = 'PAYMENT_EXCEEDS_BALANCE'; end if;
  insert into public.purchase_payments(purchase_id, amount, payment_method, notes, created_by, operation_key) values (p_purchase_id, p_amount, p_payment_method, nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid()), generated_operation_key) returning * into payment;
  update public.purchases set payment_status = case when paid_total + p_amount >= total_amount then 'paid' else 'partial' end, updated_at = timezone('utc', now()) where id = p_purchase_id;
  return payment;
end;
$$;

create or replace function public.create_expense(p_company_id uuid, p_description text, p_category text, p_amount numeric, p_expense_date date, p_competence_date date, p_due_date date, p_notes text, p_allocation_snapshot jsonb default '{}'::jsonb, p_is_recurring boolean default false, p_recurrence_id uuid default null)
returns public.expenses language plpgsql security definer set search_path = public, pg_temp as $$
declare expense_record public.expenses; allocation jsonb := coalesce(p_allocation_snapshot, '{}'::jsonb);
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception using message = 'EXPENSE_AMOUNT_INVALID'; end if;
  if nullif(btrim(coalesce(p_description, '')), '') is null or nullif(btrim(coalesce(p_category, '')), '') is null then raise exception using message = 'EXPENSE_DESCRIPTION_REQUIRED'; end if;
  if p_company_id is not null and not exists (select 1 from public.companies where id = p_company_id and is_active) then raise exception using message = 'ACTIVE_COMPANY_REQUIRED'; end if;
  if p_company_id is null then perform public.validate_shared_expense_allocation(allocation); end if;
  insert into public.expenses(company_id, description, category, amount, expense_date, competence_date, due_date, notes, allocation_snapshot, is_recurring, recurrence_id, created_by) values (p_company_id, btrim(p_description), btrim(p_category), p_amount, coalesce(p_expense_date, current_date), coalesce(p_competence_date, current_date), p_due_date, nullif(btrim(coalesce(p_notes, '')), ''), allocation, p_is_recurring, p_recurrence_id, (select auth.uid())) returning * into expense_record;
  return expense_record;
end;
$$;

revoke all on function public.validate_shared_expense_allocation(jsonb) from public, anon, authenticated;
revoke all on function public.register_purchase_payment(uuid, numeric, text, text, uuid) from public, anon, authenticated;
revoke all on function public.create_expense(uuid, text, text, numeric, date, date, date, text, jsonb, boolean, uuid) from public, anon, authenticated;
grant execute on function public.register_purchase_payment(uuid, numeric, text, text, uuid) to authenticated;
grant execute on function public.create_expense(uuid, text, text, numeric, date, date, date, text, jsonb, boolean, uuid) to authenticated;
