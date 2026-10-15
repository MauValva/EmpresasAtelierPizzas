import Link from "next/link";
import type { LucideIcon } from "lucide-react";
import { ArrowUpRight } from "lucide-react";

export function QuickAction({ label, description, href, icon: Icon, tone = "accent" }: { label: string; description: string; href: string; icon: LucideIcon; tone?: "accent" | "info" | "success" }) {
  const toneClass = tone === "success" ? "bg-success/10 text-success" : tone === "info" ? "bg-info/10 text-info" : "bg-accent/10 text-accent";
  return <Link href={href} className="group flex min-h-[72px] items-center gap-3 rounded-2xl border border-border bg-surface p-3 transition-colors hover:border-accent/50 hover:bg-elevated"><span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${toneClass}`}><Icon className="h-5 w-5" /></span><span className="min-w-0 flex-1"><span className="block text-sm font-semibold text-foreground">{label}</span><span className="mt-1 block truncate text-xs text-muted">{description}</span></span><ArrowUpRight className="h-4 w-4 text-muted transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" /></Link>;
}
