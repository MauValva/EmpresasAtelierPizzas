import { AppShell } from "@/components/layout/app-shell";
import { ProductForm } from "@/components/catalog/product-form";
import { PageHeader } from "@/components/shared/page-header";
export default function NewProductPage() { return <AppShell pageTitle="Novo produto"><PageHeader eyebrow="Produtos" title="Novo produto" description="Cadastre o produto e suas variações comerciais." /><div className="mt-7"><ProductForm /></div></AppShell>; }
