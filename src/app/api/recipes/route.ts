import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { recipeSchema } from "@/lib/catalog/schema";
import { createClient } from "@/lib/supabase/server";

const denied = () => NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });

export async function GET(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const params = request.nextUrl.searchParams; const supabase = await createClient(); let query = supabase.from("recipes").select("*, recipe_ingredients(*, inventory_items(id, name, unit, average_unit_cost))").order("name");
  if (params.get("company_id")) query = query.eq("company_id", params.get("company_id")!);
  if (params.get("search")) query = query.ilike("name", `%${params.get("search")!.replace(/[%_,]/g, " ")}%`);
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: "Não foi possível carregar as receitas." }, { status: 500 });
  return NextResponse.json({ data: data ?? [] });
}

export async function POST(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const parsed = recipeSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados da receita.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const value = parsed.data; const supabase = await createClient(); let result = await supabase.rpc("create_recipe_atomic", { p_company_id: value.company_id, p_name: value.name, p_yield_quantity: value.yield_quantity, p_yield_unit: value.yield_unit, p_notes: value.notes ?? null, p_items: value.items });
  if (result.error?.code === "PGRST202") result = await supabase.rpc("create_recipe_atomic", { p_company_id: value.company_id, p_product_variant_id: null, p_name: value.name, p_yield_quantity: value.yield_quantity, p_yield_unit: value.yield_unit, p_notes: value.notes ?? null, p_items: value.items });
  const { data, error } = result;
  if (error) return NextResponse.json({ error: "Não foi possível salvar a receita.", code: error.code }, { status: 400 });
  return NextResponse.json({ data }, { status: 201 });
}
