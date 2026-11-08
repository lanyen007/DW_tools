// Routes lanyen.de by User-Agent.
// PowerShell (irm) receives a raw script. Browsers receive the existing
// GitHub Pages origin. fetch(request) is the route pass-through to that
// origin; do not replace the DNS records.

const DEFAULT_SCRIPT_BASE = "https://lanyen007.github.io/DW_tools/lanyen";
const DEFAULT_FLGPQT_BASE = "https://lanyen007.github.io/FLGPQT";

// Files that lived only on lanyen.de and now live in DW_tools.
const MOVED = {
  "/menu.ps1": "menu.ps1",
  "/ricoh": "ricoh",
  "/scan": "scan",
  "/auto": "auto",
  "/scan2folder": "scan2folder",
  "/drivers/ricoh-user-code-prompt.ps1": "drivers/ricoh-user-code-prompt.ps1",
};

// Same bytes already in FLGPQT. Do not copy them into DW_tools.
const FLGPQT_ALIAS = {
  "/pc": "drivers/pc.ps1",
  "/fuji": "drivers/cloud-fuji.ps1",
  "/sharp": "drivers/cloud-sharp.ps1",
  "/canon": "drivers/cloud-canon.ps1",
  "/konica": "drivers/cloud-konica.ps1",
  "/fuji-old": "drivers/fuji-old.ps1",
  "/ftp": "drivers/ftp.ps1",
  "/smb": "drivers/smb.ps1",
  "/tools": "drivers/tools.ps1",
};

export function isPowerShellUserAgent(userAgent) {
  return /powershell/i.test(userAgent || "");
}

export function normalizePath(pathname) {
  let path = pathname || "/";
  try {
    path = decodeURIComponent(path);
  } catch {
    // Keep the raw path when percent-encoding is malformed.
  }
  if (path.length > 1 && path.endsWith("/")) path = path.slice(0, -1);
  return path;
}

export function decide(pathname, userAgent) {
  const path = normalizePath(pathname);
  if ((path === "/" || path === "/index.html") && isPowerShellUserAgent(userAgent)) {
    return { action: "script", base: "dw", file: "menu.ps1" };
  }
  if (Object.prototype.hasOwnProperty.call(MOVED, path)) {
    return { action: "script", base: "dw", file: MOVED[path] };
  }
  if (Object.prototype.hasOwnProperty.call(FLGPQT_ALIAS, path)) {
    return { action: "script", base: "flgpqt", file: FLGPQT_ALIAS[path] };
  }
  return { action: "origin" };
}

function baseUrl(env, which) {
  if (which === "dw") return (env && env.SCRIPT_BASE) || DEFAULT_SCRIPT_BASE;
  return (env && env.FLGPQT_BASE) || DEFAULT_FLGPQT_BASE;
}

export function upstreamUrl(decision, requestUrl, env) {
  const incoming = new URL(requestUrl);
  const base = baseUrl(env, decision.base).replace(/\/$/, "");
  const target = new URL(`${base}/${decision.file}`);
  target.search = incoming.search;
  return target.toString();
}

function textHeaders() {
  return {
    "content-type": "text/plain; charset=utf-8",
    "cache-control": "no-store",
  };
}

async function proxyScript(target) {
  let upstream;
  try {
    upstream = await fetch(target, { redirect: "follow", cache: "no-store" });
  } catch (error) {
    console.log(JSON.stringify({
      event: "upstream-error",
      target,
      message: error instanceof Error ? error.message : String(error),
    }));
    return new Response("Script upstream failed\n", { status: 502, headers: textHeaders() });
  }
  console.log(JSON.stringify({ event: "script", target, status: upstream.status }));
  return new Response(upstream.body, { status: upstream.status, headers: textHeaders() });
}

export default {
  async fetch(request, env) {
    const decision = decide(new URL(request.url).pathname, request.headers.get("user-agent"));
    if (decision.action === "script") {
      return proxyScript(upstreamUrl(decision, request.url, env));
    }
    try {
      return await fetch(request);
    } catch (error) {
      console.log(JSON.stringify({
        event: "origin-error",
        message: error instanceof Error ? error.message : String(error),
      }));
      return new Response("Origin fetch failed\n", { status: 502, headers: textHeaders() });
    }
  },
};
