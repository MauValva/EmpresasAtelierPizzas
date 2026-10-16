import { describe, expect, it } from "vitest";
import { isFutureExpenseDate, stockEntriesTotal } from "../src/lib/finance/expense-rules";

describe("regras de gastos", () => {
  it("calcula compra de um ou vários ingredientes", () => {
    expect(stockEntriesTotal([{ quantity: 2, unit_cost: 10 }])).toBe(20);
    expect(stockEntriesTotal([{ quantity: 2, unit_cost: 10 }, { quantity: 3, unit_cost: 5 }])).toBe(35);
  });
  it("permite gasto misto quando a entrada é menor que o total", () => expect(stockEntriesTotal([{ quantity: 1, unit_cost: 60 }])).toBeLessThan(100));
  it("detecta entrada acima do gasto", () => expect(stockEntriesTotal([{ quantity: 2, unit_cost: 60 }])).toBeGreaterThan(100));
  it("permite data retroativa e rejeita data futura", () => { expect(isFutureExpenseDate("2026-10-14", "2026-10-15")).toBe(false); expect(isFutureExpenseDate("2026-10-16", "2026-10-15")).toBe(true); });
});
