import Link from "next/link";
import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/shared/page-header";
import { ExpenseList } from "@/components/finance/finance-list";
import { Button } from "@/components/ui/button";
export default function ExpensesPage() { return <AppShell pageTitle="Despesas"><PageHeader eyebrow="Financeiro" title="Despesas operacionais" description="Lançamentos exclusivos ou compartilhados com snapshot do rateio." action={<Button asChild><Link href="/financeiro/despesas/nova">Nova despesa</Link></Button>} /><ExpenseList /></AppShell>; }
