import { NextResponse } from "next/server";

export async function POST() {
  return NextResponse.json({ error: "Receitas não possuem versionamento ou publicação no modelo simplificado." }, { status: 410 });
}
