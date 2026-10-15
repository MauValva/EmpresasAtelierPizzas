import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/shared/page-header";
import { ExpenseForm } from "@/components/finance/expense-form";
export default function NewExpensePage() { return <AppShell pageTitle="Nova despesa"><PageHeader eyebrow="Financeiro" title="Nova despesa" description="Registre a competência e preserve o rateio no lançamento." /><div className="mt-7"><ExpenseForm /></div></AppShell>; }
