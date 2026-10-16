import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { productVariantSchema } from "@/lib/catalog/schema";
import { createClient } from "@/lib/supabase/server";

const denied = () => NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });

export async function GET(_request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const { id } = await params;
  const { data, error } = await (await createClient()).from("products").select("*, product_variants(*)").eq("id", id).single();
  if (error || !data) return NextResponse.json({ error: "Produto não encontrado." }, { status: 404 });
  return NextResponse.json({ data });
}

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const { id } = await params;
  const body = await request.json().catch(() => null) as Record<string, unknown> | null;
  if (typeof body?.name !== "string" || body.name.trim().length < 2) return NextResponse.json({ error: "Nome inválido." }, { status: 400 });
  const { data, error } = await (await createClient()).from("products").update({ name: body.name.trim(), category: typeof body.category === "string" ? body.category.trim() || null : null, description: typeof body.description === "string" ? body.description.trim() || null : null, is_active: body.is_active !== false }).eq("id", id).select("*").single();
  if (error || !data) return NextResponse.json({ error: "Não foi possível atualizar o produto." }, { status: 400 });
  return NextResponse.json({ data });
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const { id } = await params;
  const parsed = productVariantSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados da variação.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const value = parsed.data;
  const { data, error } = await (await createClient()).from("product_variants").insert({ product_id: id, name: value.name, target_weight_g: value.target_weight_g ?? null, price: value.price, is_active: value.is_active }).select("*").single();
  if (error || !data) return NextResponse.json({ error: "Não foi possível salvar a variação." }, { status: 400 });
  return NextResponse.json({ data }, { status: 201 });
}
