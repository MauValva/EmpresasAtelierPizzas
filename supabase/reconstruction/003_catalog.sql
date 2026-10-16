-- Produtos comerciais, receitas sem versionamento formal e seus ingredientes.

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  yield_quantity numeric(18,6) not null check (yield_quantity > 0),
  yield_unit text not null check (yield_unit in ('un', 'g', 'ml')),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (company_id, name)
);

create table public.products (
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

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  price numeric(18,6) not null check (price >= 0),
  target_weight_g numeric(18,6) check (target_weight_g is null or target_weight_g > 0),
  recipe_id uuid references public.recipes(id) on delete restrict,
  recipe_portions numeric(18,6) not null default 1 check (recipe_portions > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (product_id, name)
);

create table public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete restrict,
  inventory_item_id uuid not null references public.inventory_items(id) on delete restrict,
  quantity_base numeric(18,6) not null check (quantity_base > 0),
  created_at timestamptz not null default timezone('utc', now()),
  unique (recipe_id, inventory_item_id)
);

create index recipes_company_active_idx on public.recipes(company_id, is_active);
create index products_company_active_idx on public.products(company_id, is_active);
create index product_variants_product_active_idx on public.product_variants(product_id, is_active);
create index recipe_ingredients_recipe_idx on public.recipe_ingredients(recipe_id);
create index recipe_ingredients_inventory_idx on public.recipe_ingredients(inventory_item_id);

create trigger recipes_set_updated_at before update on public.recipes
for each row execute function public.set_updated_at();
create trigger products_set_updated_at before update on public.products
for each row execute function public.set_updated_at();
create trigger product_variants_set_updated_at before update on public.product_variants
for each row execute function public.set_updated_at();

create or replace function public.validate_variant_recipe_company()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.recipe_id is not null and not exists (
    select 1
    from public.products p
    join public.recipes r on r.id = new.recipe_id and r.company_id = p.company_id
    where p.id = new.product_id
  ) then
    raise exception using message = 'PRODUCT_RECIPE_COMPANY_MISMATCH';
  end if;
  return new;
end;
$$;

create trigger product_variant_recipe_company_check
before insert or update on public.product_variants
for each row execute function public.validate_variant_recipe_company();
