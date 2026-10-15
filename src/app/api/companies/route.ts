import { NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { createClient } from "@/lib/supabase/server";
export async function GET() { const access = await getAccessState(); if (access.status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); const supabase = await createClient(); const { data, error } = await supabase.from("companies").select("id, name, slug, color").eq("is_active", true).order("name"); if (error) return NextResponse.json({ error: "Não foi possível carregar as empresas." }, { status: 500 }); return NextResponse.json({ data: data ?? [] }); }
