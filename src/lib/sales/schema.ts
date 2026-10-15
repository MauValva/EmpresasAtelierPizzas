import { z } from "zod";
export const saleItemSchema = z.object({ product_variant_id: z.string().uuid(), quantity: z.coerce.number().int().positive() });
export const saleDraftSchema = z.object({ company_id: z.string().uuid(), customer_id: z.string().uuid(), scheduled_for: z.string().datetime().optional().or(z.literal("")), delivery_address: z.string().trim().max(300).optional(), apartment: z.string().trim().max(80).optional(), notes: z.string().trim().max(800).optional(), items: z.array(saleItemSchema).min(1) });
export const confirmSaleSchema = z.object({ manual_discount: z.coerce.number().finite().min(0).default(0), discount_reason: z.string().trim().max(300).optional() });
export const cancelSaleSchema = z.object({ return_stock: z.boolean(), reason: z.string().trim().min(3).max(300), operation_key: z.string().uuid().optional() });
export const saleStatusSchema = z.object({ order_status: z.enum(["confirmed", "completed", "cancelled"]).optional(), fulfillment_status: z.enum(["pending", "preparing", "ready", "delivered"]).optional() });
