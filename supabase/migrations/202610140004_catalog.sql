-- Etapa 07: catálogo, receitas versionadas, custos estimados e promoções.

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  category text,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (company_id, name)
);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (company_id, name)
);

create table if not exists public.recipe_versions (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  yield_quantity numeric(18,6) not null check (yield_quantity > 0),
  yield_unit text not null check (yield_unit in ('g', 'ml', 'un')),
  yield_weight_g numeric(18,6),
  notes text,
  published_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  unique (recipe_id, version_number)
);

create unique index if not exists one_published_recipe_version_idx on public.recipe_versions(recipe_id) where status = 'published';

create table if not exists public.recipe_version_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_version_id uuid not null references public.recipe_versions(id) on delete restrict,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  quantity_base numeric(18,6) not null check (quantity_base > 0),
  unit_cost_snapshot numeric(18,6),
  cost_snapshot_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (recipe_version_id, inventory_item_id)
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  sku text,
  target_weight_g numeric(18,6),
  price numeric(18,6) not null check (price >= 0),
  recipe_version_id uuid references public.recipe_versions(id) on delete restrict,
  recipe_scale numeric(18,6) not null default 1 check (recipe_scale > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (product_id, name)
);

create table if not exists public.product_variant_direct_costs (
  id uuid primary key default gen_random_uuid(),
  product_variant_id uuid not null references public.product_variants(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  amount numeric(18,6) not null check (amount >= 0),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  description text,
  quantity_mode text not null default 'minimum' check (quantity_mode in ('minimum', 'exact')),
  bundle_quantity integer not null check (bundle_quantity > 0),
  bundle_price numeric(18,6) not null check (bundle_price >= 0),
  priority integer not null default 100,
  stacking_policy text not null default 'exclusive' check (stacking_policy in ('exclusive', 'stackable')),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (company_id, name, bundle_quantity)
);

create table if not exists public.promotion_eligible_variants (
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  product_variant_id uuid not null references public.product_variants(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (promotion_id, product_variant_id)
);

create index if not exists products_company_active_idx on public.products(company_id, is_active);
create index if not exists product_variants_product_active_idx on public.product_variants(product_id, is_active);
create index if not exists recipes_company_active_idx on public.recipes(company_id, is_active);
create index if not exists recipe_ingredients_version_idx on public.recipe_version_ingredients(recipe_version_id);
create index if not exists promotions_company_active_idx on public.promotions(company_id, is_active, priority);

create or replace function public.validate_variant_recipe_company()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare product_company uuid; recipe_company uuid;
begin
  if new.recipe_version_id is null then return new; end if;
  select company_id into product_company from public.products where id = new.product_id;
  select r.company_id into recipe_company from public.recipe_versions rv join public.recipes r on r.id = rv.recipe_id where rv.id = new.recipe_version_id;
  if product_company is null or recipe_company is null or product_company <> recipe_company then raise exception using message = 'PRODUCT_RECIPE_COMPANY_MISMATCH'; end if;
  return new;
end;
$$;
drop trigger if exists variant_recipe_company_check on public.product_variants;
create trigger variant_recipe_company_check before insert or update on public.product_variants for each row execute function public.validate_variant_recipe_company();

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at before update on public.products for each row execute function public.set_updated_at();
drop trigger if exists recipes_set_updated_at on public.recipes;
create trigger recipes_set_updated_at before update on public.recipes for each row execute function public.set_updated_at();
drop trigger if exists variants_set_updated_at on public.product_variants;
create trigger variants_set_updated_at before update on public.product_variants for each row execute function public.set_updated_at();
drop trigger if exists promotions_set_updated_at on public.promotions;
create trigger promotions_set_updated_at before update on public.promotions for each row execute function public.set_updated_at();

create or replace function public.prevent_published_recipe_version_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if old.status = 'published' and (new.status <> 'archived' or new.recipe_id is distinct from old.recipe_id or new.version_number is distinct from old.version_number or new.yield_quantity is distinct from old.yield_quantity or new.yield_unit is distinct from old.yield_unit or new.yield_weight_g is distinct from old.yield_weight_g or new.notes is distinct from old.notes) then
    raise exception using message = 'PUBLISHED_RECIPE_VERSION_IMMUTABLE';
  end if;
  return new;
end;
$$;
drop trigger if exists published_recipe_version_immutable on public.recipe_versions;
create trigger published_recipe_version_immutable before update on public.recipe_versions for each row execute function public.prevent_published_recipe_version_change();

create or replace function public.prevent_published_recipe_ingredient_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare version_status text;
begin
  select status into version_status from public.recipe_versions where id = coalesce(new.recipe_version_id, old.recipe_version_id);
  if version_status = 'published' then raise exception using message = 'PUBLISHED_RECIPE_INGREDIENTS_IMMUTABLE'; end if;
  return coalesce(new, old);
end;
$$;
drop trigger if exists published_recipe_ingredients_immutable on public.recipe_version_ingredients;
create trigger published_recipe_ingredients_immutable before insert or update or delete on public.recipe_version_ingredients for each row execute function public.prevent_published_recipe_ingredient_change();

create or replace function public.publish_recipe_version(p_version_id uuid)
returns public.recipe_versions
language plpgsql security definer set search_path = public, pg_temp as $$
declare version_record public.recipe_versions;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select * into version_record from public.recipe_versions where id = p_version_id for update;
  if not found then raise exception using message = 'RECIPE_VERSION_NOT_FOUND'; end if;
  if version_record.status = 'published' then return version_record; end if;
  update public.recipe_versions set status = 'archived' where recipe_id = version_record.recipe_id and status = 'published';
  update public.recipe_version_ingredients rvi
  set unit_cost_snapshot = case when ii.average_unit_cost > 0 then ii.average_unit_cost else null end,
      cost_snapshot_at = timezone('utc', now())
  from public.inventory_items ii
  where rvi.recipe_version_id = p_version_id and ii.id = rvi.inventory_item_id;
  update public.recipe_versions set status = 'published', published_at = timezone('utc', now()) where id = p_version_id returning * into version_record;
  return version_record;
end;
$$;

create or replace function public.create_recipe_draft(
  p_company_id uuid,
  p_name text,
  p_yield_quantity numeric,
  p_yield_unit text,
  p_yield_weight_g numeric,
  p_notes text,
  p_items jsonb
)
returns public.recipes
language plpgsql security definer set search_path = public, pg_temp as $$
declare recipe_record public.recipes; version_id uuid; recipe_item record; item_count integer := 0;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.companies where id = p_company_id and is_active) then raise exception using message = 'ACTIVE_COMPANY_REQUIRED'; end if;
  if p_yield_quantity is null or p_yield_quantity <= 0 or p_yield_unit not in ('g','ml','un') then raise exception using message = 'RECIPE_YIELD_INVALID'; end if;
  insert into public.recipes(company_id, name, notes) values (p_company_id, btrim(p_name), nullif(btrim(coalesce(p_notes, '')), '')) returning * into recipe_record;
  insert into public.recipe_versions(recipe_id, version_number, yield_quantity, yield_unit, yield_weight_g, notes, created_by) values (recipe_record.id, 1, p_yield_quantity, p_yield_unit, p_yield_weight_g, nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid())) returning id into version_id;
  for recipe_item in select * from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as x(inventory_item_id uuid, quantity_base numeric)
  loop
    item_count := item_count + 1;
    if recipe_item.inventory_item_id is null or not exists (select 1 from public.inventory_items where id = recipe_item.inventory_item_id and is_active) or recipe_item.quantity_base is null or recipe_item.quantity_base <= 0 then raise exception using message = 'RECIPE_INGREDIENT_INVALID'; end if;
    insert into public.recipe_version_ingredients(recipe_version_id, inventory_item_id, quantity_base) values (version_id, recipe_item.inventory_item_id, recipe_item.quantity_base);
  end loop;
  if item_count = 0 then raise exception using message = 'RECIPE_WITHOUT_INGREDIENTS'; end if;
  return recipe_record;
