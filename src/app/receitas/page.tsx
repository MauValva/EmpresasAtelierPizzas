import { BookOpen } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { RecipeList } from "@/components/catalog/recipe-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";
export default function RecipesPage() { return <AppShell pageTitle="Receitas"><PageHeader eyebrow="Produção" title="Receitas-base" description="Ingredientes, rendimento e versões publicadas para cada empresa." action={<StatusBadge tone="info"><BookOpen className="h-3.5 w-3.5" />Versionadas</StatusBadge>} /><RecipeList /></AppShell>; }
