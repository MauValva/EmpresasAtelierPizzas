import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { normalizePhone } from "@/lib/customers/normalize";
import { customerSchema } from "@/lib/customers/schema";
import { createClient } from "@/lib/supabase/server";

const customerFields = "id, name, phone, phone_normalized, apartment, address, notes, marketing_consent, is_active, created_at, updated_at";

function unauthorized() { return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); }

export async function GET(request: NextRequest) {
  const access = await getAccessState();
  if (access.status !== "authorized") return unauthorized();

  const params = request.nextUrl.searchParams;
  const search = params.get("search")?.trim() ?? "";
  const status = params.get("status") ?? "active";
  const page = Math.max(Number(params.get("page") ?? "1"), 1);
  const pageSize = Math.min(Math.max(Number(params.get("pageSize") ?? "20"), 1), 50);
  const from = (page - 1) * pageSize;

  const supabase = await createClient();
  let query = supabase.from("customers").select(customerFields, { count: "exact" }).order("name", { ascending: true }).range(from, from + pageSize - 1);
  if (status === "inactive") query = query.eq("is_active", false);
  else if (status === "active") query = query.eq("is_active", true);
  if (search) {
    const digits = search.replace(/\D/g, "");
    if (digits.length >= 3) query = query.ilike("phone_normalized", `%${digits}%`);
    else query = query.ilike("name", `%${search.replace(/[%_,]/g, " ")}%`);
  }

  const { data, error, count } = await query;
  if (error) return NextResponse.json({ error: "Não foi possível carregar os clientes." }, { status: 500 });
  return NextResponse.json({ data: data ?? [], page, pageSize, total: count ?? 0, totalPages: Math.max(Math.ceil((count ?? 0) / pageSize), 1) });
}

export async function POST(request: NextRequest) {
  const access = await getAccessState();
  if (access.status !== "authorized") return unauthorized();

  const body = await request.json().catch(() => null);
  const parsed = customerSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "Confira os campos do cliente.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });

  const values = parsed.data;
  const supabase = await createClient();
  const phone = values.phone?.trim() || null;
  const { data, error } = await supabase.from("customers").insert({ ...values, phone, phone_normalized: normalizePhone(phone), apartment: values.apartment?.trim() || null, address: values.address?.trim() || null, notes: values.notes?.trim() || null }).select(customerFields).single();
  if (error) return NextResponse.json({ error: "Não foi possível salvar o cliente." }, { status: 500 });
  return NextResponse.json({ data }, { status: 201 });
}
