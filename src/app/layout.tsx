import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = { title: "Atelier & Pizzas · Gestão", description: "Gestão comercial e financeira para Atelier do Pão e Pizzas do Condomínio." };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="pt-BR" className="dark"><body>{children}</body></html>; }
