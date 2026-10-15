import { AppShell } from "@/components/layout/app-shell";
import { SaleDetail } from "@/components/sales/sale-detail";
export default async function SaleDetailPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <AppShell pageTitle="Detalhe do pedido"><SaleDetail id={id} /></AppShell>; }
