export type CustomerSale = { customer_id: string | null; total_amount: number; status?: string };

export function aggregateCustomerSales(sales: CustomerSale[]) {
  const metrics = new Map<string, { purchases: number; totalSpent: number }>();
  for (const sale of sales) {
    if (!sale.customer_id || (sale.status && sale.status !== "paid")) continue;
    const current = metrics.get(sale.customer_id) ?? { purchases: 0, totalSpent: 0 };
    current.purchases += 1;
    current.totalSpent += Number(sale.total_amount);
    metrics.set(sale.customer_id, current);
  }
  return metrics;
}
