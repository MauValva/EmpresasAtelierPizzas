import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { confirmSaleSchema } from "@/lib/sales/schema";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
  const parsed = confirmSaleSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Informe a forma de pagamento." }, { status: 400 });
  const { id } = await params;
  const value = parsed.data;
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("finalize_sale_with_date", { p_sale_id: id, p_payment_method: value.payment_method, p_payment_operation_key: value.payment_operation_key ?? crypto.randomUUID(), p_paid_at: value.paid_at ?? null });
  if (error) return NextResponse.json({ error: "Não foi possível finalizar a venda.", code: error.code }, { status: 400 });
  return NextResponse.json({ data });
}
