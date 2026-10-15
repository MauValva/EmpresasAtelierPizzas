import { Settings2 } from "lucide-react";
import { getSupabaseConfigMessage } from "@/lib/supabase/config";

export function ConfigurationState() {
  return <div className="mx-auto flex min-h-[70vh] max-w-xl flex-col items-center justify-center px-4 text-center"><span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-warning/10 text-warning"><Settings2 className="h-6 w-6" /></span><p className="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-accent">Configuração necessária</p><h1 className="mt-2 text-2xl font-semibold text-foreground">Conecte o Supabase para continuar</h1><p className="mt-3 text-sm leading-6 text-muted">{getSupabaseConfigMessage()}</p><p className="mt-4 rounded-xl border border-border bg-surface px-4 py-3 text-left font-mono text-xs leading-6 text-muted">NEXT_PUBLIC_SUPABASE_URL<br />NEXT_PUBLIC_SUPABASE_ANON_KEY</p></div>;
}
