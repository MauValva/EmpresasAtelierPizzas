import { Suspense } from "react";
import { LoginForm } from "@/app/login/login-form";

export const metadata = { title: "Entrar · Atelier & Pizzas" };

export default function LoginPage() { return <main className="flex min-h-screen items-center justify-center bg-background px-4 py-8"><div className="w-full max-w-md"><div className="mb-8 text-center"><span className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-accent text-2xl font-bold text-background">A</span><p className="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-accent">Atelier & Pizzas</p><h1 className="mt-2 text-2xl font-semibold text-foreground">Acesse sua gestão</h1><p className="mt-2 text-sm text-muted">Entre com o administrador autorizado.</p></div><div className="rounded-2xl border border-border bg-surface p-5 shadow-soft sm:p-7"><Suspense fallback={<div className="h-48 animate-pulse rounded-xl bg-elevated" />}><LoginForm /></Suspense></div><p className="mt-5 text-center text-xs leading-5 text-muted">Apenas usuários criados e autorizados no Supabase podem acessar o sistema.</p></div></main>; }
