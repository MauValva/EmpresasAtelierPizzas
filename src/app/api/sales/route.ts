import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { saleDraftSchema } from "@/lib/sales/schema";
import { monthPeriod, operationalToday, validMonthYear } from "@/lib/summary/periods";
import { createClient } from "@/lib/supabase/server";

const denied = () => NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });

export async function GET(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const params = request.nextUrl.searchParams;
  const today = operationalToday();
  const selected = validMonthYear(Number(params.get("month")), Number(params.get("year")), today);
  const period = monthPeriod(selected.year, selected.month);
  const type = params.get("type") ?? "all";
  const search = params.get("search")?.trim().toLowerCase() ?? "";
  const supabase = await createClient();
  let query = supabase.from("sales").select("id, company_id, customer_id, order_number, record_type, status, transaction_date, scheduled_for, subtotal, discount_total, total_amount, paid_at, created_at").order("transaction_date", { ascending: false }).limit(500);
  if (type === "sale" || type === "order") query = query.eq("record_type", type);
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: "Não foi possível carregar as vendas.", code: error.code }, { status: 500 });
  const periodStart = new Date(`${period.start}T00:00:00-03:00`).getTime();
  const periodEnd = new Date(`${period.end}T23:59:59-03:00`).getTime();
  const rows = (data ?? []).filter((sale) => { const relevantDate = sale.record_type === "order" ? sale.scheduled_for ?? sale.transaction_date : sale.transaction_date; const timestamp = new Date(relevantDate).getTime(); return timestamp >= periodStart && timestamp <= periodEnd; }).sort((a, b) => { const aDate = a.record_type === "order" ? a.scheduled_for ?? a.transaction_date : a.transaction_date; const bDate = b.record_type === "order" ? b.scheduled_for ?? b.transaction_date : b.transaction_date; return new Date(bDate).getTime() - new Date(aDate).getTime(); });
  const customerIds = [...new Set(rows.map((sale) => sale.customer_id).filter(Boolean))] as string[];
  const companyIds = [...new Set(rows.map((sale) => sale.company_id))];
  const [{ data: customers }, { data: companies }] = await Promise.all([
    customerIds.length ? supabase.from("customers").select("id, name, phone").in("id", customerIds) : Promise.resolve({ data: [] as { id: string; name: string; phone: string | null }[] }),
    companyIds.length ? supabase.from("companies").select("id, name").in("id", companyIds) : Promise.resolve({ data: [] as { id: string; name: string }[] }),
  ]);
  const customerMap = new Map((customers ?? []).map((customer) => [customer.id, customer]));
  const companyMap = new Map((companies ?? []).map((company) => [company.id, company]));
  const filtered = rows.filter((sale) => !search || String(sale.order_number).includes(search) || (customerMap.get(sale.customer_id ?? "")?.name ?? "").toLowerCase().includes(search));
  return NextResponse.json({ data: filtered.map((sale) => ({ ...sale, customer: sale.customer_id ? customerMap.get(sale.customer_id) ?? null : null, company: companyMap.get(sale.company_id) ?? null })), period, selected });
}

export async function POST(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return denied();
  const parsed = saleDraftSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os dados da venda.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const value = parsed.data;
  if (value.record_type === "order" && (!value.customer_id || !value.scheduled_for)) return NextResponse.json({ error: "Pedidos futuros exigem cliente e data prevista." }, { status: 400 });
  if (value.record_type === "sale" && !value.payment_method) return NextResponse.json({ error: "Vendas realizadas exigem método de pagamento." }, { status: 400 });
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("create_sale_with_terms", { p_company_id: value.company_id, p_customer_id: value.customer_id ?? null, p_record_type: value.record_type, p_scheduled_for: value.scheduled_for || null, p_items: value.items, p_discount: value.discount, p_notes: value.notes ?? null, p_payment_method: value.payment_method ?? null, p_payment_operation_key: value.payment_operation_key ?? crypto.randomUUID(), p_paid_at: value.record_type === "sale" ? value.paid_at ?? null : null, p_operation_key: value.operation_key ?? crypto.randomUUID() });
  if (error) return NextResponse.json({ error: "Não foi possível registrar a venda.", code: error.code }, { status: 400 });
  return NextResponse.json({ data }, { status: 201 });
}
