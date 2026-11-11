import {
  CATALOG_SOURCES,
  applyUrlSizes,
  buildCatalog,
  sizeFromHeaders,
} from "./catalog.js";

// Sizes are read from the download URL itself. The GitHub REST API is not
// used: a request with no User-Agent gets HTTP 403 ("administrative rules"),
// and api.github.com also allows only 60 unauthenticated requests per hour
// per egress IP. Cloudflare Workers share those IPs, so the same 403 shows
// up in production even though this Worker sends a User-Agent. The catalog
// JSON already loads from raw.githubusercontent.com, and a HEAD of the file
// returns Content-Length without touching that API.

const MAX_BYTES = 2_000_000;
const FETCH_TIMEOUT_MS = 20_000;

async function readLimited(response) {
  const reader = response.body && response.body.getReader ? response.body.getReader() : null;
  if (!reader) {
    const text = await response.text();
    if (text.length > MAX_BYTES) throw new Error("response too large");
    return text;
  }
  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_BYTES) {
      await reader.cancel();
      throw new Error("response too large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder("utf-8").decode(bytes);
}

async function fetchText(fetchImpl, url, accept) {
  const response = await fetchImpl(url, {
    redirect: "follow",
    headers: {
      "user-agent": "lanyen-de-catalog",
      accept: accept || "*/*",
    },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`${response.status} ${url}`);
  }
  return readLimited(response);
}

async function loadSources(fetchImpl) {
  const warnings = [];
  const loaded = {};
  await Promise.all(Object.entries(CATALOG_SOURCES).map(async ([key, url]) => {
    try {
      const text = await fetchText(fetchImpl, url, key === "toolsText" ? "text/plain" : "application/json, text/plain");
      loaded[key] = key === "toolsText" ? text : JSON.parse(text);
    } catch (error) {
      warnings.push(`${key}: ${error instanceof Error ? error.message : String(error)}`);
      loaded[key] = key === "toolsText" ? "" : null;
    }
  }));
  return { loaded, warnings };
}

const SIZE_CONCURRENCY = 6;

async function cancelBody(response) {
  if (response.body) await response.body.cancel();
}

async function probeSize(fetchImpl, url) {
  try {
    const head = await fetchImpl(url, {
      method: "HEAD",
      redirect: "follow",
      cache: "no-store",
      headers: { "user-agent": "lanyen-de-catalog" },
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
    const fromHead = sizeFromHeaders(head.headers);
    await cancelBody(head);
    if (head.ok && fromHead != null) return fromHead;
  } catch {
    // HEAD is optional. A one-byte range still carries the full size.
  }

  const ranged = await fetchImpl(url, {
    method: "GET",
    redirect: "follow",
    cache: "no-store",
    headers: { "user-agent": "lanyen-de-catalog", range: "bytes=0-0" },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  const fromRange = sizeFromHeaders(ranged.headers);
  await cancelBody(ranged);
  if ((ranged.ok || ranged.status === 206) && fromRange != null) return fromRange;
  throw new Error(`${ranged.status} ${url}`);
}

async function loadSizes(fetchImpl, catalog, warnings) {
  const urls = [];
  const seen = new Set();
  for (const section of catalog.sections) {
    for (const item of section.items) {
      if (item.size != null || seen.has(item.url)) continue;
      seen.add(item.url);
      urls.push(item.url);
    }
  }
  const sizes = new Map();
  let cursor = 0;
  async function worker() {
    while (cursor < urls.length) {
      const url = urls[cursor];
      cursor += 1;
      try {
        sizes.set(url, await probeSize(fetchImpl, url));
      } catch (error) {
        warnings.push(`size ${url}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }
  const workers = Math.min(SIZE_CONCURRENCY, urls.length);
  await Promise.all(Array.from({ length: workers }, () => worker()));
  applyUrlSizes(catalog, sizes);
}

export async function loadCatalog(fetchImpl) {
  const fetchFn = fetchImpl || fetch;
  const { loaded, warnings } = await loadSources(fetchFn);
  const catalog = buildCatalog(loaded);
  await loadSizes(fetchFn, catalog, warnings);
  const count = catalog.sections.reduce((sum, section) => sum + section.items.length, 0);
  return {
    generatedAt: new Date().toISOString(),
    count,
    warnings,
    sections: catalog.sections,
  };
}
