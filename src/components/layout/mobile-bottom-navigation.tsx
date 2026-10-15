"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { primaryNav } from "@/config/navigation";
import { cn } from "@/lib/utils";

export function MobileBottomNavigation() {
  const pathname = usePathname();
  return <nav aria-label="Navegação principal" className="fixed inset-x-0 bottom-0 z-20 border-t border-border bg-background/95 px-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2 backdrop-blur-xl lg:hidden"><div className="mx-auto flex max-w-md items-end justify-around">{primaryNav.map(({ label, href, icon: Icon }) => { const active = href === "/" ? pathname === href : pathname.startsWith(href); const sale = label === "Venda"; return <Link key={href} href={href} aria-current={active ? "page" : undefined} className={cn("flex min-h-11 min-w-14 flex-col items-center justify-center gap-1 rounded-xl px-2 text-[10px] font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent", sale && "-mt-5 min-h-16 min-w-16 rounded-2xl border-4 border-background bg-accent text-background shadow-lg", !sale && (active ? "bg-accent/10 text-accent" : "text-muted hover:text-foreground"))}><Icon className={cn(sale ? "h-5 w-5" : "h-[18px] w-[18px]")} /><span>{label}</span></Link>; })}</div></nav>;
}
