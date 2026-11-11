// Turns the FLGPQT / DW_tools catalogs into the download list.
// Only direct GitHub file URLs are kept. MediaFire, vendor sites,
// Google Drive, and GitHub tree/tag pages are ignored.

export const CATALOG_SOURCES = {
  pqtVersion: "https://raw.githubusercontent.com/lanyen007/DW_tools/main/version.json",
  counterVersion: "https://raw.githubusercontent.com/lanyen007/DW_tools/main/UserCounterDownload_version.json",
  cloud: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/cloud.json",
  fujiOld: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/fuji-old.json",
  ricoh: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/ricoh.json",
  fuji: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/fuji.json",
  sharp: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/sharp.json",
  toolsText: "https://raw.githubusercontent.com/lanyen007/FLGPQT/main/drivers/tools-main.ps1",
};

const PQT_FALLBACK_URL = "https://raw.githubusercontent.com/lanyen007/DW_tools/main/PQT.exe";
const COUNTER_FALLBACK_URL = "https://raw.githubusercontent.com/lanyen007/DW_tools/main/UserCounterDownload.exe";
const KNOWN_REFS = ["cursor/ricoh-mp-c3300-c4500-0e0c", "main", "master"];

export function isGithubFileUrl(url) {
  return Boolean(parseGithubFile(url));
}

export function parseGithubFile(url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== "https:") return null;
  const host = parsed.hostname.toLowerCase();
  if (host === "raw.githubusercontent.com") {
    const parts = splitOwnerRepo(parsed.pathname);
    if (!parts) return null;
    const located = splitRef(parts.rest);
    if (!located || !hasFileExtension(located.path)) return null;
    return {
      repo: parts.repo,
      path: located.path,
      filename: fileName(located.path),
    };
  }
  if (host !== "github.com") return null;
  const raw = parsed.pathname.match(/^\/([^/]+)\/([^/]+)\/raw\/(.+)$/);
  if (raw) {
    const located = splitRef(raw[3]);
    if (!located || !hasFileExtension(located.path)) return null;
    return { repo: raw[2], path: located.path, filename: fileName(located.path) };
  }
  const release = parsed.pathname.match(/^\/([^/]+)\/([^/]+)\/releases\/download\/([^/]+)\/(.+)$/);
  if (!release || !hasFileExtension(release[4])) return null;
  const filename = decodeURIComponent(release[4]);
  return {
    repo: release[2],
    path: filename,
    filename,
    release: release[3],
  };
}

function splitOwnerRepo(pathname) {
  const match = pathname.match(/^\/([^/]+)\/([^/]+)\/(.+)$/);
  if (!match) return null;
  return { owner: match[1], repo: match[2], rest: match[3] };
}

function splitRef(rest) {
  for (const ref of KNOWN_REFS) {
    if (rest === ref) return null;
    if (rest.startsWith(`${ref}/`)) return { ref, path: rest.slice(ref.length + 1) };
  }
  const slash = rest.indexOf("/");
  if (slash <= 0) return null;
  return { ref: rest.slice(0, slash), path: rest.slice(slash + 1) };
}

function hasFileExtension(path) {
  return /\.[a-z0-9]{1,8}$/i.test(path || "");
}

function fileName(path) {
  const name = String(path || "").split("/").pop();
  try {
    return decodeURIComponent(name);
  } catch {
    return name;
  }
}

function asSize(value) {
  if (typeof value === "number" && Number.isFinite(value) && value >= 0) return Math.round(value);
  if (typeof value === "string" && /^\d+$/.test(value)) return Number(value);
  return null;
}

function clean(value) {
  const text = value == null ? "" : String(value).trim();
  return text || null;
}

function guessVersion(text) {
  const match = String(text || "").match(/\d+\.\d+\.\d+(?:\.\d+)?/);
  return match ? match[0] : null;
}

function looseVersion(text) {
  return guessVersion(text) || (String(text || "").match(/\d+\.\d+/) || [null])[0];
}

