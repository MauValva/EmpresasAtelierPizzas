import { AppShell } from "@/components/layout/app-shell";
import { ExpenseList } from "@/components/finance/finance-list";

export default function ExpensesPage() {
  return <AppShell pageTitle="Gastos" eyebrow="Financeiro"><ExpenseList /></AppShell>;
}
