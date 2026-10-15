import { z } from "zod";

const optionalText = (max: number) => z.preprocess((value) => value === "" ? undefined : value, z.string().trim().max(max).optional());
export const supplierSchema = z.object({ name: z.string().trim().min(2).max(140), contact_name: optionalText(140), phone: optionalText(40), email: z.preprocess((value) => value === "" ? undefined : value, z.string().email("E-mail inválido.").max(180).optional()), document_number: optionalText(40), address: optionalText(240), notes: optionalText(600), is_active: z.boolean().optional() });
export const purchaseItemInputSchema = z.object({ inventory_item_id: z.string().uuid(), quantity: z.coerce.number().finite().positive(), quantity_unit: z.enum(["kg", "g", "l", "ml", "un"]), unit_cost: z.coerce.number().finite().min(0) });
export const purchaseSchema = z.object({ supplier_id: z.string().uuid(), company_id: z.preprocess((value) => value === "" ? undefined : value, z.string().uuid().optional()), purchase_date: z.string().date(), notes: optionalText(600), additional_costs: z.coerce.number().finite().min(0), discount: z.coerce.number().finite().min(0), items: z.array(purchaseItemInputSchema).min(1, "Adicione ao menos um item.") });
export const paymentSchema = z.object({ amount: z.coerce.number().finite().positive(), payment_method: z.enum(["pix", "cash", "card", "other"]), notes: optionalText(300), operation_key: z.string().uuid().optional() });
export type SupplierInput = z.infer<typeof supplierSchema>;
export type PurchaseInput = z.infer<typeof purchaseSchema>;

const factors = { kg: 1000, g: 1, l: 1000, ml: 1, un: 1 } as const;
export function quantityToBase(quantity: number, inputUnit: keyof typeof factors, inventoryUnit: "g" | "ml" | "un") {
  if ((inventoryUnit === "g" && (inputUnit !== "kg" && inputUnit !== "g")) || (inventoryUnit === "ml" && (inputUnit !== "l" && inputUnit !== "ml")) || (inventoryUnit === "un" && inputUnit !== "un")) throw new Error("A unidade da compra não corresponde à unidade base do ingrediente.");
  return quantity * factors[inputUnit];
}
export function unitCostToBase(unitCost: number, inputUnit: keyof typeof factors, inventoryUnit: "g" | "ml" | "un") {
  return unitCost / quantityToBase(1, inputUnit, inventoryUnit);
}
