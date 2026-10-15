import type { LucideIcon } from "lucide-react";
import { BarChart3, Boxes, ClipboardList, Home, MoreHorizontal, ShoppingCart } from "lucide-react";

export type NavItem = { label: string; href: string; icon: LucideIcon };

export const primaryNav: NavItem[] = [
  { label: "Início", href: "/", icon: Home },
  { label: "Pedidos", href: "/vendas", icon: ClipboardList },
  { label: "Venda", href: "/vendas/nova", icon: ShoppingCart },
  { label: "Estoque", href: "/estoque", icon: Boxes },
  { label: "Mais", href: "/mais", icon: MoreHorizontal },
];

export const secondaryNav: NavItem[] = [
  { label: "Clientes", href: "/clientes", icon: ClipboardList },
  { label: "Compras", href: "/compras", icon: ShoppingCart },
  { label: "Produtos", href: "/produtos", icon: Boxes },
  { label: "Receitas", href: "/receitas", icon: ClipboardList },
  { label: "Financeiro", href: "/financeiro", icon: BarChart3 },
  { label: "Relatórios", href: "/relatorios", icon: BarChart3 },
  { label: "Configurações", href: "/configuracoes", icon: MoreHorizontal },
];
