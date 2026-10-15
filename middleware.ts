import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from "@/lib/supabase/config";

export async function middleware(request: NextRequest) {
  if (!isSupabaseConfigured()) return NextResponse.next();

  let response = NextResponse.next({ request });
  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() { return request.cookies.getAll(); },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const { data: { user } } = await supabase.auth.getUser();
  const isLogin = request.nextUrl.pathname === "/login";

  if (!user && !isLogin) return NextResponse.redirect(new URL("/login", request.url));
  if (user) {
    const { data: profile } = await supabase.from("profiles").select("id").eq("id", user.id).eq("role", "admin").maybeSingle();
    if (isLogin && profile) return NextResponse.redirect(new URL("/", request.url));
    if (!isLogin && !profile) return NextResponse.redirect(new URL("/login?error=unauthorized", request.url));
  }

  return response;
}

export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
