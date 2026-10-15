# Arquitetura inicial e mapa de entidades

## Segurança e autenticação

- O navegador usa `createBrowserClient` de `@supabase/ssr`.
- Server Components usam `createServerClient` com cookies do Next.js.
- `middleware.ts` atualiza a sessão e protege as rotas internas.
- A autorização não depende apenas da sessão: o usuário precisa existir em `public.profiles` com `role = 'admin'`.
- A service role key não existe no projeto e nunca deve ser adicionada a variáveis `NEXT_PUBLIC_*`.

## Entidades futuras

`profiles` autoriza usuários; `companies` representa as duas empresas; `app_settings` guarda configurações globais não sensíveis.

O mapa previsto para as próximas etapas é:

```text
profiles ──< sales >── companies
    │          │
    │          └──< sale_items >── product_variants >── products >── companies
    │
    ├──< customers >──< sales
    └──< manual_expenses >──< expense_allocations >── companies

products ──< recipe_versions >──< recipe_ingredients >── inventory_items
suppliers ──< purchases >──< purchase_items >── inventory_items
inventory_items ──< stock_movements
sales ──< payments
sales ──< orders ──< deliveries
```

Regras que devem orientar as próximas migrations:

1. Estoque é compartilhado; venda e faturamento pertencem a uma empresa.
2. Clientes são compartilhados entre as empresas.
3. Confirmação de venda reconhece faturamento e gera movimentações transacionais.
4. Pagamentos ficam separados da confirmação da venda.
5. Custo de estoque usa média ponderada, com snapshots históricos.
6. Compras não são duplicadas como despesa e custo de produto.
7. Cancelamentos geram estornos explícitos.
8. Rateios guardam o percentual aplicado no momento da operação.

## Escopo da migration atual

Somente perfis autorizados, empresas e configurações globais são criados nesta etapa. As tabelas de negócio ficam para migrations próprias.
