import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

export function StatCard({ label, value, detail, icon: Icon, tone = "accent" }: { label: string; value: string; detail: string; icon: LucideIcon; tone?: "accent" | "success" | "info" }) {
  return <div className="rounded-2xl border border-border bg-surface p-4 shadow-soft"><div className="flex items-start justify-between gap-3"><div><p className="text-xs font-medium text-muted">{label}</p><p className="mt-3 text-2xl font-semibold tracking-tight text-foreground">{value}</p></div><span className={cn("flex h-10 w-10 items-center justify-center rounded-xl", tone === "success" ? "bg-success/10 text-success" : tone === "info" ? "bg-info/10 text-info" : "bg-accent/10 text-accent")}><Icon className="h-5 w-5" /></span></div><p className="mt-3 text-xs text-muted">{detail}</p></div>;
}
