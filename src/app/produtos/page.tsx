import Link from "next/link";
import { Boxes } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { ProductList } from "@/components/catalog/product-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";
import { Button } from "@/components/ui/button";
export default function ProductsPage() { return <AppShell pageTitle="Produtos"><PageHeader eyebrow="Catálogo" title="Produtos" description="Catálogo, variações e preços separados por empresa." action={<div className="flex items-center gap-2"><Button asChild variant="outline" size="sm"><Link href="/promocoes">Promoções</Link></Button><StatusBadge tone="info"><Boxes className="h-3.5 w-3.5" />Por empresa</StatusBadge></div>} /><ProductList /></AppShell>; }
