import { Boxes } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { ProductList } from "@/components/catalog/product-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";

export default function ProductsPage() { return <AppShell pageTitle="Produtos"><PageHeader eyebrow="Catálogo" title="Produtos" description="Catálogo, variações e preços separados por empresa." action={<StatusBadge tone="info"><Boxes className="h-3.5 w-3.5" />Por empresa</StatusBadge>} /><ProductList /></AppShell>; }
