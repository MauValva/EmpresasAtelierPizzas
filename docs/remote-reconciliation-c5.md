# Fechamento da reconciliação — migrations 003–005

## Escopo e evidência

Foi reutilizado o `remote-audit.json` existente. Nenhuma consulta remota foi executada pelo Codex e nenhuma alteração foi feita no banco.

O snapshot contém os 20 objetos principais esperados: 20 tabelas, 198 colunas, 116 constraints, 53 índices, 20 policies, 20 funções, 15 triggers e 74 grants de funções. As sete funções `RETURNS trigger` estão presentes; as supostas ausências anteriores eram falso positivo do inventário.

## Histórico

O snapshot antigo contém `status: available` com `rows: []`, mas a consulta direta no SQL Editor confirmou:

- `202610130001`
- `202610140001`
- `202610140002`

A causa operacional é o snapshot ter sido produzido por uma consulta filtrada/interpretada como se o histórico tivesse apenas as versões-alvo. A consulta corrigida agora lê a relação sem filtro, retorna `version::text`, `name` e o tamanho bruto da versão, e não usa `COALESCE` para mascarar indisponibilidade. O resultado antigo não deve ser usado para concluir ausência de histórico.

## Comparação refinada

Após normalizar casts e formatação de defaults, o comparador identifica:

- 196 colunas equivalentes em tipo, nulabilidade e default.
- 2 colunas que dependem de evidência complementar do catálogo para confirmar geração: `purchase_items.total_cost` e `sales.order_number`.
- 0 colunas ausentes e 0 divergências estruturais comprovadas.
- 20 funções presentes, com definição remota completa no snapshot; a comparação automática de corpo continua marcada para revisão porque `pg_get_functiondef` inclui envelope, assinatura e delimitador PL/pgSQL diferentes do SQL-fonte local.
- Constraints, policies e triggers possuem definições remotas no JSON, mas o comparador ainda não faz o pareamento semântico completo de cada definição local com cada objeto remoto. Portanto, há evidência disponível, mas não equivalência automática concluída.

Os índices PRIMARY KEY e UNIQUE gerados por constraints são classificados como automáticos/legítimos; somente índices explícitos são comparados com os `CREATE INDEX` das migrations.

## Grants dos wrappers

Há divergência real de permissões, independente do histórico:

- Migration 003 local concede `EXECUTE` para `authenticated` em `register_purchase_inventory_movement`; o remoto não mostra esse grant para `PUBLIC`, `anon` ou `authenticated`.
- Migration 005 local concede `EXECUTE` para `authenticated` em `register_sale_stock_movement`; o remoto não mostra esse grant para `PUBLIC`, `anon` ou `authenticated`.
- `receive_purchase` e `confirm_sale` possuem `EXECUTE` para `authenticated` no snapshot remoto.

A ausência de `authenticated` nos wrappers é compatível com um hardening manual, mas não prova que a migration 006 foi aplicada. Ela permanece fora do histórico confirmado.

## Classificação individual

### 003 — purchases

**Divergente.** A ACL do wrapper de estoque diverge do `GRANT` explícito da migration local. Além disso, a confirmação semântica final de constraints, policies, triggers e corpos de função ainda não foi automatizada.

### 004 — catalog

**Evidência insuficiente.** Não há divergência concreta identificada no snapshot para essa migration, mas a equivalência completa das definições de constraints de publicação, policies, triggers e funções ainda não foi comprovada por comparação pareada.

### 005 — sales

**Divergente.** A ACL do wrapper de estoque diverge do `GRANT` explícito da migration local. A ausência de grant não deve ser reinterpretada como aplicação da 006.

## SQL complementar mínimo

Foi atualizado `supabase/audits/migration_history_gap.sql`. Ele consulta somente:

1. o histórico bruto sem filtro;
2. `attgenerated` e expressão de geração das duas colunas pendentes;
3. ACL efetiva dos quatro wrappers para `PUBLIC`, `anon` e `authenticated`.

Não contém DDL, SQL dinâmico, chamadas de negócio ou alteração de dados.

## Próxima ação concreta

Executar `supabase/audits/migration_history_gap.sql` no SQL Editor e salvar os três resultados. Em seguida, gerar um novo `remote-audit.json` com a consulta corrigida e rodar:

```text
node scripts/compare-remote-audit.mjs remote-audit.json
```

Não é seguro reconciliar 003–005 neste momento. Primeiro é necessário decidir/documentar se as ACLs remotas são uma alteração manual intencional e obter a evidência complementar das duas colunas geradas. Mesmo com isso, a equivalência de 004 só poderá ser liberada depois do pareamento semântico de constraints, policies, triggers e funções. Não executar `migration repair` até essa decisão.
