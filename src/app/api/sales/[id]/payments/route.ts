import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json({ error: "Pagamentos são registrados ao finalizar a venda." }, { status: 410 });
}
