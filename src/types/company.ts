export type CompanyId = "all" | "bread" | "pizza";

export type Company = {
  id: CompanyId;
  name: string;
  shortName: string;
  description: string;
  databaseId?: string;
  color?: string;
};

export const companies: Company[] = [
  { id: "all", name: "Geral", shortName: "Geral", description: "Visão consolidada" },
  { id: "bread", name: "Atelier do Pão", shortName: "Atelier", description: "Pães artesanais" },
  { id: "pizza", name: "Pizzas do Condomínio", shortName: "Pizzas", description: "Pizzas artesanais" },
];
