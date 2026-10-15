import { companies as staticCompanies, type Company } from "@/types/company";
import { createClient } from "@/lib/supabase/server";

export async function getCompanies(): Promise<Company[]> {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from("companies")
      .select("id, name, slug, is_active, color")
      .eq("is_active", true)
      .order("name");

    if (error || !data) return [];
    return data.map((company) => ({
      id: company.slug === "atelier-do-pao" ? "bread" : "pizza",
      name: company.name,
      shortName: company.slug === "atelier-do-pao" ? "Atelier" : "Pizzas",
      description: company.slug === "atelier-do-pao" ? "Pães artesanais" : "Pizzas artesanais",
      databaseId: company.id,
      color: company.color,
    }));
  } catch {
    return [];
  }
}

export function getFallbackCompanies() {
  return staticCompanies;
}
