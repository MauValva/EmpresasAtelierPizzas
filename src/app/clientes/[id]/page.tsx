import { AppShell } from "@/components/layout/app-shell";
import { CustomerDetail } from "@/components/customers/customer-detail";

export default async function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <AppShell pageTitle="Detalhe do cliente"><CustomerDetail id={id} /></AppShell>; }
