-- Testes de integração para 006_stock_security_hotfix.
-- Executar somente em banco isolado, com fixtures descartáveis e após carregar 001-006.
-- Este arquivo não deve ser executado no projeto remoto de desenvolvimento.

-- 1. Pré-condições de segurança: wrappers internos sem EXECUTE externo e funções-pai disponíveis.
select
  has_function_privilege('public', 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE') as purchase_public_execute,
  has_function_privilege('anon', 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE') as purchase_anon_execute,
  has_function_privilege('authenticated', 'public.register_purchase_inventory_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE') as purchase_authenticated_execute,
  has_function_privilege('public', 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE') as sale_public_execute,
  has_function_privilege('anon', 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE') as sale_anon_execute,
  has_function_privilege('authenticated', 'public.register_sale_stock_movement(uuid,numeric,numeric,text,uuid,uuid)', 'EXECUTE') as sale_authenticated_execute,
  has_function_privilege('authenticated', 'public.receive_purchase(uuid)', 'EXECUTE') as receive_authenticated_execute,
  has_function_privilege('authenticated', 'public.confirm_sale(uuid,numeric,text,jsonb,uuid)', 'EXECUTE') as confirm_authenticated_execute;

-- Resultado esperado: os seis primeiros valores false; os dois últimos true.

-- 2. Propriedades das funções SECURITY DEFINER.
select
  p.proname,
  p.prosecdef as security_definer,
  p.proconfig,
  pg_get_function_identity_arguments(p.oid) as identity_arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'register_inventory_movement',
    'register_purchase_inventory_movement',
    'register_sale_stock_movement',
    'receive_purchase',
    'confirm_sale'
  )
order by p.proname;

-- Resultado esperado: funções SECURITY DEFINER usam search_path contendo public e pg_temp.

-- 3. Testes comportamentais, a executar em transação isolada com usuário admin autenticado:
--    a) receive_purchase legítimo altera estoque uma vez.
--    b) repetir receive_purchase retorna o mesmo purchase recebido sem novo movimento.
--    c) duas sessões concorrentes recebendo a mesma compra resultam em um único conjunto
--       de movimentos; usar duas transações e a mesma purchase_id.
--    d) confirm_sale legítimo cria snapshots, baixa estoque e confirma a venda.
--    e) repetir confirm_sale não duplica snapshots nem movimentos.
--    f) duas sessões concorrentes confirmando a mesma venda resultam em uma confirmação.
--    g) chamada direta do wrapper por anon/authenticated falha por privilégio.
--    h) chamada com purchase_id/sale_id incorreto, quantidade, custo ou operation_key
--       incompatíveis falha com *_MOVEMENT_ORIGIN_INVALID.
--    i) operation_key repetida retorna o movimento existente e não altera o saldo novamente.
--    j) falha durante um item intermediário desfaz todos os movimentos da transação pai.
--
-- As chamadas de negócio não são incluídas aqui com UUIDs fictícios, pois dependem de
-- auth.users, profiles, companies, customers, receitas, itens e fixtures do ambiente.
-- Registrar os IDs das fixtures no protocolo de teste, sem levar dados reais ao remoto.