export function parseToolsScript(text) {
  const source = String(text || "");
  const tagMatch = source.match(/\$ReleaseTag\s*=\s*'([^']+)'/);
  const tag = tagMatch ? tagMatch[1] : "";
  const items = [];
  const pattern = /Key\s*=\s*'([^']+)'[\s\S]*?File\s*=\s*'([^']+)'[\s\S]*?Title\s*=\s*'([^']+)'[\s\S]*?Size\s*=\s*(\d+)L[\s\S]*?Note\s*=\s*'([^']*)'/g;
  let match = pattern.exec(source);
  while (match) {
    const filename = match[2];
    const title = match[3];
    const note = match[5];
    items.push({
      key: match[1],
      filename,
      title,
      note,
      size: Number(match[4]),
      version: guessVersion(title) || guessVersion(note) || looseVersion(title),
      url: tag
        ? `https://github.com/lanyen007/FLGPQT/releases/download/${tag}/${encodeURIComponent(filename)}`
        : "",
    });
    match = pattern.exec(source);
  }
  return items;
}

function toolBrand(item) {
  const haystack = `${item.title} ${item.filename}`.toLowerCase();
  if (haystack.includes("sharp") || haystack.includes("nst")) return "Sharp";
  if (haystack.includes("qserver")) return "QServer";
  return "工具";
}

function chooseUrl(preferred, fallback) {
  if (isGithubFileUrl(preferred)) return preferred;
  if (isGithubFileUrl(fallback)) return fallback;
  return null;
}

function baseItem({ name, brand, version, size, url, filename, models }) {
  const parsed = parseGithubFile(url);
  return {
    name: name || parsed?.filename || url,
    brand: brand || "",
    version: version || null,
    size: asSize(size),
    url,
    filename: filename || parsed?.filename || null,
    models: models && models.length > 1 ? models : null,
  };
}

function addDriverRows(items, drivers, brand, { keepDuplicates = false, seen }) {
  for (const driver of drivers || []) {
    if (!isGithubFileUrl(driver.url)) continue;
    if (!keepDuplicates && seen.has(driver.url)) continue;
    seen.add(driver.url);
    const title = clean(driver.title) || clean(driver.model) || clean(driver.filename);
    items.push(baseItem({
      name: title,
      brand: clean(driver.brand) || brand || "",
      version: clean(driver.version) || guessVersion(`${driver.title || ""} ${driver.notes || ""}`),
      size: driver.size,
      url: driver.url,
      filename: clean(driver.filename),
    }));
  }
}

function addGroupedDrivers(items, drivers, brand, seen) {
  const groups = new Map();
  for (const driver of drivers || []) {
    if (!isGithubFileUrl(driver.url) || seen.has(driver.url)) continue;
    let group = groups.get(driver.url);
    if (!group) {
      group = {
        brand,
        url: driver.url,
        filename: clean(driver.filename) || parseGithubFile(driver.url).filename,
        version: null,
        size: asSize(driver.size),
        models: [],
        title: clean(driver.title),
      };
      groups.set(driver.url, group);
    }
    if (driver.model && !group.models.includes(driver.model)) group.models.push(driver.model);
    if (!group.version) {
      group.version = guessVersion(`${driver.title || ""} ${driver.notes || ""}`);
    }
    if (group.size == null) group.size = asSize(driver.size);
  }
  for (const group of groups.values()) {
    seen.add(group.url);
    const single = group.models.length === 1;
    items.push(baseItem({
      name: single ? (group.title || `${group.models[0]} · ${group.filename}`) : group.filename,
      brand: group.brand,
      version: group.version,
      size: group.size,
      url: group.url,
      filename: group.filename,
      models: group.models,
    }));
  }
}

export function buildCatalog(input) {
  const sources = input || {};
  const seen = new Set();
  const sections = [];

  const toolbox = [];
  const pqtUrl = chooseUrl(sources.pqtVersion && sources.pqtVersion.url, PQT_FALLBACK_URL);
  if (pqtUrl) {
    toolbox.push(baseItem({
      name: "PQT.exe",
      brand: "PQT",
      version: clean(sources.pqtVersion && sources.pqtVersion.version),
      size: sources.pqtVersion && sources.pqtVersion.size,
      url: pqtUrl,
      filename: "PQT.exe",
    }));
    seen.add(pqtUrl);
  }
  const counterUrl = chooseUrl(sources.counterVersion && sources.counterVersion.url, COUNTER_FALLBACK_URL);
  if (counterUrl) {
    toolbox.push(baseItem({
      name: "RICOH 使用者計數下載",
      brand: "RICOH",
      version: clean(sources.counterVersion && sources.counterVersion.version),
      size: sources.counterVersion && sources.counterVersion.size,
      url: counterUrl,
      filename: "UserCounterDownload.exe",
    }));
    seen.add(counterUrl);
  }
  sections.push({ id: "toolbox", items: toolbox });

  const cloud = [];
  addDriverRows(cloud, sources.cloud && sources.cloud.drivers, null, { seen });
  sections.push({ id: "cloud", items: cloud });

  const fujiOld = [];
  const fujiBrand = "FUJIFILM";
  addDriverRows(fujiOld, sources.fujiOld && sources.fujiOld.drivers, fujiBrand, { keepDuplicates: true, seen });
  sections.push({ id: "fuji-old", items: fujiOld });

  const tools = [];
  for (const tool of parseToolsScript(sources.toolsText)) {
    if (!isGithubFileUrl(tool.url) || seen.has(tool.url)) continue;
    seen.add(tool.url);
    tools.push(baseItem({
      name: tool.title,
      brand: toolBrand(tool),
      version: tool.version,
      size: tool.size,
      url: tool.url,
      filename: tool.filename,
    }));
  }
  sections.push({ id: "common-tools", items: tools });

  const models = [];
  addGroupedDrivers(models, sources.ricoh && sources.ricoh.drivers, clean(sources.ricoh && sources.ricoh.brand) || "Ricoh", seen);
  addGroupedDrivers(models, sources.sharp && sources.sharp.drivers, clean(sources.sharp && sources.sharp.brand) || "Sharp", seen);
  addGroupedDrivers(models, sources.fuji && sources.fuji.drivers, clean(sources.fuji && sources.fuji.brand) || fujiBrand, seen);
  sections.push({ id: "github-models", items: models });

  return {
    sections: sections.filter((section) => section.items.length > 0),
  };
}

export function applySizeIndex(catalog, sizeIndex) {
  const index = sizeIndex || new Map();
  for (const section of catalog.sections) {
    for (const item of section.items) {
      if (item.size != null) continue;
      const parsed = parseGithubFile(item.url);
      if (!parsed) continue;
      const keys = [
        `${parsed.repo}:${parsed.path}`,
        parsed.release ? `${parsed.repo}:release:${parsed.filename}` : "",
      ];
      for (const key of keys) {
        if (key && index.has(key)) {
          item.size = index.get(key);
          break;
        }
      }
    }
  }
  return catalog;
}
