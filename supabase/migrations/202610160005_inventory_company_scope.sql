-- Etapa 16.5: ingredientes disponíveis por operação.

alter table public.inventory_items
  add column if not exists company_scope text not null default 'both';

alter table public.inventory_items
  drop constraint if exists inventory_items_company_scope_check;

alter table public.inventory_items
  add constraint inventory_items_company_scope_check
  check (company_scope in ('atelier', 'pizza', 'both'));
