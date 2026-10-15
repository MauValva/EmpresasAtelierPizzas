import { Inbox } from "lucide-react";
import type { ReactNode } from "react";

export function EmptyState({ title, description, icon: Icon = Inbox, action }: { title: string; description: string; icon?: typeof Inbox; action?: ReactNode }) {
  return <div className="flex min-h-56 flex-col items-center justify-center rounded-2xl border border-dashed border-border bg-surface/60 px-6 py-10 text-center"><span className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-elevated text-muted"><Icon className="h-5 w-5" /></span><h2 className="text-base font-semibold text-foreground">{title}</h2><p className="mt-2 max-w-md text-sm leading-6 text-muted">{description}</p>{action && <div className="mt-5">{action}</div>}</div>;
}
