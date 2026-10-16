import { NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { updateOpenSaleSchema } from "@/lib/sales/schema";
import { createClient } from "@/lib/supabase/server";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
  const { id } = await params;
  const supabase = await createClient();
  const { data: sale, error } = await supabase.from("sales").select("*").eq("id", id).single();
  if (error || !sale) return NextResponse.json({ error: "Venda não encontrada." }, { status: 404 });
  const [items, payments, company, customer] = await Promise.all([
    supabase.from("sale_items").select("*").eq("sale_id", id).order("created_at"),
    supabase.from("sale_payments").select("*").eq("sale_id", id),
    supabase.from("companies").select("id, name").eq("id", sale.company_id).maybeSingle(),
    sale.customer_id ? supabase.from("customers").select("id, name, phone, apartment, address").eq("id", sale.customer_id).maybeSingle() : Promise.resolve({ data: null }),
  ]);
  return NextResponse.json({ data: { ...sale, company: company.data, customer: customer.data, items: items.data ?? [], payments: payments.data ?? [] } });
}

export async function PATCH() {
  return NextResponse.json({ error: "O status é alterado pelos fluxos transacionais de finalização ou cancelamento." }, { status: 410 });
}

export async function PUT(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
  const parsed = updateOpenSaleSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados do pedido.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const { id } = await params;
  const value = parsed.data;
  const { data, error } = await (await createClient()).rpc("update_open_sale", { p_sale_id: id, p_company_id: value.company_id, p_customer_id: value.customer_id ?? null, p_scheduled_for: value.scheduled_for || null, p_items: value.items, p_discount: value.discount, p_notes: value.notes ?? null });
  if (error) return NextResponse.json({ error: "Não foi possível editar o pedido.", code: error.code }, { status: 400 });
  return NextResponse.json({ data });
}