end;
$$;

create or replace function public.create_recipe_version(
  p_recipe_id uuid,
  p_yield_quantity numeric,
  p_yield_unit text,
  p_yield_weight_g numeric,
  p_notes text,
  p_items jsonb
)
returns public.recipe_versions
language plpgsql security definer set search_path = public, pg_temp as $$
declare recipe_record public.recipes; version_record public.recipe_versions; recipe_item record; next_version integer; item_count integer := 0;
begin
  if (select auth.uid()) is null then raise exception using message = 'AUTHORIZATION_REQUIRED'; end if;
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then raise exception using message = 'ADMIN_AUTHORIZATION_REQUIRED'; end if;
  select * into recipe_record from public.recipes where id = p_recipe_id for update;
  if not found then raise exception using message = 'RECIPE_NOT_FOUND'; end if;
  select coalesce(max(version_number), 0) + 1 into next_version from public.recipe_versions where recipe_id = p_recipe_id;
  insert into public.recipe_versions(recipe_id, version_number, yield_quantity, yield_unit, yield_weight_g, notes, created_by) values (p_recipe_id, next_version, p_yield_quantity, p_yield_unit, p_yield_weight_g, nullif(btrim(coalesce(p_notes, '')), ''), (select auth.uid())) returning * into version_record;
  for recipe_item in select * from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as x(inventory_item_id uuid, quantity_base numeric)
  loop
    item_count := item_count + 1;
    if recipe_item.inventory_item_id is null or not exists (select 1 from public.inventory_items where id = recipe_item.inventory_item_id and is_active) or recipe_item.quantity_base is null or recipe_item.quantity_base <= 0 then raise exception using message = 'RECIPE_INGREDIENT_INVALID'; end if;
    insert into public.recipe_version_ingredients(recipe_version_id, inventory_item_id, quantity_base) values (version_record.id, recipe_item.inventory_item_id, recipe_item.quantity_base);
  end loop;
  if item_count = 0 then raise exception using message = 'RECIPE_WITHOUT_INGREDIENTS'; end if;
  return version_record;
