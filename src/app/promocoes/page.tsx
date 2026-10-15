import { AppShell } from "@/components/layout/app-shell";
import { PromotionManager } from "@/components/catalog/promotion-manager";
import { PageHeader } from "@/components/shared/page-header";
export default function PromotionsPage() { return <AppShell pageTitle="Promoções"><PageHeader eyebrow="Produtos" title="Promoções e combos" description="Configure grupos elegíveis, quantidades e preços fechados. A aplicação ficará pronta para a Etapa 08." /><PromotionManager /></AppShell>; }
