-- Etapa 16.3: clientes não armazenam autorização promocional.

alter table public.customers
  drop column if exists marketing_consent;
