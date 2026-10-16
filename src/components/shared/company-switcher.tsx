"use client";

import { Check, ChevronDown, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { announceCompanyChange, COMPANY_STORAGE_KEY } from "@/lib/company-selection";
import { companies as staticCompanies, type Company, type CompanyId } from "@/types/company";

export function CompanySwitcher({ companies = staticCompanies }: { companies?: Company[] }) {
  const selectableCompanies = useMemo(() => companies.length > 0 ? companies : [staticCompanies[0]], [companies]);
  const [selected, setSelected] = useState<CompanyId>("all");
  const [open, setOpen] = useState(false);
  const current = selectableCompanies.find((company) => company.id === selected) ?? selectableCompanies[0];

  useEffect(() => {
    const savedDatabaseId = window.localStorage.getItem(COMPANY_STORAGE_KEY);
    const saved = savedDatabaseId ? selectableCompanies.find((company) => company.databaseId === savedDatabaseId)?.id : "all";
    if (saved && selectableCompanies.some((company) => company.id === saved)) setSelected(saved as CompanyId);
  }, [selectableCompanies]);

  function choose(company: Company) {
    setSelected(company.id);
    announceCompanyChange(company.databaseId ?? "");
    setOpen(false);
  }

  return <div className="relative min-w-0">
    <button type="button" onClick={() => setOpen(true)} className="flex h-11 w-[164px] min-w-0 max-w-[164px] items-center gap-2 overflow-hidden rounded-xl border border-border bg-surface px-2.5 text-left hover:bg-elevated focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent" aria-expanded={open} aria-haspopup="dialog">
      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-accent/15 text-xs font-bold text-accent">{current.shortName.slice(0, 1)}</span>
      <span className="min-w-0 flex-1 overflow-hidden"><span className="block text-[9px] uppercase tracking-[0.14em] text-muted">Empresa</span><span className="block truncate text-xs font-semibold text-foreground">{current.name}</span></span>
      <ChevronDown className="h-4 w-4 shrink-0 text-muted" />
    </button>
    {open && <div className="fixed inset-0 z-40 bg-background/35" role="presentation" onClick={() => setOpen(false)}>
      <div className="absolute left-4 right-4 top-[4.5rem] max-h-[calc(100dvh-6rem)] overflow-y-auto rounded-2xl border border-border bg-surface p-2 shadow-soft sm:left-auto sm:right-4 sm:top-20 sm:w-72" role="dialog" aria-label="Selecionar empresa" onClick={(event) => event.stopPropagation()}>
        <div className="mb-1 flex items-center justify-between px-2 sm:hidden"><p className="text-xs font-semibold uppercase tracking-[0.16em] text-accent">Empresa</p><button type="button" aria-label="Fechar seletor" onClick={() => setOpen(false)} className="flex h-8 w-8 items-center justify-center rounded-lg text-muted hover:bg-elevated hover:text-foreground"><X className="h-4 w-4" /></button></div>
        {selectableCompanies.map((company) => <button key={company.id} type="button" onClick={() => choose(company)} className="flex min-h-14 w-full items-center justify-between rounded-xl px-3 text-left hover:bg-elevated focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"><span className="min-w-0 flex-1 overflow-hidden"><span className="block truncate text-sm font-semibold text-foreground">{company.name}</span><span className="mt-1 block truncate text-xs text-muted">{company.description}</span></span>{selected === company.id && <Check className="h-4 w-4 shrink-0 text-accent" />}</button>)}
      </div>
    </div>}
  </div>;
}
