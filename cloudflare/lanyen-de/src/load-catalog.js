import {
  CATALOG_SOURCES,
  applySizeIndex,
  buildCatalog,
  parseGithubFile,
} from "./catalog.js";

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

function releaseTags(catalog) {
  const tags = new Map();
  for (const section of catalog.sections) {
    for (const item of section.items) {
      if (item.size != null) continue;
      const parsed = parseGithubFile(item.url);
      if (parsed && parsed.release) {
        tags.set(`${parsed.repo}:${parsed.release}`, parsed);
      }
    }
  }
  return [...tags.values()];
}

function rememberContents(index, repo, entries) {
  const rows = Array.isArray(entries) ? entries : [];
  for (const entry of rows) {
    if (!entry || typeof entry.size !== "number" || !entry.path) continue;
    index.set(`${repo}:${entry.path}`, entry.size);
  }
}

async function loadSizes(fetchImpl, catalog, warnings) {
  const index = new Map();
  const jobs = [];
  const needs = (predicate) => catalog.sections.some((section) => section.items.some((item) => {
    if (item.size != null) return false;
    const parsed = parseGithubFile(item.url);
    return parsed && predicate(parsed);
  }));

  async function contents(repo, path) {
      const suffix = path ? `/${path}` : "";
      const url = `https://api.github.com/repos/lanyen007/${repo}/contents${suffix}`;
    try {
      const text = await fetchText(fetchImpl, url, "application/vnd.github+json");
      rememberContents(index, repo, JSON.parse(text));
    } catch (error) {
      warnings.push(`size ${repo}/${path}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  if (needs((parsed) => parsed.repo === "FLGPQT" && parsed.path.startsWith("drivers/packages/fuji-old/"))) {
    jobs.push(contents("FLGPQT", "drivers/packages/fuji-old"));
  }
  if (needs((parsed) => parsed.repo === "DW_tools" && !parsed.path.includes("/"))) {
    jobs.push(contents("DW_tools", ""));
  }
  if (needs((parsed) => parsed.repo === "DW_tools" && parsed.path.startsWith("drivers/ricoh/"))) {
    jobs.push(contents("DW_tools", "drivers/ricoh"));
  }
  for (const release of releaseTags(catalog)) {
    jobs.push((async () => {
      const url = `https://api.github.com/repos/lanyen007/${release.repo}/releases/tags/${release.release}`;
      try {
        const text = await fetchText(fetchImpl, url, "application/vnd.github+json");
        const body = JSON.parse(text);
        for (const asset of body.assets || []) {
          if (asset && typeof asset.size === "number" && asset.name) {
            index.set(`${release.repo}:release:${asset.name}`, asset.size);
          }
        }
      } catch (error) {
        warnings.push(`size ${release.repo}@${release.release}: ${error instanceof Error ? error.message : String(error)}`);
      }
    })());
  }
  await Promise.all(jobs);
  applySizeIndex(catalog, index);
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
