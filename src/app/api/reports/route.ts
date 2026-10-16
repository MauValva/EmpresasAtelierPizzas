import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { createClient } from "@/lib/supabase/server";

const iso = (date: Date) => date.toISOString().slice(0, 10);

export async function GET(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
  const today = new Date();
  const start = request.nextUrl.searchParams.get("start") ?? iso(new Date(today.getFullYear(), today.getMonth(), 1));
  const end = request.nextUrl.searchParams.get("end") ?? iso(today);
  const companyId = request.nextUrl.searchParams.get("company_id") || null;
  const supabase = await createClient();
  const [{ data: summary, error }, { data: sales }, { data: expenses }, { data: stock }] = await Promise.all([
    supabase.rpc("get_summary", { p_start: start, p_end: end, p_company_id: companyId }),
    supabase.from("sales").select("id, company_id, order_number, record_type, status, transaction_date, total_amount").gte("transaction_date", `${start}T00:00:00Z`).lte("transaction_date", `${end}T23:59:59Z`).order("transaction_date", { ascending: false }),
    supabase.from("expenses").select("id, company_id, description, category, amount, expense_date").gte("expense_date", start).lte("expense_date", end).order("expense_date", { ascending: false }),
    supabase.from("inventory_items").select("id, name, unit, current_quantity, average_unit_cost, minimum_quantity").eq("is_active", true).order("name"),
  ]);
  if (error) return NextResponse.json({ error: "Não foi possível carregar o relatório.", code: error.code }, { status: 500 });
  return NextResponse.json({ data: { period: { start, end }, summary, sales: sales ?? [], expenses: expenses ?? [], stock: stock ?? [] } });
}
