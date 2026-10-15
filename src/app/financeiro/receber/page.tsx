import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/shared/page-header";
import { ReceivableList } from "@/components/finance/finance-list";
export default function ReceivablePage() { return <AppShell pageTitle="A receber"><PageHeader eyebrow="Financeiro" title="Contas a receber" description="Vendas confirmadas com saldo pendente, sem incluir rascunhos." /><ReceivableList /></AppShell>; }
