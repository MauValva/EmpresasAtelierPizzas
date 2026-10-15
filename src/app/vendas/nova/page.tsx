import { AppShell } from "@/components/layout/app-shell";
import { SaleForm } from "@/components/sales/sale-form";
import { PageHeader } from "@/components/shared/page-header";
export default function NewSalePage() { return <AppShell pageTitle="Nova venda"><PageHeader eyebrow="Comercial" title="Nova venda" description="Crie uma venda imediata ou uma encomenda futura. A confirmação recalcula os valores e baixa o estoque." /><div className="mt-7"><SaleForm /></div></AppShell>; }
