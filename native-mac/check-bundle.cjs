const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { execFileSync } = require("node:child_process");
const [app, verify, dmg, packagedApp, pkg, expandedPkg] = process.argv.slice(2);
const binary = path.join(app, "Contents/MacOS/DimBlueDotMac");
function bytesIn(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).reduce((total, item) => {
    const file = path.join(directory, item.name);
    return total + (item.isDirectory() ? bytesIn(file) : fs.statSync(file).size);
  }, 0);
}
const bytes = bytesIn(app);
if (bytes > 1024 * 1024) throw Error(`App exceeds 1MB budget: ${bytes}`);
const architectures = execFileSync("lipo", ["-archs", binary], { encoding: "utf8" }).trim();
if (!architectures.includes("arm64") || !architectures.includes("x86_64")) throw Error("Expected universal Mac executable");
const dependencies = [...new Set(["arm64", "x86_64"].flatMap(arch =>
  execFileSync("otool", ["-arch", arch, "-L", binary], { encoding: "utf8" }).split("\n").slice(1).map(line => line.trim().split(" (", 1)[0]).filter(Boolean)
))];
if (dependencies.some(file => !file.startsWith("/System/Library/") && !file.startsWith("/usr/lib/"))) throw Error("External runtime dependency");
const ui = JSON.parse(fs.readFileSync(path.join(verify, "ui-test-report.json"), "utf8"));
if (ui.result !== "PASS" || ui.author !== "戌無营造") throw Error("UI verification failed");
const version = execFileSync("plutil", ["-extract", "CFBundleShortVersionString", "raw", path.join(app, "Contents/Info.plist")], { encoding: "utf8" }).trim();
const report = { version, language: "zh-CN", author: "戌無营造", minimumMacOS: "12.0", architectures, appBytes: bytes, dependencies, ui, signing: "ad-hoc", notarized: false, verificationDirectory: verify };
if (dmg) {
  report.dmgBytes = fs.statSync(dmg).size;
  if (report.dmgBytes > 2 * 1024 * 1024) throw Error("DMG exceeds 2MB budget");
  report.dmgSHA256 = crypto.createHash("sha256").update(fs.readFileSync(dmg)).digest("hex");
}
function manifest(directory, relative = "") {
    return fs.readdirSync(path.join(directory, relative), { withFileTypes: true }).flatMap(item => {
      const name = path.join(relative, item.name);
      return item.isDirectory() ? manifest(directory, name) : [[name, crypto.createHash("sha256").update(fs.readFileSync(path.join(directory, name))).digest("hex")]];
    }).sort((a, b) => a[0].localeCompare(b[0]));
}
if (packagedApp) {
  if (JSON.stringify(manifest(app)) !== JSON.stringify(manifest(packagedApp))) throw Error("Packaged app differs from validated app");
  report.packagedContentsVerified = true;
}
if (pkg) {
  const metadata = path.join(expandedPkg, "PackageInfo");
  const query = expression => execFileSync("xmllint", ["--xpath", expression, metadata], { encoding: "utf8" }).trim();
  if (query("string(/pkg-info/@install-location)") !== "/Applications") throw Error("Installer must target /Applications");
  if (query("string(/pkg-info/@version)") !== version) throw Error("Installer version mismatch");
  if (query("string(/pkg-info/@relocatable)") !== "false" || query("count(/pkg-info/relocate/*)") !== "0") throw Error("Installer must not relocate to an existing build folder");
  if (query("count(/pkg-info/scripts)") !== "0") throw Error("Unexpected installer scripts");
  const payload = path.join(expandedPkg, "Payload");
  const items = fs.readdirSync(payload).filter(name => name !== ".DS_Store");
  if (items.length !== 1 || items[0] !== path.basename(app)) throw Error("Installer contains unexpected payload");
  if (JSON.stringify(manifest(app)) !== JSON.stringify(manifest(path.join(payload, path.basename(app))))) throw Error("Installer app differs from validated app");
  report.pkgBytes = fs.statSync(pkg).size;
  if (report.pkgBytes > 2 * 1024 * 1024) throw Error("PKG exceeds 2MB budget");
  report.pkgSHA256 = crypto.createHash("sha256").update(fs.readFileSync(pkg)).digest("hex");
  report.pkgContentsVerified = true;
  report.installLocation = "/Applications";
  report.pkgSigned = false;
}
fs.writeFileSync(path.join(path.dirname(app), "build-report.json"), JSON.stringify(report, null, 2) + "\n");
console.log(JSON.stringify(report, null, 2));
