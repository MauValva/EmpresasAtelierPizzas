import { AppShell } from "@/components/layout/app-shell";
import { SupplierForm } from "@/components/suppliers/supplier-form";
import { PageHeader } from "@/components/shared/page-header";
export default function NewSupplierPage() { return <AppShell pageTitle="Novo fornecedor"><PageHeader eyebrow="Fornecedores" title="Novo fornecedor" description="Cadastre um parceiro para usar nas compras." /><div className="mt-7 max-w-3xl"><SupplierForm /></div></AppShell>; }
