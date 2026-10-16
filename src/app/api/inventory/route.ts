import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { inventoryItemSchema } from "@/lib/inventory/schema";
import { inventoryStatus } from "@/lib/inventory/rules";
import { createClient } from "@/lib/supabase/server";

const fields = "id, name, category, unit, company_scope, current_quantity, average_unit_cost, minimum_quantity, is_active, notes, created_at, updated_at";

function denied() { return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); }

export async function GET(request: NextRequest) {
  const access = await getAccessState();
  if (access.status !== "authorized") return denied();
  const params = request.nextUrl.searchParams;
  const search = params.get("search")?.trim() ?? "";
  const category = params.get("category")?.trim() ?? "";
  const status = params.get("status") ?? "all";
  const sort = params.get("sort") ?? "name";
  const page = Math.max(Number(params.get("page") ?? "1"), 1);
  const pageSize = Math.min(Math.max(Number(params.get("pageSize") ?? "20"), 1), 50);
  const supabase = await createClient();
  let query = supabase.from("inventory_items").select(fields).order(sort === "quantity" ? "current_quantity" : sort === "updated" ? "updated_at" : "name", { ascending: sort !== "quantity" }).limit(1000);
  if (search) query = query.ilike("name", `%${search.replace(/[%_,]/g, " ")}%`);
  if (category) query = query.eq("category", category);
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: "Não foi possível carregar o estoque." }, { status: 500 });
  const all = (data ?? []).map((item) => ({ ...item, status: inventoryStatus(Number(item.current_quantity), Number(item.minimum_quantity), item.is_active), estimated_value: Number(item.current_quantity) * Number(item.average_unit_cost) }));
  const filtered = status === "all" ? all : all.filter((item) => item.status === status);
  const totalValue = all.filter((item) => item.is_active).reduce((sum, item) => sum + item.estimated_value, 0);
  const indicators = { total: all.filter((item) => item.is_active).length, belowMinimum: all.filter((item) => item.is_active && (item.status === "low" || item.status === "zero" || item.status === "negative")).length, zero: all.filter((item) => item.is_active && item.status === "zero").length, negative: all.filter((item) => item.is_active && item.status === "negative").length, estimatedValue: totalValue };
  const from = (page - 1) * pageSize;
  return NextResponse.json({ data: filtered.slice(from, from + pageSize), categories: [...new Set(all.map((item) => item.category).filter(Boolean))].sort(), indicators, page, pageSize, total: filtered.length, totalPages: Math.max(Math.ceil(filtered.length / pageSize), 1) });
}

export async function POST(request: NextRequest) {
  const access = await getAccessState();
  if (access.status !== "authorized") return denied();
  const parsed = inventoryItemSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os campos do ingrediente.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const values = parsed.data;
  const supabase = await createClient();
  const { data, error } = await supabase.from("inventory_items").insert({ name: values.name, category: values.category?.trim() || null, unit: values.unit, company_scope: values.company_scope, minimum_quantity: values.minimum_quantity, is_active: values.is_active, notes: values.notes?.trim() || null }).select(fields).single();
  if (error) return NextResponse.json({ error: "Não foi possível salvar o ingrediente." }, { status: 500 });
  return NextResponse.json({ data }, { status: 201 });
}