end;
$$;

alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_versions enable row level security;
alter table public.recipe_version_ingredients enable row level security;
alter table public.product_variant_direct_costs enable row level security;
alter table public.promotions enable row level security;
alter table public.promotion_eligible_variants enable row level security;

revoke all on table public.products, public.product_variants, public.recipes, public.recipe_versions, public.recipe_version_ingredients, public.product_variant_direct_costs, public.promotions, public.promotion_eligible_variants from anon, authenticated;
grant select, insert, update on table public.products, public.product_variants, public.recipes, public.recipe_versions, public.recipe_version_ingredients, public.product_variant_direct_costs, public.promotions, public.promotion_eligible_variants to authenticated;

create policy "authorized admins manage products" on public.products for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins manage product variants" on public.product_variants for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins manage recipes" on public.recipes for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins manage recipe versions" on public.recipe_versions for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins manage recipe ingredients" on public.recipe_version_ingredients for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins manage direct costs" on public.product_variant_direct_costs for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins manage promotions" on public.promotions for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));
create policy "authorized admins manage promotion variants" on public.promotion_eligible_variants for all to authenticated using (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin')) with check (exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin'));

revoke all on function public.publish_recipe_version(uuid) from public, anon, authenticated;
revoke all on function public.create_recipe_draft(uuid, text, numeric, text, numeric, text, jsonb) from public, anon, authenticated;
revoke all on function public.create_recipe_version(uuid, numeric, text, numeric, text, jsonb) from public, anon, authenticated;
grant execute on function public.publish_recipe_version(uuid) to authenticated;
grant execute on function public.create_recipe_draft(uuid, text, numeric, text, numeric, text, jsonb) to authenticated;
grant execute on function public.create_recipe_version(uuid, numeric, text, numeric, text, jsonb) to authenticated;

-- Configuração inicial idempotente de catálogo e promoções, sem criar receitas ou custos fictícios.
do $$
declare v_atelier_id uuid; v_pizza_id uuid; v_product_id uuid; v_variant_id uuid; item_name text; variant_name text;
begin
  select id into v_atelier_id from public.companies where slug = 'atelier-do-pao';
  select id into v_pizza_id from public.companies where slug = 'pizzas-do-condominio';
  if v_atelier_id is not null then
    foreach item_name in array array['Tradicional','Girassol','Aveia','Linhaça','Gergelim','Chia','Pão de Cacau 50%'] loop
      insert into public.products(company_id, name, category) values (v_atelier_id, item_name, 'Pães') on conflict (company_id, name) do update set is_active = true returning id into v_product_id;
      foreach variant_name in array array['200 g','650 g'] loop
        insert into public.product_variants(product_id, name, target_weight_g, price) values (v_product_id, variant_name, case when variant_name = '200 g' then 200 else 650 end, case when item_name = 'Pão de Cacau 50%' and variant_name = '200 g' then 15 when item_name = 'Pão de Cacau 50%' and variant_name = '650 g' then 32 when variant_name = '200 g' then 12 else 28 end) on conflict (product_id, name) do update set price = excluded.price, is_active = true returning id into v_variant_id;
      end loop;
    end loop;
  end if;
  if v_pizza_id is not null then
    foreach item_name in array array['Calabresa','Mussarela','Mista','Frango com requeijão','Chocolate'] loop
      insert into public.products(company_id, name, category) values (v_pizza_id, 'Pizza ' || item_name, 'Pizzas') on conflict (company_id, name) do update set is_active = true returning id into v_product_id;
      insert into public.product_variants(product_id, name, target_weight_g, price) values (v_product_id, '30 cm', null, 35) on conflict (product_id, name) do update set price = excluded.price, is_active = true returning id into v_variant_id;
    end loop;
  end if;
end;
$$;

