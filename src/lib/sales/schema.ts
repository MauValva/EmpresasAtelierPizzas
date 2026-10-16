import { z } from "zod";
export const saleItemSchema = z.object({ product_variant_id: z.string().uuid(), quantity: z.coerce.number().int().positive(), unit_price: z.coerce.number().finite().min(0).optional() });
export const saleDraftSchema = z.object({ company_id: z.string().uuid(), customer_id: z.string().uuid().nullable().optional(), record_type: z.enum(["order", "sale"]).default("order"), scheduled_for: z.string().datetime().optional().or(z.literal("")), notes: z.string().trim().max(800).optional(), discount: z.coerce.number().finite().min(0).default(0), payment_method: z.enum(["pix", "cash", "card", "other"]).optional(), paid_at: z.string().datetime().optional(), payment_operation_key: z.string().uuid().optional(), operation_key: z.string().uuid().optional(), items: z.array(saleItemSchema).min(1) });
export const updateOpenSaleSchema = saleDraftSchema.extend({ record_type: z.literal("order") });
export const confirmSaleSchema = z.object({ payment_method: z.enum(["pix", "cash", "card", "other"]), paid_at: z.string().datetime().optional(), payment_operation_key: z.string().uuid().optional() });
export const cancelSaleSchema = z.object({});
export const saleStatusSchema = z.object({ status: z.enum(["open", "paid", "cancelled"]).optional(), record_type: z.enum(["order", "sale"]).optional() });
