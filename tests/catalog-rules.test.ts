import { describe, expect, it } from "vitest";
import { calculatePromotionalPrice } from "../src/lib/catalog/pricing";
import { calculatePricing, calculateRecipeCost, calculateVariantCost } from "../src/lib/catalog/costs";

describe("catalog costs", () => {
  it("calculates recipe cost from base-unit average costs", () => {
    expect(calculateRecipeCost([{ name: "Farinha", quantity: 400, unitCost: 0.012 }, { name: "Sal", quantity: 10, unitCost: 0.02 }]).totalCost).toBeCloseTo(5);
  });
  it("distinguishes partial and unknown costs", () => {
    expect(calculateRecipeCost([{ name: "Farinha", quantity: 400, unitCost: null }]).status).toBe("unknown");
    expect(calculateRecipeCost([{ name: "Farinha", quantity: 400, unitCost: 0.012 }, { name: "Sal", quantity: 10, unitCost: null }]).status).toBe("partial");
  });
  it("calculates margin without pretending unknown cost is zero", () => {
    expect(calculateVariantCost(calculateRecipeCost([{ name: "Farinha", quantity: 400, unitCost: 0.012 }]), [1]).totalCost).toBeCloseTo(5.8);
    expect(calculatePricing(28, null).marginPercent).toBeNull();
    expect(calculatePricing(28, 10).grossProfit).toBe(18);
  });
});

describe("promotion pricing", () => {
  const classics = { id: "classic-2", name: "Clássicos 2 por 19", eligibleVariantIds: ["a", "b", "c"], bundleQuantity: 2, bundlePrice: 19, quantityMode: "exact" as const, priority: 20, stackingPolicy: "exclusive" as const };
  it("applies a mixed-flavor bread bundle", () => {
    const result = calculatePromotionalPrice([{ variantId: "a", name: "Tradicional", quantity: 1, unitPrice: 12 }, { variantId: "b", name: "Girassol", quantity: 1, unitPrice: 12 }], [classics]);
    expect(result.finalTotal).toBe(19); expect(result.discountTotal).toBe(5); expect(result.appliedBundles).toHaveLength(1);
  });
  it("does not reuse units and leaves excess quantities at regular price", () => {
    const result = calculatePromotionalPrice([{ variantId: "a", name: "Pão", quantity: 3, unitPrice: 12 }], [classics]);
    expect(result.finalTotal).toBe(31); expect(result.appliedBundles[0].quantity).toBe(2);
  });
  it("chooses the lower deterministic price among competing rules", () => {
    const result = calculatePromotionalPrice([{ variantId: "a", name: "Pizza", quantity: 2, unitPrice: 35 }], [{ ...classics, eligibleVariantIds: ["b", "c"] }, { ...classics, id: "pizza-2", name: "Pizza 2 por 60", eligibleVariantIds: ["a"], bundlePrice: 60, priority: 10 }]);
    expect(result.finalTotal).toBe(60); // the configured bundle wins over the regular price
  });
});
