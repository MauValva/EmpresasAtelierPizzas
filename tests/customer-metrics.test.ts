import { describe, expect, it } from "vitest";
import { aggregateCustomerSales } from "../src/lib/customers/metrics";

describe("métricas de clientes", () => {
  it("soma apenas vendas pagas, de qualquer empresa", () => {
    const metrics = aggregateCustomerSales([
      { customer_id: "c1", total_amount: 20, status: "paid" },
      { customer_id: "c1", total_amount: 35, status: "paid" },
      { customer_id: "c1", total_amount: 99, status: "open" },
      { customer_id: "c1", total_amount: 12, status: "cancelled" },
    ]);
    expect(metrics.get("c1")).toEqual({ purchases: 2, totalSpent: 55 });
  });

  it("ignora cliente sem vendas e vendas sem cliente", () => {
    const metrics = aggregateCustomerSales([{ customer_id: null, total_amount: 10, status: "paid" }]);
    expect(metrics.has("c1")).toBe(false);
    expect(metrics.size).toBe(0);
  });
});
