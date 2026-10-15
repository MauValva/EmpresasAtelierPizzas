import { Package } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { InventoryList } from "@/components/inventory/inventory-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";

export default function InventoryPage() { return <AppShell pageTitle="Estoque"><PageHeader eyebrow="Operação" title="Estoque" description="Ingredientes e saldos compartilhados entre Atelier do Pão e Pizzas do Condomínio." action={<StatusBadge tone="info"><Package className="h-3.5 w-3.5" />Controle compartilhado</StatusBadge>} /><InventoryList /></AppShell>; }
