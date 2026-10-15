"use client";

import { Loader2, LockKeyhole, Mail } from "lucide-react";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import { Button } from "@/components/ui/button";
import { isSupabaseConfigured } from "@/lib/supabase/config";
import { createClient } from "@/lib/supabase/client";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setLoading(true);
    const { error: signInError } = await createClient().auth.signInWithPassword({ email, password });
    if (signInError) {
      setError("Não foi possível entrar. Verifique seus dados ou se o acesso foi autorizado.");
      setLoading(false);
      return;
    }
    router.replace("/");
    router.refresh();
  }

  if (!isSupabaseConfigured()) return <p className="rounded-xl border border-warning/30 bg-warning/10 p-4 text-sm leading-6 text-warning">Configure as variáveis do Supabase no arquivo `.env.local` antes de fazer login.</p>;

  return <form onSubmit={handleSubmit} className="space-y-4"><div><label htmlFor="email" className="mb-2 block text-sm font-medium text-foreground">E-mail</label><div className="relative"><Mail className="pointer-events-none absolute left-3 top-3.5 h-4 w-4 text-muted" /><input id="email" name="email" type="email" autoComplete="email" required value={email} onChange={(event) => setEmail(event.target.value)} className="min-h-12 w-full rounded-xl border border-border bg-background pl-10 pr-3 text-sm text-foreground outline-none transition focus:border-accent focus:ring-2 focus:ring-accent/20" placeholder="admin@exemplo.com" /></div></div><div><label htmlFor="password" className="mb-2 block text-sm font-medium text-foreground">Senha</label><div className="relative"><LockKeyhole className="pointer-events-none absolute left-3 top-3.5 h-4 w-4 text-muted" /><input id="password" name="password" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} className="min-h-12 w-full rounded-xl border border-border bg-background pl-10 pr-3 text-sm text-foreground outline-none transition focus:border-accent focus:ring-2 focus:ring-accent/20" placeholder="Sua senha" /></div></div>{error && <p role="alert" className="rounded-xl border border-danger/30 bg-danger/10 p-3 text-sm leading-5 text-danger">{error}</p>}<Button type="submit" className="w-full" disabled={loading}>{loading && <Loader2 className="h-4 w-4 animate-spin" />}{loading ? "Entrando..." : "Entrar"}</Button></form>;
}
