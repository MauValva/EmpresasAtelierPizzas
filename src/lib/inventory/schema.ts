import { z } from "zod";

export const inventoryUnitSchema = z.enum(["g", "ml", "un"]);
export const inventoryItemSchema = z.object({
  name: z.string().trim().min(2, "Informe o nome do ingrediente.").max(120),
  category: z.string().trim().max(80).optional(),
  unit: inventoryUnitSchema,
  minimum_quantity: z.coerce.number().finite().min(0, "O estoque mínimo não pode ser negativo."),
  notes: z.string().trim().max(500).optional(),
});
export const movementSchema = z.object({
  movement_type: z.enum(["opening_balance", "manual_in", "manual_out", "adjustment"]),
  quantity: z.coerce.number().finite().min(0, "A quantidade não pode ser negativa."),
  unit_cost: z.preprocess((value) => value === "" || value === undefined ? undefined : value, z.coerce.number().finite().min(0).optional()),
  reason: z.string().trim().min(3, "Informe o motivo da movimentação.").max(300),
});
export type InventoryItemInput = z.infer<typeof inventoryItemSchema>;
export type MovementInput = z.infer<typeof movementSchema>;
