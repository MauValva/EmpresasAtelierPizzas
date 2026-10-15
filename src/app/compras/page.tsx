import { ShoppingCart } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { PurchaseList } from "@/components/purchases/purchase-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";
export default function PurchasesPage() { return <AppShell pageTitle="Compras"><PageHeader eyebrow="Abastecimento" title="Compras" description="Registre pedidos, recebimentos e pagamentos sem separar o estoque compartilhado." action={<StatusBadge tone="info"><ShoppingCart className="h-3.5 w-3.5" />Entrada controlada</StatusBadge>} /><PurchaseList /></AppShell>; }
