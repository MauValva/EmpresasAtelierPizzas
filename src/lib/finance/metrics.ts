export type FinancialSale = { id: string; total_amount: number; order_status: string; estimated_cogs?: number | null };
export type FinancialPayment = { sale_id: string; amount: number; paid_at?: string };
export type FinancialRefund = { sale_id: string; amount: number; refunded_at?: string };
export type FinancialCogsItem = { sale_id: string; estimated_total_cost_snapshot: number | null; cost_status_snapshot: string | null };
export type FinancialObligation = { id: string; amount: number; payment_status?: string; due_date?: string | null };
export type FinancialObligationPayment = { expense_id?: string; purchase_id?: string; amount: number; paid_at?: string };

export function periodCash<T extends { amount: number; paid_at?: string }>(rows: T[], start: string, end: string) {
  return rows.filter((row) => Boolean(row.paid_at) && row.paid_at! >= `${start}T00:00:00Z` && row.paid_at! <= `${end}T23:59:59Z`).reduce((total, row) => total + Number(row.amount), 0);
}

export function canonicalCogs(sales: FinancialSale[], items: FinancialCogsItem[]) {
  let total = 0;
  let incomplete = false;
  let inconsistent = false;
  for (const sale of sales.filter((row) => row.order_status !== "cancelled")) {
    const saleItems = items.filter((item) => item.sale_id === sale.id);
    if (!saleItems.length || saleItems.some((item) => item.cost_status_snapshot === "unknown" || item.estimated_total_cost_snapshot === null)) {
      incomplete = true;
      continue;
    }
    const itemTotal = saleItems.reduce((sum, item) => sum + Number(item.estimated_total_cost_snapshot), 0);
    if (sale.estimated_cogs !== null && sale.estimated_cogs !== undefined && Math.abs(Number(sale.estimated_cogs) - itemTotal) > 0.000001) inconsistent = true;
    total += itemTotal;
  }
  return { value: incomplete || inconsistent ? null : total, incomplete, inconsistent };
}

export function netReceipts(payments: FinancialPayment[], refunds: FinancialRefund[], start: string, end: string) {
  const refundsInPeriod = refunds.filter((row) => Boolean(row.refunded_at) && row.refunded_at! >= `${start}T00:00:00Z` && row.refunded_at! <= `${end}T23:59:59Z`).reduce((total, row) => total + Number(row.amount), 0);
  return Math.max(periodCash(payments, start, end) - refundsInPeriod, 0);
}

export function refundsInPeriod(refunds: FinancialRefund[], start: string, end: string) {
  return refunds.filter((row) => Boolean(row.refunded_at) && row.refunded_at! >= `${start}T00:00:00Z` && row.refunded_at! <= `${end}T23:59:59Z`).reduce((total, row) => total + Number(row.amount), 0);
}

export function saleReceivable(sale: { total_amount: number; order_status: string }, paid: number, refunded: number) {
  if (sale.order_status === "cancelled") return 0;
  return Math.max(Number(sale.total_amount) - Math.max(Number(paid) - Number(refunded), 0), 0);
}

export function cancelledPendingRefund(sale: { order_status: string }, paid: number, refunded: number) {
  return sale.order_status === "cancelled" ? Math.max(Number(paid) - Number(refunded), 0) : 0;
}

export function obligationBalance(total: number, paid: number) { return Math.max(Number(total) - Number(paid), 0); }

export function obligationStatus(total: number, paid: number, dueDate: string | null | undefined, cutoff: string) {
  const balance = obligationBalance(total, paid);
  if (balance === 0) return "paid" as const;
  if (dueDate && dueDate < cutoff) return "overdue" as const;
  return "open" as const;
}

export function expenseAllocation(amount: number, companyId: string | null, expenseCompanyId: string | null, allocation: Record<string, number> | null, companySlug?: string) {
  if (companyId && expenseCompanyId && companyId !== expenseCompanyId) return 0;
  if (!companyId || expenseCompanyId) return Number(amount);
  return companySlug ? Number(amount) * Number(allocation?.[companySlug] ?? 0) / 100 : 0;
}
