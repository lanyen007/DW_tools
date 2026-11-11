import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { once } from "node:events";
import { fileURLToPath } from "node:url";
import path from "node:path";
import worker, { decide, isPowerShellUserAgent } from "../src/index.js";
import { CATALOG_SOURCES, buildCatalog, isGithubFileUrl, parseToolsScript, sizeFromHeaders } from "../src/catalog.js";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const psUa = "Mozilla/5.0 (Windows NT; Windows NT 10.0; zh-TW) WindowsPowerShell/5.1.22621.2506";
const ps7Ua = "Mozilla/5.0 (Windows NT 10.0; Microsoft Windows 10.0.22621; zh-TW) PowerShell/7.4.6";
const browserUa = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36";

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

function checkDecisions() {
  assert(isPowerShellUserAgent(psUa), "Windows PowerShell 5.1 UA");
  assert(isPowerShellUserAgent(ps7Ua), "PowerShell 7 UA");
  assert(!isPowerShellUserAgent(browserUa), "browser UA");
  assert(!isPowerShellUserAgent(""), "empty UA");

  assert(decide("/", psUa).file === "menu.ps1", "/ powershell -> menu");
  assert(decide("/", browserUa).action === "page", "/ browser -> page");
  assert(decide("/index.html", psUa).file === "menu.ps1", "index.html powershell -> menu");
  assert(decide("/index.html", browserUa).action === "page", "index.html browser -> page");
  assert(decide("/downloads.json", psUa).action === "catalog", "downloads.json is not the menu");
  assert(decide("/downloads.json", browserUa).action === "catalog", "downloads.json for browsers");
  assert(decide("/ricoh", browserUa).file === "ricoh", "ricoh is a script for every UA");
  assert(decide("/scan/", psUa).file === "scan", "trailing slash");
  assert(decide("/pc", psUa).base === "flgpqt" && decide("/pc", psUa).file === "drivers/pc.ps1", "pc stays on FLGPQT");
  assert(decide("/fuji", browserUa).file === "drivers/cloud-fuji.ps1", "fuji alias");
  assert(decide("/map.html", browserUa).action === "origin", "site pages stay on the origin");
  assert(
    decide("/drivers/ricoh-user-code-prompt.ps1", psUa).file === "drivers/ricoh-user-code-prompt.ps1",
    "prompt script",
  );
}

function startFileServer(port) {
  return spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1"], {
    cwd: repoRoot,
    stdio: ["ignore", "ignore", "pipe"],
  });
}

function startRouter(port, scriptBase) {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url.startsWith(`http://127.0.0.1:${port}/`)) {
      return new Response("<!doctype html><title>lanyen.de</title><p>browser</p>", {
        status: 200,
        headers: { "content-type": "text/html; charset=utf-8" },
      });
    }
    return realFetch(input, init);
  };
  const server = createServer(async (req, res) => {
    const request = new Request(`http://127.0.0.1:${port}${req.url}`, {
      method: req.method,
      headers: req.headers,
    });
    const response = await worker.fetch(request, {
      SCRIPT_BASE: scriptBase,
      FLGPQT_BASE: "https://lanyen007.github.io/FLGPQT",
    });
    const body = Buffer.from(await response.arrayBuffer());
    const headers = {};
    response.headers.forEach((value, key) => {
      headers[key] = value;
    });
    res.writeHead(response.status, headers);
    res.end(body);
  });
  server.listen(port, "127.0.0.1");
  return { server, restore: () => { globalThis.fetch = realFetch; } };
}

function curl(args) {
  return new Promise((resolve, reject) => {
    const child = spawn("curl", ["-sS", ...args], { stdio: ["ignore", "pipe", "pipe"] });
    const out = [];
    const err = [];
    child.stdout.on("data", (chunk) => out.push(chunk));
    child.stderr.on("data", (chunk) => err.push(chunk));
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(Buffer.concat(err).toString() || `curl ${code}`));
      else resolve(Buffer.concat(out));
    });
  });
}

