import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { supplierSchema } from "@/lib/purchases/schema";
import { createClient } from "@/lib/supabase/server";

const fields = "id, name, contact_name, phone, email, document_number, address, notes, is_active, created_at, updated_at";
function denied() { return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); }
export async function GET(request: NextRequest) {
  const access = await getAccessState(); if (access.status !== "authorized") return denied();
  const params = request.nextUrl.searchParams; const search = params.get("search")?.trim() ?? ""; const status = params.get("status") ?? "active"; const page = Math.max(Number(params.get("page") ?? "1"), 1); const pageSize = Math.min(Math.max(Number(params.get("pageSize") ?? "20"), 1), 50);
  const supabase = await createClient(); let query = supabase.from("suppliers").select(fields, { count: "exact" }).order("name").range((page - 1) * pageSize, page * pageSize - 1); if (status === "active") query = query.eq("is_active", true); if (status === "inactive") query = query.eq("is_active", false); if (search) query = query.or(`name.ilike.%${search.replace(/[%_,]/g, " ") }%,contact_name.ilike.%${search.replace(/[%_,]/g, " ") }%`);
  const { data, error, count } = await query; if (error) return NextResponse.json({ error: "Não foi possível carregar os fornecedores." }, { status: 500 }); return NextResponse.json({ data: data ?? [], page, pageSize, total: count ?? 0, totalPages: Math.max(Math.ceil((count ?? 0) / pageSize), 1) });
}
export async function POST(request: NextRequest) {
  const access = await getAccessState(); if (access.status !== "authorized") return denied(); const parsed = supplierSchema.safeParse(await request.json().catch(() => null)); if (!parsed.success) return NextResponse.json({ error: "Confira os campos do fornecedor.", issues: parsed.error.flatten().fieldErrors }, { status: 400 }); const values = parsed.data; const supabase = await createClient(); const { data, error } = await supabase.from("suppliers").insert({ ...values, contact_name: values.contact_name || null, phone: values.phone || null, email: values.email || null, document_number: values.document_number || null, address: values.address || null, notes: values.notes || null }).select(fields).single(); if (error) return NextResponse.json({ error: "Não foi possível salvar o fornecedor." }, { status: 500 }); return NextResponse.json({ data }, { status: 201 });
}
