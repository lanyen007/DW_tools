// Fetches the live catalogs and checks every GitHub download URL with curl.
// Not part of `npm test` (that suite stays offline).

import { spawn } from "node:child_process";
import { loadCatalog } from "../src/load-catalog.js";

const MAIN_COPIES = [
  ["https://raw.githubusercontent.com/lanyen007/DW_tools/main/drivers/ricoh/RICOH_MPC_3300_X32_RPCS.exe", 5102224],
  ["https://raw.githubusercontent.com/lanyen007/DW_tools/main/drivers/ricoh/RICOH_MP_C4500PCL6.exe", 5872787],
];

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

function curl(args) {
  return new Promise((resolve) => {
    const child = spawn("curl", args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let err = "";
    child.stdout.on("data", (chunk) => { out += chunk; });
    child.stderr.on("data", (chunk) => { err += chunk; });
    child.on("close", (code) => resolve({ code, out, err }));
  });
}

function finalStatus(headerText) {
  const codes = [...headerText.matchAll(/^HTTP\/\d(?:\.\d)?\s+(\d+)/gm)].map((match) => Number(match[1]));
  return codes.length ? codes[codes.length - 1] : 0;
}

async function checkUrl(url) {
  const head = await curl([
    "-sS", "-I", "-L", "--max-time", "45",
    "-A", "lanyen-de-link-check",
    "-D", "-", "-o", "/dev/null",
    url,
  ]);
  const status = finalStatus(head.out);
  return {
    ok: head.code === 0 && status === 200,
    status,
    via: "head",
    detail: head.err.trim(),
  };
}

function section(catalog, id) {
  return catalog.sections.find((item) => item.id === id) || { items: [] };
}

async function main() {
  const catalog = await loadCatalog(fetch);
  console.log(`generated ${catalog.generatedAt} count=${catalog.count} warnings=${catalog.warnings.length}`);
  for (const warning of catalog.warnings) console.log("warning:", warning);

  const toolbox = section(catalog, "toolbox");
  const cloud = section(catalog, "cloud");
  const fujiOld = section(catalog, "fuji-old");
  const tools = section(catalog, "common-tools");
  const models = section(catalog, "github-models");
  assert(toolbox.items.map((item) => item.filename).join() === "PQT.exe,UserCounterDownload.exe", "toolbox files");
  assert(toolbox.items.every((item) => item.version), "toolbox versions");
  assert(cloud.items.length === 5, `cloud count ${cloud.items.length}`);
  assert(fujiOld.items.length === 22, `fuji-old count ${fujiOld.items.length}`);
  assert(tools.items.length === 6, `tools count ${tools.items.length}`);
  assert(models.items.some((item) => item.filename === "RICOH_MPC_3300_X32_RPCS.exe"), "ricoh-37");
  assert(models.items.some((item) => item.filename === "RICOH_MP_C4500PCL6.exe"), "ricoh-45");
  const allowedHosts = new Set(["github.com", "raw.githubusercontent.com"]);
  for (const group of catalog.sections) {
    for (const item of group.items) {
      assert(item.name && item.brand, `missing name/brand ${item.url}`);
      assert("version" in item, "version field");
      assert(typeof item.size === "number" && item.size > 0, `missing size ${item.filename}`);
      const host = new URL(item.url).hostname;
      assert(allowedHosts.has(host), `blocked host ${host} ${item.url}`);
    }
  }

  const urls = [...new Set(catalog.sections.flatMap((group) => group.items.map((item) => item.url)))];
  for (const [url] of MAIN_COPIES) urls.push(url);
  console.log(`checking ${urls.length} urls`);
  const failures = [];
  for (const url of urls) {
    const result = await checkUrl(url);
    const label = `${result.ok ? "ok" : "FAIL"} ${result.status} ${result.via} ${url}`;
    console.log(label);
    if (!result.ok) failures.push(`${label} ${result.detail || ""}`);
  }
  if (failures.length) {
    console.error(failures.join("\n"));
    process.exit(1);
  }
  console.log("live-links-ok");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
