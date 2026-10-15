import { Users } from "lucide-react";
import { AppShell } from "@/components/layout/app-shell";
import { CustomerList } from "@/components/customers/customer-list";
import { PageHeader } from "@/components/shared/page-header";
import { StatusBadge } from "@/components/shared/status-badge";

export default function CustomersPage() { return <AppShell pageTitle="Clientes"><PageHeader eyebrow="Relacionamento" title="Clientes" description="Uma base global compartilhada entre Atelier do Pão e Pizzas do Condomínio." action={<StatusBadge tone="info"><Users className="h-3.5 w-3.5" />Base compartilhada</StatusBadge>} /><CustomerList /></AppShell>; }
