import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { Button } from "@/components/ui/button";

export default function NotFound() { return <AppShell><div className="mx-auto flex min-h-[60vh] max-w-lg flex-col items-center justify-center text-center"><p className="text-sm font-semibold uppercase tracking-[0.18em] text-accent">404</p><h1 className="mt-3 text-3xl font-semibold text-foreground">Página não encontrada</h1><p className="mt-3 text-sm leading-6 text-muted">Esse caminho ainda não faz parte da fundação do projeto.</p><Button asChild className="mt-6"><Link href="/"><ArrowLeft className="h-4 w-4" />Voltar ao início</Link></Button></div></AppShell>; }
