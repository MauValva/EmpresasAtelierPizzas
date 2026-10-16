import { describe, expect, it } from "vitest";
import { expensesForCompany, historicalProfit } from "../src/lib/summary/total-profit";

describe("lucro histórico", () => {
  it("preserva valores negativos e não depende de mês ou ano", () => {
    expect(historicalProfit(100, 80, 40)).toBe(-20);
  });

  it("não atribui gasto compartilhado a uma empresa sem rateio", () => {
    const expenses = [{ company_id: "atelier", amount: 50, stock_amount: 0 }, { company_id: null, amount: 30, stock_amount: 0 }];
    expect(expensesForCompany(expenses, "atelier")).toEqual([expenses[0]]);
    expect(expensesForCompany(expenses, null)).toEqual(expenses);
  });

  it("mantém compras incorporadas ao estoque fora dos gastos operacionais", () => {
    expect(historicalProfit(500, 100, 50)).toBe(350);
  });
});