do $$
declare v_atelier_id uuid; v_pizza_id uuid; v_promotion_id uuid; q integer; bundle numeric; promotion_name text;
begin
  select id into v_atelier_id from public.companies where slug = 'atelier-do-pao';
  select id into v_pizza_id from public.companies where slug = 'pizzas-do-condominio';
  if v_atelier_id is not null then
    foreach q in array array[1,2] loop
      bundle := case when q = 1 then 28 else 54 end;
      promotion_name := 'Pães clássicos 650 g - ' || q || ' unidade(s)';
      insert into public.promotions(company_id, name, quantity_mode, bundle_quantity, bundle_price, priority) values (v_atelier_id, promotion_name, 'exact', q, bundle, 20) on conflict (company_id, name, bundle_quantity) do update set bundle_price = excluded.bundle_price, is_active = true;
      select id into v_promotion_id from public.promotions where company_id = v_atelier_id and name = promotion_name and bundle_quantity = q;
      insert into public.promotion_eligible_variants(promotion_id, product_variant_id) select v_promotion_id, pv.id from public.product_variants pv join public.products p on p.id = pv.product_id where p.company_id = v_atelier_id and p.name <> 'Pão de Cacau 50%' and pv.name = '650 g' on conflict do nothing;
    end loop;
    foreach q in array array[1,2,3,4,5] loop
      bundle := case q when 1 then 12 when 2 then 19 when 3 then 28 when 4 then 35 else 39 end;
      promotion_name := 'Pães clássicos 200 g - ' || q || ' unidade(s)';
      insert into public.promotions(company_id, name, quantity_mode, bundle_quantity, bundle_price, priority) values (v_atelier_id, promotion_name, 'exact', q, bundle, 20) on conflict (company_id, name, bundle_quantity) do update set bundle_price = excluded.bundle_price, is_active = true;
      select id into v_promotion_id from public.promotions where company_id = v_atelier_id and name = promotion_name and bundle_quantity = q;
      insert into public.promotion_eligible_variants(promotion_id, product_variant_id) select v_promotion_id, pv.id from public.product_variants pv join public.products p on p.id = pv.product_id where p.company_id = v_atelier_id and p.name <> 'Pão de Cacau 50%' and pv.name = '200 g' on conflict do nothing;
    end loop;
    foreach q in array array[1,2] loop
      bundle := case when q = 1 then 32 else 62 end;
      promotion_name := 'Pão de Cacau 50% 650 g - ' || q || ' unidade(s)';
      insert into public.promotions(company_id, name, quantity_mode, bundle_quantity, bundle_price, priority) values (v_atelier_id, promotion_name, 'exact', q, bundle, 20) on conflict (company_id, name, bundle_quantity) do update set bundle_price = excluded.bundle_price, is_active = true;
      select id into v_promotion_id from public.promotions where company_id = v_atelier_id and name = promotion_name and bundle_quantity = q;
      insert into public.promotion_eligible_variants(promotion_id, product_variant_id) select v_promotion_id, pv.id from public.product_variants pv join public.products p on p.id = pv.product_id where p.company_id = v_atelier_id and p.name = 'Pão de Cacau 50%' and pv.name = '650 g' on conflict do nothing;
    end loop;
    foreach q in array array[1,2,3,4,5] loop
      bundle := case q when 1 then 15 when 2 then 22 when 3 then 32 when 4 then 39 else 44 end;
      promotion_name := 'Pão de Cacau 50% 200 g - ' || q || ' unidade(s)';
      insert into public.promotions(company_id, name, quantity_mode, bundle_quantity, bundle_price, priority) values (v_atelier_id, promotion_name, 'exact', q, bundle, 20) on conflict (company_id, name, bundle_quantity) do update set bundle_price = excluded.bundle_price, is_active = true;
      select id into v_promotion_id from public.promotions where company_id = v_atelier_id and name = promotion_name and bundle_quantity = q;
      insert into public.promotion_eligible_variants(promotion_id, product_variant_id) select v_promotion_id, pv.id from public.product_variants pv join public.products p on p.id = pv.product_id where p.company_id = v_atelier_id and p.name = 'Pão de Cacau 50%' and pv.name = '200 g' on conflict do nothing;
    end loop;
  end if;
  if v_pizza_id is not null then
    foreach q in array array[1,2] loop
      bundle := case when q = 1 then 35 else 60 end;
      promotion_name := 'Pizzas 30 cm - ' || q || ' unidade(s)';
      insert into public.promotions(company_id, name, quantity_mode, bundle_quantity, bundle_price, priority) values (v_pizza_id, promotion_name, 'exact', q, bundle, 20) on conflict (company_id, name, bundle_quantity) do update set bundle_price = excluded.bundle_price, is_active = true;
      select id into v_promotion_id from public.promotions where company_id = v_pizza_id and name = promotion_name and bundle_quantity = q;
      insert into public.promotion_eligible_variants(promotion_id, product_variant_id) select v_promotion_id, pv.id from public.product_variants pv join public.products p on p.id = pv.product_id where p.company_id = v_pizza_id and p.category = 'Pizzas' and pv.name = '30 cm' on conflict do nothing;
    end loop;
  end if;
end;
$$;
