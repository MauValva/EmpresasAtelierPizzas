import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { productSchema } from "@/lib/catalog/schema";
import { createClient } from "@/lib/supabase/server";

const denied = () => NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });

export async function GET(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const params = request.nextUrl.searchParams;
  const supabase = await createClient();
  let query = supabase.from("products").select("*, product_variants(*)").order("name");
  if (params.get("company_id")) query = query.eq("company_id", params.get("company_id")!);
  if (params.get("search")) query = query.ilike("name", `%${params.get("search")!.replace(/[%_,]/g, " ")} %`.trim());
  if (params.get("status") === "active") query = query.eq("is_active", true);
  if (params.get("status") === "inactive") query = query.eq("is_active", false);
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: "Não foi possível carregar os produtos." }, { status: 500 });
  return NextResponse.json({ data: data ?? [] });
}

export async function POST(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const parsed = productSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados do produto.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const value = parsed.data;
  const supabase = await createClient();
  const { data: product, error } = await supabase.from("products").insert({ company_id: value.company_id, name: value.name, category: value.category ?? null, description: value.description ?? null, is_active: value.is_active }).select("*").single();
  if (error || !product) return NextResponse.json({ error: "Não foi possível salvar o produto." }, { status: 400 });
  const { error: variantsError } = await supabase.from("product_variants").insert(value.variants.map((variant) => ({ product_id: product.id, name: variant.name, target_weight_g: variant.target_weight_g ?? null, price: variant.price, is_active: variant.is_active })));
  if (variantsError) return NextResponse.json({ error: "Não foi possível salvar as variações." }, { status: 400 });
  return NextResponse.json({ data: product }, { status: 201 });
}
