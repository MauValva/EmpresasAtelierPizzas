import { AppShell } from "@/components/layout/app-shell";
import { ProductDetail } from "@/components/catalog/product-detail";
export default async function ProductDetailPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <AppShell pageTitle="Detalhe do produto"><ProductDetail id={id} /></AppShell>; }
