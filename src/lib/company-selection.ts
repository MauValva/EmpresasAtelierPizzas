export const COMPANY_STORAGE_KEY = "atelier-pizzas.company-database-id";
export const COMPANY_CHANGE_EVENT = "atelier-company-change";
export const SUMMARY_PERIOD_EVENT = "atelier-summary-period-change";
export const FINANCIAL_CHANGE_EVENT = "atelier-financial-change";

export function readSelectedCompanyId() {
  if (typeof window === "undefined") return "";
  return window.localStorage.getItem(COMPANY_STORAGE_KEY) ?? "";
}

export function announceCompanyChange(companyId: string) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(COMPANY_STORAGE_KEY, companyId);
  window.dispatchEvent(new CustomEvent(COMPANY_CHANGE_EVENT, { detail: companyId }));
}

export function announceFinancialChange() {
  if (typeof window !== "undefined") window.dispatchEvent(new Event(FINANCIAL_CHANGE_EVENT));
}
