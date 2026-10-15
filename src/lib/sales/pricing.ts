import { calculatePromotionalPrice, type PricingLine, type PromotionRule } from "@/lib/catalog/pricing";
export type SalePricingItem = { sale_item_id: string; variant_id: string; quantity: number; unit_price_snapshot: number; original_subtotal: number; discount_allocated: number; final_total: number };
export function buildSalePricing(items: { id: string; product_variant_id: string; quantity: number; price: number; name: string }[], promotions: PromotionRule[], manualDiscount = 0) {
  const lines: PricingLine[] = items.map((item) => ({ variantId: item.product_variant_id, name: item.name, quantity: item.quantity, unitPrice: item.price }));
  const priced = calculatePromotionalPrice(lines, promotions);
  const expanded = lines.flatMap((line, lineIndex) => Array.from({ length: line.quantity }, (_, unitIndex) => ({ lineIndex, unitIndex, variantId: line.variantId, price: line.unitPrice, used: false })));
  const automaticDiscounts = new Map<number, number>();
  for (const bundle of priced.appliedBundles) {
    const selected = expanded.map((unit, index) => ({ unit, index })).filter(({ unit }) => !unit.used && bundle.variantIds.includes(unit.variantId)).sort((a, b) => b.unit.price - a.unit.price || a.index - b.index).slice(0, bundle.quantity);
    selected.forEach(({ unit }) => { unit.used = true; });
    const original = selected.reduce((sum, entry) => sum + entry.unit.price, 0); const discount = Math.max(original - bundle.price, 0);
    selected.forEach((entry, index) => automaticDiscounts.set(entry.unit.lineIndex, (automaticDiscounts.get(entry.unit.lineIndex) ?? 0) + (index === selected.length - 1 ? discount - selected.slice(0, -1).reduce((sum, previous) => sum + discount * (previous.unit.price / original), 0) : discount * (entry.unit.price / original))));
  }
  const automaticLines = items.map((item, index) => { const original = item.quantity * item.price; const discount = automaticDiscounts.get(index) ?? 0; return { item, original, afterPromotion: Math.max(original - discount, 0), discount }; });
  const promotionTotal = automaticLines.reduce((sum, line) => sum + line.afterPromotion, 0); const safeManual = Math.min(Math.max(manualDiscount, 0), promotionTotal); const result: SalePricingItem[] = automaticLines.map(({ item, original, afterPromotion, discount }) => { const manualPart = promotionTotal > 0 ? safeManual * (afterPromotion / promotionTotal) : 0; const finalTotal = Math.max(afterPromotion - manualPart, 0); return { sale_item_id: item.id, variant_id: item.product_variant_id, quantity: item.quantity, unit_price_snapshot: item.price, original_subtotal: original, discount_allocated: discount + manualPart, final_total: finalTotal }; });
  return { ...priced, items: result, manualDiscount: safeManual, appliedPromotions: priced.appliedBundles };
}
