import { AppShell } from "@/components/layout/app-shell";
import { InventoryDetail } from "@/components/inventory/inventory-detail";

export default async function InventoryDetailPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <AppShell pageTitle="Detalhe do estoque"><InventoryDetail id={id} /></AppShell>; }
