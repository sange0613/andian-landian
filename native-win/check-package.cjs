const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const output = path.resolve(__dirname, "../dist/native-win");
const app = path.join(output, "DimBlueDot.exe");
const installer = path.join(output, "DimBlueDot-1.1.0-Win10-x64-Setup.exe");
const limits = [[app, 5 * 1024 * 1024], [installer, 2 * 1024 * 1024]];
const data = fs.readFileSync(app);
if (data.readUInt16LE(0) !== 0x5a4d) throw new Error("Not a Windows executable");
const pe = data.readUInt32LE(0x3c);
if (data.readUInt32LE(pe) !== 0x4550 || data.readUInt16LE(pe + 4) !== 0x8664) throw new Error("Expected Windows x64 PE");
const sections = data.readUInt16LE(pe + 6);
const optionalSize = data.readUInt16LE(pe + 20);
const opt = pe + 24;
if (data.readUInt16LE(opt) !== 0x20b) throw new Error("Expected PE32+");
if (data.readUInt16LE(opt + 68) !== 2) throw new Error("Expected GUI subsystem");
function offsetOf(rva) {
  for (let i = 0; i < sections; i++) {
    const section = opt + optionalSize + i * 40;
    const start = data.readUInt32LE(section + 12);
    const length = Math.max(data.readUInt32LE(section + 8), data.readUInt32LE(section + 16));
    if (rva >= start && rva < start + length) return data.readUInt32LE(section + 20) + rva - start;
  }
  throw new Error(`Cannot map RVA ${rva}`);
}
const imports = [];
let descriptor = offsetOf(data.readUInt32LE(opt + 120));
while (data.readUInt32LE(descriptor + 12)) {
  const name = offsetOf(data.readUInt32LE(descriptor + 12));
  const dll = data.subarray(name, data.indexOf(0, name)).toString("ascii").toLowerCase();
  if (!/^(kernel32|user32|gdi32|gdiplus|shell32|advapi32|msvcrt|ole32|oleaut32|comdlg32|comctl32|ucrtbase)\.dll$/.test(dll) && !dll.startsWith("api-ms-win-"))
    throw new Error(`Unexpected external runtime: ${dll}`);
  imports.push(dll);
  descriptor += 20;
}
const artifacts = limits.map(([file, limit]) => {
  const bytes = fs.statSync(file).size;
  if (bytes > limit) throw new Error(`${file} exceeds size limit`);
  return { file: path.basename(file), bytes, sha256: crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex") };
});
const report = { version: "1.1.0", platform: "Windows 10 x64", imports, artifacts };
fs.writeFileSync(path.join(output, "build-report.json"), JSON.stringify(report, null, 2) + "\n");
console.log(JSON.stringify(report, null, 2));
