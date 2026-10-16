import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { expenseSchema } from "@/lib/finance/schema";
import { createClient } from "@/lib/supabase/server";

const denied = () => NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
const localToday = () => new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());

export async function GET(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const params = request.nextUrl.searchParams; const supabase = await createClient(); let query = supabase.from("expenses").select("*, expense_stock_entries(*, inventory_items(id, name, unit))").order("expense_date", { ascending: false }).limit(200);
  if (params.get("company_id")) query = query.eq("company_id", params.get("company_id")!);
  const month = Number(params.get("month")); const year = Number(params.get("year"));
  if (month >= 1 && month <= 12 && year >= 2000) { const start = `${year}-${String(month).padStart(2, "0")}-01`; const end = new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10); query = query.gte("expense_date", start).lte("expense_date", end); }
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: "Não foi possível carregar os gastos." }, { status: 500 });
  return NextResponse.json({ data: data ?? [], total: (data ?? []).reduce((sum, item) => sum + Number(item.amount), 0) });
}

export async function POST(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const parsed = expenseSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados da despesa.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const value = parsed.data;
  if (value.expense_date > localToday()) return NextResponse.json({ error: "A data do gasto não pode ser futura." }, { status: 400 });
  const { data, error } = await (await createClient()).rpc("create_expense", { p_company_id: value.company_id ?? null, p_description: value.description, p_category: value.category, p_amount: value.amount, p_expense_date: value.expense_date, p_notes: value.notes ?? null, p_stock_entries: value.stock_entries, p_operation_key: value.operation_key ?? crypto.randomUUID() });
  if (error) return NextResponse.json({ error: "Não foi possível cadastrar a despesa.", code: error.code }, { status: 400 });
  return NextResponse.json({ data }, { status: 201 });
}
