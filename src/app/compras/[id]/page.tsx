import { AppShell } from "@/components/layout/app-shell";
import { PurchaseDetail } from "@/components/purchases/purchase-detail";
export default async function PurchaseDetailPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <AppShell pageTitle="Detalhe da compra"><PurchaseDetail id={id} /></AppShell>; }
