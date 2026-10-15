import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { createClient } from "@/lib/supabase/server";
export async function POST(_request: NextRequest, { params }: { params: Promise<{ id: string }> }) { const access = await getAccessState(); if (access.status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); const { id } = await params; const supabase = await createClient(); const { data, error } = await supabase.rpc("receive_purchase", { p_purchase_id: id }); if (error) return NextResponse.json({ error: "Não foi possível confirmar o recebimento." }, { status: 400 }); return NextResponse.json({ data }); }
