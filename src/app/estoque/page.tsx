import { AppShell } from "@/components/layout/app-shell";
import { StockWorkspace } from "@/components/inventory/stock-workspace";

export default function InventoryPage() {
  return <AppShell pageTitle="Estoque" eyebrow="Operação"><StockWorkspace /></AppShell>;
}
