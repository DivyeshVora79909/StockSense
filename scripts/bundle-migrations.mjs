import fs from "node:fs";
import path from "node:path";

const directory = path.resolve("backend/migrations");
const files = fs.readdirSync(directory).filter(name => /^\d{4}-.+\.surql$/.test(name)).sort();
if (!files.length || files.some((name, index) => Number(name.slice(0, 4)) !== index + 1)) {
  throw new Error("Migrations must be numbered consecutively from 0001.");
}

const output = path.resolve("backend/stocksense-install.surql");
const sql = "OPTION IMPORT;\n" + files.map(name => fs.readFileSync(path.join(directory, name), "utf8")).join("");
fs.writeFileSync(output, sql);
console.log(`Combined ${files.length} migrations into ${path.relative(process.cwd(), output)}`);
