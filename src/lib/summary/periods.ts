export type DatePeriod = { start: string; end: string };
export type OperationalDate = { year: number; month: number; day: number };

export function operationalToday(now = new Date()): OperationalDate {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
  return { year: Number(parts.find((part) => part.type === "year")?.value), month: Number(parts.find((part) => part.type === "month")?.value), day: Number(parts.find((part) => part.type === "day")?.value) };
}

function dateOnly(value: Date) { return value.toISOString().slice(0, 10); }

export function monthPeriod(year: number, month: number): DatePeriod {
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month, 0));
  return { start: dateOnly(start), end: dateOnly(end) };
}

export function weekPeriod(date: OperationalDate): DatePeriod {
  const current = new Date(Date.UTC(date.year, date.month - 1, date.day));
  const mondayOffset = (current.getUTCDay() + 6) % 7;
  current.setUTCDate(current.getUTCDate() - mondayOffset);
  const end = new Date(current);
  end.setUTCDate(end.getUTCDate() + 6);
  return { start: dateOnly(current), end: dateOnly(end) };
}

export function validMonthYear(month: number, year: number, today = operationalToday()): { month: number; year: number } {
  if (!Number.isInteger(month) || month < 1 || month > 12 || !Number.isInteger(year) || year < 2000 || year > today.year) return { month: today.month, year: today.year };
  if (year === today.year && month > today.month) return { month: today.month, year: today.year };
  return { month, year };
}
