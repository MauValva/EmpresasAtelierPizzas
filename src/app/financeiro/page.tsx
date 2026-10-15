import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/shared/page-header";
import { DashboardView } from "@/components/dashboard/dashboard-view";
export default function FinancePage() { return <AppShell pageTitle="Dashboard"><PageHeader eyebrow="Gestão" title="Dashboard gerencial" description="Resultado, caixa e operação em um único período de análise." /><DashboardView /></AppShell>; }
