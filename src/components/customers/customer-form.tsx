"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { AlertCircle, CheckCircle2, Loader2, Save } from "lucide-react";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { useRouter } from "next/navigation";
import { customerSchema, type CustomerFormInput, type CustomerFormValues } from "@/lib/customers/schema";
import { Button } from "@/components/ui/button";

type Customer = { id?: string; name: string; phone?: string | null; apartment?: string | null; address?: string | null; notes?: string | null; marketing_consent?: boolean; is_active?: boolean };

export function CustomerForm({ initialCustomer, onSaved }: { initialCustomer?: Customer; onSaved?: (customer: Customer & { id: string }) => void }) {
  const router = useRouter();
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [similar, setSimilar] = useState<Array<{ id: string; name: string; phone: string | null }>>([]);
  const [checkingSimilar, setCheckingSimilar] = useState(false);
  const form = useForm<CustomerFormInput, unknown, CustomerFormValues>({ resolver: zodResolver(customerSchema), defaultValues: { name: initialCustomer?.name ?? "", phone: initialCustomer?.phone ?? "", apartment: initialCustomer?.apartment ?? "", address: initialCustomer?.address ?? "", notes: initialCustomer?.notes ?? "", marketing_consent: initialCustomer?.marketing_consent ?? false } });
  const name = form.watch("name");
  const phone = form.watch("phone");

  useEffect(() => {
    const nameValue = name.trim();
    const phoneValue = phone?.trim() ?? "";
    const value = nameValue.length >= 3 ? nameValue : phoneValue;
    if ((nameValue.length < 3 && phoneValue.replace(/\D/g, "").length < 4) || initialCustomer) { setSimilar([]); return; }
    const controller = new AbortController();
    setCheckingSimilar(true);
    const timeout = window.setTimeout(async () => {
      try { const response = await fetch(`/api/customers?search=${encodeURIComponent(value)}&pageSize=4&status=all`, { signal: controller.signal }); const payload = await response.json(); setSimilar(payload.data ?? []); } catch { setSimilar([]); } finally { setCheckingSimilar(false); }
    }, 350);
    return () => { window.clearTimeout(timeout); controller.abort(); };
  }, [name, phone, initialCustomer]);

  async function onSubmit(values: CustomerFormValues) {
    setSubmitError(null); setSuccessMessage(null);
    const endpoint = initialCustomer?.id ? `/api/customers/${initialCustomer.id}` : "/api/customers";
    const response = await fetch(endpoint, { method: initialCustomer?.id ? "PATCH" : "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(values) });
    const payload = await response.json().catch(() => null);
    if (!response.ok) { setSubmitError(payload?.error ?? "Não foi possível salvar o cliente."); return; }
    setSuccessMessage(initialCustomer ? "Alterações salvas." : "Cliente cadastrado.");
    if (onSaved) onSaved(payload.data);
    else if (!initialCustomer?.id) router.push(`/clientes/${payload.data.id}`);
  }

  const fieldClass = "min-h-12 w-full rounded-xl border border-border bg-background px-3 text-sm text-foreground outline-none placeholder:text-muted focus:border-accent focus:ring-2 focus:ring-accent/20";
  const errorFor = (field: keyof CustomerFormValues) => form.formState.errors[field]?.message;
  return <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-5"><div className="grid gap-5 sm:grid-cols-2"><label className="block sm:col-span-2"><span className="mb-2 block text-sm font-medium text-foreground">Nome <span className="text-danger">*</span></span><input {...form.register("name")} className={fieldClass} placeholder="Ex.: Maria da Silva" autoComplete="name" />{errorFor("name") && <span className="mt-2 block text-xs text-danger">{errorFor("name")}</span>}</label><label className="block"><span className="mb-2 block text-sm font-medium text-foreground">Telefone / WhatsApp</span><input {...form.register("phone")} className={fieldClass} placeholder="(11) 99999-9999" type="tel" inputMode="tel" autoComplete="tel" />{errorFor("phone") && <span className="mt-2 block text-xs text-danger">{errorFor("phone")}</span>}</label><label className="block"><span className="mb-2 block text-sm font-medium text-foreground">Apartamento</span><input {...form.register("apartment")} className={fieldClass} placeholder="Ex.: Bloco A, 42" autoComplete="address-line2" />{errorFor("apartment") && <span className="mt-2 block text-xs text-danger">{errorFor("apartment")}</span>}</label></div><label className="block"><span className="mb-2 block text-sm font-medium text-foreground">Endereço</span><textarea {...form.register("address")} className={`${fieldClass} min-h-24 resize-y py-3`} placeholder="Rua, número e complemento" autoComplete="street-address" />{errorFor("address") && <span className="mt-2 block text-xs text-danger">{errorFor("address")}</span>}</label><label className="block"><span className="mb-2 block text-sm font-medium text-foreground">Observações internas</span><textarea {...form.register("notes")} className={`${fieldClass} min-h-24 resize-y py-3`} placeholder="Preferências ou observações para a equipe" />{errorFor("notes") && <span className="mt-2 block text-xs text-danger">{errorFor("notes")}</span>}</label><label className="flex min-h-12 cursor-pointer items-start gap-3 rounded-xl border border-border bg-surface p-3"><input type="checkbox" {...form.register("marketing_consent")} className="mt-1 h-4 w-4 accent-[hsl(var(--accent))]" /><span><span className="block text-sm font-medium text-foreground">Autoriza contato promocional</span><span className="mt-1 block text-xs leading-5 text-muted">Ter um telefone cadastrado não implica consentimento.</span></span></label>{similar.length > 0 && <div className="rounded-2xl border border-warning/30 bg-warning/10 p-4"><p className="flex items-center gap-2 text-sm font-semibold text-warning"><AlertCircle className="h-4 w-4" />Clientes semelhantes encontrados</p><p className="mt-1 text-xs leading-5 text-muted">Confira antes de salvar para evitar duplicidades acidentais.</p><div className="mt-3 space-y-2">{similar.map((candidate) => <div key={candidate.id} className="rounded-xl border border-warning/20 bg-background/30 px-3 py-2 text-sm text-foreground"><span className="font-semibold">{candidate.name}</span>{candidate.phone && <span className="ml-2 text-xs text-muted">{candidate.phone}</span>}</div>)}</div></div>}{checkingSimilar && <p className="text-xs text-muted">Verificando clientes semelhantes...</p>}{submitError && <p role="alert" className="flex items-center gap-2 rounded-xl border border-danger/30 bg-danger/10 p-3 text-sm text-danger"><AlertCircle className="h-4 w-4 shrink-0" />{submitError}</p>}{successMessage && <p role="status" className="flex items-center gap-2 rounded-xl border border-success/30 bg-success/10 p-3 text-sm text-success"><CheckCircle2 className="h-4 w-4 shrink-0" />{successMessage}</p>}<Button type="submit" className="w-full sm:w-auto" disabled={form.formState.isSubmitting}>{form.formState.isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}{form.formState.isSubmitting ? "Salvando..." : initialCustomer ? "Salvar alterações" : "Cadastrar cliente"}</Button></form>;
}
