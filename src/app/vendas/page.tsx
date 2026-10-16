import { AppShell } from "@/components/layout/app-shell";
import { SaleList } from "@/components/sales/sale-list";

export default function SalesPage() {
  return <AppShell pageTitle="Vendas" eyebrow="Comercial"><SaleList /></AppShell>;
}
