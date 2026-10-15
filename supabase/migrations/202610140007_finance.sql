-- Etapa 09: pagamentos de vendas, reembolsos, despesas e caixa.
-- Migration local; não altera as migrations históricas.

create table if not exists public.sale_refunds (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete restrict,
  payment_id uuid not null references public.sale_payments(id) on delete restrict,
  amount numeric(18,6) not null check (amount > 0),
  refunded_at timestamptz not null default timezone('utc', now()),
  reason text not null check (btrim(reason) <> ''),
  operation_key uuid not null unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.expense_recurrences (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete restrict,
  description text not null check (btrim(description) <> ''),
  category text not null,
  amount numeric(18,6) not null check (amount > 0),
  day_of_month integer not null default 1 check (day_of_month between 1 and 31),
  starts_on date not null,
  ends_on date,
  is_active boolean not null default true,
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (ends_on is null or ends_on >= starts_on)
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete restrict,
  description text not null check (btrim(description) <> ''),
  category text not null,
  amount numeric(18,6) not null check (amount > 0),
  expense_date date not null default current_date,
  competence_date date not null default current_date,
  due_date date,
  payment_status text not null default 'pending' check (payment_status in ('pending', 'partial', 'paid', 'cancelled')),
  notes text,
  is_recurring boolean not null default false,
  recurrence_id uuid references public.expense_recurrences(id) on delete restrict,
  allocation_snapshot jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.expense_payments (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete restrict,
  amount numeric(18,6) not null check (amount > 0),
  paid_at timestamptz not null default timezone('utc', now()),
  payment_method text not null check (payment_method in ('pix', 'cash', 'card', 'other')),
  notes text,
  operation_key uuid not null unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists sale_refunds_sale_idx on public.sale_refunds(sale_id, refunded_at desc);
create index if not exists expenses_company_date_idx on public.expenses(company_id, expense_date desc);
create index if not exists expenses_status_due_idx on public.expenses(payment_status, due_date);
create index if not exists expense_payments_expense_idx on public.expense_payments(expense_id, paid_at desc);
create unique index if not exists expense_recurrence_competence_idx on public.expenses(recurrence_id, competence_date) where recurrence_id is not null;

drop trigger if exists expense_recurrences_set_updated_at on public.expense_recurrences;
create trigger expense_recurrences_set_updated_at before update on public.expense_recurrences for each row execute function public.set_updated_at();
drop trigger if exists expenses_set_updated_at on public.expenses;
create trigger expenses_set_updated_at before update on public.expenses for each row execute function public.set_updated_at();

alter table public.sale_refunds enable row level security;
alter table public.expense_recurrences enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_payments enable row level security;

revoke all on table public.sale_refunds, public.expense_recurrences, public.expenses, public.expense_payments from anon, authenticated;
grant select on table public.sale_refunds, public.expense_recurrences, public.expenses, public.expense_payments to authenticated;

create policy "authorized admins read sale refunds" on public.sale_refunds for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read expense recurrences" on public.expense_recurrences for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read expenses" on public.expenses for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins read expense payments" on public.expense_payments for select to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));

create or replace function public.register_sale_payment(p_sale_id uuid, p_amount numeric, p_payment_method text, p_notes text default null, p_operation_key uuid default null)
returns public.sale_payments language plpgsql security definer set search_path = public, pg_temp as $$
declare sale_record public.sales; payment public.sale_payments; existing_payment public.sale_payments; received_total numeric; refunded_total numeric; balance numeric;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception using message = 'PAYMENT_AMOUNT_INVALID'; end if;
  if p_payment_method not in ('pix', 'cash', 'card', 'other') then raise exception using message = 'PAYMENT_METHOD_INVALID'; end if;
  if p_operation_key is not null then select * into existing_payment from public.sale_payments where operation_key = p_operation_key; if found then return existing_payment; end if; end if;
  select * into sale_record from public.sales where id = p_sale_id for update;
  if not found then raise exception using message = 'SALE_NOT_FOUND'; end if;
  if sale_record.order_status = 'draft' then raise exception using message = 'SALE_NOT_CONFIRMED'; end if;
  if sale_record.order_status = 'cancelled' then raise exception using message = 'CANCELLED_SALE'; end if;
  received_total := coalesce((select sum(amount) from public.sale_payments where sale_id = p_sale_id), 0);
  refunded_total := coalesce((select sum(amount) from public.sale_refunds where sale_id = p_sale_id), 0);
  balance := sale_record.total_amount - greatest(received_total - refunded_total, 0);
  if p_amount > balance then raise exception using message = 'PAYMENT_EXCEEDS_BALANCE'; end if;
  insert into public.sale_payments(sale_id, amount, payment_method, notes, created_by, operation_key) values (p_sale_id, p_amount, nullif(btrim(p_payment_method), ''), nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid()), coalesce(p_operation_key, gen_random_uuid())) returning * into payment;
  update public.sales set payment_status = case when received_total + p_amount - refunded_total >= total_amount then 'paid' else 'partial' end, updated_at = timezone('utc', now()) where id = p_sale_id;
  return payment;
end;
$$;

create or replace function public.register_sale_refund(p_sale_id uuid, p_payment_id uuid, p_amount numeric, p_reason text, p_operation_key uuid default null)
returns public.sale_refunds language plpgsql security definer set search_path = public, pg_temp as $$
declare sale_record public.sales; payment_record public.sale_payments; refund public.sale_refunds; existing_refund public.sale_refunds; paid numeric; refunded numeric;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception using message = 'REFUND_AMOUNT_INVALID'; end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then raise exception using message = 'REFUND_REASON_REQUIRED'; end if;
  if p_operation_key is not null then select * into existing_refund from public.sale_refunds where operation_key = p_operation_key; if found then return existing_refund; end if; end if;
  select * into sale_record from public.sales where id = p_sale_id for update;
  select * into payment_record from public.sale_payments where id = p_payment_id and sale_id = p_sale_id for update;
  if not found then raise exception using message = 'PAYMENT_NOT_FOUND'; end if;
  paid := payment_record.amount;
  refunded := coalesce((select sum(amount) from public.sale_refunds where payment_id = p_payment_id), 0);
  if p_amount > paid - refunded then raise exception using message = 'REFUND_EXCEEDS_PAYMENT'; end if;
  insert into public.sale_refunds(sale_id, payment_id, amount, reason, created_by, operation_key) values (p_sale_id, p_payment_id, p_amount, btrim(p_reason), (select auth.uid()), coalesce(p_operation_key, gen_random_uuid())) returning * into refund;
  if coalesce((select sum(amount) from public.sale_refunds where sale_id = p_sale_id), 0) >= coalesce((select sum(amount) from public.sale_payments where sale_id = p_sale_id), 0) then update public.sales set payment_status = 'refunded', updated_at = timezone('utc', now()) where id = p_sale_id; end if;
  return refund;
end;
$$;

create or replace function public.create_expense(p_company_id uuid, p_description text, p_category text, p_amount numeric, p_expense_date date, p_competence_date date, p_due_date date, p_notes text, p_allocation_snapshot jsonb default '{}'::jsonb, p_is_recurring boolean default false, p_recurrence_id uuid default null)
returns public.expenses language plpgsql security definer set search_path = public, pg_temp as $$
declare expense_record public.expenses; allocation_total numeric;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception using message = 'EXPENSE_AMOUNT_INVALID'; end if;
  if nullif(btrim(coalesce(p_description, '')), '') is null or nullif(btrim(coalesce(p_category, '')), '') is null then raise exception using message = 'EXPENSE_DESCRIPTION_REQUIRED'; end if;
  if p_company_id is not null and not exists (select 1 from public.companies where id = p_company_id and is_active) then raise exception using message = 'ACTIVE_COMPANY_REQUIRED'; end if;
  allocation_total := coalesce((select sum(value::numeric) from jsonb_each(coalesce(p_allocation_snapshot, '{}'::jsonb))), 0);
  if p_company_id is null and abs(allocation_total - 100) > 0.000001 then raise exception using message = 'ALLOCATION_MUST_TOTAL_100'; end if;
  insert into public.expenses(company_id, description, category, amount, expense_date, competence_date, due_date, notes, allocation_snapshot, is_recurring, recurrence_id, created_by) values (p_company_id, btrim(p_description), btrim(p_category), p_amount, coalesce(p_expense_date, current_date), coalesce(p_competence_date, current_date), p_due_date, nullif(btrim(coalesce(p_notes, '')), ''), coalesce(p_allocation_snapshot, '{}'::jsonb), p_is_recurring, p_recurrence_id, (select auth.uid())) returning * into expense_record;
  return expense_record;
end;
$$;

create or replace function public.create_expense_recurrence(p_company_id uuid, p_description text, p_category text, p_amount numeric, p_day_of_month integer, p_starts_on date, p_ends_on date default null, p_notes text default null)
returns public.expense_recurrences language plpgsql security definer set search_path = public, pg_temp as $$
declare recurrence public.expense_recurrences;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_company_id is not null and not exists (select 1 from public.companies where id = p_company_id and is_active) then raise exception using message = 'ACTIVE_COMPANY_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 or p_day_of_month not between 1 and 31 then raise exception using message = 'RECURRENCE_VALUES_INVALID'; end if;
  insert into public.expense_recurrences(company_id, description, category, amount, day_of_month, starts_on, ends_on, notes, created_by) values (p_company_id, btrim(p_description), btrim(p_category), p_amount, p_day_of_month, p_starts_on, p_ends_on, nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid())) returning * into recurrence;
  return recurrence;
end;
$$;

create or replace function public.register_expense_payment(p_expense_id uuid, p_amount numeric, p_payment_method text, p_notes text default null, p_operation_key uuid default null)
returns public.expense_payments language plpgsql security definer set search_path = public, pg_temp as $$
declare expense_record public.expenses; payment public.expense_payments; existing_payment public.expense_payments; paid numeric;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if p_amount is null or p_amount <= 0 then raise exception using message = 'PAYMENT_AMOUNT_INVALID'; end if;
  if p_payment_method not in ('pix', 'cash', 'card', 'other') then raise exception using message = 'PAYMENT_METHOD_INVALID'; end if;
  if p_operation_key is not null then select * into existing_payment from public.expense_payments where operation_key = p_operation_key; if found then return existing_payment; end if; end if;
  select * into expense_record from public.expenses where id = p_expense_id for update;
  if not found then raise exception using message = 'EXPENSE_NOT_FOUND'; end if;
  paid := coalesce((select sum(amount) from public.expense_payments where expense_id = p_expense_id), 0);
  if paid + p_amount > expense_record.amount then raise exception using message = 'PAYMENT_EXCEEDS_BALANCE'; end if;
  insert into public.expense_payments(expense_id, amount, payment_method, notes, created_by, operation_key) values (p_expense_id, p_amount, p_payment_method, nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid()), coalesce(p_operation_key, gen_random_uuid())) returning * into payment;
  update public.expenses set payment_status = case when paid + p_amount >= amount then 'paid' else 'partial' end, updated_at = timezone('utc', now()) where id = p_expense_id;
  return payment;
