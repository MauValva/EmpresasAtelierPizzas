export function weightedAverageCost(previousQuantity: number, previousCost: number, incomingQuantity: number, incomingCost: number) {
  if (incomingQuantity <= 0 || incomingCost < 0) throw new Error("Entrada inválida.");
  if (previousQuantity <= 0) return incomingCost;
  return ((previousQuantity * previousCost) + (incomingQuantity * incomingCost)) / (previousQuantity + incomingQuantity);
}

export function movementDelta(type: "opening_balance" | "manual_in" | "manual_out" | "adjustment", quantity: number, currentQuantity: number) {
  if (quantity < 0 || (type !== "adjustment" && quantity === 0)) throw new Error("A quantidade informada é inválida.");
  if (type === "manual_out") return -quantity;
  if (type === "adjustment") return quantity - currentQuantity;
  return quantity;
}

export function inventoryStatus(quantity: number, minimum: number, active = true) {
  if (!active) return "inactive" as const;
  if (quantity < 0) return "negative" as const;
  if (quantity === 0) return "zero" as const;
  if (quantity <= minimum) return "low" as const;
  return "normal" as const;
}
