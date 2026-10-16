"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronRight, CircleDot } from "lucide-react";
import { primaryNav } from "@/config/navigation";
import { cn } from "@/lib/utils";

export function DesktopSidebar() {
  const pathname = usePathname();
  return <aside className="fixed inset-y-0 left-0 hidden w-64 flex-col border-r border-border bg-background px-4 py-6 lg:flex"><div className="flex items-center gap-3 px-3"><span className="flex h-10 w-10 items-center justify-center rounded-xl bg-accent text-lg font-bold text-background">A</span><div><p className="font-semibold text-foreground">Atelier &amp; Pizzas</p><p className="text-xs text-muted">Gestão comercial</p></div></div><div className="mt-10"><p className="mb-3 px-3 text-[10px] font-semibold uppercase tracking-[0.18em] text-muted">Menu principal</p><nav className="space-y-1">{primaryNav.map(({ label, href, icon: Icon }) => { const active = href === "/" ? pathname === href : pathname.startsWith(href); return <Link key={href} href={href} className={cn("flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-medium transition-colors", active ? "bg-accent/10 text-accent" : "text-muted hover:bg-elevated hover:text-foreground")}><Icon className="h-[18px] w-[18px]" /><span>{label}</span>{active && <ChevronRight className="ml-auto h-4 w-4" />}</Link>; })}</nav></div><div className="mt-auto rounded-2xl border border-border bg-surface p-4"><div className="flex items-center gap-2 text-xs font-semibold text-foreground"><CircleDot className="h-3.5 w-3.5 text-success" /> Ambiente local</div><p className="mt-2 text-xs leading-5 text-muted">Atelier &amp; Pizzas</p></div></aside>;
}
