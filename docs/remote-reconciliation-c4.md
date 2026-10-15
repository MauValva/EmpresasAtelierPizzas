# Auditoria conclusiva — migrations 003–005

## Evidência analisada

Arquivo: `remote-audit.json` existente no workspace.

Inventário remoto retornado:

- 20 tabelas.
- 198 colunas.
- 116 constraints.
- 53 índices.
- 20 policies.
- 20 funções.
- 15 triggers.
- 74 grants de funções.

As 20 funções esperadas, incluindo as sete funções `RETURNS trigger`, aparecem no JSON. Portanto, as sete “ausências” anteriores eram falha do inventário esperado, não ausência comprovada no banco.

## Histórico

O JSON contém:

```json
{"status":"available","rows":[]}
```

Isso é inconsistente com a consulta direta informada pelo usuário, que confirmou 003, 004 e 005.

A causa mais provável é o filtro exato por `version` usado na auditoria anterior: ele pode não coincidir com o valor efetivamente armazenado ou com o formato de identificação usado pelo histórico remoto. Como o JSON não contém as linhas brutas, a causa exata não pode ser provada retroativamente.

Foi criada a consulta mínima `supabase/audits/migration_history_gap.sql`, que retorna `version` sem filtro e sem `COALESCE`.

## Comparação normalizada

Resultado do comparador atual:

- 164 colunas estruturalmente equivalentes.
- 32 colunas com default que exigem revisão textual.
- 2 colunas geradas sem metadados no JSON antigo:
  - `purchase_items.total_cost`
  - `sales.order_number`
- 0 colunas ausentes.
- 0 colunas classificadas como divergentes após tratar `PRIMARY KEY` e identity.
- 20 funções presentes, mas ainda não declaradas equivalentes pelo comparador de corpos.
- 0 funções ausentes.

Os 32 defaults são principalmente variações de representação do PostgreSQL, como `timezone('utc', now())` versus `timezone('utc'::text, now())`. A definição remota precisa ser comparada normalizando casts implícitos antes de concluir.

## Segurança remota observada

Para os wrappers de estoque:

- `register_purchase_inventory_movement`: nenhum grant para `PUBLIC`, `anon` ou `authenticated` no JSON; grants observados apenas para papéis internos.
- `register_sale_stock_movement`: nenhum grant para `PUBLIC`, `anon` ou `authenticated` no JSON; grants observados apenas para papéis internos.
- `receive_purchase`: `EXECUTE` para `authenticated`, além de papéis internos.
- `confirm_sale`: `EXECUTE` para `authenticated`, além de papéis internos.

Isso separa acesso externo dos wrappers da equivalência histórica. A ausência de `authenticated` nos wrappers é compatível com o hardening esperado, mas a migration 006 ainda não consta no histórico e a origem exata desses grants deve ser confirmada antes de afirmar que 006 está aplicada.

Há uma divergência de grants relevante para 005: o SQL local de 005 concede `EXECUTE` aos wrappers para `authenticated`, enquanto o JSON remoto não mostra esse privilégio. Isso pode ser uma aplicação manual parcial do hardening ou outra alteração remota. É uma diferença de definição/permissão que impede declarar 005 equivalente sem preservar e explicar a ACL atual.

## Seeds observados

As empresas esperadas existem e estão ativas. Foi observado:

```json
{
  "atelier_do_pao": 50,
  "pizzas_do_condominio": 50
}
```

Enquanto os slugs das empresas são:

```text
atelier-do-pao
pizzas-do-condominio
```

Essa diferença é uma pendência real para o fluxo de despesas recorrentes de 007, mas não afeta a equivalência estrutural de 003–005.

## Classificação por migration

### 003 — purchases

**Evidência insuficiente.**

Objetos, funções e triggers estão presentes por nome e contagem. Constraints, defaults, corpos completos e policies ainda não foram comparados semanticamente de forma conclusiva.

### 004 — catalog

**Evidência insuficiente.**

Objetos, funções, triggers e policies estão presentes. A equivalência das constraints de publicação, integridade entre empresas e corpos dos triggers ainda não está comprovada.

### 005 — sales

**Evidência insuficiente.**

Objetos, funções, triggers e policies estão presentes. Ainda falta comprovar integralmente funções transacionais, snapshots, reversões, grants e constraints.

Além disso, existe a divergência de grants dos wrappers de estoque descrita acima.

## Decisão

Nenhuma migration pode ser registrada como aplicada com segurança usando somente o JSON atual.

Não foram executados `migration repair`, `db push`, `db reset` ou qualquer alteração remota.

## Próxima ação

Executar somente `supabase/audits/migration_history_gap.sql` no SQL Editor para obter as versões brutas. Em seguida, complementar apenas as definições ainda ausentes: constraints, defaults gerados, corpos de funções, policies e triggers. Só após essa evidência as migrations poderão receber classificação de elegibilidade.
