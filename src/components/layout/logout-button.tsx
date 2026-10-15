"use client";

import { LogOut } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";

export function LogoutButton() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function handleLogout() {
    setLoading(true);
    try {
      await createClient().auth.signOut();
    } finally {
      router.replace("/login");
      router.refresh();
      setLoading(false);
    }
  }

  return <Button type="button" variant="ghost" size="sm" onClick={handleLogout} disabled={loading}><LogOut className="h-4 w-4" />{loading ? "Saindo..." : "Sair"}</Button>;
}
