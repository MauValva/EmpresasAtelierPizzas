import { describe, expect, it } from "vitest";
import { calculateSaleTotal, isPaymentDateFuture } from "../src/lib/sales/terms";

describe("regras comerciais de vendas", () => {
  it("preserva subtotal, desconto e total final", () => {
    expect(calculateSaleTotal(56, 2)).toBe(54);
    expect(calculateSaleTotal(56, 0)).toBe(56);
  });

  it("rejeita desconto negativo ou maior que o subtotal", () => {
    expect(() => calculateSaleTotal(56, -1)).toThrow("Desconto inválido");
    expect(() => calculateSaleTotal(56, 57)).toThrow("Desconto superior ao subtotal");
  });

  it("identifica data de pagamento futura", () => {
    const now = new Date("2026-10-15T12:00:00-03:00");
    expect(isPaymentDateFuture("2026-10-15T11:59:00-03:00", now)).toBe(false);
    expect(isPaymentDateFuture("2026-10-15T12:01:00-03:00", now)).toBe(true);
  });

  it("aceita pagamento retroativo", () => {
    expect(isPaymentDateFuture("2026-10-14T18:00:00-03:00", new Date("2026-10-15T12:00:00-03:00"))).toBe(false);
  });
});
