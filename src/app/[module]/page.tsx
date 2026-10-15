import { Boxes, ClipboardList, FileText, Settings2, ShoppingCart, Users, WalletCards } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { EmptyState } from "@/components/shared/empty-state";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";

const modules: Record<string, { title: string; description: string; eyebrow: string; icon: typeof Boxes }> = {
  vendas: { title: "Vendas e pedidos", description: "Organize o fluxo comercial das duas operações.", eyebrow: "Comercial", icon: ClipboardList },
  clientes: { title: "Clientes", description: "Um espaço preparado para sua base de clientes.", eyebrow: "Relacionamento", icon: Users },
  estoque: { title: "Estoque", description: "Acompanhe o estoque compartilhado entre as empresas.", eyebrow: "Operação", icon: Boxes },
  compras: { title: "Compras", description: "Planeje suas compras e abastecimento.", eyebrow: "Operação", icon: ShoppingCart },
  produtos: { title: "Produtos", description: "Estruture o catálogo das suas operações.", eyebrow: "Catálogo", icon: FileText },
  receitas: { title: "Receitas", description: "Prepare fichas técnicas e receitas padronizadas.", eyebrow: "Produção", icon: FileText },
  financeiro: { title: "Financeiro", description: "Uma visão financeira independente por empresa.", eyebrow: "Financeiro", icon: WalletCards },
  relatorios: { title: "Relatórios", description: "Indicadores para apoiar suas decisões.", eyebrow: "Análises", icon: FileText },
  configuracoes: { title: "Configurações", description: "Preferências gerais do aplicativo.", eyebrow: "Sistema", icon: Settings2 },
};

export default async function ModulePage({ params }: { params: Promise<{ module: string }> }) {
  const { module } = await params;
  const data = modules[module] ?? { title: "Módulo", description: "Este módulo está sendo preparado.", eyebrow: "Workspace", icon: FileText };
  const Icon = data.icon;
  return <AppShell pageTitle={data.title}><PageHeader eyebrow={data.eyebrow} title={data.title} description={data.description} /><div className="mt-7"><div className="mb-4 flex items-center gap-2"><StatusBadge>Estrutura inicial</StatusBadge><span className="text-xs text-muted">Disponível visualmente na Etapa 03</span></div><EmptyState icon={Icon} title={`Nenhum dado em ${data.title.toLowerCase()}`} description="Este espaço está pronto para receber as funcionalidades das próximas etapas. Nenhuma operação real foi implementada ainda." /></div></AppShell>;
}
