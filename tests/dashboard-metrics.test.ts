import { describe, expect, it } from "vitest";
import { allocatedExpense, dashboardProfit, dailySeries } from "../src/lib/dashboard/metrics";
const slugs = new Map([["a", "atelier-do-pao"], ["p", "pizzas-do-condominio"]]);
describe("dashboard metrics", () => {
  it("calculates gross and operational result without treating cash as revenue", () => expect(dashboardProfit(100, 40, 20)).toEqual({ gross: 60, operating: 40, margin: 0.4 }));
  it("keeps unknown cost incomplete", () => expect(dashboardProfit(100, null, 20)).toEqual({ gross: null, operating: null, margin: null }));
  it("allocates a shared expense only to the selected company", () => expect(allocatedExpense({ id: "1", company_id: null, amount: 200, allocation_snapshot: { "atelier-do-pao": 50, "pizzas-do-condominio": 50 } }, "a", slugs)).toBe(100));
  it("does not duplicate a shared expense in general view", () => expect(allocatedExpense({ id: "1", company_id: null, amount: 200, allocation_snapshot: { "atelier-do-pao": 50, "pizzas-do-condominio": 50 } }, null, slugs)).toBe(200));
  it("creates a consistent daily series", () => expect(dailySeries("2026-01-01", "2026-01-02", [{ id: "1", company_id: "a", order_date: "2026-01-01T12:00:00Z", total_amount: 50, estimated_cogs: 20, order_status: "confirmed" }], [{ paid_at: "2026-01-02T12:00:00Z", amount: 30 }], [], null, slugs)).toEqual([{ date: "2026-01-01", revenue: 50, receipts: 0, expenses: 0 }, { date: "2026-01-02", revenue: 0, receipts: 30, expenses: 0 }]));
});
