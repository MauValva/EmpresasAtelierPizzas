import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { inventoryItemSchema } from "@/lib/inventory/schema";
import { inventoryStatus } from "@/lib/inventory/rules";
import { createClient } from "@/lib/supabase/server";

function denied() { return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); }

export async function GET(_request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState();
  if (access.status !== "authorized") return denied();
  const { id } = await params;
  const supabase = await createClient();
  const { data, error } = await supabase.from("inventory_items").select("*").eq("id", id).single();
  if (error || !data) return NextResponse.json({ error: "Ingrediente não encontrado." }, { status: 404 });
  return NextResponse.json({ data: { ...data, status: inventoryStatus(Number(data.current_quantity), Number(data.minimum_quantity), data.is_active), estimated_value: Number(data.current_quantity) * Number(data.average_unit_cost) } });
}

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState();
  if (access.status !== "authorized") return denied();
  const { id } = await params;
  const body = await request.json().catch(() => null) as Record<string, unknown> | null;
  const parsed = inventoryItemSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "Confira os campos do ingrediente.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const values = parsed.data;
  const supabase = await createClient();
  const { data, error } = await supabase.from("inventory_items").update({ name: values.name, category: values.category?.trim() || null, unit: values.unit, minimum_quantity: values.minimum_quantity, notes: values.notes?.trim() || null }).eq("id", id).select("*").single();
  if (error || !data) return NextResponse.json({ error: "Não foi possível atualizar o ingrediente." }, { status: 500 });
  return NextResponse.json({ data });
}
