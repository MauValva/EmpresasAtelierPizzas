-- Seed mínimo: somente as duas empresas, sem produtos ou valores fictícios.

insert into public.companies (name, slug, color)
values
  ('Atelier do Pão', 'atelier-do-pao', '#D5A66D'),
  ('Pizzas do Condomínio', 'pizzas-do-condominio', '#81B5D9')
on conflict (slug) do update
set name = excluded.name, color = excluded.color, is_active = true;
