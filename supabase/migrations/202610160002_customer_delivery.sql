-- Etapa 16.2: retirada e dados de entrega específicos por empresa.

alter table public.customers
  add column if not exists pickup_order boolean not null default false,
  add column if not exists street text,
  add column if not exists address_number text,
  add column if not exists neighborhood text,
  add column if not exists city text,
  add column if not exists building_block text;
