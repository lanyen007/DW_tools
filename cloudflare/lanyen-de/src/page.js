// Browser homepage. The private lanyen.de GitHub Pages site is still the
// origin for map.html, log.html, and apps.html. PowerShell never receives
// this document.

export function renderPage() {
  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>lanyen.de Toolkit</title>
<style>
body{font-size:0;font-family:sans-serif;max-width:720px;margin:40px auto;padding:0 16px;color:#222}
body>*{font-size:1rem}
h1{font-size:2rem;margin:0}
.top{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:4px}
.lang-btn{font-size:.95rem;padding:6px 12px;border:1px solid #99f6e4;border-radius:8px;background:#f0fdfa;color:#0f766e;cursor:pointer;white-space:nowrap}
.lang-btn:hover{background:#ccfbf1}
h3{font-size:1.17rem;margin-top:1.6em}
body>pre,pre{font-size:18px;background:#f5f5f5;padding:12px 14px;border-radius:6px;overflow:auto}
.cmd-row{display:flex;align-items:stretch;gap:8px;flex-wrap:wrap}
.cmd-row pre{flex:1 1 auto;margin:0;cursor:pointer;user-select:all}
.cmd-row pre:hover{background:#eef2f7}
.copy-btn{font-size:1rem;padding:0 14px;border:1px solid #99f6e4;border-radius:6px;background:#f0fdfa;color:#0f766e;cursor:pointer;white-space:nowrap}
.copy-btn:hover{background:#ccfbf1}
.copy-btn.ok{background:#dcfce7;border-color:#86efac;color:#166534}
.tabs{display:flex;flex-wrap:wrap;gap:4px;border-bottom:2px solid #e2e8f0;margin:12px 0 16px}.tab{font-size:1rem;padding:8px 14px;border:1px solid #e2e8f0;border-bottom:none;border-radius:8px 8px 0 0;background:#f7fafc;color:#475569;cursor:pointer;margin-bottom:-2px;text-decoration:none;display:inline-block}.tab.on{background:#fff;color:#0f766e;font-weight:700;border-color:#e2e8f0;border-bottom:2px solid #fff}.map{font-size:14px!important;line-height:1.55;overflow-x:auto;white-space:pre}.map a,.map a:visited,.map a:hover,.map a:active,.map a:focus{color:inherit;text-decoration:none;cursor:pointer;pointer-events:auto}.pane{display:none}.pane.on{display:block}
#flg-stats .row{flex-wrap:wrap}
#flg-stats{background:#f7fafc;border:1px solid #e2e8f0;border-radius:.5em;padding:.6em .9em;box-sizing:border-box;line-height:1.7}
#flg-stats .total{font-size:1.35em;font-weight:700;color:#0f766e}
#flg-stats .row{display:flex;justify-content:space-between;gap:.8em;border-top:1px solid #e2e8f0;padding:.25em 0;margin-top:.25em}
#flg-stats .muted,.muted{color:#64748b;font-size:0.92em}
#flg-stats .err,.err{color:#b45309}
.dl-intro{line-height:1.6;margin:0 0 12px}
.dl-search{width:100%;box-sizing:border-box;font-size:16px;padding:10px 12px;border:1px solid #e2e8f0;border-radius:8px;margin:0 0 14px}
.dl-sec{margin:0 0 18px}
.dl-sec h2{font-size:1.05rem;margin:0 0 8px;color:#0f766e}
.dl-card{border:1px solid #e2e8f0;border-radius:8px;padding:12px 14px;margin:0 0 8px;background:#fff;overflow-wrap:anywhere}
.dl-card h3{font-size:1rem;margin:0 0 6px;line-height:1.45}
.dl-meta{display:flex;flex-wrap:wrap;gap:4px 12px;color:#475569;font-size:.92rem;line-height:1.5}
.dl-models{color:#64748b;font-size:.88rem;margin:6px 0 0;line-height:1.45}
.dl-intro,.dl-models,.dl-card h3,.dl-meta{overflow-wrap:anywhere}
.dl-btn{display:inline-flex;align-items:center;justify-content:center;margin-top:10px;min-height:44px;padding:8px 16px;border-radius:8px;background:#0f766e;color:#fff;text-decoration:none;font-weight:700}
.dl-btn:hover{background:#115e59}
.dl-warn{background:#fffbeb;border:1px solid #fde68a;border-radius:8px;padding:8px 12px;color:#92400e;margin:0 0 12px}
</style>
</head>
<body>
<div class="top"><h1 data-i18n="title">lanyen.de 工具箱</h1><button type="button" class="lang-btn" id="langBtn" aria-label="Language">English</button></div>
<nav class="tabs">
  <button type="button" class="tab on" data-t="t-home" data-i18n="tab_home">安裝</button>
  <button type="button" class="tab" data-t="t-dl" data-i18n="tab_dl">下載</button>
  <button type="button" class="tab" data-t="t-stats" data-i18n="tab_stats">累計使用人次</button>
  <a class="tab" href="map.html" data-i18n="tab_map">選單地圖</a>
  <a class="tab" href="log.html" data-i18n="tab_log">更新表</a>
  <a class="tab" href="apps.html" data-i18n="tab_apps">手機列印 App</a>
  <button type="button" class="tab" data-t="t-decl" data-i18n="tab_decl">使用聲明</button>
</nav>
<section id="t-home" class="pane on"><div class="cmd-row"><pre id="installCmd" title="irm lanyen.de | iex">irm lanyen.de | iex</pre><button type="button" class="copy-btn" id="copyCmdBtn" data-i18n="copy_btn">複製</button></div></section>
<section id="t-dl" class="pane">
  <p class="dl-intro" data-i18n="dl_intro">以下是放在 GitHub 的驅動程式與工具，可以直接下載。清單由目錄自動產生。MediaFire 和原廠官網的連結不在這裡。</p>
  <input id="dlSearch" class="dl-search" type="search" data-i18n-placeholder="dl_search" placeholder="搜尋名稱、廠牌、版本或檔名" autocomplete="off">
  <div id="dlList"><span class="muted" data-i18n="dl_loading">載入中…</span></div>
  <noscript><p class="err">請開啟 JavaScript 以載入下載清單。</p></noscript>
</section>
<section id="t-stats" class="pane"><div id="flg-stats"><span class="muted" data-i18n="stats_loading">載入中…</span></div></section>
<section id="t-decl" class="pane"><div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:12px 16px;line-height:1.8">
<p data-i18n="decl_intro">本站是影印機相關的安裝工具，方便快速安裝影印機與印表機驅動程式。</p>
<p data-i18n-html="decl_body">・驅動程式皆來自 Ricoh、FUJIFILM、Sharp、Canon、Konica Minolta 等原廠公開提供的通用版本，未經任何修改。<br>
・所有腳本原始碼完全公開，可在 <a href="https://github.com/lanyen007/FLGPQT">GitHub</a> 上逐行檢視。<br>
・程式只會在您的電腦上安裝驅動、建立印表機連接埠，或依您的選擇建立掃描用的 FTP／共用資料夾。<br>
・重灌後常用軟體（irm lanyen.de/pc）只安裝你勾選的項目，來源是 Windows 的 winget，或 LINE、新酷音、AweSun、RustDesk、KMPlayer、Global PotPlayer 的官方安裝檔。<br>
・不會讀取、蒐集或上傳任何個人資料、密碼、檔案或信用卡資訊。<br>
・唯一對外傳送的是匿名的「使用次數」統計（例如：安裝了一次 Ricoh），不含 IP 以外的任何識別資訊，也不含電腦內容。</p>
<p class="muted" data-i18n="decl_https">若瀏覽器顯示「不安全」，是因為本站的 HTTPS 憑證仍在由 GitHub 核發中，並非網站有惡意程式。</p>
</div></section>
<script>
(function(){
  var I18N = {
    zh: {
      title: 'lanyen.de 工具箱',
      lang_btn: 'English',
      copy_btn: '複製', copy_ok: '已複製！',
      tab_home: '安裝', tab_dl: '下載', tab_stats: '累計使用人次', tab_map: '選單地圖', tab_log: '更新表', tab_apps: '手機列印 App', tab_decl: '使用聲明',
      stats_loading: '載入中…',
      stats_total: '合計 {n} 人次',
      stats_note: '含選單、雲端安裝、驅動下載、掃描到資料夾、FTP／SMB、檔案箱、常用工具、重灌後常用軟體（瀏覽本頁不計入）',
      stats_err: '目前無法讀取計數（稍後再試）。',
      s_menu: '選單（irm lanyen.de）',
      s_ricoh: 'Ricoh（雲端安裝 + 下載）',
      s_fuji: 'FUJIFILM／全錄（雲端安裝 + 下載）',
      s_fuji_old: '舊版 FUJI（IV／V／DocuCentre）',
      s_sharp: 'Sharp（雲端安裝 + 下載）',
      s_canon: 'Canon（雲端安裝）',
      s_konica: '美樂達／KONICA MINOLTA（雲端安裝）',
      s_auto: '自動偵測機型下載／安裝',
      s_lan: '區網掃描安裝',
      s_ftp: '簡易 FTP 伺服器',
      s_smb: 'SMB 共用資料夾',
      s_s2f: '掃描到資料夾（GUI）',
      s_box: '檔案箱',
      s_tools: '常用工具下載',
      s_pc: '重灌後常用軟體',
      s_okfail: '雲端安裝成功 / 失敗',
      decl_intro: '本站是影印機相關的安裝工具，方便快速安裝影印機與印表機驅動程式。',
      decl_body: '・驅動程式皆來自 Ricoh、FUJIFILM、Sharp、Canon、Konica Minolta 等原廠公開提供的通用版本，未經任何修改。<br>・所有腳本原始碼完全公開，可在 <a href="https://github.com/lanyen007/FLGPQT">GitHub</a> 上逐行檢視。<br>・程式只會在您的電腦上安裝驅動、建立印表機連接埠，或依您的選擇建立掃描用的 FTP／共用資料夾。<br>・重灌後常用軟體（irm lanyen.de/pc）只安裝你勾選的項目，來源是 Windows 的 winget，或 LINE、新酷音、AweSun、RustDesk、KMPlayer、Global PotPlayer 的官方安裝檔。<br>・不會讀取、蒐集或上傳任何個人資料、密碼、檔案或信用卡資訊。<br>・唯一對外傳送的是匿名的「使用次數」統計（例如：安裝了一次 Ricoh），不含 IP 以外的任何識別資訊，也不含電腦內容。',
      decl_https: '若瀏覽器顯示「不安全」，是因為本站的 HTTPS 憑證仍在由 GitHub 核發中，並非網站有惡意程式。',
      dl_intro: '以下是放在 GitHub 的驅動程式與工具，可以直接下載。清單由 FLGPQT 與 DW_tools 的目錄自動產生。MediaFire 和原廠官網的連結不在這裡。',
      dl_search: '搜尋名稱、廠牌、版本或檔名',
      dl_loading: '載入中…',
      dl_err: '目前無法讀取下載清單（稍後再試）。',
      dl_empty: '找不到符合的項目。',
      dl_warn: '有部分目錄暫時讀不到，清單可能不完整。',
      dl_brand: '廠牌',
      dl_version: '版本',
      dl_size: '大小',
      dl_file: '檔案',
      dl_models: '適用機型',
      dl_download: '下載',
      dl_unknown_ver: '未標版本',
      dl_unknown_size: '大小未知',
      dl_count: '共 {n} 筆',
      dl_tools_note: '常用工具的版權屬於原作者與原廠。這裡是 GitHub 上的備份檔，供個人維修參考。',
      sec_toolbox: '工具',
      sec_cloud: '雲端通用驅動',
      sec_fuji_old: '舊版 FUJI',
      sec_common_tools: '常用工具',
      sec_github_models: '其他 GitHub 驅動'
    },
    en: {
      title: 'lanyen.de Toolkit',
      lang_btn: '中文',
      copy_btn: 'Copy', copy_ok: 'Copied!',
      tab_home: 'Install', tab_dl: 'Download', tab_stats: 'Usage count', tab_map: 'Menu map', tab_log: 'Updates', tab_apps: 'Mobile print apps', tab_decl: 'Disclaimer',
      stats_loading: 'Loading…',
      stats_total: 'Total {n} uses',
      stats_note: 'Includes menu, cloud install, driver download, scan-to-folder, FTP/SMB, file box, tools, post-reinstall apps (viewing this page is not counted)',
      stats_err: 'Unable to load counters right now. Try again later.',
      s_menu: 'Menu (irm lanyen.de)',
      s_ricoh: 'Ricoh (cloud install + download)',
      s_fuji: 'FUJIFILM / Xerox (cloud install + download)',
      s_fuji_old: 'Legacy FUJI (IV / V / DocuCentre)',
      s_sharp: 'Sharp (cloud install + download)',
      s_canon: 'Canon (cloud install)',
      s_konica: 'Konica Minolta (cloud install)',
      s_auto: 'Auto model detect / install',
      s_lan: 'LAN scan install',
      s_ftp: 'Simple FTP server',
      s_smb: 'SMB shared folder',
      s_s2f: 'Scan to folder (GUI)',
      s_box: 'File box',
      s_tools: 'Common tools download',
      s_pc: 'Post-reinstall apps',
      s_okfail: 'Cloud install OK / fail',
      decl_intro: 'This site is a copier-related install toolkit for quickly installing MFP and printer drivers.',
      decl_body: '・Drivers come from the public universal packages published by Ricoh, FUJIFILM, Sharp, Canon, Konica Minolta, and similar vendors, unmodified.<br>・All script source is public on <a href="https://github.com/lanyen007/FLGPQT">GitHub</a>.<br>・Scripts only install drivers, create printer ports on your PC, or optionally set up FTP/SMB folders for scanning.<br>・Post-reinstall apps (irm lanyen.de/pc) install only what you select, using Windows winget or the official installers for LINE, Chewing, AweSun, RustDesk, KMPlayer, and Global PotPlayer.<br>・They do not read, collect, or upload personal data, passwords, files, or payment details.<br>・The only outbound telemetry is an anonymous usage counter (e.g. “Ricoh install once”), with no identifiers beyond IP and no PC contents.',
      decl_https: 'If the browser says “Not secure”, the HTTPS certificate may still be provisioning; it does not mean the site is malware.',
      dl_intro: 'Drivers and tools hosted on GitHub. The list is built from the FLGPQT and DW_tools catalogs. MediaFire and vendor-site links are not listed.',
      dl_search: 'Search name, brand, version, or file',
      dl_loading: 'Loading…',
      dl_err: 'Unable to load the download list. Try again later.',
      dl_empty: 'No matching items.',
      dl_warn: 'Some catalogs could not be read. This list may be incomplete.',
      dl_brand: 'Brand',
      dl_version: 'Version',
      dl_size: 'Size',
      dl_file: 'File',
      dl_models: 'Models',
      dl_download: 'Download',
      dl_unknown_ver: 'Not listed',
      dl_unknown_size: 'Unknown size',
      dl_count: '{n} items',
      dl_tools_note: 'Common tools remain the copyright of their authors and vendors. These GitHub copies are for personal repair use.',
      sec_toolbox: 'Tools',
      sec_cloud: 'Cloud universal drivers',
      sec_fuji_old: 'Legacy FUJI',
      sec_common_tools: 'Common tools',
      sec_github_models: 'Other GitHub drivers'
    }
  };
  var lang = 'zh';
  var statsCache = null;
  var dlCache = null;
  var dlQuery = '';
  var dlFailed = false;
  function detectLang() {
    try {
      var q = new URLSearchParams(location.search).get('lang');
      if (q && /^zh/i.test(q)) return 'zh';
      if (q && /^en/i.test(q)) return 'en';
    } catch (e) {}
    try {
      var s = localStorage.getItem('lanyen-lang');
      if (s === 'zh' || s === 'en') return s;
    } catch (e) {}
    var nav = (navigator.language || navigator.userLanguage || 'en').toLowerCase();
    return nav.indexOf('zh') === 0 ? 'zh' : 'en';
  }
  function t(key) {
    var d = I18N[lang] || I18N.zh;
    return (d[key] != null ? d[key] : (I18N.zh[key] || key));
  }
  function apply() {
    document.documentElement.lang = (lang === 'zh' ? 'zh-Hant' : 'en');
    document.title = t('title');
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      el.textContent = t(el.getAttribute('data-i18n'));
    });
    document.querySelectorAll('[data-i18n-html]').forEach(function (el) {
      el.innerHTML = t(el.getAttribute('data-i18n-html'));
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(function (el) {
      el.setAttribute('placeholder', t(el.getAttribute('data-i18n-placeholder')));
    });
    var btn = document.getElementById('langBtn');
    if (btn) btn.textContent = t('lang_btn');
    if (statsCache) renderStats(statsCache);
    renderDownloads();
  }
  function setLang(next, persist) {
    lang = next;
    if (persist !== false) {
      try { localStorage.setItem('lanyen-lang', lang); } catch (e) {}
    }
    apply();
  }
  window.__flgI18n = { t: t, getLang: function () { return lang; }, setLang: setLang };
  document.getElementById('langBtn').onclick = function () {
    setLang(lang === 'zh' ? 'en' : 'zh', true);
  };
  function switchTab(targetId) {
    var btn = document.querySelector('.tab[data-t="' + targetId + '"]');
    if (btn) {
      document.querySelectorAll('.tab,.pane').forEach(function (e) { e.classList.remove('on'); });
      btn.classList.add('on');
      var pane = document.getElementById(targetId);
      if (pane) pane.classList.add('on');
    }
  }
  document.querySelectorAll('.tab').forEach(function (b) {
    if (b.tagName.toLowerCase() === 'button') {
      b.onclick = function () { switchTab(b.dataset.t); };
    }
  });
  try {
    var tabParam = new URLSearchParams(location.search).get('tab');
    if (tabParam) switchTab('t-' + tabParam);
  } catch (e) {}

  var COPY_TEXT = 'irm lanyen.de | iex';
  var copyTimer = null;
  function flashCopied() {
    var btn = document.getElementById('copyCmdBtn');
    if (!btn) return;
    btn.textContent = t('copy_ok');
    btn.classList.add('ok');
    if (copyTimer) clearTimeout(copyTimer);
    copyTimer = setTimeout(function () {
      btn.textContent = t('copy_btn');
      btn.classList.remove('ok');
      copyTimer = null;
    }, 2000);
  }
  function copyInstallCmd() {
    function ok() { flashCopied(); }
    function fail() {
      try {
        var ta = document.createElement('textarea');
        ta.value = COPY_TEXT;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        document.body.appendChild(ta);
        ta.select();
        var done = document.execCommand('copy');
        document.body.removeChild(ta);
        if (done) ok();
      } catch (e) {}
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(COPY_TEXT).then(ok).catch(fail);
    } else {
      fail();
    }
  }
  var copyBtn = document.getElementById('copyCmdBtn');
  if (copyBtn) copyBtn.onclick = function (ev) { ev.preventDefault(); copyInstallCmd(); };
  var cmdPre = document.getElementById('installCmd');
  if (cmdPre) cmdPre.onclick = function () { copyInstallCmd(); };

  function safeUrl(url) {
    try {
      var u = new URL(url);
      if (u.protocol !== 'https:') return '';
      var h = u.hostname.toLowerCase();
      if (h === 'github.com' || h === 'raw.githubusercontent.com' || h === 'objects.githubusercontent.com' || h === 'release-assets.githubusercontent.com') return u.href;
    } catch (e) {}
    return '';
  }
  function formatSize(n) {
    if (typeof n !== 'number' || !isFinite(n)) return t('dl_unknown_size');
    if (n >= 1073741824) return (n / 1073741824).toFixed(1) + ' GB';
    if (n >= 1048576) {
      var mb = n / 1048576;
      return (mb >= 10 ? mb.toFixed(0) : mb.toFixed(1)) + ' MB';
    }
    if (n >= 1024) return Math.round(n / 1024) + ' KB';
    return n + ' B';
  }
  function metaSpan(label, value) {
    var span = document.createElement('span');
    var b = document.createElement('b');
    b.textContent = label + ' ';
    span.appendChild(b);
    span.appendChild(document.createTextNode(value));
    return span;
  }
  function renderDownloads() {
    var root = document.getElementById('dlList');
    if (!root) return;
    root.textContent = '';
    if (dlFailed) {
      var err = document.createElement('span');
      err.className = 'err';
      err.textContent = t('dl_err');
      root.appendChild(err);
      return;
    }
    if (!dlCache) {
      var loading = document.createElement('span');
      loading.className = 'muted';
      loading.textContent = t('dl_loading');
      root.appendChild(loading);
      return;
    }
    if (dlCache.warnings && dlCache.warnings.length) {
      var warn = document.createElement('p');
      warn.className = 'dl-warn';
      warn.textContent = t('dl_warn');
      root.appendChild(warn);
    }
    var q = dlQuery.trim().toLowerCase();
    var shown = 0;
    var blocks = [];
    (dlCache.sections || []).forEach(function (section) {
      var visible = (section.items || []).filter(function (item) {
        if (!q) return true;
        var models = (item.models || []).join(' ');
        var hay = [item.name, item.brand, item.version, item.filename, item.note, models].join(' ').toLowerCase();
        return hay.indexOf(q) !== -1;
      });
      if (!visible.length) return;
      shown += visible.length;
      var sec = document.createElement('section');
      sec.className = 'dl-sec';
      var h2 = document.createElement('h2');
      var key = 'sec_' + String(section.id || '').replace(/-/g, '_');
      var heading = t(key);
      if (lang === 'zh' && section.titleZh) heading = section.titleZh;
      else if (lang !== 'zh' && section.titleEn) heading = section.titleEn;
      else if (section.titleZh) heading = section.titleZh;
      h2.textContent = heading + '（' + visible.length + '）';
      sec.appendChild(h2);
      var sectionNote = '';
      if (section.noteZh != null || section.noteEn != null) {
        sectionNote = lang === 'zh' ? (section.noteZh || '') : (section.noteEn || '');
      } else if (section.id === 'common-tools') {
        sectionNote = t('dl_tools_note');
      }
      if (sectionNote) {
        var note = document.createElement('p');
        note.className = 'muted';
        note.textContent = sectionNote;
        sec.appendChild(note);
      }
      visible.forEach(function (item) {
        var card = document.createElement('article');
        card.className = 'dl-card';
        var h3 = document.createElement('h3');
        h3.textContent = item.name || item.filename || '';
        card.appendChild(h3);
        var meta = document.createElement('div');
        meta.className = 'dl-meta';
        meta.appendChild(metaSpan(t('dl_brand'), item.brand || '—'));
        meta.appendChild(metaSpan(t('dl_version'), item.version || t('dl_unknown_ver')));
        meta.appendChild(metaSpan(t('dl_size'), formatSize(item.size)));
        if (item.filename && String(item.name || '').indexOf(item.filename) === -1) {
          meta.appendChild(metaSpan(t('dl_file'), item.filename));
        }
        card.appendChild(meta);
        if (item.note) {
          var itemNote = document.createElement('p');
          itemNote.className = 'dl-models';
          itemNote.textContent = item.note;
          card.appendChild(itemNote);
        }
        if (item.models && item.models.length > 1) {
          var models = item.models.slice(0, 8).join('、');
          if (item.models.length > 8) models += '…';
          var line = document.createElement('p');
          line.className = 'dl-models';
          line.textContent = t('dl_models') + '：' + models + '（' + item.models.length + '）';
          card.appendChild(line);
        }
        var href = safeUrl(item.url);
        if (href) {
          var a = document.createElement('a');
          a.className = 'dl-btn';
          a.href = href;
          a.target = '_blank';
          a.rel = 'noopener noreferrer';
          a.textContent = t('dl_download');
          card.appendChild(a);
        }
        sec.appendChild(card);
      });
      blocks.push(sec);
    });
    var count = document.createElement('p');
    count.className = 'muted';
    count.textContent = shown ? t('dl_count').replace('{n}', String(shown)) : t('dl_empty');
    root.appendChild(count);
    blocks.forEach(function (sec) { root.appendChild(sec); });
  }
  var search = document.getElementById('dlSearch');
  if (search) search.addEventListener('input', function () {
    dlQuery = search.value || '';
    renderDownloads();
  });
  fetch('/downloads.json', { cache: 'no-store' }).then(function (r) {
    if (!r.ok) throw new Error('status');
    return r.json();
  }).then(function (data) {
    dlCache = data || { sections: [] };
    renderDownloads();
  }).catch(function () {
    dlFailed = true;
    renderDownloads();
  });

  function renderStats(m) {
    statsCache = m;
    function row(label, n) {
      return '<div class="row"><span>' + label + '</span><strong>' + Number(n).toLocaleString(lang === 'zh' ? 'zh-TW' : 'en-US') + '</strong></div>';
    }
    var entry = m['menu'] + m['cloud-ricoh'] + m['cloud-fuji'] + m['cloud-sharp'] + m['cloud-canon'] + m['cloud-konica']
      + m['dl-ricoh'] + m['dl-fuji'] + m['dl-fuji-old'] + m['dl-sharp'] + m['auto-driver'] + m['lan-scan'] + m['ftp'] + m['smb'] + m['scan2folder'] + m['filebox'] + m['dl-tools'] + m['dl-pc'];
    var ricoh = m['cloud-ricoh'] + m['dl-ricoh'];
    var fuji = m['cloud-fuji'] + m['dl-fuji'];
    var sharp = m['cloud-sharp'] + m['dl-sharp'];
    var canon = m['cloud-canon'];
    var konica = m['cloud-konica'];
    var ok = m['install-ok-ricoh'] + m['install-ok-fuji'] + m['install-ok-sharp'] + m['install-ok-canon'] + m['install-ok-konica'];
    var fail = m['install-fail-ricoh'] + m['install-fail-fuji'] + m['install-fail-sharp'] + m['install-fail-canon'] + m['install-fail-konica'];
    var el = document.getElementById('flg-stats');
    el.innerHTML =
      '<div class="total">' + t('stats_total').replace('{n}', entry.toLocaleString(lang === 'zh' ? 'zh-TW' : 'en-US')) + '</div>' +
      '<div class="muted">' + t('stats_note') + '</div>' +
      row(t('s_menu'), m['menu']) +
      row(t('s_ricoh'), ricoh) +
      row(t('s_fuji'), fuji) +
      row(t('s_fuji_old'), m['dl-fuji-old']) +
      row(t('s_sharp'), sharp) +
      row(t('s_canon'), canon) +
      row(t('s_konica'), konica) +
      row(t('s_auto'), m['auto-driver']) +
      row(t('s_lan'), m['lan-scan']) +
      row(t('s_ftp'), m['ftp']) +
      row(t('s_smb'), m['smb']) +
      row(t('s_s2f'), m['scan2folder']) +
      row(t('s_box'), m['filebox']) +
      row(t('s_tools'), m['dl-tools']) +
      row(t('s_pc'), m['dl-pc']) +
      row(t('s_okfail'), ok + ' / ' + fail);
  }
  setLang(detectLang(), false);
  (function loadStats() {
    var base = 'https://abacus.jasoncameron.dev/get/lanyen-de/';
    var keys = [
      'menu',
      'cloud-ricoh', 'cloud-fuji', 'cloud-sharp', 'cloud-canon', 'cloud-konica',
      'dl-ricoh', 'dl-fuji', 'dl-fuji-old', 'dl-sharp',
      'auto-driver', 'lan-scan',
      'ftp', 'smb', 'scan2folder',
      'filebox', 'dl-tools', 'dl-pc',
      'install-ok-ricoh', 'install-ok-fuji', 'install-ok-sharp', 'install-ok-canon', 'install-ok-konica',
      'install-fail-ricoh', 'install-fail-fuji', 'install-fail-sharp', 'install-fail-canon', 'install-fail-konica'
    ];
    function get(key) {
      return fetch(base + key, { cache: 'no-store' })
        .then(function (r) { return r.ok ? r.json() : { value: 0 }; })
        .then(function (j) { return (j && typeof j.value === 'number') ? j.value : 0; })
        .catch(function () { return 0; });
    }
    Promise.all(keys.map(get)).then(function (vals) {
      var m = {};
      keys.forEach(function (k, i) { m[k] = vals[i]; });
      renderStats(m);
    }).catch(function () {
      document.getElementById('flg-stats').innerHTML = '<span class="err">' + t('stats_err') + '</span>';
    });
  })();
})();
</script>
</body></html>`;
}
