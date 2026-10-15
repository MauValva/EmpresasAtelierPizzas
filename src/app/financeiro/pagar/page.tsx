import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/shared/page-header";
import { PayableList } from "@/components/finance/finance-list";
export default function PayablePage() { return <AppShell pageTitle="A pagar"><PageHeader eyebrow="Financeiro" title="Contas a pagar" description="Compras de estoque e despesas operacionais, sem duplicar obrigações." /><PayableList /></AppShell>; }
