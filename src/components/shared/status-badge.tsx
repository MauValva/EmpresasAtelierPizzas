import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function StatusBadge({ children, tone = "neutral" }: { children: ReactNode; tone?: "neutral" | "success" | "warning" | "info" | "danger" }) {
  return <span className={cn("inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-semibold", tone === "success" ? "border-success/20 bg-success/10 text-success" : tone === "warning" ? "border-warning/20 bg-warning/10 text-warning" : tone === "info" ? "border-info/20 bg-info/10 text-info" : tone === "danger" ? "border-danger/20 bg-danger/10 text-danger" : "border-border bg-elevated text-muted")}><span className="h-1.5 w-1.5 rounded-full bg-current" />{children}</span>;
}
