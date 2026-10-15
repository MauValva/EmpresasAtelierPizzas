import { describe, expect, it } from "vitest";
import { comparePeriods, groupSales, inventoryValue, periodKey, rankProducts } from "../src/lib/reports/metrics";

describe("report metrics", () => {
  it("groups by day, week and month", () => {
    expect(periodKey("2026-10-14T12:00:00Z", "day")).toBe("2026-10-14");
    expect(periodKey("2026-10-14T12:00:00Z", "week")).toBe("2026-10-12");
    expect(periodKey("2026-10-14T12:00:00Z", "month")).toBe("2026-10");
  });

  it("excludes cancelled sales and aggregates revenue", () => {
    expect(groupSales([
      { id: "1", company_id: "a", order_date: "2026-10-14T12:00:00Z", total_amount: 20, order_status: "confirmed" },
      { id: "2", company_id: "a", order_date: "2026-10-14T13:00:00Z", total_amount: 30, order_status: "cancelled" },
    ], "day")).toEqual([{ period: "2026-10-14", revenue: 20, orders: 1 }]);
  });

  it("ranks products and leaves margin incomplete when cost is unknown", () => {
    const rows = rankProducts([
      { sale_id: "1", product_name_snapshot: "Pizza", variant_name_snapshot: "Média", quantity: 2, final_total: 40, estimated_total_cost_snapshot: 12, cost_status_snapshot: "known" },
      { sale_id: "2", product_name_snapshot: "Pizza", variant_name_snapshot: "Média", quantity: 1, final_total: 20, estimated_total_cost_snapshot: null, cost_status_snapshot: "unknown" },
    ]);
    expect(rows[0]).toMatchObject({ quantity: 3, revenue: 60, cogs: null, gross: null, margin: null });
  });

  it("compares periods without inventing a percentage when there is no base", () => {
    expect(comparePeriods(120, 100)).toBe(0.2);
    expect(comparePeriods(120, 0)).toBeNull();
  });

  it("calculates current stock value", () => {
    expect(inventoryValue([{ current_quantity: 3, average_unit_cost: 4 }, { current_quantity: 2, average_unit_cost: 5 }])).toBe(22);
  });
});
