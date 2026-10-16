import { NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { recipeSchema } from "@/lib/catalog/schema";
import { createClient } from "@/lib/supabase/server";

const denied = () => NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const { id } = await params; const { data, error } = await (await createClient()).from("recipes").select("*, recipe_ingredients(*, inventory_items(id, name, unit, average_unit_cost))").eq("id", id).single();
  if (error || !data) return NextResponse.json({ error: "Receita não encontrada." }, { status: 404 });
  return NextResponse.json({ data });
}

export async function PATCH(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const { id } = await params; const parsed = recipeSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados da receita.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const value = parsed.data; const supabase = await createClient(); let result = await supabase.rpc("update_recipe_atomic", { p_recipe_id: id, p_company_id: value.company_id, p_name: value.name, p_yield_quantity: value.yield_quantity, p_yield_unit: value.yield_unit, p_notes: value.notes ?? null, p_items: value.items });
  if (result.error?.code === "PGRST202") result = await supabase.rpc("update_recipe_atomic", { p_recipe_id: id, p_company_id: value.company_id, p_product_variant_id: null, p_name: value.name, p_yield_quantity: value.yield_quantity, p_yield_unit: value.yield_unit, p_notes: value.notes ?? null, p_items: value.items });
  const { data, error } = result;
  if (error) return NextResponse.json({ error: "Não foi possível atualizar a receita.", code: error.code }, { status: 400 });
  return NextResponse.json({ data });
}
