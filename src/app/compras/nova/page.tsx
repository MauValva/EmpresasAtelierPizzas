import { AppShell } from "@/components/layout/app-shell";
import { PurchaseForm } from "@/components/purchases/purchase-form";
import { PageHeader } from "@/components/shared/page-header";
export default function NewPurchasePage() { return <AppShell pageTitle="Nova compra"><PageHeader eyebrow="Compras" title="Nova compra" description="Monte a compra, revise os totais e confirme o recebimento apenas quando a mercadoria chegar." /><div className="mt-7"><PurchaseForm /></div></AppShell>; }
