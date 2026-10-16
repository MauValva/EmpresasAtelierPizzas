import { NextRequest, NextResponse } from "next/server";
import { getAccessState } from "@/lib/auth/access";
import { normalizePhone } from "@/lib/customers/normalize";
import { customerSchema } from "@/lib/customers/schema";
import { aggregateCustomerSales } from "@/lib/customers/metrics";
import { createClient } from "@/lib/supabase/server";

const customerFields = "id, name, phone, phone_normalized, pickup_order, delivery_type, street, address_number, neighborhood, city, building_block, apartment, address, customer_tags, created_at, updated_at";
const unauthorized = () => NextResponse.json({ error: "Acesso nÃ£o autorizado." }, { status: 403 });

export async function GET(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return unauthorized();
  const params = request.nextUrl.searchParams; const search = params.get("search")?.trim() ?? ""; const page = Math.max(Number(params.get("page") ?? "1"), 1); const pageSize = Math.min(Math.max(Number(params.get("pageSize") ?? "20"), 1), 100); const from = (page - 1) * pageSize; const supabase = await createClient();
  let query = supabase.from("customers").select(customerFields, { count: "exact" }).order("name", { ascending: true }).range(from, from + pageSize - 1);

  if (search) { const text = search.replace(/[%_,]/g, " "); const digits = normalizePhone(search); query = digits ? query.or(`name.ilike.%${text}%,phone_normalized.ilike.%${digits}%`) : query.ilike("name", `%${text}%`); }
  const { data, error, count } = await query;
  if (error) return NextResponse.json({ error: "NÃ£o foi possÃ­vel carregar os clientes." }, { status: 500 });
  const customers = data ?? []; const ids = customers.map((customer) => customer.id); let metrics = new Map<string, { purchases: number; totalSpent: number }>();
  if (ids.length) { const { data: sales, error: salesError } = await supabase.from("sales").select("customer_id, total_amount, status").in("customer_id", ids).eq("status", "paid"); if (salesError) return NextResponse.json({ error: "NÃ£o foi possÃ­vel calcular o histÃ³rico dos clientes." }, { status: 500 }); metrics = aggregateCustomerSales(sales ?? []); }
  const result = customers.map((customer) => ({ ...customer, whatsapp_url: customer.phone_normalized ? `https://wa.me/${customer.phone_normalized}` : null, purchases_count: metrics.get(customer.id)?.purchases ?? 0, total_spent: metrics.get(customer.id)?.totalSpent ?? 0 }));
  return NextResponse.json({ data: result, page, pageSize, total: count ?? 0, totalPages: Math.max(Math.ceil((count ?? 0) / pageSize), 1) });
}

export async function POST(request: NextRequest) {
  if ((await getAccessState()).status !== "authorized") return unauthorized();
  const parsed = customerSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Confira os campos do cliente.", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  const values = parsed.data; const phone = values.phone?.trim() || null; const supabase = await createClient();
  const { data, error } = await supabase.from("customers").insert({ name: values.name, phone, phone_normalized: normalizePhone(phone), pickup_order: values.pickup_order, delivery_type: values.pickup_order ? values.delivery_type ?? "condominio" : null, street: values.pickup_order ? values.street?.trim() || null : null, address_number: values.pickup_order ? values.address_number?.trim() || null : null, neighborhood: values.pickup_order ? values.neighborhood?.trim() || null : null, city: values.pickup_order ? values.city?.trim() || null : null, building_block: values.pickup_order ? values.building_block?.trim() || null : null, apartment: values.pickup_order ? values.apartment?.trim() || null : null, address: values.pickup_order ? values.address?.trim() || null : null }).select(customerFields).single();
  if (error) return NextResponse.json({ error: "NÃ£o foi possÃ­vel salvar o cliente." }, { status: 500 });
  return NextResponse.json({ data }, { status: 201 });
}


