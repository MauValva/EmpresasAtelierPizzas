-- Lucro histórico acumulado, agregado no banco e sem data inicial arbitrária.
-- Gastos sem empresa ficam somente no consolidado; não há rateio implícito.

create or replace function public.get_total_profit(p_company_id uuid default null)
returns numeric
language sql
security definer
set search_path = public, pg_temp
as $$
  with paid_sales as (
    select sp.sale_id, sp.amount
    from public.sale_payments sp
    join public.sales s on s.id = sp.sale_id
    where p_company_id is null or s.company_id = p_company_id
  ), sales_costs as (
    select coalesce(sum(si.total_cost_snapshot), 0) as value
    from public.sale_items si
    join paid_sales ps on ps.sale_id = si.sale_id
  ), stock_expenses as (
    select e.id, coalesce(sum(ese.total_cost), 0) as stock_total
    from public.expenses e
    left join public.expense_stock_entries ese on ese.expense_id = e.id
    where p_company_id is null or e.company_id = p_company_id
    group by e.id
  ), operating_expenses as (
    select coalesce(sum(e.amount - se.stock_total), 0) as value
    from public.expenses e
    join stock_expenses se on se.id = e.id
  )
  select coalesce((select sum(amount) from paid_sales), 0)
       - coalesce((select value from sales_costs), 0)
       - coalesce((select value from operating_expenses), 0);
$$;

revoke all on function public.get_total_profit(uuid) from public;
grant execute on function public.get_total_profit(uuid) to authenticated;
