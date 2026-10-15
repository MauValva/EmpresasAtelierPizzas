import Link from "next/link";
import { ArrowLeft, UserPlus } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { CustomerForm } from "@/components/customers/customer-form";
import { PageHeader } from "@/components/shared/page-header";
import { Button } from "@/components/ui/button";

export default function NewCustomerPage() { return <AppShell pageTitle="Novo cliente"><PageHeader eyebrow="Clientes" title="Novo cliente" description="Cadastre uma pessoa uma única vez para as duas operações." action={<Button asChild variant="outline"><Link href="/clientes"><ArrowLeft className="h-4 w-4" />Voltar</Link></Button>} /><div className="mt-7 max-w-3xl rounded-2xl border border-border bg-surface p-4 sm:p-6"><div className="mb-6 flex items-center gap-3 border-b border-border pb-5"><span className="flex h-11 w-11 items-center justify-center rounded-xl bg-accent/10 text-accent"><UserPlus className="h-5 w-5" /></span><div><h2 className="text-base font-semibold text-foreground">Dados do cliente</h2><p className="mt-1 text-xs text-muted">Campos com * são obrigatórios.</p></div></div><CustomerForm /></div></AppShell>; }
