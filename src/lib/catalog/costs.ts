export type RecipeCostIngredient = { name: string; quantity: number; unitCost: number | null };
export type RecipeCostResult = { status: "complete" | "partial" | "unknown"; ingredientCost: number; missingIngredients: string[]; totalCost: number | null };

export function calculateRecipeCost(ingredients: RecipeCostIngredient[], scale = 1): RecipeCostResult {
  const missingIngredients = ingredients.filter((ingredient) => ingredient.unitCost === null || !Number.isFinite(ingredient.unitCost)).map((ingredient) => ingredient.name);
  const ingredientCost = ingredients.reduce((sum, ingredient) => sum + (ingredient.unitCost === null ? 0 : ingredient.quantity * ingredient.unitCost * scale), 0);
  const status = ingredients.length === 0 || missingIngredients.length === ingredients.length ? "unknown" : missingIngredients.length ? "partial" : "complete";
  return { status, ingredientCost, missingIngredients, totalCost: status === "complete" ? ingredientCost : null };
}

export function calculateVariantCost(recipe: RecipeCostResult | null, directCosts: number[] = [], scale = 1) {
  const directCost = directCosts.reduce((sum, cost) => sum + cost, 0);
  if (!recipe || recipe.status === "unknown") return { directCost, totalCost: null, status: "unknown" as const };
  if (recipe.status === "partial") return { ...recipe, directCost, totalCost: null, status: "partial" as const };
  return { ...recipe, directCost, totalCost: recipe.ingredientCost * scale + directCost, status: "complete" as const };
}

export function calculatePricing(price: number, cost: number | null) {
  if (cost === null || !Number.isFinite(cost)) return { grossProfit: null, marginPercent: null, markup: null };
  const grossProfit = price - cost;
  return { grossProfit, marginPercent: price > 0 ? (grossProfit / price) * 100 : null, markup: cost > 0 ? price / cost : null };
}
