export type PricingLine = { variantId: string; name: string; quantity: number; unitPrice: number };
export type PromotionRule = { id: string; name: string; eligibleVariantIds: string[]; bundleQuantity: number; bundlePrice: number; quantityMode: "minimum" | "exact"; priority: number; stackingPolicy: "exclusive" | "stackable" };
export type AppliedBundle = { promotionId: string; promotionName: string; variantIds: string[]; quantity: number; price: number; discount: number };
export type PricingResult = { baseTotal: number; finalTotal: number; discountTotal: number; lines: PricingLine[]; appliedBundles: AppliedBundle[] };

function stateKey(counts: number[]) { return counts.join(","); }
export function calculatePromotionalPrice(lines: PricingLine[], promotions: PromotionRule[]): PricingResult {
  const units = lines.flatMap((line) => Array.from({ length: Math.max(0, Math.floor(line.quantity)) }, () => ({ variantId: line.variantId, name: line.name, unitPrice: line.unitPrice })));
  const baseTotal = units.reduce((sum, unit) => sum + unit.unitPrice, 0);
  const orderedPromotions = [...promotions].filter((promotion) => promotion.bundleQuantity > 0 && promotion.bundlePrice >= 0).sort((a, b) => a.priority - b.priority || a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
  const memo = new Map<string, { total: number; bundles: AppliedBundle[] }>();
  function solve(remaining: typeof units): { total: number; bundles: AppliedBundle[] } {
    const key = stateKey(remaining.map((unit) => units.indexOf(unit)));
    const cached = memo.get(key); if (cached) return cached;
    let best = { total: remaining.reduce((sum, unit) => sum + unit.unitPrice, 0), bundles: [] as AppliedBundle[] };
    for (const promotion of orderedPromotions) {
      const eligible = remaining.map((unit, index) => ({ unit, index })).filter(({ unit }) => promotion.eligibleVariantIds.includes(unit.variantId));
      if (eligible.length < promotion.bundleQuantity) continue;
      const selected = [...eligible].sort((a, b) => b.unit.unitPrice - a.unit.unitPrice || a.index - b.index).slice(0, promotion.bundleQuantity);
      const selectedIndexes = new Set(selected.map(({ index }) => index));
      const next = remaining.filter((_, index) => !selectedIndexes.has(index));
      const nextResult = solve(next);
      const candidateTotal = promotion.bundlePrice + nextResult.total;
      if (candidateTotal < best.total - 0.000001) best = { total: candidateTotal, bundles: [{ promotionId: promotion.id, promotionName: promotion.name, variantIds: selected.map(({ unit }) => unit.variantId), quantity: selected.length, price: promotion.bundlePrice, discount: selected.reduce((sum, item) => sum + item.unit.unitPrice, 0) - promotion.bundlePrice }, ...nextResult.bundles] };
    }
    memo.set(key, best); return best;
  }
  const optimized = solve(units);
  return { baseTotal, finalTotal: optimized.total, discountTotal: Math.max(baseTotal - optimized.total, 0), lines, appliedBundles: optimized.bundles };
}
