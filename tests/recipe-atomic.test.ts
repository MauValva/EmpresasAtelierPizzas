import { describe, expect, it } from "vitest";
import { recipeSchema } from "../src/lib/catalog/schema";

const company = "11111111-1111-4111-8111-111111111111";
const ingredient = "33333333-3333-4333-8333-333333333333";

describe("contrato de receitas transacionais", () => {
  it("aceita criação e edição com variante e ingredientes", () => {
    const result = recipeSchema.safeParse({ company_id: company, name: "Massa", yield_quantity: 10, yield_unit: "un", items: [{ inventory_item_id: ingredient, quantity_base: 500 }] });
    expect(result.success).toBe(true);
  });

  it("rejeita rendimento inválido, quantidade inválida e ingrediente inválido", () => {
    expect(recipeSchema.safeParse({ company_id: company, name: "Massa", yield_quantity: 0, yield_unit: "un", items: [{ inventory_item_id: ingredient, quantity_base: 1 }] }).success).toBe(false);
    expect(recipeSchema.safeParse({ company_id: company, name: "Massa", yield_quantity: 1, yield_unit: "un", items: [{ inventory_item_id: ingredient, quantity_base: 0 }] }).success).toBe(false);
    expect(recipeSchema.safeParse({ company_id: company, name: "Massa", yield_quantity: 1, yield_unit: "lb", items: [{ inventory_item_id: ingredient, quantity_base: 1 }] }).success).toBe(false);
  });

  it("exige ao menos um ingrediente e nome válido", () => {
    expect(recipeSchema.safeParse({ company_id: company, name: "A", yield_quantity: 1, yield_unit: "un", items: [] }).success).toBe(false);
  });
});
