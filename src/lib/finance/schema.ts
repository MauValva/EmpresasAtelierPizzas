import { z } from "zod";

const optionalText = (max: number) => z.string().trim().max(max).optional().nullable();
export const paymentSchema = z.object({ amount: z.coerce.number().positive(), payment_method: z.enum(["pix", "cash", "card", "other"]), notes: optionalText(300), operation_key: z.string().uuid().optional() });
export const refundSchema = z.object({ payment_id: z.string().uuid(), amount: z.coerce.number().positive(), reason: z.string().trim().min(3).max(300), operation_key: z.string().uuid().optional() });
export const expenseStockEntrySchema = z.object({ inventory_item_id: z.string().uuid(), quantity: z.coerce.number().positive(), unit_cost: z.coerce.number().nonnegative(), operation_key: z.string().uuid().optional() });
export const expenseSchema = z.object({ company_id: z.string().uuid().nullable().optional(), description: z.string().trim().min(2).max(180), category: z.enum(["paes", "pizzas", "compartilhado", "administrativo"]), amount: z.coerce.number().positive(), expense_date: z.string().date(), notes: optionalText(500), stock_entries: z.array(expenseStockEntrySchema).default([]), operation_key: z.string().uuid().optional() });
export const recurrenceSchema = z.object({ company_id: z.string().uuid().nullable().optional(), description: z.string().trim().min(2).max(180), category: z.string().trim().min(2).max(80), amount: z.coerce.number().positive(), day_of_month: z.coerce.number().int().min(1).max(31), starts_on: z.string(), ends_on: z.string().nullable().optional(), notes: optionalText(500) });
