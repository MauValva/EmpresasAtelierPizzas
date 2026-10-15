import { Bell, Menu } from "lucide-react";
import { CompanySwitcher } from "@/components/shared/company-switcher";
import { Button } from "@/components/ui/button";
import { LogoutButton } from "@/components/layout/logout-button";
import { getCompanies } from "@/lib/companies";

export async function AppHeader({ displayName, pageTitle }: { displayName: string | null; pageTitle: string }) {
  const companies = await getCompanies();
  return <header className="sticky top-0 z-10 border-b border-border bg-background/90 px-4 backdrop-blur-xl sm:px-6 lg:px-10"><div className="flex min-h-[72px] items-center justify-between gap-3"><div className="flex min-w-0 items-center gap-3"><Button variant="ghost" size="icon" className="lg:hidden" aria-label="Abrir menu"><Menu className="h-5 w-5" /></Button><div className="min-w-0"><p className="truncate text-sm font-semibold text-foreground">{pageTitle}</p><p className="truncate text-[10px] text-muted">Atelier & Pizzas · Gestão comercial</p></div></div><div className="flex shrink-0 items-center gap-1.5 sm:gap-3"><span className="hidden text-xs text-muted xl:inline">{displayName ?? "Administrador"}</span><Button variant="ghost" size="icon" aria-label="Notificações"><Bell className="h-5 w-5" /></Button><CompanySwitcher companies={companies} /><span className="hidden sm:block"><LogoutButton /></span></div></div></header>;
}