function parsePs(file) {
  return new Promise((resolve, reject) => {
    const command = `
      $errs = $null; $toks = $null
      [void][System.Management.Automation.Language.Parser]::ParseFile(${JSON.stringify(file)}, [ref]$toks, [ref]$errs)
      if (@($errs).Count -gt 0) { $errs | ForEach-Object { Write-Output $_.Message }; exit 1 }
      Write-Output 'parse-ok'
    `;
    const child = spawn("pwsh", ["-NoLogo", "-Command", command], { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let err = "";
    child.on("error", (error) => reject(error));
    child.stdout.on("data", (chunk) => { out += chunk; });
    child.stderr.on("data", (chunk) => { err += chunk; });
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(out + err));
      else resolve(out.trim());
    });
  });
}

async function waitFor(url) {
  for (let i = 0; i < 40; i++) {
    try {
      const response = await fetch(url);
      if (response.ok || response.status === 404) return;
    } catch {
      // server still starting
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`timed out waiting for ${url}`);
}

function checkCatalogShape() {
  assert(sizeFromHeaders(new Headers({ "content-length": "197120" })) === 197120, "content-length");
  assert(sizeFromHeaders(new Headers({
    "content-length": "1",
    "content-range": "bytes 0-0/50688",
  })) === 50688, "content-range wins over a one-byte length");
  assert(sizeFromHeaders(new Headers()) === null, "missing length");
  assert(isGithubFileUrl("https://github.com/lanyen007/DW_tools/raw/main/PQT.exe"), "github raw alias");
  assert(isGithubFileUrl("https://raw.githubusercontent.com/lanyen007/DW_tools/cursor/ricoh-mp-c3300-c4500-0e0c/drivers/ricoh/RICOH_MPC_3300_X32_RPCS.exe"), "branch raw url");
  assert(!isGithubFileUrl("https://www.mediafire.com/file/abc/x.exe/file"), "mediafire excluded");
  assert(!isGithubFileUrl("https://support.ricoh.com/bb/pub_e/x.exe"), "vendor site excluded");
  assert(!isGithubFileUrl("https://github.com/lanyen007/FLGPQT/tree/main/drivers/packages/fuji-old"), "tree page excluded");
  const tools = parseToolsScript(`
    $ReleaseTag = 'tools-mediafire-20261101'
    @{
        Key = 'desk'
        File = 'sharpdesk3.3.exe'
        Title = 'Sharpdesk 3.3'
        Size = 12L
        Note = '約 587 MB'
    }
  `);
  assert(tools.length === 1 && tools[0].version === "3.3", "tool version from title");
  assert(tools[0].url.endsWith("/tools-mediafire-20261101/sharpdesk3.3.exe"), "tool release url");

  const catalog = buildCatalog({
    pqtVersion: { version: "4.1.22", url: "https://github.com/lanyen007/DW_tools/raw/main/PQT.exe" },
    counterVersion: { version: "1.0.1", url: "https://github.com/lanyen007/DW_tools/raw/main/UserCounterDownload.exe" },
    cloud: { drivers: [
      { title: "Ricoh PCL6", brand: "Ricoh", version: "4.46.0.0", filename: "RICOH.zip", size: 10, url: "https://github.com/lanyen007/FLGPQT/releases/download/drivers-ricoh-upd-pcl6-4.46.0.0/RICOH.zip" },
      { title: "MediaFire driver", url: "https://www.mediafire.com/file/abc/x.exe/file" },
    ] },
    fujiOld: { drivers: [
      { title: "IV · 2.6.13.1 · a.exe", filename: "a.exe", url: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/packages/fuji-old/a.exe" },
      { title: "DocuPrint shares a.exe", filename: "a.exe", url: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/packages/fuji-old/a.exe" },
    ] },
    ricoh: { brand: "Ricoh", drivers: [
      { id: "ricoh-37", model: "MP C3300", title: "MP C3300 · RPCS · Win32", filename: "RICOH_MPC_3300_X32_RPCS.exe", url: "https://raw.githubusercontent.com/lanyen007/DW_tools/cursor/ricoh-mp-c3300-c4500-0e0c/drivers/ricoh/RICOH_MPC_3300_X32_RPCS.exe" },
      { title: "official", url: "https://support.ricoh.com/bb/x.exe" },
    ] },
    fuji: { drivers: [
      { title: "duplicate of fuji-old", filename: "a.exe", url: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/packages/fuji-old/a.exe" },
    ] },
    sharp: { brand: "Sharp", drivers: [
      { model: "MX-1", title: "MX-1", filename: "same.exe", notes: "PCL6 01.01.00.06", url: "https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-missing-20261102/same.exe" },
      { model: "MX-2", title: "MX-2", filename: "same.exe", notes: "PCL6 01.01.00.06", url: "https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-missing-20261102/same.exe" },
    ] },
    toolsText: "$ReleaseTag = 'tools-mediafire-20261101'\n@{ Key = 'desk'\n File = 'sharpdesk3.3.exe'\n Title = 'Sharpdesk 3.3'\n Size = 12L\n Note = 'desk' }",
  });
  const byId = Object.fromEntries(catalog.sections.map((section) => [section.id, section]));
  assert(byId.toolbox.items.map((item) => item.filename).join() === "PQT.exe,UserCounterDownload.exe", "toolbox files");
  assert(byId.toolbox.items[0].version === "4.1.22", "pqt version");
  assert(byId.cloud.items.length === 1 && byId.cloud.items[0].version === "4.46.0.0", "cloud keeps github zip only");
  assert(byId["fuji-old"].items.length === 2, "fuji-old keeps both catalog rows");
  assert(byId["fuji-old"].items[0].version === "2.6.13.1", "version guessed from title");
  assert(byId["common-tools"].items[0].brand === "Sharp", "sharpdesk brand");
  assert(byId["github-models"].items.length === 2, "ricoh raw plus one sharp file");
  assert(byId["github-models"].items.some((item) => item.filename === "RICOH_MPC_3300_X32_RPCS.exe"), "ricoh-37 file");
  const sharp = byId["github-models"].items.find((item) => item.filename === "same.exe");
  assert(sharp.models.join() === "MX-1,MX-2" && sharp.version === "01.01.00.06", "sharp models grouped");
  const hosts = catalog.sections.flatMap((section) => section.items.map((item) => new URL(item.url).hostname));
  assert(hosts.every((host) => host === "github.com" || host === "raw.githubusercontent.com"), `off-github host ${hosts.join(" ")}`);
}

async function checkRoutesWithFixtures() {
  const realFetch = globalThis.fetch;
  const sources = {
    [CATALOG_SOURCES.pqtVersion]: JSON.stringify({ version: "4.1.22", url: "https://github.com/lanyen007/DW_tools/raw/main/PQT.exe" }),
    [CATALOG_SOURCES.counterVersion]: JSON.stringify({ version: "1.0.1", url: "https://github.com/lanyen007/DW_tools/raw/main/UserCounterDownload.exe" }),
    [CATALOG_SOURCES.cloud]: JSON.stringify({ drivers: [] }),
    [CATALOG_SOURCES.fujiOld]: JSON.stringify({ drivers: [] }),
    [CATALOG_SOURCES.ricoh]: JSON.stringify({ drivers: [] }),
    [CATALOG_SOURCES.fuji]: JSON.stringify({ drivers: [] }),
    [CATALOG_SOURCES.sharp]: JSON.stringify({ drivers: [] }),
    [CATALOG_SOURCES.toolsText]: "# no tools in this fixture\n",
  };
  let apiCalls = 0;
  globalThis.fetch = async (input, init) => {
    const url = input instanceof Request ? input.url : String(input);
    const method = ((init && init.method) || (input instanceof Request ? input.method : "GET")).toUpperCase();
    if (url.includes("api.github.com")) {
      apiCalls += 1;
      return new Response("forbidden", { status: 403 });
    }
    if (method === "HEAD" && url.endsWith("/PQT.exe")) {
      return new Response(null, { status: 200, headers: { "content-length": "197120" } });
    }
    if (method === "HEAD" && url.endsWith("/UserCounterDownload.exe")) {
      return new Response(null, { status: 200 });
    }
    if (method === "GET" && url.endsWith("/UserCounterDownload.exe")) {
      return new Response("x", {
        status: 206,
        headers: { "content-length": "1", "content-range": "bytes 0-0/50688" },
      });
    }
    if (sources[url]) return new Response(sources[url], { status: 200 });
    if (url.includes("menu.ps1")) return new Response("try { menu }\n", { status: 200 });
    return new Response(`missing ${url}`, { status: 404 });
  };
  try {
    const page = await worker.fetch(new Request("https://lanyen.de/", { headers: { "user-agent": browserUa } }));
    const html = await page.text();
    assert(page.headers.get("content-type").includes("text/html"), "page content-type");
    assert(html.includes('data-t="t-dl"'), "download tab");
    assert(html.includes("下載"), "download label");
    assert(html.includes("irm lanyen.de | iex"), "install command stays");
    assert(!html.includes("Get-FlgUiIsZh"), "page is not the menu script");

    const menu = await worker.fetch(new Request("https://lanyen.de/", { headers: { "user-agent": psUa } }));
    const menuBody = await menu.text();
    assert(menu.headers.get("content-type").includes("text/plain"), "powershell content-type");
    assert(menuBody.startsWith("try "), "powershell body is the menu");
    assert(!menuBody.includes("t-dl"), "powershell body has no download tab");

    const catalogResponse = await worker.fetch(new Request("https://lanyen.de/downloads.json", {
      headers: { "user-agent": psUa },
    }));
    const catalog = await catalogResponse.json();
    assert(catalogResponse.status === 200, "catalog status");
    const toolbox = catalog.sections.find((section) => section.id === "toolbox");
    assert(toolbox.items[0].size === 197120, "pqt size from content-length");
    assert(toolbox.items[1].size === 50688, "counter size from content-range");
    assert(toolbox.items[1].filename === "UserCounterDownload.exe", "ascii counter filename");
    assert(toolbox.items[1].version === "1.0.1", "counter version");
    assert(apiCalls === 0, "catalog does not call the GitHub API");
    assert(catalog.warnings.length === 0, `catalog warnings ${catalog.warnings.join("; ")}`);
  } finally {
    globalThis.fetch = realFetch;
  }
}

async function main() {
  checkDecisions();
  checkCatalogShape();
  await checkRoutesWithFixtures();
  const filePort = 8765;
  const routerPort = 8766;
  const files = startFileServer(filePort);
  let router;
  try {
    await waitFor(`http://127.0.0.1:${filePort}/lanyen/menu.ps1`);
    router = startRouter(routerPort, `http://127.0.0.1:${filePort}/lanyen`);
    await once(router.server, "listening");

    const browser = await curl([
      "-D", "-",
      "-o", "/tmp/lanyen-browser.body",
      "-A", browserUa,
      `http://127.0.0.1:${routerPort}/`,
    ]);
    const powershell = await curl([
      "-D", "-",
      "-o", "/tmp/lanyen-ps.body",
      "-A", psUa,
      `http://127.0.0.1:${routerPort}/`,
    ]);
    const ricoh = await curl(["-A", browserUa, `http://127.0.0.1:${routerPort}/ricoh`]);
    const pc = await curl(["-A", psUa, `http://127.0.0.1:${routerPort}/pc`]);

    const browserBody = await import("node:fs").then((fs) => fs.readFileSync("/tmp/lanyen-browser.body"));
    const psBody = await import("node:fs").then((fs) => fs.readFileSync("/tmp/lanyen-ps.body"));
    assert(browserBody.includes("<!doctype html>"), "browser body is HTML");
    assert(browserBody.includes('data-t="t-dl"'), "served page has the download tab");
    assert(!browserBody.includes("Get-FlgUiIsZh"), "browser body is not the menu script");
    assert(psBody.subarray(0, 4).toString() === "try ", "powershell body is the menu");
    assert(!psBody.includes("<!doctype"), "powershell body has no HTML");
    assert(String(browser).includes("content-type: text/html"), "browser content-type");
    assert(String(powershell).includes("content-type: text/plain"), "powershell content-type");
    assert(ricoh.includes("cloud-install-main.ps1"), "ricoh still loads FLGPQT");
    assert(ricoh.includes("github.io/DW_tools/lanyen/drivers/ricoh-user-code-prompt.ps1"), "ricoh prompt moved");
    assert(!ricoh.includes("lanyen.de/"), "ricoh has no lanyen.de download");
    assert(pc.includes("pc-main.ps1"), "pc alias reaches FLGPQT");
    const map = await curl(["-A", browserUa, `http://127.0.0.1:${routerPort}/map.html`]);
    assert(map.includes("<p>browser</p>"), "map.html still passes through to the origin");

    const parsed = await parsePs("/tmp/lanyen-ps.body");
    console.log("browser headers:\n" + browser);
    console.log("powershell headers:\n" + powershell);
    console.log("served menu:", parsed);
    console.log("check-ok");
  } finally {
    if (router) {
      router.restore();
      router.server.close();
    }
    files.kill("SIGTERM");
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
