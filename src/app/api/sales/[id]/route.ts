import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { saleStatusSchema } from "@/lib/sales/schema";
import { createClient } from "@/lib/supabase/server";

function denied() { return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); }

export async function GET(_request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState(); if (access.status !== "authorized") return denied(); const { id } = await params; const supabase = await createClient();
  const saleResult = await supabase.from("sales").select("*").eq("id", id).single(); if (saleResult.error || !saleResult.data) return NextResponse.json({ error: "Pedido não encontrado." }, { status: 404 });
  const [itemsResult, paymentResult, refundResult, historyResult, companyResult, customerResult] = await Promise.all([
    supabase.from("sale_items").select("*").eq("sale_id", id).order("created_at"),
    supabase.from("sale_payments").select("*").eq("sale_id", id).order("paid_at", { ascending: false }),
    supabase.from("sale_refunds").select("*").eq("sale_id", id).order("refunded_at", { ascending: false }),
    supabase.from("sale_status_history").select("*").eq("sale_id", id).order("created_at", { ascending: false }),
    supabase.from("companies").select("id, name").eq("id", saleResult.data.company_id).maybeSingle(),
    supabase.from("customers").select("id, name, phone, apartment, address").eq("id", saleResult.data.customer_id).single(),
  ]);
  const itemIds = (itemsResult.data ?? []).map((item) => item.id); const snapshots = itemIds.length ? await supabase.from("sale_item_ingredient_snapshots").select("*").in("sale_item_id", itemIds) : { data: [] as never[] };
  const variantsResult = await supabase.from("product_variants").select("id, name, product_id").in("id", (itemsResult.data ?? []).map((item) => item.product_variant_id)); const productIds = (variantsResult.data ?? []).map((variant) => variant.product_id); const { data: products } = productIds.length ? await supabase.from("products").select("id, name").in("id", productIds) : { data: [] as never[] }; const productMap = new Map((products ?? []).map((product) => [product.id, product.name])); const variantMap = new Map((variantsResult.data ?? []).map((variant) => [variant.id, { ...variant, product_name: productMap.get(variant.product_id) }]));
  const promotions = await supabase.from("sale_applied_promotions").select("*").eq("sale_id", id);
  return NextResponse.json({ data: { ...saleResult.data, company: companyResult.data, customer: customerResult.data, payments: paymentResult.data ?? [], refunds: refundResult.data ?? [], items: (itemsResult.data ?? []).map((item) => ({ ...item, variant: variantMap.get(item.product_variant_id), ingredients: (snapshots.data ?? []).filter((snapshot) => snapshot.sale_item_id === item.id) })), promotions: promotions.data ?? [], history: historyResult.data ?? [] } });
}

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) { const access = await getAccessState(); if (access.status !== "authorized") return denied(); const { id } = await params; const parsed = saleStatusSchema.safeParse(await request.json().catch(() => null)); if (!parsed.success) return NextResponse.json({ error: "Status inválido.", issues: parsed.error.flatten().fieldErrors }, { status: 400 }); const value = parsed.data; const supabase = await createClient(); const { data, error } = await supabase.rpc("advance_sale_status", { p_sale_id: id, p_order_status: value.order_status ?? null, p_fulfillment_status: value.fulfillment_status ?? null }); if (error) return NextResponse.json({ error: "Não foi possível atualizar o pedido." }, { status: 400 }); return NextResponse.json({ data }); }
