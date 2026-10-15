import fs from "node:fs";
import path from "node:path";

const input = process.argv[2];
if (!input) { console.error("Uso: node scripts/compare-remote-audit.mjs <resultado.json>"); process.exit(2); }
const remote = JSON.parse(fs.readFileSync(path.resolve(input), "utf8"));
const migrationDir = path.resolve("supabase/migrations");
const migrationFiles = ["202610140003_purchases.sql", "202610140004_catalog.sql", "202610140005_sales.sql"];
const sources = migrationFiles.map((file) => fs.readFileSync(path.join(migrationDir, file), "utf8"));
const sql = sources.join("\n");
const unique = (values) => [...new Set(values)].sort();
const normalize = (value) => String(value ?? "").replace(/\/\*[\s\S]*?\*\//g, "").replace(/--[^\n]*/g, "").replace(/\s+/g, " ").trim().toLowerCase();
const columnInfo = (definition) => { const value = normalize(definition); const type = value.match(/^(uuid|text|boolean|date|jsonb|integer|bigint|timestamptz|timestamp with time zone|timestamp without time zone|numeric(?:\([^)]*\))?|character varying(?:\([^)]*\))?)/)?.[1] ?? value.split(" ")[0]; const defaultMatch = value.match(/\bdefault\s+(.+?)(?=\s+(?:check|references|generated|constraint|unique|primary|not null)\b|$)/); const generated = /\bgenerated (?:always|by default) as\b/.test(value); return { type: type.replace("timestamp with time zone", "timestamptz"), nullable: !/\bnot null\b/.test(value) && !/\bprimary key\b/.test(value) && !/\bgenerated (?:always|by default) as\b/.test(value), default: normalize(defaultMatch?.[1] ?? ""), generated }; };
const bodyOnly = (value) => {
  const normalized = normalize(value);
  const match = normalized.match(/\bas\s+(\$[^$]*\$)([\s\S]*?)\1/);
  return normalize(match?.[2] ?? normalized);
};
const normalizeDefault = (value) => normalize(value)
  .replace(/::(?:text|timestamptz|timestamp with time zone|timestamp without time zone|numeric|integer|bigint|uuid|jsonb|boolean|date)/g, "")
  .replace(/\s+/g, "");
