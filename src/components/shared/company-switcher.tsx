"use client";

import { Check, ChevronDown, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { companies as staticCompanies, type Company, type CompanyId } from "@/types/company";

export function CompanySwitcher({ companies = staticCompanies }: { companies?: Company[] }) {
  const selectableCompanies = useMemo(() => companies.length > 0 ? companies : [staticCompanies[0]], [companies]);
  const [selected, setSelected] = useState<CompanyId>("all");
  const [open, setOpen] = useState(false);
  const current = selectableCompanies.find((company) => company.id === selected) ?? selectableCompanies[0];

  useEffect(() => {
    const saved = window.localStorage.getItem("atelier-pizzas.company");
    if (saved === "all" || selectableCompanies.some((company) => company.id === saved)) setSelected(saved as CompanyId);
  }, [selectableCompanies]);

  useEffect(() => { window.localStorage.setItem("atelier-pizzas.company", selected); }, [selected]);

  function choose(company: Company) { setSelected(company.id); setOpen(false); }

  return <div className="relative"><button type="button" onClick={() => setOpen(true)} className="flex min-h-11 max-w-[164px] items-center gap-2 rounded-xl border border-border bg-surface px-2.5 text-left hover:bg-elevated focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent" aria-expanded={open} aria-haspopup="dialog"><span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-accent/15 text-xs font-bold text-accent">{current.shortName.slice(0, 1)}</span><span className="min-w-0"><span className="block text-[9px] uppercase tracking-[0.14em] text-muted">Empresa</span><span className="block truncate text-xs font-semibold text-foreground">{current.name}</span></span><ChevronDown className="h-4 w-4 shrink-0 text-muted" /></button>{open && <div className="fixed inset-0 z-40 bg-background/60 backdrop-blur-sm" role="presentation" onClick={() => setOpen(false)}><div className="absolute inset-x-0 bottom-0 rounded-t-3xl border border-border bg-surface p-4 pb-[max(1rem,env(safe-area-inset-bottom))] shadow-soft sm:left-auto sm:right-4 sm:top-20 sm:bottom-auto sm:w-72 sm:rounded-2xl sm:p-2" role="dialog" aria-label="Selecionar empresa" onClick={(event) => event.stopPropagation()}><div className="mb-3 flex items-center justify-between px-2 sm:hidden"><div><p className="text-xs font-semibold uppercase tracking-[0.16em] text-accent">Contexto</p><p className="mt-1 text-base font-semibold text-foreground">Selecionar empresa</p></div><button type="button" aria-label="Fechar seletor" onClick={() => setOpen(false)} className="flex h-10 w-10 items-center justify-center rounded-xl text-muted hover:bg-elevated hover:text-foreground"><X className="h-5 w-5" /></button></div>{selectableCompanies.map((company) => <button key={company.id} type="button" onClick={() => choose(company)} className="flex min-h-14 w-full items-center justify-between rounded-xl px-3 text-left hover:bg-elevated focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent"><span><span className="block text-sm font-semibold text-foreground">{company.name}</span><span className="mt-1 block text-xs text-muted">{company.description}</span></span>{selected === company.id && <Check className="h-4 w-4 text-accent" />}</button>)}</div></div>}</div>;
}
