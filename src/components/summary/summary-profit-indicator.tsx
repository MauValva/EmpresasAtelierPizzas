"use client";

import { useEffect, useState } from "react";
import { COMPANY_CHANGE_EVENT, FINANCIAL_CHANGE_EVENT, readSelectedCompanyId } from "@/lib/company-selection";

export function SummaryProfitIndicator() {
  const [companyId, setCompanyId] = useState(""); const [refreshKey, setRefreshKey] = useState(0); const [value, setValue] = useState<number | null>(null); const [loading, setLoading] = useState(true); const [error, setError] = useState(false);
  useEffect(() => { setCompanyId(readSelectedCompanyId()); const onCompany = (event: Event) => setCompanyId((event as CustomEvent<string>).detail ?? readSelectedCompanyId()); const onFinancialChange = () => setRefreshKey((current) => current + 1); window.addEventListener(COMPANY_CHANGE_EVENT, onCompany); window.addEventListener(FINANCIAL_CHANGE_EVENT, onFinancialChange); return () => { window.removeEventListener(COMPANY_CHANGE_EVENT, onCompany); window.removeEventListener(FINANCIAL_CHANGE_EVENT, onFinancialChange); }; }, []);
  useEffect(() => { let active = true; setLoading(true); const query = companyId ? `?company_id=${encodeURIComponent(companyId)}` : ""; fetch(`/api/dashboard${query}`).then(async (response) => { const payload = await response.json(); if (!response.ok) throw new Error(); if (active) { setValue(Number(payload.data?.totalProfit ?? 0)); setError(false); } }).catch(() => { if (active) setError(true); }).finally(() => { if (active) setLoading(false); }); return () => { active = false; }; }, [companyId, refreshKey]);
  return <div className="text-left"><span className="block text-[10px] uppercase tracking-[0.14em] text-muted">Lucro total</span><strong className={`mt-1 block text-sm ${error ? "text-danger" : "text-success"}`}>{loading ? "…" : error ? "—" : `R$ ${(value ?? 0).toFixed(2).replace(".", ",")}`}</strong></div>;
}
