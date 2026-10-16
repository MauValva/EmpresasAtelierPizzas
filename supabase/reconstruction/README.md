# Reconstrução SQL — Fase 1

Este diretório contém o modelo SQL simplificado da nova aplicação.

As migrations aqui não devem ser misturadas automaticamente com `supabase/migrations/`, que representa o modelo legado. Devem ser aplicadas em um projeto Supabase de desenvolvimento isolado ou em uma sessão controlada, na ordem numérica.

Nenhum arquivo desta pasta foi executado contra o Supabase remoto nesta fase.

O modelo preserva `auth.users` e cria `profiles` referenciando a autenticação existente. Não usa `DROP SCHEMA`, não remove usuários, Storage, buckets, secrets ou configurações de infraestrutura.

O modelo não recria compras, fornecedores, promoções, recorrências, etapas de produção/entrega, versionamento formal de receitas, estornos ou contas a pagar/receber.

Os testes de contrato ficam em `tests/001_contract.test.sql` e devem ser executados em banco de desenvolvimento com pgTAP habilitado.

## Fase 2.4.1

Fase 3.1: aplicar manualmente `010_recipe_atomic_operations.sql` depois de 009 e validar as funções com `verify_010_readonly.sql`. Nenhum teste remoto ou alteração de dados foi executado por este repositório.

As consultas somente leitura de `verify_009_readonly.sql` ajudam a confirmar as assinaturas, a coluna `notes` e os grants de `create_expense` sem modificar dados.

Fase 2.7: aplicar manualmente `009_expense_notes_and_date.sql` depois de 008. Ela adiciona a assinatura de `create_expense` usada pelo modal, preserva observações e rejeita datas futuras. Verifique o grant para `authenticated` antes de usar o cadastro de gastos.

O arquivo `008_sales_essential_flows.sql` é uma migration incremental para descontos, datas de pagamento retroativas e edição transacional de pedidos abertos. A aplicação deve ser feita manualmente no SQL Editor do Supabase, somente após confirmar o schema reconstruído. Este repositório não executa essa migration remotamente.

Após a execução, verifique as funções `create_sale_with_terms`, `update_open_sale` e `finalize_sale_with_date` em `pg_proc` e confirme os grants para `authenticated` antes de usar os fluxos no aplicativo.
