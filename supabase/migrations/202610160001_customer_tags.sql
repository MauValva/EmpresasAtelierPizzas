-- Etapa 16: tags automáticas de relacionamento dos clientes.

alter table public.customers
  add column if not exists customer_tags text[] not null default '{}'::text[];

alter table public.customers
  drop constraint if exists customers_customer_tags_check;

alter table public.customers
  add constraint customers_customer_tags_check
  check (customer_tags <@ array['paes', 'pizzas']::text[]);

create index if not exists customers_customer_tags_gin_idx
  on public.customers using gin (customer_tags);

create or replace function public.refresh_customer_tags_from_sales()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  affected_customer_id uuid;
begin
  affected_customer_id := coalesce(new.customer_id, old.customer_id);

  if affected_customer_id is null then
    return new;
  end if;

  update public.customers c
  set customer_tags = coalesce(tags.tags, '{}'::text[])
  from (
    select s.customer_id,
      array_agg(distinct case
        when co.slug = 'atelier-do-pao' then 'paes'
        when co.slug = 'pizzas-do-condominio' then 'pizzas'
        else null
      end) filter (where co.slug in ('atelier-do-pao', 'pizzas-do-condominio')) as tags
    from public.sales s
    join public.companies co on co.id = s.company_id
    where s.customer_id = affected_customer_id
    group by s.customer_id
  ) tags
  where c.id = affected_customer_id;

  if not found then
    update public.customers
    set customer_tags = '{}'::text[]
    where id = affected_customer_id;
  end if;

  return new;
end;
$$;

drop trigger if exists sales_refresh_customer_tags on public.sales;
create trigger sales_refresh_customer_tags
after insert or update on public.sales
for each row execute function public.refresh_customer_tags_from_sales();

-- Preenche as tags dos clientes já existentes ao aplicar a migration.
update public.customers c
set customer_tags = coalesce(tags.tags, '{}'::text[])
from (
  select s.customer_id,
    array_agg(distinct case
      when co.slug = 'atelier-do-pao' then 'paes'
      when co.slug = 'pizzas-do-condominio' then 'pizzas'
      else null
    end) filter (where co.slug in ('atelier-do-pao', 'pizzas-do-condominio')) as tags
  from public.sales s
  join public.companies co on co.id = s.company_id
  group by s.customer_id
) tags
where c.id = tags.customer_id;
