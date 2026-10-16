import { NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { createClient } from "@/lib/supabase/server";

export async function POST(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  if ((await getAccessState()).status !== "authorized") return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 });
  const { id } = await params;
  const { data, error } = await (await createClient()).rpc("cancel_open_sale", { p_sale_id: id });
  if (error) return NextResponse.json({ error: "Não foi possível cancelar o pedido.", code: error.code }, { status: 400 });
  return NextResponse.json({ data });
}
