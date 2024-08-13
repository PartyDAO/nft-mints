import fs from "fs";

const filePath = process.argv[2];
const jsonString = fs.readFileSync(filePath, "utf8");
try {
  JSON.parse(jsonString.substring(27));
} catch {
  // Invalid json
  process.stdout.write("0x0000000000000000000000000000000000000000000000000000000000000002");
  process.exit();
}

process.stdout.write("0x0000000000000000000000000000000000000000000000000000000000000001");
process.exit();