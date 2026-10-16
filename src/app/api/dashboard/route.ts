import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { monthPeriod, operationalToday, validMonthYear, weekPeriod } from "@/lib/summary/periods";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
  const today = operationalToday();
  const requested = validMonthYear(Number(request.nextUrl.searchParams.get("month")), Number(request.nextUrl.searchParams.get("year")), today);
  const month = monthPeriod(requested.year, requested.month);
  const week = weekPeriod(today);
  const companyId = request.nextUrl.searchParams.get("company_id") || null;
  const supabase = await createClient();
  const [{ data: summary, error: summaryError }, { data: weeklySummary, error: weeklyError }, { data: totalProfit, error: totalProfitError }, { data: inventory, error: inventoryError }] = await Promise.all([
    supabase.rpc("get_summary", { p_start: month.start, p_end: month.end, p_company_id: companyId }),
    supabase.rpc("get_summary", { p_start: week.start, p_end: week.end, p_company_id: companyId }),
    supabase.rpc("get_total_profit", { p_company_id: companyId }),
    supabase.from("inventory_items").select("id, name, unit, current_quantity, average_unit_cost, minimum_quantity, is_active").eq("is_active", true).order("name"),
  ]);
  if (summaryError || weeklyError || totalProfitError || inventoryError) return NextResponse.json({ error: "Não foi possível carregar o resumo.", code: summaryError?.code ?? weeklyError?.code ?? totalProfitError?.code ?? inventoryError?.code }, { status: 500 });
  const lowStock = (inventory ?? []).filter((item) => Number(item.current_quantity) <= Number(item.minimum_quantity) || Number(item.current_quantity) < 0);
  return NextResponse.json({ data: { selected: requested, month, week, summary, weeklySummary, totalProfit, lowStock } });
}
