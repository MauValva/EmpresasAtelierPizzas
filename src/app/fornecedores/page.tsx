import { Building2 } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { SupplierList } from "@/components/suppliers/supplier-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";
export default function SuppliersPage() { return <AppShell pageTitle="Fornecedores"><PageHeader eyebrow="Compras" title="Fornecedores" description="Mantenha os parceiros de abastecimento ativos e preservados no histórico." action={<StatusBadge tone="info"><Building2 className="h-3.5 w-3.5" />Cadastro compartilhado</StatusBadge>} /><SupplierList /></AppShell>; }
