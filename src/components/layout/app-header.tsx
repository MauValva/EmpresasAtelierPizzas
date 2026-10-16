import { CompanySwitcher } from "@/components/shared/company-switcher";
import { getCompanies } from "@/lib/companies";

export async function AppHeader({ eyebrow = "Workspace", pageTitle }: { eyebrow?: string; pageTitle: string }) {
  const companies = await getCompanies();
  return <header className="sticky top-0 z-10 border-b border-border bg-background/95 px-4 backdrop-blur-xl sm:px-6 lg:px-10"><div className="flex min-h-16 items-center justify-between gap-3"><div className="min-w-0"><p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-accent">{eyebrow}</p><h1 className="truncate text-xl font-semibold tracking-tight text-foreground sm:text-2xl">{pageTitle}</h1></div><CompanySwitcher companies={companies} /></div></header>;
}
