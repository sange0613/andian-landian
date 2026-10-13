const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "build/icon.ico"));
if (source.readUInt16LE(0) !== 0 || source.readUInt16LE(2) !== 1) throw new Error("Invalid ICO file");
const entries = [];
for (let i = 0; i < source.readUInt16LE(4); i++) {
  const entry = Buffer.from(source.subarray(6 + i * 16, 22 + i * 16));
  const width = entry[0] || 256;
  if (width <= 64) {
    const start = entry.readUInt32LE(12);
    const length = entry.readUInt32LE(8);
    entries.push({ entry, pixels: source.subarray(start, start + length) });
  }
}
if (!entries.length) {
  // The existing icon generator stores only 256px. Use its blue-circle design
  // at native tray/shortcut sizes instead of shipping that large uncompressed DIB.
  for (const size of [16, 32, 48, 64]) {
    const maskStride = Math.ceil(size / 32) * 4;
    const pixels = Buffer.alloc(40 + size * size * 4 + maskStride * size);
    pixels.writeUInt32LE(40, 0);
    pixels.writeInt32LE(size, 4);
    pixels.writeInt32LE(size * 2, 8);
    pixels.writeUInt16LE(1, 12);
    pixels.writeUInt16LE(32, 14);
    const center = (size - 1) / 2;
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const alpha = Math.round(255 * Math.max(0, Math.min(1, size * 0.39 + 0.5 - Math.hypot(x - center, y - center))));
        const pixel = 40 + (y * size + x) * 4;
        pixels[pixel] = 0xa7;
        pixels[pixel + 1] = 0x2f;
        pixels[pixel + 3] = alpha;
        if (!alpha) pixels[40 + size * size * 4 + y * maskStride + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
    const entry = Buffer.alloc(16);
    entry[0] = entry[1] = size;
    entry.writeUInt16LE(1, 4);
    entry.writeUInt16LE(32, 6);
    entry.writeUInt32LE(pixels.length, 8);
    entries.push({ entry, pixels });
  }
}
const header = Buffer.alloc(6 + entries.length * 16);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(entries.length, 4);
let offset = header.length;
for (const [i, item] of entries.entries()) {
  item.entry.writeUInt32LE(offset, 12);
  item.entry.copy(header, 6 + i * 16);
  offset += item.pixels.length;
}
const output = path.join(root, "dist/native-win");
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, "icon-small.ico"), Buffer.concat([header, ...entries.map(item => item.pixels)]));
console.log(`Embedded icon: ${offset} bytes (${entries.length} sizes)`);
