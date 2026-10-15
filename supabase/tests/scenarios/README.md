# Cenários de integração real

Estes cenários devem ser executados em um PostgreSQL local descartável, depois que as migrations 001–008 forem carregadas. Eles não são executados automaticamente pelo Supabase remoto.

## Fixture mínima

Criar somente dados fictícios:

- um usuário Auth administrador com `profiles.role = 'admin'`;
- um usuário Auth sem linha em `profiles`;
- as duas empresas seed;
- um cliente;
- um fornecedor;
- um ingrediente ativo com saldo inicial zero;
- uma receita publicada, variante e item de venda;
- uma compra em estado `draft` com um item;
- uma venda em estado `draft` com item e snapshot de ingrediente.

Ao testar RPCs, configurar `request.jwt.claim.sub` com o UUID do usuário administrador e usar o papel `authenticated`. Nunca usar credenciais ou IDs do Supabase remoto.

## Cenários obrigatórios

1. **Segurança:** anon e authenticated sem perfil não acessam tabelas protegidas nem funções administrativas; o wrapper de compra e o de venda falham por privilégio.
2. **Recebimento:** `receive_purchase` legítimo cria um movimento de entrada, atualiza saldo e custo médio.
3. **Recebimento idempotente:** repetir o recebimento não cria movimento adicional.
4. **Venda:** `confirm_sale` cria snapshots, baixa estoque e confirma a venda.
5. **Venda idempotente:** repetir a confirmação não duplica snapshots nem movimentos.
6. **Origem falsa:** wrapper com purchase/sale ID, item, quantidade, custo ou chave incompatível falha.
7. **Rollback:** uma falha em item posterior desfaz alterações de saldo, snapshots e ledger da operação.
8. **Concorrência:** duas sessões confirmando a mesma venda ou recebendo a mesma compra produzem um único resultado.
9. **Estorno:** estorno parcial e integral preservam pagamentos e não criam valores negativos indevidos.
10. **Financeiro:** pagamento parcial, excesso, duplicidade por `operation_key`, despesa compartilhada e rateio de 100%.
11. **Recorrência:** a mesma competência não gera duas despesas para a mesma recorrência.
12. **Imutabilidade:** venda confirmada, compra recebida, snapshots e movimentos históricos não podem ser alterados fora do fluxo de reversão.

## Concorrência

Abrir duas conexões PostgreSQL independentes. Iniciar as duas transações antes de chamar a mesma RPC, registrar o tempo de espera e confirmar que somente uma alteração efetiva foi criada. Não simular concorrência com duas chamadas sequenciais na mesma conexão.
