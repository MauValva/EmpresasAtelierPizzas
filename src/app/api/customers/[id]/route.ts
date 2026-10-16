import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { normalizePhone, whatsappUrl } from "@/lib/customers/normalize";
import { customerUpdateSchema } from "@/lib/customers/schema";
import { createClient } from "@/lib/supabase/server";

const customerFields = "id, name, phone, phone_normalized, pickup_order, delivery_type, street, address_number, neighborhood, city, building_block, apartment, address, customer_tags, created_at, updated_at";

function unauthorized() { return NextResponse.json({ error: "Acesso nÃ£o autorizado." }, { status: 403 }); }

export async function GET(_request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const access = await getAccessState();
  if (access.status !== "authorized") return unauthorized();
  const { id } = await params;
  const supabase = await createClient();
  const { data, error } = await supabase.from("customers").select(customerFields).eq("id", id).maybeSingle();
  if (error) return NextResponse.json({ error: "NÃ£o foi possÃ­vel carregar o cliente." }, { status: 500 });
  if (!data) return NextResponse.json({ error: "Cliente nÃ£o encontrado." }, { status: 404 });
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
  const update = { ...(values.name !== undefined ? { name: values.name } : {}), ...(values.phone !== undefined ? { phone: values.phone?.trim() || null, phone_normalized: normalizePhone(values.phone) } : {}), ...(values.pickup_order !== undefined ? { pickup_order: values.pickup_order, delivery_type: values.pickup_order ? values.delivery_type ?? "condominio" : null, ...(values.pickup_order ? {} : { street: null, address_number: null, neighborhood: null, city: null, building_block: null, apartment: null, address: null }) } : {}), ...(values.delivery_type !== undefined ? { delivery_type: values.delivery_type } : {}), ...(values.street !== undefined ? { street: values.street?.trim() || null } : {}), ...(values.address_number !== undefined ? { address_number: values.address_number?.trim() || null } : {}), ...(values.neighborhood !== undefined ? { neighborhood: values.neighborhood?.trim() || null } : {}), ...(values.city !== undefined ? { city: values.city?.trim() || null } : {}), ...(values.building_block !== undefined ? { building_block: values.building_block?.trim() || null } : {}), ...(values.apartment !== undefined ? { apartment: values.apartment?.trim() || null } : {}), ...(values.address !== undefined ? { address: values.address?.trim() || null } : {}) };
  const supabase = await createClient();
  const { data, error } = await supabase.from("customers").update(update).eq("id", id).select(customerFields).maybeSingle();
  if (error) return NextResponse.json({ error: "NÃ£o foi possÃ­vel atualizar o cliente." }, { status: 500 });
  if (!data) return NextResponse.json({ error: "Cliente nÃ£o encontrado." }, { status: 404 });
  return NextResponse.json({ data });
}

