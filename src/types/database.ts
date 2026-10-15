export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: { id: string; display_name: string | null; role: "admin"; created_at: string; updated_at: string };
        Insert: { id: string; display_name?: string | null; role?: "admin"; created_at?: string; updated_at?: string };
        Update: { display_name?: string | null; role?: "admin"; updated_at?: string };
        Relationships: [];
      };
      companies: {
        Row: { id: string; name: string; slug: string; is_active: boolean; color: string; created_at: string; updated_at: string };
        Insert: { id?: string; name: string; slug: string; is_active?: boolean; color: string; created_at?: string; updated_at?: string };
        Update: { name?: string; slug?: string; is_active?: boolean; color?: string; updated_at?: string };
        Relationships: [];
      };
      app_settings: {
        Row: { key: string; value: Json; description: string | null; created_at: string; updated_at: string };
        Insert: { key: string; value: Json; description?: string | null; created_at?: string; updated_at?: string };
        Update: { value?: Json; description?: string | null; updated_at?: string };
        Relationships: [];
      };
      customers: {
        Row: { id: string; name: string; phone: string | null; phone_normalized: string | null; apartment: string | null; address: string | null; notes: string | null; marketing_consent: boolean; is_active: boolean; created_at: string; updated_at: string };
        Insert: { id?: string; name: string; phone?: string | null; phone_normalized?: string | null; apartment?: string | null; address?: string | null; notes?: string | null; marketing_consent?: boolean; is_active?: boolean; created_at?: string; updated_at?: string };
        Update: { name?: string; phone?: string | null; phone_normalized?: string | null; apartment?: string | null; address?: string | null; notes?: string | null; marketing_consent?: boolean; is_active?: boolean; updated_at?: string };
        Relationships: [];
      };
      inventory_items: {
        Row: { id: string; name: string; category: string | null; unit: "g" | "ml" | "un"; current_quantity: number; average_unit_cost: number; minimum_quantity: number; is_active: boolean; notes: string | null; created_at: string; updated_at: string };
        Insert: { id?: string; name: string; category?: string | null; unit: "g" | "ml" | "un"; current_quantity?: number; average_unit_cost?: number; minimum_quantity?: number; is_active?: boolean; notes?: string | null; created_at?: string; updated_at?: string };
        Update: { name?: string; category?: string | null; minimum_quantity?: number; is_active?: boolean; notes?: string | null; updated_at?: string };
        Relationships: [];
      };
      inventory_movements: {
        Row: { id: string; inventory_item_id: string; movement_type: "opening_balance" | "manual_in" | "manual_out" | "adjustment"; quantity_delta: number; unit_cost_snapshot: number; total_cost_snapshot: number; previous_quantity: number; resulting_quantity: number; reason: string; source_type: string; source_id: string | null; created_by: string; operation_key: string | null; created_at: string };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      suppliers: {
        Row: { id: string; name: string; contact_name: string | null; phone: string | null; email: string | null; document_number: string | null; address: string | null; notes: string | null; is_active: boolean; created_at: string; updated_at: string };
        Insert: { id?: string; name: string; contact_name?: string | null; phone?: string | null; email?: string | null; document_number?: string | null; address?: string | null; notes?: string | null; is_active?: boolean; created_at?: string; updated_at?: string };
        Update: { name?: string; contact_name?: string | null; phone?: string | null; email?: string | null; document_number?: string | null; address?: string | null; notes?: string | null; is_active?: boolean; updated_at?: string };
        Relationships: [];
      };
      purchases: {
        Row: { id: string; supplier_id: string; company_id: string | null; purchase_date: string; received_at: string | null; received_by: string | null; status: "draft" | "ordered" | "received" | "cancelled"; payment_status: "pending" | "partial" | "paid"; notes: string | null; subtotal: number; additional_costs: number; discount: number; total_amount: number; created_by: string; created_at: string; updated_at: string };
        Insert: { id?: string; supplier_id: string; company_id?: string | null; purchase_date?: string; received_at?: string | null; received_by?: string | null; status?: "draft" | "ordered" | "received" | "cancelled"; payment_status?: "pending" | "partial" | "paid"; notes?: string | null; subtotal?: number; additional_costs?: number; discount?: number; total_amount?: number; created_by: string; created_at?: string; updated_at?: string };
        Update: { supplier_id?: string; company_id?: string | null; purchase_date?: string; status?: "draft" | "ordered" | "received" | "cancelled"; notes?: string | null; additional_costs?: number; discount?: number; updated_at?: string };
        Relationships: [];
      };
      purchase_items: {
        Row: { id: string; purchase_id: string; inventory_item_id: string; quantity: number; unit_cost: number; total_cost: number; receipt_operation_key: string; created_at: string };
        Insert: { id?: string; purchase_id: string; inventory_item_id: string; quantity: number; unit_cost: number; receipt_operation_key?: string; created_at?: string };
        Update: { inventory_item_id?: string; quantity?: number; unit_cost?: number };
        Relationships: [];
      };
      purchase_payments: {
        Row: { id: string; purchase_id: string; amount: number; paid_at: string; payment_method: "pix" | "cash" | "card" | "other"; notes: string | null; created_by: string; operation_key: string; created_at: string };
        Insert: never;
        Update: never;
        Relationships: [];
      };
    };
  };
};
