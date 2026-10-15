import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { supabaseAnonKey, supabaseUrl } from "@/lib/supabase/config";

let browserClient: SupabaseClient | undefined;

export function createClient() {
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Supabase não está configurado.");
  }

  browserClient ??= createBrowserClient(supabaseUrl, supabaseAnonKey);
  return browserClient;
}
