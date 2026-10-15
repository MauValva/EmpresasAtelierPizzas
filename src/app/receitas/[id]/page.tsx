import { AppShell } from "@/components/layout/app-shell";
import { RecipeDetail } from "@/components/catalog/recipe-detail";
export default async function RecipeDetailPage({ params }: { params: Promise<{ id: string }> }) { const { id } = await params; return <AppShell pageTitle="Detalhe da receita"><RecipeDetail id={id} /></AppShell>; }
