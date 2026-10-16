-- Não atribui gastos compartilhados/administrativos a uma empresa sem regra explícita.
-- No resumo geral, gastos com company_id nulo continuam incluídos.
-- Em uma empresa específica, somente gastos vinculados àquela empresa entram no lucro.
-- Aplicar manualmente após 011_inventory_absolute_adjustments.sql.

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
      and (p_company_id is null or e.company_id = p_company_id)
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

revoke all on function public.get_summary(date, date, uuid) from public;
grant execute on function public.get_summary(date, date, uuid) to authenticated;
