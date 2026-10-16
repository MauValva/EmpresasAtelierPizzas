export function calculateSaleTotal(subtotal: number, discount: number): number {
  if (!Number.isFinite(subtotal) || subtotal < 0) throw new Error("Subtotal inválido");
  if (!Number.isFinite(discount) || discount < 0) throw new Error("Desconto inválido");
  if (discount > subtotal) throw new Error("Desconto superior ao subtotal");
  return subtotal - discount;
}

export function isPaymentDateFuture(value: string | null | undefined, now = new Date()): boolean {
  return Boolean(value) && new Date(value as string).getTime() > now.getTime();
}
