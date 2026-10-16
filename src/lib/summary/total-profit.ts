export type HistoricalExpense = { company_id: string | null; amount: number; stock_amount: number };

export function historicalProfit(revenue: number, cogs: number, operatingExpenses: number) {
  return Number(revenue) - Number(cogs) - Number(operatingExpenses);
}

export function expensesForCompany(expenses: HistoricalExpense[], companyId: string | null) {
  return expenses.filter((expense) => companyId === null || expense.company_id === companyId);
}
