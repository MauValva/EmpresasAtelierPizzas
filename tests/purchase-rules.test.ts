import { describe, expect, it } from "vitest";
import { quantityToBase, unitCostToBase } from "../src/lib/purchases/schema";

describe("purchase unit conversion", () => {
  it("converts kilograms to grams without premature rounding", () => {
    expect(quantityToBase(5, "kg", "g")).toBe(5000);
    expect(unitCostToBase(13, "kg", "g")).toBe(0.013);
  });

  it("converts liters to milliliters", () => {
    expect(quantityToBase(2.5, "l", "ml")).toBe(2500);
    expect(unitCostToBase(8.75, "l", "ml")).toBe(0.00875);
  });

  it("rejects an incompatible unit", () => {
    expect(() => quantityToBase(1, "kg", "ml")).toThrow();
  });
});
