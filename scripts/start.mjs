import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import http from "node:http";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
process.chdir(root);
const envFile = path.join(root, ".env");
if (!fs.existsSync(envFile)) {
  const template = fs.readFileSync(path.join(root, ".env.example"), "utf8");
  fs.writeFileSync(envFile, template.replace(/^SURREAL_PASS=$/m,
    `SURREAL_PASS=${crypto.randomBytes(24).toString("base64url")}`), { mode: 0o600 });
  console.log("Created private .env. Add BREVO_API_KEY to enable email verification and password reset.");
}
process.loadEnvFile(envFile);

const setting = (name, fallback) => process.env[name] || fallback;
const user = setting("SURREAL_USER", "root");
const password = process.env.SURREAL_PASS;
const host = setting("SURREAL_HOST", "127.0.0.1");
const dbPort = Number(setting("SURREAL_PORT", "8100"));
const webPort = Number(setting("FRONTEND_PORT", "5173"));
const namespace = setting("SURREAL_NAMESPACE", "stocksense");
const database = setting("SURREAL_DATABASE", "stocksense");
const apiKey = process.env.BREVO_API_KEY?.trim();
const sender = setting("BREVO_FROM_EMAIL", "divy.r.vora14@gmail.com");
const binaryDir = path.join(root, ".tools");
let surreal = "surreal";
let databaseProcess;
let webServer;

if (!password) throw new Error("Set SURREAL_PASS in .env.");
if (![namespace, database].every(value => /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(value))) {
  throw new Error("SURREAL_NAMESPACE and SURREAL_DATABASE must be simple identifiers.");
}
if (host !== "127.0.0.1" && host !== "localhost") {
  throw new Error("The local starter supports SURREAL_HOST=127.0.0.1 or localhost.");
}
if (![dbPort, webPort].every(port => Number.isInteger(port) && port > 0 && port < 65536)) {
  throw new Error("SURREAL_PORT and FRONTEND_PORT must be valid ports.");
}

function command(executable, args, options = {}) {
  const result = spawnSync(executable, args, { cwd: root, encoding: "utf8", ...options });
  if (result.error || result.status !== 0) {
    throw new Error(`${executable} ${args[0]} failed: ${result.error?.message || result.stderr?.trim() || result.stdout?.trim()}`);
  }
  return result.stdout?.trim() || "";
}

async function ensureSurrealBinary() {
  const local = path.join(binaryDir, "surreal");
  if (fs.existsSync(local)) surreal = local;
  let check = spawnSync(surreal, ["version"], { encoding: "utf8" });
  if (check.error?.code === "ENOENT") {
    if (process.platform === "win32") throw new Error("Install SurrealDB 3.2.0, then run npm run dev again.");
    fs.mkdirSync(binaryDir, { recursive: true });
    console.log("Installing SurrealDB 3.2.0 into .tools/ ...");
    const response = await fetch("https://install.surrealdb.com");
    if (!response.ok) throw new Error(`Could not download the SurrealDB installer (${response.status}).`);
    const installer = path.join(binaryDir, "install.sh");
    fs.writeFileSync(installer, await response.text(), { mode: 0o700 });
    command("sh", [installer, "-v", "3.2.0", binaryDir], { cwd: binaryDir, stdio: "inherit" });
    surreal = local;
    check = spawnSync(surreal, ["version"], { encoding: "utf8" });
  }
  if (check.error || check.status !== 0 || !/^3\.2\./.test(check.stdout.trim())) {
    throw new Error("StockSense requires the SurrealDB 3.2 CLI. Install 3.2.x or remove an incompatible surreal from PATH.");
  }
}

const base = `http://${host}:${dbPort}`;
async function healthy() {
  try { return (await fetch(`${base}/health`, { signal: AbortSignal.timeout(800) })).ok; }
  catch { return false; }
}

async function sql(statement, { ns, db } = {}) {
  const headers = {
    "Content-Type": "text/plain",
    "Accept": "application/json",
    "Authorization": `Basic ${Buffer.from(`${user}:${password}`).toString("base64")}`,
  };
  if (ns) headers["surreal-ns"] = ns;
  if (db) headers["surreal-db"] = db;
  const response = await fetch(`${base}/sql`, { method: "POST", headers, body: statement });
  if (!response.ok) throw new Error(`SurrealDB rejected the configured root credentials or query (HTTP ${response.status}).`);
  const results = await response.json();
  const failed = results.find(item => item.status !== "OK");
  if (failed) throw new Error(`SurrealDB query failed: ${failed.result}`);
  return results.at(-1)?.result;
}

