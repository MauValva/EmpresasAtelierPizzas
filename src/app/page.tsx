import { AppShell } from "@/components/layout/app-shell";
import { SummaryView } from "@/components/summary/summary-view";

export default function DashboardPage() {
  return <AppShell pageTitle="Resumo" eyebrow="Visão geral"><SummaryView /></AppShell>;
}
