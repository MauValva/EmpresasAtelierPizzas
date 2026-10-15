import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/shared/page-header";
import { CashList } from "@/components/finance/finance-list";
export default function CashPage() { return <AppShell pageTitle="Caixa"><PageHeader eyebrow="Financeiro" title="Fluxo de caixa realizado" description="Entradas e saídas efetivamente pagas, incluindo reembolsos." /><CashList /></AppShell>; }
