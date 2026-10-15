import { ClipboardList } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { SaleList } from "@/components/sales/sale-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";
export default function SalesPage() { return <AppShell pageTitle="Pedidos"><PageHeader eyebrow="Comercial" title="Vendas e encomendas" description="Acompanhe pedidos imediatos e entregas futuras por empresa." action={<StatusBadge tone="info"><ClipboardList className="h-3.5 w-3.5" />Estoque integrado</StatusBadge>} /><SaleList /></AppShell>; }
