export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type PaymentMethod = "pix" | "cash" | "card" | "other";
export type InventoryUnit = "kg" | "ml" | "un";
export type SaleRecordType = "order" | "sale";
export type SaleStatus = "open" | "paid" | "cancelled";
export type ExpenseCategory = "paes" | "pizzas" | "compartilhado" | "administrativo";

export type Database = {
  public: {
    Tables: {
      profiles: Table<{ id: string; display_name: string | null; role: "admin"; created_at: string; updated_at: string }>;
      companies: Table<{ id: string; name: string; slug: string; color: string; is_active: boolean; created_at: string; updated_at: string }>;
      customers: Table<{ id: string; name: string; phone: string | null; phone_normalized: string | null; pickup_order: boolean; delivery_type: "condominio" | "fora" | null; street: string | null; address_number: string | null; neighborhood: string | null; city: string | null; building_block: string | null; apartment: string | null; address: string | null; notes: string | null; customer_tags: string[]; created_at: string; updated_at: string }>;
      inventory_items: Table<{ id: string; name: string; category: string | null; unit: InventoryUnit; company_scope: "atelier" | "pizza" | "both"; current_quantity: number; average_unit_cost: number; minimum_quantity: number; is_active: boolean; notes: string | null; created_at: string; updated_at: string }>;
      inventory_movements: Table<{ id: string; inventory_item_id: string; movement_type: "opening" | "manual_in" | "manual_out" | "sale" | "expense" | "adjustment"; quantity_delta: number; unit_cost_snapshot: number; total_cost_snapshot: number; previous_quantity: number; resulting_quantity: number; source_type: string; source_id: string | null; reason: string | null; created_by: string; operation_key: string; created_at: string }>;
      recipes: Table<{ id: string; company_id: string; name: string; yield_quantity: number; yield_unit: InventoryUnit; notes: string | null; is_active: boolean; created_at: string; updated_at: string }>;
      recipe_ingredients: Table<{ id: string; recipe_id: string; inventory_item_id: string; quantity_base: number; created_at: string }>;
      products: Table<{ id: string; company_id: string; name: string; category: string | null; description: string | null; is_active: boolean; created_at: string; updated_at: string }>;
      product_variants: Table<{ id: string; product_id: string; name: string; price: number; target_weight_g: number | null; is_active: boolean; created_at: string; updated_at: string }>;
      sales: Table<{ id: string; company_id: string; customer_id: string | null; order_number: number; record_type: SaleRecordType; status: SaleStatus; transaction_date: string; scheduled_for: string | null; subtotal: number; discount_total: number; total_amount: number; notes: string | null; paid_at: string | null; cancelled_at: string | null; operation_key: string | null; created_by: string; created_at: string; updated_at: string }>;
      sale_items: Table<{ id: string; sale_id: string; product_variant_id: string; product_name_snapshot: string; variant_name_snapshot: string; quantity: number; unit_price_snapshot: number; subtotal: number; unit_cost_snapshot: number | null; total_cost_snapshot: number | null; created_at: string }>;
      sale_payments: Table<{ id: string; sale_id: string; amount: number; payment_method: PaymentMethod; paid_at: string; operation_key: string; created_by: string; created_at: string }>;
      expenses: Table<{ id: string; company_id: string | null; description: string; category: ExpenseCategory; amount: number; expense_date: string; notes: string | null; operation_key: string | null; created_by: string; created_at: string; updated_at: string }>;
      expense_stock_entries: Table<{ id: string; expense_id: string; inventory_item_id: string; quantity: number; unit_cost: number; total_cost: number; operation_key: string; created_at: string }>;
    };
    Functions: {
      create_sale: Rpc<"create_sale">;
      create_sale_with_terms: Rpc<"create_sale_with_terms">;
      finalize_sale: Rpc<"finalize_sale">;
      finalize_sale_with_date: Rpc<"finalize_sale_with_date">;
      update_open_sale: Rpc<"update_open_sale">;
      cancel_open_sale: Rpc<"cancel_open_sale">;
      register_inventory_movement: Rpc<"register_inventory_movement">;
      create_expense: Rpc<"create_expense">;
      get_summary: Rpc<"get_summary">;
      is_admin: Rpc<"is_admin">;
      create_recipe_atomic: Rpc<"create_recipe_atomic">;
      update_recipe_atomic: Rpc<"update_recipe_atomic">;
    };
  };
};

type Table<Row> = { Row: Row; Insert: Partial<Row>; Update: Partial<Row>; Relationships: [] };
type Rpc<Name extends string> = { Args: Record<string, Json>; Returns: Json; Name: Name };