end;
$$;

create or replace function public.generate_recurring_expense(p_recurrence_id uuid, p_competence_date date)
returns public.expenses language plpgsql security definer set search_path = public, pg_temp as $$
declare recurrence public.expense_recurrences; expense_record public.expenses; launch_date date;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select * into recurrence from public.expense_recurrences where id = p_recurrence_id for update;
  if not found or not recurrence.is_active then raise exception using message = 'RECURRENCE_NOT_ACTIVE'; end if;
  if p_competence_date < recurrence.starts_on or recurrence.ends_on is not null and p_competence_date > recurrence.ends_on then raise exception using message = 'RECURRENCE_OUT_OF_RANGE'; end if;
  launch_date := make_date(extract(year from p_competence_date)::integer, extract(month from p_competence_date)::integer, least(recurrence.day_of_month, extract(day from (date_trunc('month', p_competence_date) + interval '1 month - 1 day'))::integer));
  insert into public.expenses(company_id, description, category, amount, expense_date, competence_date, due_date, notes, is_recurring, recurrence_id, allocation_snapshot, created_by) values (recurrence.company_id, recurrence.description, recurrence.category, recurrence.amount, launch_date, p_competence_date, launch_date, recurrence.notes, true, recurrence.id, case when recurrence.company_id is null then coalesce((select value from public.app_settings where key = 'shared_expense_allocation'), '{}'::jsonb) else jsonb_build_object((select slug from public.companies where id = recurrence.company_id), 100) end, (select auth.uid())) on conflict (recurrence_id, competence_date) do update set updated_at = public.expenses.updated_at returning * into expense_record;
  return expense_record;
