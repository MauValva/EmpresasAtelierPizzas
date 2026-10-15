import { AlertTriangle } from "lucide-react";

export function AccessErrorState({ message }: { message: string }) {
  return <div className="mx-auto flex min-h-[70vh] max-w-xl flex-col items-center justify-center px-4 text-center"><span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-danger/10 text-danger"><AlertTriangle className="h-6 w-6" /></span><h1 className="mt-5 text-2xl font-semibold text-foreground">Não foi possível validar o acesso</h1><p className="mt-3 text-sm leading-6 text-muted">{message} Verifique as variáveis e a conexão do projeto Supabase.</p></div>;
}
