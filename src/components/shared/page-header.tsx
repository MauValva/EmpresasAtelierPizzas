import type { ReactNode } from "react";

export function PageHeader({ eyebrow = "Workspace", title, action }: { eyebrow?: string; title: string; description?: string; action?: ReactNode }) {
  return <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"><div><p className="mb-2 text-xs font-semibold uppercase tracking-[0.18em] text-accent">{eyebrow}</p><h1 className="text-2xl font-semibold tracking-tight text-foreground sm:text-3xl">{title}</h1></div>{action}</div>;
}