end;
$$;

revoke all on function public.register_sale_payment(uuid, numeric, text, text, uuid) from public, anon, authenticated;
revoke all on function public.register_sale_refund(uuid, uuid, numeric, text, uuid) from public, anon, authenticated;
revoke all on function public.create_expense(uuid, text, text, numeric, date, date, date, text, jsonb, boolean, uuid) from public, anon, authenticated;
revoke all on function public.create_expense_recurrence(uuid, text, text, numeric, integer, date, date, text) from public, anon, authenticated;
revoke all on function public.register_expense_payment(uuid, numeric, text, text, uuid) from public, anon, authenticated;
revoke all on function public.generate_recurring_expense(uuid, date) from public, anon, authenticated;
grant execute on function public.register_sale_payment(uuid, numeric, text, text, uuid) to authenticated;
grant execute on function public.register_sale_refund(uuid, uuid, numeric, text, uuid) to authenticated;
grant execute on function public.create_expense(uuid, text, text, numeric, date, date, date, text, jsonb, boolean, uuid) to authenticated;
grant execute on function public.create_expense_recurrence(uuid, text, text, numeric, integer, date, date, text) to authenticated;
grant execute on function public.register_expense_payment(uuid, numeric, text, text, uuid) to authenticated;
grant execute on function public.generate_recurring_expense(uuid, date) to authenticated;
