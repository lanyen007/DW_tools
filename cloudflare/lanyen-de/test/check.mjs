import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { once } from "node:events";
import { fileURLToPath } from "node:url";
import path from "node:path";
import worker, { decide, isPowerShellUserAgent } from "../src/index.js";

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
  assert(decide("/", browserUa).action === "origin", "/ browser -> origin");
  assert(decide("/index.html", psUa).file === "menu.ps1", "index.html powershell -> menu");
  assert(decide("/index.html", browserUa).action === "origin", "index.html browser -> origin");
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

async function main() {
  checkDecisions();
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
    assert(!browserBody.includes("Get-FlgUiIsZh"), "browser body is not the menu script");
    assert(psBody.subarray(0, 4).toString() === "try ", "powershell body is the menu");
    assert(!psBody.includes("<!doctype"), "powershell body has no HTML");
    assert(String(browser).includes("content-type: text/html"), "browser content-type");
    assert(String(powershell).includes("content-type: text/plain"), "powershell content-type");
    assert(ricoh.includes("cloud-install-main.ps1"), "ricoh still loads FLGPQT");
    assert(ricoh.includes("github.io/DW_tools/lanyen/drivers/ricoh-user-code-prompt.ps1"), "ricoh prompt moved");
    assert(!ricoh.includes("lanyen.de/"), "ricoh has no lanyen.de download");
    assert(pc.includes("pc-main.ps1"), "pc alias reaches FLGPQT");

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
