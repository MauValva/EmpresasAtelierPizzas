import type { Json } from "@/types/database";

export type SharedExpenseAllocation = {
  atelier_do_pao: number;
  pizzas_do_condominio: number;
};

export function parseSharedExpenseAllocation(value: Json): SharedExpenseAllocation | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const candidate = value as Record<string, Json | undefined>;
  const atelier = candidate.atelier_do_pao;
  const pizzas = candidate.pizzas_do_condominio;
  if (typeof atelier !== "number" || typeof pizzas !== "number") return null;
  if (atelier < 0 || pizzas < 0 || atelier + pizzas !== 100) return null;
  return { atelier_do_pao: atelier, pizzas_do_condominio: pizzas };
}
