import { describe, expect, it } from "vitest";
import { inventoryStatus, movementDelta, weightedAverageCost } from "../src/lib/inventory/rules";

describe("inventory rules", () => {
  it("calculates weighted average cost", () => {
    expect(weightedAverageCost(500, 2, 500, 4)).toBe(3);
  });

  it("uses incoming cost after a negative balance", () => {
    expect(weightedAverageCost(-10, 2, 10, 5)).toBe(5);
  });

  it("calculates entries, exits and physical adjustments", () => {
    expect(movementDelta("manual_in", 10, 0)).toBe(10);
    expect(movementDelta("manual_out", 3, 10)).toBe(-3);
    expect(movementDelta("adjustment", 0, 8)).toBe(-8);
    expect(movementDelta("adjustment", 12, 8)).toBe(4);
  });

  it("allows zero physical counts but rejects invalid quantities", () => {
    expect(() => movementDelta("adjustment", -1, 8)).toThrow();
    expect(() => movementDelta("manual_in", 0, 8)).toThrow();
  });

  it("classifies inventory status", () => {
    expect(inventoryStatus(-1, 5)).toBe("negative");
    expect(inventoryStatus(0, 5)).toBe("zero");
    expect(inventoryStatus(5, 5)).toBe("low");
    expect(inventoryStatus(8, 5)).toBe("normal");
    expect(inventoryStatus(8, 5, false)).toBe("inactive");
  });
});
