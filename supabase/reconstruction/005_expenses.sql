-- Gastos operacionais e entradas opcionais de estoque.

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete restrict,
  description text not null check (btrim(description) <> ''),
  category text not null check (category in ('paes', 'pizzas', 'compartilhado', 'administrativo')),
  amount numeric(18,6) not null check (amount > 0),
  expense_date date not null default current_date,
  notes text,
  operation_key uuid unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.expense_stock_entries (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  quantity numeric(18,3) not null check (quantity > 0),
  unit_cost numeric(18,6) not null check (unit_cost >= 0),
  total_cost numeric(18,6) generated always as (quantity * unit_cost) stored,
  operation_key uuid not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create index expenses_company_date_idx on public.expenses(company_id, expense_date desc);
create index expenses_category_date_idx on public.expenses(category, expense_date desc);
create index expense_stock_entries_expense_idx on public.expense_stock_entries(expense_id);
create index expense_stock_entries_item_idx on public.expense_stock_entries(inventory_item_id);

create trigger expenses_set_updated_at before update on public.expenses
for each row execute function public.set_updated_at();

create or replace function public.create_expense(
  p_company_id uuid,
  p_description text,
  p_category text,
  p_amount numeric,
  p_expense_date date,
  p_stock_entries jsonb default '[]'::jsonb,
  p_operation_key uuid default null
)
returns public.expenses
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expense public.expenses;
  v_entry jsonb;
  v_total_stock numeric := 0;
  v_quantity numeric;
  v_unit_cost numeric;
  v_item uuid;
begin
  if not public.is_admin() then raise exception using message = 'UNAUTHORIZED'; end if;
  if p_operation_key is not null then
    select * into v_expense from public.expenses where operation_key = p_operation_key;
    if found then return v_expense; end if;
  end if;
  if jsonb_typeof(coalesce(p_stock_entries, '[]'::jsonb)) <> 'array' then raise exception using message = 'INVALID_STOCK_ENTRIES'; end if;
  for v_entry in select * from jsonb_array_elements(coalesce(p_stock_entries, '[]'::jsonb)) loop
    v_item := (v_entry->>'inventory_item_id')::uuid;
    v_quantity := (v_entry->>'quantity')::numeric;
    v_unit_cost := (v_entry->>'unit_cost')::numeric;
    if v_item is null or v_quantity is null or v_quantity <= 0 or v_unit_cost is null or v_unit_cost < 0 then raise exception using message = 'INVALID_STOCK_ENTRY'; end if;
    if not exists (select 1 from public.inventory_items where id = v_item and is_active) then raise exception using message = 'INVENTORY_ITEM_NOT_FOUND'; end if;
    v_total_stock := v_total_stock + v_quantity * v_unit_cost;
  end loop;
  if v_total_stock > p_amount then raise exception using message = 'STOCK_ENTRIES_EXCEED_EXPENSE'; end if;

  insert into public.expenses(company_id, description, category, amount, expense_date, operation_key, created_by)
  values (p_company_id, btrim(p_description), p_category, p_amount, coalesce(p_expense_date, current_date), p_operation_key, auth.uid())
  returning * into v_expense;

  for v_entry in select * from jsonb_array_elements(coalesce(p_stock_entries, '[]'::jsonb)) loop
    v_item := (v_entry->>'inventory_item_id')::uuid;
    v_quantity := (v_entry->>'quantity')::numeric;
    v_unit_cost := (v_entry->>'unit_cost')::numeric;
    insert into public.expense_stock_entries(expense_id, inventory_item_id, quantity, unit_cost, operation_key)
    values (v_expense.id, v_item, v_quantity, v_unit_cost, gen_random_uuid());
    perform public.register_inventory_movement(v_item, 'expense', v_quantity, v_unit_cost, 'expense', v_expense.id, gen_random_uuid(), p_description);
  end loop;
  return v_expense;
end;
$$;

create or replace function public.get_summary(
  p_start date,
  p_end date,
  p_company_id uuid default null
)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  with paid_sales as (
    select sp.sale_id, sp.amount
    from public.sale_payments sp
    join public.sales s on s.id = sp.sale_id
    where sp.paid_at::date between p_start and p_end
      and (p_company_id is null or s.company_id = p_company_id)
  ), sales_costs as (
    select coalesce(sum(si.total_cost_snapshot), 0) as value
    from public.sale_items si
    join paid_sales ps on ps.sale_id = si.sale_id
  ), stock_expenses as (
    select e.id, coalesce(sum(ese.total_cost), 0) as stock_total
    from public.expenses e
    left join public.expense_stock_entries ese on ese.expense_id = e.id
    where e.expense_date between p_start and p_end
      and (p_company_id is null or e.company_id = p_company_id or e.company_id is null)
    group by e.id
  ), operating_expenses as (
    select coalesce(sum(e.amount - se.stock_total), 0) as value
    from public.expenses e
    join stock_expenses se on se.id = e.id
  ), totals as (
    select coalesce((select sum(amount) from paid_sales), 0) as revenue,
           (select value from sales_costs) as cogs,
           (select value from operating_expenses) as operating_expenses
  )
  select jsonb_build_object(
    'revenue', revenue,
    'cogs', cogs,
    'operating_expenses', operating_expenses,
    'profit', revenue - cogs - operating_expenses,
    'start', p_start,
    'end', p_end,
    'company_id', p_company_id
  ) from totals;
$$;
