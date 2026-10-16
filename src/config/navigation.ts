import type { LucideIcon } from "lucide-react";
import { BarChart3, Boxes, CircleDollarSign, ShoppingCart, Users } from "lucide-react";

export type NavItem = { label: string; href: string; icon: LucideIcon };

export const primaryNav: NavItem[] = [
  { label: "Vendas", href: "/vendas", icon: ShoppingCart },
  { label: "Estoque", href: "/estoque", icon: Boxes },
  { label: "Resumo", href: "/", icon: BarChart3 },
  { label: "Clientes", href: "/clientes", icon: Users },
  { label: "Gastos", href: "/gastos", icon: CircleDollarSign },
];

export const secondaryNav: NavItem[] = [];
