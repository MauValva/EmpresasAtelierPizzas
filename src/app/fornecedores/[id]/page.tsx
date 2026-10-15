import { AppShell } from "@/components/layout/app-shell";
import { SupplierDetail } from "@/components/suppliers/supplier-detail";
export default async function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <AppShell pageTitle="Detalhe do fornecedor"><SupplierDetail id={id} /></AppShell>; }
