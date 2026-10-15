# Atelier & Pizzas — Gestão

Aplicação mobile-first para gestão comercial e financeira de duas operações: Atelier do Pão e Pizzas do Condomínio. A fundação visual e a Etapa 02 de autenticação/Supabase estão implementadas; as operações de negócio ainda não.

## Requisitos

- Node.js 20 ou superior
- npm 10 ou superior

## Instalação e desenvolvimento

```bash
npm install
npm run dev
```

Abra `http://localhost:3000` no navegador.

## Validação

```bash
npm run typecheck
npm run lint
npm run build
```

## Variáveis de ambiente

Copie `.env.example` para `.env.local` e preencha apenas a URL e a chave pública (anon) do projeto Supabase:

```env
NEXT_PUBLIC_SUPABASE_URL=https://seu-projeto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sua-chave-anon
```

Nunca adicione service role keys a variáveis `NEXT_PUBLIC_*` ou ao navegador.

## Estrutura principal

- `src/app`: rotas, layout global e estilos.
- `src/components/layout`: shell responsivo, sidebar e navegação inferior.
- `src/components/shared`: componentes reutilizáveis de produto.
- `src/components/ui`: primitives de interface no padrão shadcn/ui.
- `src/config`: navegação e configurações estáticas.
- `src/features`: reservado para módulos de domínio das próximas etapas.
- `src/lib` e `src/types`: utilitários e contratos TypeScript.
- `src/lib/supabase`: clientes browser/server e configuração de ambiente.
- `src/lib/auth`: verificação de sessão e autorização por perfil.
- `supabase/migrations`: migrations SQL versionadas com RLS.
- `docs/architecture.md`: mapa de entidades e regras para as próximas etapas.

## Deploy

O projeto está preparado para Vercel como aplicação Next.js. Conecte o repositório na Vercel e use o comando de build padrão. Não há deploy automático configurado nesta etapa.

## Configuração do Supabase — Etapa 02

1. Crie um projeto no painel do Supabase.
2. Copie a URL e a chave pública anon para `.env.local`.
3. Instale a CLI do Supabase e faça login, se ainda não estiver instalada.
4. Aponte o projeto e aplique a migration:

```bash
supabase link --project-ref SEU_PROJECT_REF
supabase db push
```

5. No painel Authentication, crie manualmente o primeiro usuário administrador com e-mail e senha. Não há cadastro público.
6. Copie o UUID desse usuário e autorize-o no SQL Editor:

```sql
insert into public.profiles (id, display_name, role)
values ('UUID_DO_USUARIO_AUTH', 'Administrador', 'admin');
```

7. Execute a aplicação e valide login, logout, leitura das duas empresas e bloqueio de usuário sem perfil.

Para a Vercel, configure as mesmas duas variáveis em Project Settings → Environment Variables para os ambientes desejados. Não é necessário configurar service role key nesta etapa.

## Escopo da Etapa 02

Há login por e-mail/senha, sessão via cookies SSR, proteção de rotas, autorização por perfil, migration inicial com RLS e empresas carregadas do Supabase. Não há CRUD, cálculos financeiros, vendas reais, pagamentos ou movimentações de estoque.
