import type { LucideIcon } from "lucide-react";
import { ChevronRight } from "lucide-react";

export function MobileListItem({ title, description, icon: Icon, trailing }: { title: string; description: string; icon: LucideIcon; trailing?: React.ReactNode }) {
  return <div className="flex min-h-[68px] items-center gap-3 rounded-2xl border border-border bg-surface p-3"><span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-elevated text-muted"><Icon className="h-5 w-5" /></span><span className="min-w-0 flex-1"><span className="block truncate text-sm font-semibold text-foreground">{title}</span><span className="mt-1 block truncate text-xs text-muted">{description}</span></span>{trailing ?? <ChevronRight className="h-4 w-4 text-muted" />}</div>;
}
