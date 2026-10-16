import { describe, expect, it } from "vitest";
import { monthPeriod, validMonthYear, weekPeriod } from "../src/lib/summary/periods";

describe("summary periods", () => {
  it("creates the complete selected month", () => {
    expect(monthPeriod(2025, 2)).toEqual({ start: "2025-02-01", end: "2025-02-28" });
  });

  it("keeps the current operational week from Monday to Sunday", () => {
    expect(weekPeriod({ year: 2025, month: 3, day: 2 })).toEqual({ start: "2025-02-24", end: "2025-03-02" });
  });

  it("clamps future month and year combinations", () => {
    expect(validMonthYear(12, 2025, { year: 2025, month: 3, day: 10 })).toEqual({ month: 3, year: 2025 });
    expect(validMonthYear(2, 2024, { year: 2025, month: 3, day: 10 })).toEqual({ month: 2, year: 2024 });
  });
});
