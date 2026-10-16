export type StockEntryValue = { quantity: number; unit_cost: number };

export function stockEntriesTotal(entries: StockEntryValue[]) {
  return entries.reduce((sum, entry) => sum + entry.quantity * entry.unit_cost, 0);
}

export function isFutureExpenseDate(value: string, today: string) {
  return value > today;
}
