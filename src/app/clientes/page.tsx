import { AppShell } from "@/components/layout/app-shell";
import { CustomerList } from "@/components/customers/customer-list";

export default function CustomersPage() {
  return <AppShell pageTitle="Clientes" eyebrow="Relacionamento"><CustomerList /></AppShell>;
}