async function startDatabase() {
  if (await healthy()) {
    console.log(`Using SurrealDB already running at ${base}`);
    return;
  }
  fs.mkdirSync(path.join(root, ".data"), { recursive: true });
  databaseProcess = spawn(surreal, ["start", "--bind", `${host}:${dbPort}`,
    "--allow-net", "api.brevo.com:443", `surrealkv://${path.join(root, ".data", "stocksense.db")}`], {
    cwd: root, env: { ...process.env, SURREAL_USER: user, SURREAL_PASS: password },
    stdio: ["ignore", "ignore", "pipe"],
  });
  let failure = "";
  databaseProcess.stderr.on("data", chunk => { failure = (failure + chunk).slice(-1200); });
  for (let attempt = 0; attempt < 80; attempt++) {
    if (await healthy()) { console.log(`Started SurrealDB at ${base}`); return; }
    if (databaseProcess.exitCode !== null) break;
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error(`SurrealDB did not start. ${failure.trim()}`);
}

async function installSchema() {
  await sql(`DEFINE NAMESPACE IF NOT EXISTS ${namespace};`);
  await sql(`DEFINE DATABASE IF NOT EXISTS ${database};`, { ns: namespace });
  let version;
  try {
    version = (await sql("SELECT VALUE version FROM stocksense_schema_version:current;",
      { ns: namespace, db: database }))?.[0];
  } catch { /* No marker table on a new database. */ }
  if (version !== "1.0.0") {
    if (version) throw new Error(`Database has schema version ${version}; no automatic upgrade is defined.`);
    command(process.execPath, ["scripts/bundle-migrations.mjs"]);
    command(surreal, ["validate", "backend/stocksense-install.surql"]);
    console.log("Installing StockSense migrations ...");
    command(surreal, ["import", "--endpoint", base, "--namespace", namespace,
      "--database", database, "backend/stocksense-install.surql"], {
      env: { ...process.env, SURREAL_USER: user, SURREAL_PASS: password },
    });
    const installed = (await sql("SELECT VALUE version FROM stocksense_schema_version:current;",
      { ns: namespace, db: database }))?.[0];
    if (installed !== "1.0.0") throw new Error("Migration import finished without an installation marker.");
    console.log("StockSense schema installed.");
  } else {
    console.log("StockSense schema already installed.");
  }
  if (apiKey) {
    if (sender !== "divy.r.vora14@gmail.com") {
      throw new Error("This Brevo integration is configured for divy.r.vora14@gmail.com only.");
    }
    await sql(`UPSERT stocksense_email_delivery_config:stocksense SET api_key = ${JSON.stringify(apiKey)}, from_email = ${JSON.stringify(sender)}, from_name = 'StockSense';`,
      { ns: namespace, db: database });
    console.log("Brevo email configured.");
  } else {
    console.log("BREVO_API_KEY is empty. Add it to .env for email verification and password reset.");
  }
  fs.writeFileSync(path.join(root, "frontend/runtime.json"),
    JSON.stringify({ url: `ws://${host}:${dbPort}/rpc`, namespace, database }, null, 2) + "\n");
}

const mime = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".json": "application/json", ".svg": "image/svg+xml" };
function serveFrontend() {
  const directory = path.join(root, "frontend");
  let servePort = webPort;
  webServer = http.createServer((request, response) => {
    let pathname;
    try { pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname); }
    catch { response.writeHead(400).end(); return; }
    const target = path.resolve(directory, `.${pathname === "/" ? "/index.html" : pathname}`);
    if (!target.startsWith(directory + path.sep)) { response.writeHead(403).end(); return; }
    fs.readFile(target, (error, contents) => {
      if (error) { response.writeHead(error.code === "ENOENT" ? 404 : 500).end(); return; }
      response.writeHead(200, { "Content-Type": mime[path.extname(target)] || "application/octet-stream" });
      response.end(contents);
    });
  });
  webServer.on("error", error => {
    if (error.code === "EADDRINUSE" && servePort < webPort + 20) {
      servePort++;
      webServer.listen(servePort, "127.0.0.1");
      return;
    }
    console.error(`Frontend could not start: ${error.message}`);
    shutdown(1);
  });
  webServer.on("listening", () => console.log(`StockSense ready: http://127.0.0.1:${servePort}`));
  webServer.listen(servePort, "127.0.0.1");
}

function shutdown(code = 0) {
  webServer?.close();
  if (databaseProcess?.exitCode === null) databaseProcess.kill("SIGTERM");
  process.exitCode = code;
}
process.on("SIGINT", () => shutdown());
process.on("SIGTERM", () => shutdown());

try {
  await ensureSurrealBinary();
  await startDatabase();
  await installSchema();
  if (process.argv.includes("--install-only")) shutdown();
  else serveFrontend();
} catch (error) {
  console.error(error.message);
  shutdown(1);
}
