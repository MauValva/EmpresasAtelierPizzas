import { describe, expect, it } from "vitest";
import { canonicalCogs, cancelledPendingRefund, expenseAllocation, netReceipts, obligationBalance, obligationStatus, saleReceivable } from "../src/lib/finance/metrics";

describe("shared financial metrics", () => {
  it("uses consolidated item snapshots as canonical CMV", () => {
    expect(canonicalCogs([{ id: "s", total_amount: 100, order_status: "confirmed", estimated_cogs: 20 }], [{ sale_id: "s", estimated_total_cost_snapshot: 20, cost_status_snapshot: "known" }])).toMatchObject({ value: 20, inconsistent: false });
    expect(canonicalCogs([{ id: "s", total_amount: 100, order_status: "confirmed", estimated_cogs: 19 }], [{ sale_id: "s", estimated_total_cost_snapshot: 20, cost_status_snapshot: "known" }])).toMatchObject({ value: null, inconsistent: true });
  });
  it("keeps unknown costs incomplete", () => expect(canonicalCogs([{ id: "s", total_amount: 100, order_status: "confirmed", estimated_cogs: null }], [{ sale_id: "s", estimated_total_cost_snapshot: null, cost_status_snapshot: "unknown" }]).value).toBeNull());
  it("separates period cash from cutoff receivable", () => {
    const payments = [{ sale_id: "s", amount: 40, paid_at: "2026-10-10T12:00:00Z" }, { sale_id: "s", amount: 20, paid_at: "2026-10-20T12:00:00Z" }];
    const refunds = [{ sale_id: "s", amount: 10, refunded_at: "2026-10-20T12:00:00Z" }];
    expect(netReceipts(payments, refunds, "2026-10-20", "2026-10-20")).toBe(10);
    expect(saleReceivable({ total_amount: 100, order_status: "confirmed" }, 60, 10)).toBe(50);
  });
  it("keeps cancelled money as pending refund, not receivable", () => {
    expect(saleReceivable({ total_amount: 100, order_status: "cancelled" }, 80, 20)).toBe(0);
    expect(cancelledPendingRefund({ order_status: "cancelled" }, 80, 20)).toBe(60);
  });
  it("calculates partial obligations and overdue status", () => {
    expect(obligationBalance(100, 40)).toBe(60);
    expect(obligationStatus(100, 40, "2026-10-01", "2026-10-14")).toBe("overdue");
    expect(obligationStatus(100, 100, "2026-10-01", "2026-10-14")).toBe("paid");
  });
  it("allocates shared expenses once and by company", () => {
    expect(expenseAllocation(200, null, null, { atelier: 50, pizzas: 50 })).toBe(200);
    expect(expenseAllocation(200, "a", null, { atelier: 50, pizzas: 50 }, "atelier")).toBe(100);
  });
});