const localTables = unique([...sql.matchAll(/create table if not exists public\.([a-z0-9_]+)\s*\(([\s\S]*?)\n\);/gi)].map((m) => m[1]));
const tableColumns = new Map();
for (const match of sql.matchAll(/create table if not exists public\.([a-z0-9_]+)\s*\(([\s\S]*?)\n\);/gi)) {
  const columns = [];
  for (const line of match[2].split(/\r?\n/)) {
    const clean = line.trim().replace(/,$/, "");
    const column = clean.match(/^([a-z_][a-z0-9_]*)\s+(.+)$/i);
    if (column && !/^(constraint|primary|unique|check|foreign)\b/i.test(clean)) columns.push({ table_name: match[1], column_name: column[1], definition: normalize(column[2]), ...columnInfo(column[2]) });
  }
  tableColumns.set(match[1], columns);
}
const localFunctions = [];
for (const match of sql.matchAll(/create or replace function public\.([a-z0-9_]+)\s*\(([\s\S]*?)\)\s*returns\s+([^\n]+?)\s+language\s+([a-z0-9_]+)/gi)) {
  const start = match.index ?? 0; const tail = sql.slice(start); const definitionMatch = tail.match(/\$\$[\s\S]*?\$\$;/);
  localFunctions.push({ function_name: match[1], signature: normalize(match[2]), return_type: normalize(match[3]), language: normalize(match[4]), definition: normalize(definitionMatch ? `as ${definitionMatch[0]}` : tail.slice(0, 1000)) });
}
const localTriggers = unique([...sql.matchAll(/create trigger ([a-z0-9_]+)/gi)].map((m) => m[1]));
const localPolicies = unique([...sql.matchAll(/create policy "([^"]+)"/gi)].map((m) => m[1]));
const localIndexes = unique([...sql.matchAll(/create (?:unique )?index if not exists ([a-z0-9_]+)/gi)].map((m) => m[1]));
const names = (rows, field) => unique((Array.isArray(rows) ? rows : []).map((row) => row[field]).filter(Boolean));
const keyed = (rows, key) => new Map((Array.isArray(rows) ? rows : []).map((row) => [key(row), row]));
const classifyNames = (expected, actual) => ({
  equivalent: expected.filter((name) => actual.includes(name)),
  missing: expected.filter((name) => !actual.includes(name)),
  extra_legitimate_or_review: actual.filter((name) => !expected.includes(name)),
});
const remoteTables = names(remote.tables, "table_name");
const remoteFunctions = names(remote.functions, "function_name");
const remoteTriggers = names(remote.triggers, "trigger_name");
const remotePolicies = names(remote.policies, "policy_name");
const remoteIndexes = names(remote.indexes, "index_name");
const expectedFunctionNames = unique(localFunctions.map((row) => row.function_name));
const expectedColumns = [...tableColumns.values()].flat();
const remoteColumns = (remote.columns ?? []).map((row) => ({ ...row, key: `${row.table_name}.${row.column_name}` }));
const localColumnMap = keyed(expectedColumns, (row) => `${row.table_name}.${row.column_name}`);
const remoteColumnMap = keyed(remoteColumns, (row) => row.key);
const columns = [...new Set([...localColumnMap.keys(), ...remoteColumnMap.keys()])].sort().map((key) => {
  const local = localColumnMap.get(key); const actual = remoteColumnMap.get(key);
  if (!local) return { key, status: "extra_legitimate_or_review", remote: actual };
  if (!actual) return { key, status: "absent", expected: local };
  const remoteType = `${actual.data_type === "numeric" ? `numeric(${actual.numeric_precision},${actual.numeric_scale})` : actual.data_type === "timestamp with time zone" ? "timestamptz" : actual.data_type}${actual.character_maximum_length ? `(${actual.character_maximum_length})` : ""}`.toLowerCase();
  const generatedKnown = actual.is_generated !== undefined;
  const structureEqual = local.type === remoteType && local.nullable === (actual.is_nullable !== "NO") && (!generatedKnown || local.generated === (actual.is_generated === "ALWAYS"));
  const defaultComparable = !local.default || normalizeDefault(actual.column_default) === normalizeDefault(local.default);
  return { key, status: !generatedKnown && local.generated ? "evidence_missing_generated_metadata" : structureEqual && defaultComparable ? "equivalent_structure" : structureEqual ? "default_needs_review" : "divergent", expected: { type: local.type, nullable: local.nullable, default: local.default, generated: local.generated }, remote: actual };
});
const remoteFunctionMap = keyed(remote.functions, (row) => `${row.function_name}(${row.identity_arguments ?? ""})`);
const localFunctionMap = keyed(localFunctions, (row) => row.function_name);
const functions = expectedFunctionNames.map((name) => {
  const actuals = (remote.functions ?? []).filter((row) => row.function_name === name);
  if (!actuals.length) return { function_name: name, status: "absent" };
  const actual = actuals[0]; const expected = localFunctionMap.get(name); const bodyComparable = bodyOnly(actual.definition) === bodyOnly(expected.definition);
  return { function_name: name, identity_arguments: actual.identity_arguments, status: bodyComparable && Boolean(actual.security_definer) === normalize(expected.definition).includes("security definer") ? "equivalent_by_normalized_definition" : "present_definition_needs_review", security_definer: actual.security_definer, configuration: actual.configuration, definition: actual.definition };
});
const indexRows = (remote.indexes ?? []).map((row) => ({ ...row, status: localIndexes.includes(row.index_name) ? "explicit_expected" : ["primary_key", "unique_constraint"].includes(row.index_kind) ? "extra_legitimate_automatic" : "extra_review" }));
const securityNames = ["register_purchase_inventory_movement", "register_sale_stock_movement", "receive_purchase", "confirm_sale"];
const security = securityNames.map((name) => ({ function_name: name, functions: (remote.functions ?? []).filter((row) => row.function_name === name).map((fn) => ({ identity_arguments: fn.identity_arguments, security_definer: fn.security_definer, configuration: fn.configuration })), grants: (remote.function_grants ?? []).filter((grant) => grant.function_name === name && ["PUBLIC", "anon", "authenticated"].includes(grant.grantee)) }));
const history = remote.migration_history ?? { status: "unavailable", reason: "missing_section", rows: [] };
const result = { status: "review_required", source: path.basename(input), comparisons: { names: { tables: classifyNames(localTables, remoteTables), functions: classifyNames(expectedFunctionNames, remoteFunctions), triggers: classifyNames(localTriggers, remoteTriggers), policies: classifyNames(localPolicies, remotePolicies) }, columns, functions, indexes: { expected_explicit: localIndexes, remote: indexRows }, constraints: { status: "definition_review_required", remote_count: (remote.constraints ?? []).length }, policies: { status: "definition_review_required", remote: remote.policies ?? [] }, triggers: { status: "definition_review_required", remote: remote.triggers ?? [] }, grants: { status: "definition_review_required", table_grants: remote.table_grants ?? [], function_grants: remote.function_grants ?? [] } }, security, migration_history: history, seed_checks: remote.seed_checks ?? [], limitations: ["A comparação automática não substitui revisão SQL de constraints complexas, casts, defaults equivalentes e corpos PL/pgSQL.", "Funções com múltiplas sobrecargas permanecem em revisão individual.", "Índices PRIMARY KEY e UNIQUE são classificados como automáticos/legítimos quando identificados pelo catálogo.", "Histórico indisponível não é tratado como histórico vazio."] };
console.log(JSON.stringify(result, null, 2));
