export function normalizePhone(phone?: string | null) {
  const digits = (phone ?? "").replace(/\D/g, "");
  if (!digits) return null;
  return digits.length <= 11 ? `55${digits}` : digits;
}

export function whatsappUrl(phone?: string | null) {
  const normalized = normalizePhone(phone);
  return normalized ? `https://wa.me/${normalized}` : null;
}
