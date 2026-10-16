import { z } from "zod";

export const inventoryUnitSchema = z.enum(["kg", "ml", "un"]);
export const inventoryCompanyScopeSchema = z.enum(["atelier", "pizza", "both"]);
export const inventoryItemSchema = z.object({
  name: z.string().trim().min(2).max(120),
  category: z.string().trim().max(80).optional(),
  unit: inventoryUnitSchema,
  company_scope: inventoryCompanyScopeSchema.default("both"),
  minimum_quantity: z.coerce.number().finite().min(0),
  notes: z.string().trim().max(500).optional(),
  is_active: z.boolean().default(true),
});
export const movementSchema = z.object({
  movement_type: z.enum(["opening", "manual_in", "manual_out", "adjustment"]),
  quantity: z.coerce.number().finite().refine((value) => value !== 0),
  unit_cost: z.preprocess((value) => value === "" || value === undefined ? undefined : value, z.coerce.number().finite().min(0).optional()),
  reason: z.string().trim().max(300).optional().default("Ajuste manual"),
  operation_key: z.string().uuid().optional(),
});
export type InventoryItemInput = z.infer<typeof inventoryItemSchema>;
export type MovementInput = z.infer<typeof movementSchema>;
