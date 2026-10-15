import { describe, expect, it } from "vitest";
import { allocateSharedExpense, balanceDue, cashFlow } from "../src/lib/finance/rules";
describe("finance rules", () => {
  it("calculates partial balance without recognizing payment as new revenue", () => expect(balanceDue(60, 20)).toBe(40));
  it("handles refunds in the outstanding balance", () => expect(balanceDue(60, 60, 20)).toBe(20));
  it("allocates shared cents deterministically", () => expect(allocateSharedExpense(100, { atelier: 50, pizzas: 50 })).toEqual({ atelier: 50, pizzas: 50 }));
  it("keeps rounding remainder in the last company", () => expect(allocateSharedExpense(10, { atelier: 33.33, pizzas: 66.67 })).toEqual({ atelier: 3.33, pizzas: 6.67 }));
  it("rejects allocation that does not total 100", () => expect(() => allocateSharedExpense(100, { atelier: 40, pizzas: 40 })).toThrow("ALLOCATION_MUST_TOTAL_100"));
  it("separates realized cash from financial obligations", () => expect(cashFlow([60, 20], [10], [5], [15])).toEqual({ inflow: 80, outflow: 30, net: 50 }));
});
