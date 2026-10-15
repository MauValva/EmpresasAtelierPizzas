import { AppShell } from "@/components/layout/app-shell";
import { RecipeForm } from "@/components/catalog/recipe-form";
import { PageHeader } from "@/components/shared/page-header";
export default function NewRecipePage() { return <AppShell pageTitle="Nova receita"><PageHeader eyebrow="Receitas" title="Nova receita-base" description="Associe ingredientes reais do estoque e informe o rendimento efetivo." /><div className="mt-7"><RecipeForm /></div></AppShell>; }
