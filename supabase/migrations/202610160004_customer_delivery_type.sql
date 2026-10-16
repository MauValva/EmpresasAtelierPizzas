-- Etapa 16.4: tipo de endereço escolhido individualmente por cliente.

alter table public.customers
  add column if not exists delivery_type text;

alter table public.customers
  drop constraint if exists customers_delivery_type_check;

alter table public.customers
  add constraint customers_delivery_type_check
  check (delivery_type is null or delivery_type in ('condominio', 'fora'));

update public.customers
set delivery_type = case
  when building_block is not null or apartment is not null then 'condominio'
  when street is not null or address_number is not null or neighborhood is not null or city is not null then 'fora'
  else null
end
where pickup_order = true and delivery_type is null;
