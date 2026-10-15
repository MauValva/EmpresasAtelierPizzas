import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { createClient } from "@/lib/supabase/server";
import { netReceipts, obligationBalance, saleReceivable } from "@/lib/finance/metrics";

export async function GET(request: NextRequest) {
  const access = await getAccessState();
  if (access.status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
  const params = request.nextUrl.searchParams;
  const companyId = params.get("company_id");
  const cutoff = params.get("cutoff") ?? new Date().toISOString();
  const start = params.get("start") ?? cutoff.slice(0, 10);
  const end = params.get("end") ?? cutoff.slice(0, 10);
  const supabase = await createClient();
  const [sales, salePayments, refunds, purchases, purchasePayments, expenses, expensePayments] = await Promise.all([
    supabase.from("sales").select("id, total_amount, company_id, order_status").in("order_status", ["confirmed", "completed", "cancelled"]),
    supabase.from("sale_payments").select("sale_id, amount, paid_at"),
    supabase.from("sale_refunds").select("sale_id, amount, refunded_at"),
    supabase.from("purchases").select("id, total_amount, company_id, status"),
    supabase.from("purchase_payments").select("purchase_id, amount, paid_at"),
    supabase.from("expenses").select("id, amount, company_id, payment_status"),
    supabase.from("expense_payments").select("expense_id, amount, paid_at"),
  ]);
  const selectedSales = (sales.data ?? []).filter((sale) => !companyId || sale.company_id === companyId);
  const selectedIds = new Set(selectedSales.map((sale) => sale.id));
  const paidBySale = new Map<string, number>();
  (salePayments.data ?? []).forEach((row) => paidBySale.set(row.sale_id, (paidBySale.get(row.sale_id) ?? 0) + Number(row.amount)));
  const refundedBySale = new Map<string, number>();
  (refunds.data ?? []).forEach((row) => refundedBySale.set(row.sale_id, (refundedBySale.get(row.sale_id) ?? 0) + Number(row.amount)));
  const faturamento = selectedSales.filter((sale) => sale.order_status !== "cancelled").reduce((total, sale) => total + Number(sale.total_amount), 0);
  const receber = selectedSales.reduce((total, sale) => total + saleReceivable(sale, paidBySale.get(sale.id) ?? 0, refundedBySale.get(sale.id) ?? 0), 0);
  const pendenteDevolucao = selectedSales.filter((sale) => sale.order_status === "cancelled").reduce((total, sale) => total + Math.max((paidBySale.get(sale.id) ?? 0) - (refundedBySale.get(sale.id) ?? 0), 0), 0);
  const recebido = netReceipts((salePayments.data ?? []).filter((row) => selectedIds.has(row.sale_id)), (refunds.data ?? []).filter((row) => selectedIds.has(row.sale_id)), start, end);
  const paidPurchases = new Map<string, number>();
  (purchasePayments.data ?? []).forEach((row) => paidPurchases.set(row.purchase_id, (paidPurchases.get(row.purchase_id) ?? 0) + Number(row.amount)));
  const paidExpenses = new Map<string, number>();
  (expensePayments.data ?? []).forEach((row) => paidExpenses.set(row.expense_id, (paidExpenses.get(row.expense_id) ?? 0) + Number(row.amount)));
  const pagarCompras = (purchases.data ?? []).filter((row) => row.status !== "cancelled" && (!companyId || row.company_id === companyId)).reduce((total, row) => total + obligationBalance(Number(row.total_amount), paidPurchases.get(row.id) ?? 0), 0);
  const pagarDespesas = (expenses.data ?? []).filter((row) => row.payment_status !== "cancelled" && (!companyId || row.company_id === companyId || row.company_id === null)).reduce((total, row) => total + obligationBalance(Number(row.amount), paidExpenses.get(row.id) ?? 0), 0);
  const pago = (purchasePayments.data ?? []).filter((row) => row.paid_at >= `${start}T00:00:00Z` && row.paid_at <= `${end}T23:59:59Z`).reduce((total, row) => total + Number(row.amount), 0) + (expensePayments.data ?? []).filter((row) => row.paid_at >= `${start}T00:00:00Z` && row.paid_at <= `${end}T23:59:59Z`).reduce((total, row) => total + Number(row.amount), 0);
  return NextResponse.json({ data: { faturamento, receber, pagar: pagarCompras + pagarDespesas, recebido, pago, fluxo: recebido - pago, pendente_devolucao: pendenteDevolucao, cutoff, regras: { receita: "competência da venda", recebimentos: "pagamentos menos estornos no período", saldos: "posição acumulada até a data de corte" } } });
}
