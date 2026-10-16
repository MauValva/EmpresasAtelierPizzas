export const unitLabels = { kg: "quilogramas", ml: "mililitros", un: "unidades" } as const;
export const unitCostUnitLabels = { kg: "kg", ml: "ml", un: "unidade" } as const;
export const movementLabels = { opening_balance: "Saldo inicial", manual_in: "Entrada", manual_out: "Saída", adjustment: "Ajuste físico" } as const;
export const statusLabels = { inactive: "Inativo", negative: "Negativo", zero: "Zerado", low: "Abaixo do mínimo", normal: "Normal" } as const;
export function formatQuantity(value: number, unit: keyof typeof unitLabels) { return `${new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 3 }).format(value)} ${unit}`; }
export function formatCurrency(value: number) { return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(value); }
export function unitCostLabel(unit: keyof typeof unitCostUnitLabels) { return `Custo unitário por ${unitCostUnitLabels[unit]} (R$), opcional`; }
