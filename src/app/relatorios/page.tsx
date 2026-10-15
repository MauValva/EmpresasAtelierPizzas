import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/shared/page-header";
import { ReportView } from "@/components/reports/report-view";
export default function ReportsPage() { return <AppShell pageTitle="Relatórios"><PageHeader eyebrow="Análise gerencial" title="Relatórios" description="Vendas, produtos, finanças, despesas, estoque e comparação entre empresas." /><ReportView /></AppShell>; }
