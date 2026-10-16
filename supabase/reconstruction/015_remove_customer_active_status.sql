-- Fase 3.3: clientes não possuem status ativo/inativo.
-- Aplicar manualmente depois da migration 014.
-- Não remove clientes nem histórico de vendas.

begin;

alter table public.customers
  drop column if exists is_active;

commit;
