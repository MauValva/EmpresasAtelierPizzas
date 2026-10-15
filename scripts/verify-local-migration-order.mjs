import fs from "node:fs";
import path from "node:path";

const root = path.resolve("supabase/migrations");
const expected = [
  "202610130001_foundation.sql",
  "202610140001_customers.sql",
  "202610140002_inventory.sql",
  "202610140003_purchases.sql",
  "202610140004_catalog.sql",
  "202610140005_sales.sql",
  "202610140006_stock_security_hotfix.sql",
  "202610140007_finance.sql",
  "202610140008_integrity_hardening.sql",
];

const actual = fs.readdirSync(root).filter((file) => file.endsWith(".sql")).sort();
const missing = expected.filter((file) => !actual.includes(file));
const unexpected = actual.filter((file) => !expected.includes(file));

console.log(JSON.stringify({
  status: missing.length === 0 ? "ready" : "blocked",
  expected_order: expected,
  actual,
  missing,
  unexpected,
  note: "Verificação local de arquivos; não conecta ao Supabase e não executa migrations.",
}, null, 2));

process.exitCode = missing.length === 0 ? 0 : 1;
