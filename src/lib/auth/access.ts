import { isSupabaseConfigured } from "@/lib/supabase/config";
import { createClient } from "@/lib/supabase/server";

export type AccessState =
  | { status: "unconfigured" }
  | { status: "unauthenticated" }
  | { status: "unauthorized" }
  | { status: "authorized"; displayName: string | null; userId: string }
  | { status: "error"; message: string };

export async function getAccessState(): Promise<AccessState> {
  if (!isSupabaseConfigured()) return { status: "unconfigured" };

  try {
    const supabase = await createClient();
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError) return { status: "unauthenticated" };
    if (!userData.user) return { status: "unauthenticated" };

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, display_name, role")
      .eq("id", userData.user.id)
      .eq("role", "admin")
      .maybeSingle();

    if (profileError) return { status: "error", message: "Não foi possível validar a autorização." };
    if (!profile) return { status: "unauthorized" };

    return { status: "authorized", displayName: profile.display_name, userId: profile.id };
  } catch {
    return { status: "error", message: "Não foi possível conectar ao Supabase." };
  }
}
