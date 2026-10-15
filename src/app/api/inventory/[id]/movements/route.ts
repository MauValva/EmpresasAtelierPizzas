import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { movementSchema } from "@/lib/inventory/schema";
import { createClient } from "@/lib/supabase/server";

function denied() { return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); }

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState();
  if (access.status !== "authorized") return denied();
  const { id } = await params;
  const page = Math.max(Number(request.nextUrl.searchParams.get("page") ?? "1"), 1);
  const pageSize = Math.min(Math.max(Number(request.nextUrl.searchParams.get("pageSize") ?? "20"), 1), 50);
  const supabase = await createClient();
  const { data, error, count } = await supabase.from("inventory_movements").select("id, movement_type, quantity_delta, unit_cost_snapshot, total_cost_snapshot, previous_quantity, resulting_quantity, reason, source_type, created_by, operation_key, created_at", { count: "exact" }).eq("inventory_item_id", id).order("created_at", { ascending: false }).range((page - 1) * pageSize, page * pageSize - 1);
  if (error) return NextResponse.json({ error: "Não foi possível carregar o histórico." }, { status: 500 });
  return NextResponse.json({ data: data ?? [], page, pageSize, total: count ?? 0, totalPages: Math.max(Math.ceil((count ?? 0) / pageSize), 1) });
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState();
  if (access.status !== "authorized") return denied();
  const { id } = await params;
  const body = await request.json().catch(() => null) as Record<string, unknown> | null;
  const parsed = movementSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados da movimentação.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const values = parsed.data;
  const operationKey = typeof body?.operation_key === "string" ? body.operation_key : crypto.randomUUID();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("register_inventory_movement", { p_inventory_item_id: id, p_movement_type: values.movement_type, p_quantity: values.quantity, p_unit_cost: values.unit_cost ?? null, p_reason: values.reason, p_operation_key: operationKey });
  if (error) return NextResponse.json({ error: "Não foi possível registrar a movimentação." }, { status: 400 });
  return NextResponse.json({ data }, { status: 201 });
}
