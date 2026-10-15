# Preparação dos testes de integração PostgreSQL

## Escopo

A suíte foi preparada para um Supabase local, descartável, com PostgreSQL fornecido pelo Supabase CLI/Docker. Nenhum comando foi executado automaticamente e nenhum teste foi executado contra o projeto remoto.

## Requisitos

- Docker Desktop em execução.
- Supabase CLI instalado e disponível no PATH.
- Node.js para verificações locais.
- Workspace com as migrations 001–008.

O ambiente atual não possui `supabase/config.toml` no workspace e a disponibilidade do CLI/Docker não foi presumida. Isso é um bloqueio de execução, não de preparação.

## Verificação local da ordem

```powershell
node scripts/verify-local-migration-order.mjs
```

O script somente verifica os nove arquivos esperados e não conecta nem executa SQL.

## Execução recomendada, somente local

Depois de instalar os requisitos:

```powershell
supabase init
supabase start
supabase db reset --local
supabase test db
supabase stop
```

`supabase init` deve ser executado apenas se o projeto local ainda não tiver configuração. `db reset --local` é destrutivo somente para o banco local descartável; nunca substituir por um comando sem `--local` apontado a projeto remoto.

Os testes de contrato existentes e o novo `supabase/tests/integration_security.test.sql` devem rodar via pgTAP. Os cenários comportamentais em `supabase/tests/scenarios/README.md` exigem fixtures e duas conexões reais; não devem ser considerados cobertos por testes unitários ou por uma única sessão.

## Ordem testada

1. Foundation.
2. Customers.
3. Inventory.
4. Purchases.
5. Catalog.
6. Sales.
7. Stock security hotfix 006.
8. Finance 007.
9. Integrity hardening 008.

O nome e a ordem são validados pelo script local. As migrations históricas não foram alteradas.

## Cobertura preparada

| Área | Contrato preparado | Integração real pendente |
|---|---:|---:|
| Ordem e presença das migrations | Sim | Execução local |
| RLS e grants | Sim | Teste com roles reais |
| Wrappers e SECURITY DEFINER | Sim | Chamada interna autenticada |
| Recebimento e custo médio | Parcial | Fixture e RPC |
| Confirmação e baixa de estoque | Parcial | Fixture e RPC |
| Cancelamento/reversão | Não conclusivo | Duas sessões e ledger |
| Pagamentos/estornos | Contrato | Cenários financeiros |
| Rateio/recorrência | Contrato | Fixtures financeiras |
| Idempotência | Especificada | Execução real |
| Rollback | Especificado | Falha controlada |
| Concorrência | Especificada | Duas conexões PostgreSQL |

## Bloqueios atuais

- Docker/Supabase CLI não foram executados nem confirmados neste ambiente.
- O histórico remoto 003–005 continua pendente de reconciliação.
- 006–008 não foram aplicadas remotamente.
- Ainda não há resultado de PostgreSQL local para validar concorrência, owners de `SECURITY DEFINER`, rollback e comportamento das RPCs.

## Critério de aprovação

Liberar a próxima integração somente quando o banco local concluir sem falhas: contracts, RLS/grants, recebimento, venda, cancelamento/reversão, pagamentos, estornos, despesas, recorrências, idempotência, rollback e concorrência. Falhas de catálogo, definições de função ou permissões devem bloquear a aplicação remota.
