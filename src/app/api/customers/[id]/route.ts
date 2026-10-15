import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { normalizePhone, whatsappUrl } from "@/lib/customers/normalize";
import { customerUpdateSchema } from "@/lib/customers/schema";
import { createClient } from "@/lib/supabase/server";

const customerFields = "id, name, phone, phone_normalized, apartment, address, notes, marketing_consent, is_active, created_at, updated_at";

function unauthorized() { return NextResponse.json({ error: "Acesso não autorizado." }, { status: 403 }); }

export async function GET(_request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState();
  if (access.status !== "authorized") return unauthorized();
  const { id } = await params;
  const supabase = await createClient();
  const { data, error } = await supabase.from("customers").select(customerFields).eq("id", id).maybeSingle();
  if (error) return NextResponse.json({ error: "Não foi possível carregar o cliente." }, { status: 500 });
  if (!data) return NextResponse.json({ error: "Cliente não encontrado." }, { status: 404 });
  return NextResponse.json({ data: { ...data, whatsapp_url: whatsappUrl(data.phone) } });
}

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState();
  if (access.status !== "authorized") return unauthorized();
  const { id } = await params;
  const body = await request.json().catch(() => null);
  const parsed = customerUpdateSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: "Confira os campos do cliente.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });

  const values = parsed.data;
  const update = { ...values, ...(values.phone !== undefined ? { phone: values.phone?.trim() || null, phone_normalized: normalizePhone(values.phone) } : {}), ...(values.apartment !== undefined ? { apartment: values.apartment?.trim() || null } : {}), ...(values.address !== undefined ? { address: values.address?.trim() || null } : {}), ...(values.notes !== undefined ? { notes: values.notes?.trim() || null } : {}) };
  const supabase = await createClient();
  const { data, error } = await supabase.from("customers").update(update).eq("id", id).select(customerFields).maybeSingle();
  if (error) return NextResponse.json({ error: "Não foi possível atualizar o cliente." }, { status: 500 });
  if (!data) return NextResponse.json({ error: "Cliente não encontrado." }, { status: 404 });
  return NextResponse.json({ data });
}
