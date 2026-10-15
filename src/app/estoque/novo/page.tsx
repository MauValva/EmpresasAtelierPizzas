import { AppShell } from "@/components/layout/app-shell";
import { InventoryItemForm } from "@/components/inventory/inventory-item-form";
import { PageHeader } from "@/components/shared/page-header";

export default function NewInventoryItemPage() { return <AppShell pageTitle="Novo ingrediente"><PageHeader eyebrow="Estoque" title="Novo ingrediente" description="Cadastre o ingrediente e defina a unidade base e o estoque mínimo." /><div className="mt-7 max-w-3xl"><InventoryItemForm /></div></AppShell>; }
