import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import { AppHeader } from "@/components/layout/app-header";
import { DesktopSidebar } from "@/components/layout/desktop-sidebar";
import { MobileBottomNavigation } from "@/components/layout/mobile-bottom-navigation";
import { getAccessState } from "@/lib/auth/access";
import { ConfigurationState } from "@/components/shared/configuration-state";
import { AccessErrorState } from "@/components/shared/access-error-state";

export async function AppShell({ children, pageTitle = "Gestão", eyebrow = "Workspace" }: { children: ReactNode; pageTitle?: string; eyebrow?: string }) {
  const access = await getAccessState();
  if (access.status === "unconfigured") return <ConfigurationState />;
  if (access.status === "unauthenticated" || access.status === "unauthorized") redirect("/login");
  if (access.status === "error") return <AccessErrorState message={access.message} />;
  return <div className="min-h-screen bg-background"><DesktopSidebar /><div className="lg:pl-64"><AppHeader eyebrow={eyebrow} pageTitle={pageTitle} /><main className="mx-auto max-w-[1440px] px-4 pb-28 pt-6 sm:px-6 lg:px-10 lg:pb-10">{children}</main></div><MobileBottomNavigation /></div>;
}
