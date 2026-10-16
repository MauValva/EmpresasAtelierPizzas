-- RLS, grants e funções auxiliares.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
grant usage on schema public to authenticated;

do $$
declare t text;
begin
  foreach t in array array['profiles','companies','customers','products','product_variants','sales','sale_items','sale_payments','inventory_items','inventory_movements','recipes','recipe_ingredients','expenses','expense_stock_entries'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon', t);
    execute format('grant select on table public.%I to authenticated', t);
  end loop;
end;
$$;

create policy profiles_read_own on public.profiles for select to authenticated
using (id = auth.uid() and role = 'admin');
create policy companies_read_active on public.companies for select to authenticated
using (is_active and public.is_admin());

create policy customers_admin_all on public.customers for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy products_admin_all on public.products for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy product_variants_admin_all on public.product_variants for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy recipes_admin_all on public.recipes for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy recipe_ingredients_admin_all on public.recipe_ingredients for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy inventory_items_admin_read on public.inventory_items for select to authenticated
using (public.is_admin());
create policy inventory_items_admin_insert on public.inventory_items for insert to authenticated
with check (public.is_admin());
create policy inventory_items_admin_update on public.inventory_items for update to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy inventory_movements_admin_read on public.inventory_movements for select to authenticated
using (public.is_admin());

create policy sales_admin_read on public.sales for select to authenticated
using (public.is_admin());
create policy sale_items_admin_read on public.sale_items for select to authenticated
using (public.is_admin());
create policy sale_payments_admin_read on public.sale_payments for select to authenticated
using (public.is_admin());
create policy expenses_admin_read on public.expenses for select to authenticated
using (public.is_admin());
create policy expense_stock_entries_admin_read on public.expense_stock_entries for select to authenticated
using (public.is_admin());

revoke insert, update, delete on public.inventory_movements from authenticated;
revoke insert, update, delete on public.sales, public.sale_items, public.sale_payments from authenticated;
revoke insert, update, delete on public.expenses, public.expense_stock_entries from authenticated;
grant insert, update, delete on public.customers, public.products, public.product_variants, public.recipes, public.recipe_ingredients to authenticated;
grant insert (name, category, unit, minimum_quantity, is_active, notes) on public.inventory_items to authenticated;
grant update (name, category, minimum_quantity, is_active, notes) on public.inventory_items to authenticated;

grant execute on function public.create_sale(uuid, uuid, text, timestamptz, jsonb, text, text, uuid, uuid) to authenticated;
grant execute on function public.finalize_sale(uuid, text, uuid) to authenticated;
grant execute on function public.cancel_open_sale(uuid) to authenticated;
grant execute on function public.register_inventory_movement(uuid, text, numeric, numeric, text, uuid, uuid, text) to authenticated;
grant execute on function public.create_expense(uuid, text, text, numeric, date, jsonb, uuid) to authenticated;
grant execute on function public.get_summary(date, date, uuid) to authenticated;
