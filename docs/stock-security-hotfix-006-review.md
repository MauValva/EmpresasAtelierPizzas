# Revisão direcionada — migration 006

## Resultado

**Compatível com o estado remoto conhecido, mas bloqueada para aplicação remota neste momento.**

O bloqueio é processual e de evidência, não uma incompatibilidade sintática observada:

- 003 e 005 ainda não estão reconciliadas no histórico.
- A migration 006 depende das funções e tabelas criadas por essas migrations.
- Os wrappers remotos já estão sem `EXECUTE` para `PUBLIC`, `anon` e `authenticated`, mas isso não prova que 006 esteja registrada ou integralmente aplicada.
- Ainda faltam testes reais de concorrência e idempotência em ambiente isolado.

## O que 006 faz

1. Revoga todos os privilégios dos wrappers:
   - `register_purchase_inventory_movement(...)`
   - `register_sale_stock_movement(...)`
2. Redefine ambos como `SECURITY DEFINER`, com `search_path = public, pg_temp`.
3. Mantém `EXECUTE` para `authenticated` somente em:
   - `receive_purchase(uuid)`
   - `confirm_sale(uuid, numeric, text, jsonb, uuid)`
4. Compra: exige `operation_key` e valida compra, item, quantidade, custo e `receipt_operation_key` antes de criar o movimento.
5. Venda: exige `operation_key` e valida venda em `draft`, snapshot, item, quantidade e custo antes de criar o movimento.

## Compatibilidade

### Wrappers e funções-pai

Os wrappers continuam sendo chamados internamente por `receive_purchase` e `confirm_sale`. Como essas funções são `SECURITY DEFINER`, a revogação de `EXECUTE` do papel `authenticated` não impede a chamada interna pelo proprietário da função.

O snapshot remoto já mostra:

- `receive_purchase`: `EXECUTE` para `authenticated`.
- `confirm_sale`: `EXECUTE` para `authenticated`.
- wrappers: nenhum `EXECUTE` para `PUBLIC`, `anon` ou `authenticated`.

Isso é compatível com o objetivo da 006 e não exige restaurar permissões perigosas.

### Segurança da cadeia

`register_inventory_movement` também é `SECURITY DEFINER`, usa `search_path = public, pg_temp`, valida administrador via `auth.uid()`, bloqueia o item com `FOR UPDATE` e possui idempotência por `operation_key`.

`receive_purchase` bloqueia a compra com `FOR UPDATE` antes de iterar os itens. `confirm_sale` bloqueia a venda com `FOR UPDATE`. Isso reduz duplicação em concorrência e torna a repetição de operações já concluídas idempotente.

## Riscos restantes

1. **Migração parcialmente refletida:** aplicar 006 sobre objetos remotos já alterados por SQL Editor pode substituir definições equivalentes, mas não deixa o histórico automaticamente correto.
2. **Dependência de ownership:** `SECURITY DEFINER` depende do proprietário da função possuir os privilégios necessários. A auditoria deve confirmar owner e ACL do proprietário antes da aplicação.
3. **Testes concorrentes ainda pendentes:** a análise estática confirma os locks principais, mas não substitui duas sessões PostgreSQL reais.
4. **Histórico:** não usar a ausência de 006 no histórico para inferir que os objetos estão na versão antiga; o remoto já apresenta os grants revogados e os corpos compatíveis.
5. **Rastreabilidade de origem:** o wrapper cria primeiro um movimento interno e depois atualiza `source_type/source_id`. Deve ser verificado em ambiente isolado se triggers de imutabilidade, caso existam, não bloqueiam essa anotação.

## Testes preparados

Arquivo: `supabase/tests/stock_security_hotfix_006.sql`.

Inclui verificações de ACL, `SECURITY DEFINER`, `search_path` e roteiro de integração para:

- acesso anônimo e autenticado aos wrappers;
- recebimento e confirmação legítimos;
- repetição e concorrência;
- origem inválida;
- quantidade/custo/chave incompatíveis;
- rollback transacional;
- ausência de duplicação de movimentos.

## Plano seguro de aplicação posterior

1. Fazer backup lógico e confirmar janela de manutenção.
2. Reexecutar a auditoria de histórico e guardar os resultados.
3. Confirmar que 003–005 foram reconciliadas ou que suas diferenças foram documentadas e aceitas.
4. Em clone/ambiente isolado, aplicar 006 e executar `stock_security_hotfix_006.sql` com fixtures descartáveis.
5. Comparar corpos, `SECURITY DEFINER`, `search_path`, owners e ACLs antes/depois.
6. No remoto, aplicar somente após autorização explícita, em transação controlada quando suportado pelo procedimento operacional.
7. Verificar imediatamente:
   - wrappers sem `EXECUTE` para `PUBLIC`, `anon`, `authenticated`;
   - pais com `EXECUTE` para `authenticated`;
   - recebimento e confirmação funcionando;
   - nenhum movimento duplicado;
   - histórico de migrations atualizado apenas pelo mecanismo oficial escolhido.

## Recomendação final

**Não aplicar ainda no remoto.** A migration é compatível e não deve restaurar os grants dos wrappers, mas a liberação exige reconciliação/documentação de 003–005, confirmação do owner SECURITY DEFINER e execução dos testes PostgreSQL concorrentes em ambiente isolado.
