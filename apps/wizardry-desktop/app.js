(function () {
  var state = {
    appDir: inferAppDir(),
    bridge: false,
    bootReadySent: false,
    activePage: 'home',
    drawerOpen: false,
    settingsOpen: false,
    themeMenuOpen: false,
    theme: 'psionic',
    themes: [],
    logs: [],
    doctor: '',
    doctorKv: {},
    categories: [],
    customRootSpells: [],
    castEntries: [],
    spellActivity: [],
    arcana: [],
    synonyms: [],
    players: [],
    mudStatus: {},
    spellCache: {},
    navRows: [],
    toastTimer: null,
    spellActivityTimer: null,
    spellActivityBusy: false,
    synonymComposerOpen: false,
    startupWindowSized: false,
    windowFitInFlight: false
  };

  var els = {};

  function inferAppDir() {
    try {
      var path = decodeURIComponent(String((window.location && window.location.pathname) || ''));
      if (path && /\/index\.html$/i.test(path)) {
        return path.replace(/\/index\.html$/i, '');
      }
    } catch (_err) {}
    return '.';
  }

  function backendScript() {
    if (state.appDir === '.') {
      return 'scripts/wizardry-desktop-backend.sh';
    }
    return state.appDir + '/scripts/wizardry-desktop-backend.sh';
  }

  function parseKv(blob) {
    var out = {};
    String(blob || '').split('\n').forEach(function (line) {
      var idx = line.indexOf('=');
      if (idx <= 0) {
        return;
      }
      out[line.slice(0, idx)] = line.slice(idx + 1);
    });
    return out;
  }

  function parseTsv(blob) {
    return String(blob || '').trim().split('\n').filter(Boolean).map(function (line) {
      return line.split('\t');
    });
  }

  function parseSpellActivity(blob) {
    return parseTsv(blob).map(function (row) {
      return {
        kind: row[0] || '',
        app: row[1] || 'external',
        pid: row[2] || '',
        ppid: row[3] || '',
        elapsed: row[4] || '',
        target: row[5] || '',
        path: row[6] || '',
        command: row[7] || ''
      };
    });
  }

  function escHtml(text) {
    return String(text == null ? '' : text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function shellQuote(text) {
    return "'" + String(text == null ? '' : text).replace(/'/g, "'\\''") + "'";
  }

  function nowStamp() {
    var date = new Date();
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  }

  function setBootStatus(text) {
    if (els.bootStatus) {
      els.bootStatus.textContent = text;
    }
  }

  function pushLog(title, argv, result, error) {
    var lines = [];
    lines.push('[' + nowStamp() + '] ' + title);
    if (Array.isArray(argv) && argv.length) {
      lines.push('$ ' + argv.map(shellQuote).join(' '));
    }
    if (result && result.stdout) {
      lines.push('');
      lines.push(result.stdout.trimEnd());
    }
    if (result && result.stderr) {
      lines.push('');
      lines.push(result.stderr.trimEnd());
    }
    if (result && typeof result.exit_code !== 'undefined') {
      lines.push('');
      lines.push('exit ' + result.exit_code);
    }
    if (error) {
      lines.push('');
      lines.push('error: ' + String(error.message || error));
    }
    state.logs.unshift(lines.join('\n').trim());
    state.logs = state.logs.slice(0, 160);
    renderLogs();
  }

  function renderLogs() {
    if (!els.activityLog) {
      return;
    }
    els.activityLog.textContent = state.logs.length ? state.logs.join('\n\n') : 'Waiting for activity.';
  }

  function requestRender() {
    return Promise.resolve(render()).catch(function (error) {
      console.error(error);
      toast(error.message || 'Render failed');
    });
  }

  async function execArgv(argv, options) {
    options = options || {};
    if (!(window.wizardry && window.wizardry.exec)) {
      throw new Error('wizardry bridge unavailable; run this app in the native host');
    }
    state.bridge = true;
    updateBridgePill();
    try {
      var result = await window.wizardry.exec(argv);
      if (!options.quiet) {
        pushLog(options.title || 'Bridge command', argv, result);
      }
      if (typeof result.exit_code !== 'undefined' && result.exit_code !== 0) {
        throw new Error(String(result.stderr || result.stdout || 'command failed').trim());
      }
      return result;
    } catch (error) {
      if (!options.quiet) {
        pushLog(options.title || 'Bridge command', argv, null, error);
      }
      throw error;
    }
  }

  async function backend(command, args, options) {
    args = args || [];
    return execArgv(['sh', backendScript(), command].concat(args), Object.assign({ title: command }, options || {}));
  }

  function updateBridgePill() {
    if (!els.bridgePill) {
      return;
    }
    els.bridgePill.textContent = state.bridge ? 'Bridge: connected' : 'Bridge: offline';
  }

  function toast(message) {
    if (!els.toast) {
      return;
    }
    els.toast.textContent = message;
    els.toast.classList.add('show');
    window.clearTimeout(state.toastTimer);
    state.toastTimer = window.setTimeout(function () {
      els.toast.classList.remove('show');
    }, 2200);
  }

  async function requestWindowFit() {
    if (state.startupWindowSized || state.windowFitInFlight) {
      return;
    }
    if (!(window.wizardry && typeof window.wizardry.exec === 'function')) {
      return;
    }
    state.windowFitInFlight = true;
    try {
      var doc = document.documentElement;
      var innerWidth = window.innerWidth || 920;
      var innerHeight = window.innerHeight || 760;
      var requiredWidth = Math.max(980, Math.round(Math.max(doc.scrollWidth || 0, innerWidth) + 36));
      var requiredHeight = Math.max(760, Math.round(Math.max(doc.scrollHeight || 0, innerHeight) + 84));
      await execArgv(['__wizardry_host_resize', String(requiredWidth), String(requiredHeight)], { quiet: true });
      state.startupWindowSized = true;
    } catch (_error) {
      return;
    } finally {
      state.windowFitInFlight = false;
    }
  }

  function waitForBridge(timeoutMs) {
    var deadline = Date.now() + (timeoutMs || 1600);
    return new Promise(function (resolve) {
      function poll() {
        if (window.wizardry && typeof window.wizardry.exec === 'function') {
          resolve(true);
          return;
        }
        if (Date.now() >= deadline) {
          resolve(false);
          return;
        }
        window.setTimeout(poll, 40);
      }
      poll();
    });
  }

  async function loadPrefs() {
    try {
      var text = await backend('get-ui-prefs', [], { quiet: true });
      var prefs = parseKv(text.stdout || '');
      if (prefs.theme) {
        state.theme = prefs.theme;
      }
      if (prefs.active_page) {
        state.activePage = prefs.active_page;
      }
      if (els.settingsWorkDir) {
        els.settingsWorkDir.value = prefs.work_dir || '';
      }
      if (els.settingsMudRoom) {
        els.settingsMudRoom.value = prefs.mud_room_path || '';
      }
    } catch (error) {
      console.error(error);
    }
  }

  async function savePref(key, value) {
    try {
      await backend('set-ui-pref', [key, String(value || '')], { quiet: true });
    } catch (error) {
      console.error(error);
      toast(error.message || 'Could not save setting');
    }
  }

  async function loadSnapshot() {
    setBootStatus('Loading wizardry snapshot…');
    var responses = await Promise.all([
      backend('doctor', [], { quiet: true }),
      backend('list-themes', [], { quiet: true }),
      backend('list-categories', [], { quiet: true }),
      backend('list-custom-root-spells', [], { quiet: true }),
      backend('list-cast', [], { quiet: true }),
      backend('list-spell-activity', [], { quiet: true }),
      backend('list-arcana', [], { quiet: true }),
      backend('list-synonyms', [], { quiet: true }),
      backend('list-players', [], { quiet: true }),
      backend('mud-status', [], { quiet: true })
    ]);
    state.doctor = String(responses[0].stdout || '');
    state.doctorKv = parseKv(state.doctor);
    state.themes = parseTsv(String(responses[1].stdout || '')).map(function (row) { return row[0]; }).filter(Boolean);
    state.categories = parseTsv(String(responses[2].stdout || '')).map(function (row) {
      return {
        kind: row[0],
        id: row[1],
        label: row[2],
        count: row[3],
        description: row[4],
        path: row[5]
      };
    });
    state.customRootSpells = parseTsv(String(responses[3].stdout || '')).map(function (row) {
      return { name: row[0], summary: row[1], path: row[2] };
    });
    state.castEntries = parseTsv(String(responses[4].stdout || '')).map(function (row) {
      return { alias: row[0], command: row[1] };
    });
    state.spellActivity = parseSpellActivity(String(responses[5].stdout || ''));
    state.arcana = parseTsv(String(responses[6].stdout || '')).map(function (row) {
      return {
        kind: row[0],
        name: row[1],
        label: row[2],
        status: row[3],
        description: row[4],
        actionKind: row[5],
        actionLabel: row[6]
      };
    });
    state.synonyms = parseTsv(String(responses[7].stdout || '')).map(function (row) {
      return { word: row[0], target: row[1], origin: row[2] };
    });
    state.players = parseTsv(String(responses[8].stdout || '')).map(function (row) {
      return { name: row[0], active: row[1] === '1', path: row[2] };
    });
    state.mudStatus = parseKv(String(responses[9].stdout || ''));
    state.spellCache = {};
    if (els.doctorOutput) {
      els.doctorOutput.textContent = state.doctor.trim() || 'No backend output.';
    }
    if (els.settingsWorkDir && !els.settingsWorkDir.value) {
      els.settingsWorkDir.value = state.doctorKv.work_dir || '';
    }
    if (els.settingsMudRoom && !els.settingsMudRoom.value) {
      els.settingsMudRoom.value = state.mudStatus.room_path || '';
    }
    buildNavRows();
    ensureActivePage();
    renderThemeMenu();
    applyTheme(state.theme, true);
  }

  function buildNavRows() {
    var guided = [
      { id: 'home', label: 'Main Menu', meta: 'Main menu map', group: 'Guided Panels' },
      { id: 'cast', label: 'Cast', meta: String(state.castEntries.length || 0), group: 'Guided Panels' },
      { id: 'spellbook', label: 'Spellbook', meta: String(state.synonyms.length || 0), group: 'Guided Panels' },
      { id: 'arcana', label: 'Arcana', meta: String(state.arcana.length || 0), group: 'Guided Panels' },
      { id: 'computer', label: 'Computer', meta: 'System flows', group: 'Guided Panels' },
      { id: 'mud', label: 'MUD', meta: state.players.length ? String(state.players.length) : '', group: 'Guided Panels' }
    ];
    var desktopFeatures = [
      { id: 'spell-activity', label: 'Casting Watch', meta: String(state.spellActivity.length || 0), group: 'Desktop Features' }
    ];
    var builtin = state.categories.filter(function (item) { return item.kind === 'builtin'; }).map(function (item) {
      return { id: 'builtin:' + item.id, label: item.label, meta: item.count, group: 'Spell Categories' };
    });
    var custom = state.categories.filter(function (item) { return item.kind === 'custom'; }).map(function (item) {
      return { id: 'custom:' + item.id, label: item.label, meta: item.count, group: 'Custom Categories' };
    });
    state.navRows = guided.concat(desktopFeatures, builtin, custom);
  }

  function ensureActivePage() {
    var known = {};
    state.navRows.forEach(function (row) {
      known[row.id] = true;
    });
    if (!known[state.activePage]) {
      state.activePage = 'home';
    }
    savePref('active_page', state.activePage);
  }

  function pageMeta(pageId) {
    if (pageId === 'home') {
      return {
        eyebrow: 'Main Menu',
        title: 'Wizardry Desktop',
        subtitle: 'The `menu` command translated into persistent panels, plus direct access to every spell category.'
      };
    }
    if (pageId === 'cast') {
      return {
        eyebrow: 'Cast',
        title: 'Memorized Spells',
        subtitle: 'Your cast menu, without needing to reopen the terminal menu loop.'
      };
    }
    if (pageId === 'spell-activity') {
      return {
        eyebrow: 'Desktop Feature',
        title: 'Casting Watch',
        subtitle: 'A Wizardry Desktop utility for watching running spells and app backends, with source app attribution inferred from the standard backend and host paths.'
      };
    }
    if (pageId === 'spellbook') {
      return {
        eyebrow: 'Spellbook',
        title: 'Scribe And Organize',
        subtitle: 'Create categories, scribe custom spells, and maintain synonyms from one page.'
      };
    }
    if (pageId === 'arcana') {
      return {
        eyebrow: 'Arcana',
        title: 'Installable Add-Ons',
        subtitle: 'Optional software and support surfaces discovered from Wizardry’s install menu.'
      };
    }
    if (pageId === 'computer') {
      return {
        eyebrow: 'Computer',
        title: 'System Maintenance',
        subtitle: 'Services, users, networking, updates, and power actions from the system menu family.'
      };
    }
    if (pageId === 'mud') {
      return {
        eyebrow: 'MUD',
        title: 'Adventure Console',
        subtitle: 'Player identity, room controls, portals, and feature toggles backed by Wizardry’s MUD commands.'
      };
    }
    var split = pageId.split(':');
    if (split.length === 2) {
      var category = state.categories.find(function (item) {
        return item.kind === split[0] && item.id === split[1];
      });
      if (category) {
        return {
          eyebrow: split[0] === 'builtin' ? 'Spell Category' : 'Custom Category',
          title: category.label,
          subtitle: category.description || 'Wizardry spell page.'
        };
      }
    }
    return { eyebrow: 'Wizardry', title: 'Wizardry Desktop', subtitle: '' };
  }

  function renderNav() {
    var groupOrder = ['Guided Panels', 'Desktop Features', 'Spell Categories', 'Custom Categories'];
    var html = '';
    groupOrder.forEach(function (groupName) {
      var rows = state.navRows.filter(function (row) { return row.group === groupName; });
      if (!rows.length) {
        return;
      }
      html += '<section class="nav-group">';
      html += '<p class="nav-group-title">' + escHtml(groupName) + '</p>';
      rows.forEach(function (row) {
        html += '<button class="nav-row' + (state.activePage === row.id ? ' active' : '') + '" type="button" role="option" aria-selected="' + (state.activePage === row.id ? 'true' : 'false') + '" data-page="' + escHtml(row.id) + '">';
        html += '<span class="nav-row-label">' + escHtml(row.label) + '</span>';
        html += '<span class="nav-row-meta">' + escHtml(row.meta || '') + '</span>';
        html += '</button>';
      });
      html += '</section>';
    });
    els.navGroups.innerHTML = html;
    Array.prototype.forEach.call(els.navGroups.querySelectorAll('[data-page]'), function (button) {
      button.addEventListener('click', function () {
        state.activePage = button.getAttribute('data-page') || 'home';
        if (state.activePage !== 'spellbook') {
          state.synonymComposerOpen = false;
        }
        savePref('active_page', state.activePage);
        requestRender();
      });
    });
  }

  function applyTheme(themeName, skipSave) {
    if (!themeName) {
      return;
    }
    state.theme = themeName;
    if (els.themeStylesheet) {
      els.themeStylesheet.href = 'themes/' + themeName + '.css?v=wizardry-desktop-20260317e';
    }
    if (els.themePickerBtn) {
      els.themePickerBtn.textContent = themeName.charAt(0).toUpperCase() + themeName.slice(1);
    }
    if (!skipSave) {
      savePref('theme', themeName);
    }
    renderThemeMenu();
  }

  function renderThemeMenu() {
    if (!els.themePickerList) {
      return;
    }
    els.themePickerList.innerHTML = state.themes.map(function (themeName) {
      return '<button class="menu-item' + (themeName === state.theme ? ' active' : '') + '" type="button" data-theme="' + escHtml(themeName) + '">' + escHtml(themeName.charAt(0).toUpperCase() + themeName.slice(1)) + '</button>';
    }).join('');
    Array.prototype.forEach.call(els.themePickerList.querySelectorAll('[data-theme]'), function (button) {
      button.addEventListener('click', function () {
        applyTheme(button.getAttribute('data-theme'));
        closeThemeMenu();
      });
    });
  }

  function openThemeMenu() {
    state.themeMenuOpen = true;
    els.themePickerMenu.classList.remove('hidden');
    els.themePickerBtn.setAttribute('aria-expanded', 'true');
  }

  function closeThemeMenu() {
    state.themeMenuOpen = false;
    els.themePickerMenu.classList.add('hidden');
    els.themePickerBtn.setAttribute('aria-expanded', 'false');
  }

  function cycleTheme(direction) {
    if (!state.themes.length) {
      return;
    }
    var index = state.themes.indexOf(state.theme);
    if (index < 0) {
      index = 0;
    }
    index = (index + direction + state.themes.length) % state.themes.length;
    applyTheme(state.themes[index]);
  }

  function openSettings() {
    state.settingsOpen = true;
    els.settingsModal.classList.remove('hidden');
  }

  function closeSettings() {
    state.settingsOpen = false;
    els.settingsModal.classList.add('hidden');
  }

  function syncDrawer() {
    document.body.classList.toggle('drawer-open', state.drawerOpen);
    els.activityToggle.setAttribute('aria-expanded', state.drawerOpen ? 'true' : 'false');
  }

  function toggleDrawer() {
    state.drawerOpen = !state.drawerOpen;
    syncDrawer();
  }

  async function loadCategoryPage(pageId) {
    if (state.spellCache[pageId]) {
      return state.spellCache[pageId];
    }
    var split = pageId.split(':');
    var result = await backend('list-spells', [split[0], split[1]], { quiet: true });
    state.spellCache[pageId] = parseTsv(String(result.stdout || '')).map(function (row) {
      return {
        name: row[0],
        origin: row[1],
        summary: row[2],
        memorized: row[3] === '1',
        path: row[4]
      };
    });
    return state.spellCache[pageId];
  }

  async function runAndRefresh(command, args, title) {
    await backend(command, args, { title: title || command });
    await loadSnapshot();
    await requestRender();
  }

  async function loadSpellActivity() {
    var result = await backend('list-spell-activity', [], { quiet: true });
    state.spellActivity = parseSpellActivity(String(result.stdout || ''));
  }

  function countSpellActivity(kindPrefix) {
    return state.spellActivity.filter(function (item) {
      return String(item.kind || '').indexOf(kindPrefix) === 0;
    }).length;
  }

  function countDistinctActivityApps() {
    var seen = {};
    state.spellActivity.forEach(function (item) {
      var name = item.app || 'external';
      seen[name] = true;
    });
    return Object.keys(seen).length;
  }

  function activityKindLabel(kind) {
    if (kind === 'builtin-spell') {
      return 'Built-in spell';
    }
    if (kind === 'home-spell') {
      return 'Home spell';
    }
    if (kind === 'app-backend') {
      return 'App backend';
    }
    return 'Activity';
  }

  function renderSpellActivity() {
    var spellCount = countSpellActivity('builtin') + countSpellActivity('home');
    var backendCount = state.spellActivity.filter(function (item) { return item.kind === 'app-backend'; }).length;
    var appCount = countDistinctActivityApps();
    var html = '';
    html += '<section class="hero">';
    html += '<div class="card-copy"><h3>Live Spell Monitor</h3><p class="subtle-copy">This watches the current process table. Built-in spells show up when the running command resolves into `' + escHtml(state.doctorKv.wizardry_dir || '~/.wizardry') + '/spells` or `~/spells`; app-backend rows show the standard app-internal analogue path.</p></div>';
    html += '<div class="stat-grid">';
    html += '<div class="stat-card"><strong>' + escHtml(String(spellCount)) + '</strong><span>Active spells</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(String(backendCount)) + '</strong><span>App backends</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(String(appCount)) + '</strong><span>Apps represented</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(String(state.spellActivity.length)) + '</strong><span>Total rows</span></div>';
    html += '</div>';
    html += '<div class="button-row"><button id="refresh-spell-activity-btn" class="action-btn" type="button">Refresh now</button><span class="pill">Auto refresh: 2.2s while visible</span></div>';
    html += '</section>';

    html += '<section class="card list-card"><div class="list-head"><h3>Active Casting And App Commands</h3><p class="subtle-copy">Rows are live process snapshots. If a wizardry app only uses its own backend analogue, you will see the backend row but not a spell row.</p></div><div class="list-body">';
    if (!state.spellActivity.length) {
      html += '<div class="list-row"><p class="empty-state">No active Wizardry spells or app backends were detected in the current process table.</p></div>';
    } else {
      state.spellActivity.forEach(function (item) {
        var subtitle = (item.app || 'external') + ' • ' + (item.elapsed || 'now');
        if (item.path) {
          subtitle += ' • ' + item.path;
        }
        if (item.command) {
          subtitle += ' • ' + item.command;
        }
        html += '<div class="list-row"><div class="row-copy"><span class="row-title">' + escHtml(item.target || item.command || item.kind) + '</span><span class="row-subtitle">' + escHtml(subtitle) + '</span></div><div class="row-actions"><span class="pill">' + escHtml(activityKindLabel(item.kind)) + '</span><span class="pill">pid ' + escHtml(item.pid || '?') + '</span></div></div>';
      });
    }
    html += '</div></section>';
    return html;
  }

  function syncSpellActivityMonitor() {
    if (state.spellActivityTimer) {
      window.clearInterval(state.spellActivityTimer);
      state.spellActivityTimer = null;
    }
    if (state.activePage !== 'spell-activity') {
      return;
    }
    state.spellActivityTimer = window.setInterval(function () {
      if (document.hidden || state.spellActivityBusy) {
        return;
      }
      state.spellActivityBusy = true;
      requestRender().finally(function () {
        state.spellActivityBusy = false;
      });
    }, 2200);
  }

  function renderHome() {
    var hero = '';
    hero += '<section class="hero">';
    hero += '<div class="card-copy"><h3>Main Menu Structure</h3><p class="subtle-copy">The left rail mirrors Wizardry’s main menu first, then expands into discovered spell categories. Desktop-only utilities live in their own rail section.</p></div>';
    hero += '<div class="stat-grid">';
    hero += '<div class="stat-card"><strong>' + escHtml(state.doctorKv.category_count || '0') + '</strong><span>Categories</span></div>';
    hero += '<div class="stat-card"><strong>' + escHtml(state.doctorKv.spell_count || '0') + '</strong><span>Executable spells</span></div>';
    hero += '<div class="stat-card"><strong>' + escHtml(state.doctorKv.memorized_count || '0') + '</strong><span>Memorized</span></div>';
    hero += '<div class="stat-card"><strong>' + escHtml(state.doctorKv.arcana_count || '0') + '</strong><span>Arcana entries</span></div>';
    hero += '</div>';
    hero += '<div class="card-grid">';
    hero += quickCard('Cast', 'Launch your memorized commands without reopening the terminal menu.', 'cast');
    hero += quickCard('Spellbook', 'Scribe, categorize, and alias commands through GUI forms.', 'spellbook');
    hero += quickCard('Arcana', 'Browse the same installable add-ons the install menu exposes.', 'arcana');
    hero += quickCard('Computer', 'System flows from services to shutdown.', 'computer');
    hero += '</div>';
    hero += '</section>';

    var summary = '<section class="card list-card"><div class="list-head"><h3>Resolved Paths</h3><p class="subtle-copy">Desktop prefs and backend roots stay file-backed.</p></div><div class="list-body">';
    summary += infoRow('wizardry dir', state.doctorKv.wizardry_dir || '');
    summary += infoRow('spellbook dir', state.doctorKv.spellbook_dir || '');
    summary += infoRow('working dir', state.doctorKv.work_dir || '');
    summary += infoRow('MUD room', state.doctorKv.mud_room_path || '');
    summary += '</div></section>';
    return hero + summary;
  }

  function quickCard(title, copy, pageId) {
    return '<article class="card"><div class="card-copy"><h4>' + escHtml(title) + '</h4><p class="subtle-copy">' + escHtml(copy) + '</p></div><div class="button-row"><button class="action-btn" type="button" data-nav="' + escHtml(pageId) + '">Open</button></div></article>';
  }

  function infoRow(label, value) {
    return '<div class="list-row"><div class="row-copy"><span class="row-title">' + escHtml(label) + '</span><span class="row-subtitle">' + escHtml(value) + '</span></div></div>';
  }

  function renderCast() {
    var distinctCommands = {};
    state.castEntries.forEach(function (entry) {
      distinctCommands[String(entry.command || '')] = true;
    });
    var html = '';
    html += '<section class="hero">';
    html += '<div class="card-copy"><h3>Cast Menu Overview</h3><p class="subtle-copy">Memorized spells are stable aliases for commands you want to launch quickly. This panel stays focused on the saved cast list rather than live process activity.</p></div>';
    html += '<div class="stat-grid">';
    html += '<div class="stat-card"><strong>' + escHtml(String(state.castEntries.length)) + '</strong><span>Memorized aliases</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(String(Object.keys(distinctCommands).filter(Boolean).length)) + '</strong><span>Distinct commands</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(state.castEntries.length ? state.castEntries[0].alias : 'none') + '</strong><span>First alias</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(state.castEntries.length ? 'ready' : 'empty') + '</strong><span>Cast state</span></div>';
    html += '</div>';
    html += '<div class="button-row"><button class="action-btn" type="button" data-nav="spellbook">Open Spellbook</button><button class="action-btn" type="button" data-nav="home">Back to main menu</button></div>';
    html += '</section>';

    html += '<section class="card list-card"><div class="list-head"><h3>Memorized Spells</h3><p class="subtle-copy">Wizardry stores each memorized command as an alias plus the command text it will execute.</p></div><div class="list-body">';
    if (!state.castEntries.length) {
      html += '<div class="list-row"><p class="empty-state">No memorized spells yet. Use a category page or the spellbook panel to memorize one.</p></div>';
    } else {
      state.castEntries.forEach(function (entry) {
        html += '<div class="list-row">';
        html += '<div class="row-copy"><span class="row-title">' + escHtml(entry.alias) + '</span><span class="row-subtitle">' + escHtml(entry.command) + '</span></div>';
        html += '<div class="row-actions"><button class="action-btn" type="button" data-run-cast="' + escHtml(entry.alias) + '">Cast</button><button class="action-btn" type="button" data-forget="' + escHtml(entry.alias) + '">Forget</button></div>';
        html += '</div>';
      });
    }
    html += '</div></section>';
    return html;
  }

  function renderSpellbook() {
    var options = state.categories.filter(function (item) { return item.kind === 'builtin' || item.kind === 'custom'; }).map(function (item) {
      return '<option value="' + escHtml(item.id) + '">' + escHtml(item.label) + '</option>';
    }).join('');
    var html = '';
    html += '<section class="section-grid">';
    html += '<article class="card"><div class="card-copy"><h4>New Category</h4><p class="subtle-copy">Create a custom spellbook folder like the spellbook menu does.</p></div><div class="inline-form"><input id="create-category-name" type="text" spellcheck="false" placeholder="rituals"><button id="create-category-btn" class="action-btn" type="button">Create</button></div></article>';
    html += '<article class="card settings-card-wide"><div class="card-copy"><h4>Scribe Spell</h4><p class="subtle-copy">Write a custom executable in your spellbook without dropping to the terminal.</p></div><div class="field-row"><input id="scribe-name" type="text" spellcheck="false" placeholder="ship-it"><select id="scribe-category"><option value="">Spellbook root</option>' + options + '</select><input id="scribe-command" type="text" spellcheck="false" placeholder="git status --short"><button id="scribe-btn" class="action-btn" type="button">Scribe</button></div></article>';
    html += '</section>';

    html += '<section class="card list-card"><div class="list-head"><h3>Synonyms</h3><p class="subtle-copy">Custom entries override defaults when both use the same word.</p></div><div class="list-body">';
    if (!state.synonyms.length) {
      html += '<div class="list-row"><p class="empty-state">No synonyms discovered.</p></div>';
    } else {
      state.synonyms.forEach(function (item) {
        html += '<div class="list-row synonym-row"><div class="row-copy synonym-copy"><span class="row-title">' + escHtml(item.word) + '</span><span class="synonym-command">' + escHtml(item.target) + '</span><span class="synonym-meta">' + escHtml(item.origin) + '</span></div><div class="row-actions synonym-actions">';
        if (item.origin === 'custom') {
          html += '<button class="action-btn" type="button" data-delete-synonym="' + escHtml(item.word) + '">Delete</button>';
        }
        html += '</div></div>';
      });
    }
    html += '</div><div class="list-foot">';
    html += '<div class="button-row synonym-footer-row"><button id="open-synonym-composer-btn" class="icon-btn list-plus-btn" type="button" aria-label="Add synonym" title="Add synonym">+</button><p class="subtle-copy">Add a new synonym under the existing list.</p></div>';
    if (state.synonymComposerOpen) {
      html += '<div class="inline-reveal-card"><div class="card-copy"><h4>New Synonym</h4><p class="subtle-copy">Map a short word to an existing spell or command target.</p></div><div class="field-row"><input id="synonym-word" type="text" spellcheck="false" placeholder="ll"><input id="synonym-target" type="text" spellcheck="false" placeholder="ls -l"><button id="add-synonym-btn" class="action-btn" type="button">Add</button><button id="cancel-synonym-btn" class="action-btn" type="button">Cancel</button></div></div>';
    }
    html += '</div></section>';

    html += '<section class="card list-card"><div class="list-head"><h3>Custom Spell Root</h3><p class="subtle-copy">Executable files sitting directly in your spellbook root.</p></div><div class="list-body">';
    if (!state.customRootSpells.length) {
      html += '<div class="list-row"><p class="empty-state">No custom root spells discovered.</p></div>';
    } else {
      state.customRootSpells.forEach(function (item) {
        html += spellRow(item.name, item.summary, 'custom-root', false);
      });
    }
    html += '</div></section>';

    html += '<section class="card list-card"><div class="list-head"><h3>Categories</h3><p class="subtle-copy">Built-in categories from `spells/` plus custom folders from your spellbook.</p></div><div class="list-body">';
    state.categories.forEach(function (item) {
      html += '<div class="list-row"><div class="row-copy"><span class="row-title">' + escHtml(item.label) + '</span><span class="row-subtitle">' + escHtml(item.description) + '</span></div><div class="row-actions"><span class="pill">' + escHtml(item.count) + ' spells</span><button class="action-btn" type="button" data-nav="' + escHtml(item.kind + ':' + item.id) + '">Open</button></div></div>';
    });
    html += '</div></section>';
    return html;
  }

  function renderArcana() {
    var installable = state.arcana.filter(function (item) { return item.kind === 'entry'; });
    var utility = state.arcana.filter(function (item) { return item.kind !== 'entry'; });
    var menuCount = installable.filter(function (item) { return item.actionKind === 'menu'; }).length;
    var installCount = installable.filter(function (item) { return item.actionKind === 'install'; }).length;
    var html = '';
    html += '<section class="hero">';
    html += '<div class="card-copy"><h3>Install Menu Structure</h3><p class="subtle-copy">This page follows the POSIX `install-menu`: the same preferred order, the same renamed labels, the same status text, and the same special import utility row.</p></div>';
    html += '<div class="stat-grid">';
    html += '<div class="stat-card"><strong>' + escHtml(String(installable.length)) + '</strong><span>Arcana entries</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(String(menuCount)) + '</strong><span>Submenus</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(String(installCount)) + '</strong><span>Direct installers</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(String(utility.length)) + '</strong><span>Utility items</span></div>';
    html += '</div>';
    html += '</section>';

    html += '<section class="card list-card"><div class="list-head"><h3>Install Menu</h3><p class="subtle-copy">Entries are ordered and labeled the same way as the shell install menu, with submenu actions preserved where Wizardry defines them.</p></div><div class="list-body">';
    if (!installable.length) {
      html += '<div class="list-row"><p class="empty-state">No installable arcana were discovered.</p></div>';
    } else {
      installable.forEach(function (item) {
        html += '<div class="list-row"><div class="row-copy"><span class="row-title">' + escHtml(item.label || item.name) + '</span><span class="row-subtitle">' + escHtml(item.description) + '</span></div><div class="row-actions">';
        if (item.status) {
          html += '<span class="pill">' + escHtml(item.status) + '</span>';
        }
        html += '<span class="pill">' + escHtml(item.actionKind === 'menu' ? 'submenu' : item.actionKind) + '</span>';
        if (item.actionKind !== 'pending') {
          html += '<button class="action-btn" type="button" data-run-arcana="' + escHtml(item.name) + '">' + escHtml(item.actionLabel || 'Run') + '</button>';
        }
        html += '</div></div>';
      });
    }
    html += '</div>';
    if (utility.length) {
      html += '<div class="list-foot">';
      utility.forEach(function (item) {
        html += '<div class="list-row"><div class="row-copy"><span class="row-title">' + escHtml(item.label || item.name) + '</span><span class="row-subtitle">' + escHtml(item.description) + '</span></div><div class="row-actions">';
        html += '<span class="pill">' + escHtml(item.actionKind) + '</span>';
        html += '<button class="action-btn" type="button" data-run-arcana="' + escHtml(item.name) + '">' + escHtml(item.actionLabel || 'Run') + '</button>';
        html += '</div></div>';
      });
      html += '</div>';
    }
    html += '</section>';
    return html;
  }

  function renderComputer() {
    var html = '';
    html += '<section class="section-grid">';
    html += '<article class="card"><div class="card-copy"><h4>System</h4><p class="subtle-copy">The high-level actions from `system-menu`.</p></div><div class="button-grid">';
    html += actionButton('Update all', 'data-system', 'update-all');
    html += actionButton('Update wizardry', 'data-system', 'update-wizardry');
    html += actionButton('Verify POSIX', 'data-system', 'verify-posix');
    html += actionButton('Test spells', 'data-system', 'test-magic');
    html += actionButton('Profile tests', 'data-system', 'profile-tests');
    html += '</div></article>';

    html += '<article class="card"><div class="card-copy"><h4>Network</h4><p class="subtle-copy">The current network menu is small and direct.</p></div><div class="button-row">';
    html += actionButton('Configure static IP', 'data-network', 'static-ip');
    html += actionButton('Configure DHCP', 'data-network', 'dhcp');
    html += '</div></article>';
    html += '</section>';

    html += '<section class="card"><div class="card-copy"><h4>Services</h4><p class="subtle-copy">Provide a unit name and run the underlying service spell directly.</p></div><div class="field-row"><input id="service-unit" type="text" spellcheck="false" placeholder="nginx.service">';
    ['start', 'stop', 'restart', 'enable', 'disable', 'status', 'installed', 'remove'].forEach(function (name) {
      html += actionButton(titleCase(name), 'data-service', name);
    });
    html += '</div><p class="muted-note">`install-service-template` still expects a longer interactive flow, so this page focuses on the unit-based actions.</p></section>';

    html += '<section class="card"><div class="card-copy"><h4>Users And Groups</h4><p class="subtle-copy">Most actions require `sudo`, so results and permission failures are surfaced in the activity drawer.</p></div><div class="field-row"><input id="user-name" type="text" spellcheck="false" placeholder="alice"><input id="group-name" type="text" spellcheck="false" placeholder="blog-admin"></div><div class="button-grid">';
    html += actionButton('List users', 'data-user', 'list-users');
    html += actionButton('List groups', 'data-user', 'list-groups');
    html += actionButton('My groups', 'data-user', 'my-groups');
    html += actionButton('User groups', 'data-user', 'user-groups');
    html += actionButton('Group members', 'data-user', 'group-members');
    html += actionButton('Create group', 'data-user', 'create-group');
    html += actionButton('Delete group', 'data-user', 'delete-group');
    html += actionButton('Join group', 'data-user', 'join-group');
    html += actionButton('Leave group', 'data-user', 'leave-group');
    html += actionButton('Add user to group', 'data-user', 'add-user-to-group');
    html += actionButton('Remove user from group', 'data-user', 'remove-user-from-group');
    html += actionButton('Create user', 'data-user', 'create-user');
    html += actionButton('Delete user', 'data-user', 'delete-user');
    html += '</div></section>';

    html += '<section class="card"><div class="card-copy"><h4>Power</h4><p class="subtle-copy">These are host-level actions. The confirmation checkbox must be enabled before a power command can run.</p></div><label class="confirm-box"><input id="power-confirm" type="checkbox">I understand these actions affect the host machine.</label><div class="button-grid">';
    ['restart', 'shutdown', 'logout', 'sleep', 'hibernate', 'force-restart', 'force-shutdown', 'force-logout'].forEach(function (name) {
      html += actionButton(titleCase(name), 'data-power', name);
    });
    html += '</div></section>';
    return html;
  }

  function renderMud() {
    var html = '';
    html += '<section class="hero">';
    html += '<div class="card-copy"><h3>MUD Runtime</h3><p class="subtle-copy">This page translates the MUD play menu and the MUD settings toggles into direct controls.</p></div>';
    html += '<div class="stat-grid">';
    html += '<div class="stat-card"><strong>' + escHtml(state.mudStatus.current_player || 'none') + '</strong><span>Player</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(state.mudStatus.room_path || 'unset') + '</strong><span>Room path</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(state.mudStatus.portal_location || 'n/a') + '</strong><span>Portal chamber</span></div>';
    html += '<div class="stat-card"><strong>' + escHtml(state.mudStatus.onion_address || 'off') + '</strong><span>Onion</span></div>';
    html += '</div>';
    html += '</section>';

    html += '<section class="card"><div class="card-copy"><h4>Room Controls</h4><p class="subtle-copy">Room-aware actions use the persisted MUD room path.</p></div><div class="field-row"><input id="mud-room-input" type="text" spellcheck="false" value="' + escHtml(state.mudStatus.room_path || '') + '"><button id="mud-room-save" class="action-btn" type="button">Set room</button><button class="action-btn" type="button" data-mud="goto-home">Home</button><button class="action-btn" type="button" data-mud="goto-portal">Portal chamber</button><input id="mud-marker" type="text" spellcheck="false" value="1" placeholder="marker"><button id="mud-goto-marker" class="action-btn" type="button">Jump to marker</button></div><div class="button-row"><button class="action-btn" type="button" data-mud="look">Look around</button><button class="action-btn" type="button" data-mud="stats">Stats</button><button class="action-btn" type="button" data-mud="player-status">Player status</button><button class="action-btn" type="button" data-mud="list-players">List players</button></div></section>';

    html += '<section class="card"><div class="card-copy"><h4>Speak</h4><p class="subtle-copy">`say` appends to the room log inside the selected room directory.</p></div><div class="field-row"><input id="mud-message" type="text" spellcheck="false" placeholder="Hello, adventurers"><button id="mud-say-btn" class="action-btn" type="button">Say</button></div></section>';

    html += '<section class="card"><div class="card-copy"><h4>Player Identity</h4><p class="subtle-copy">Pick an existing SSH-backed player or generate a new one.</p></div><div class="field-row"><select id="mud-player-select"><option value="">Select player</option>' + state.players.map(function (player) { return '<option value="' + escHtml(player.name) + '"' + (player.active ? ' selected' : '') + '>' + escHtml(player.name) + '</option>'; }).join('') + '</select><button id="mud-set-player-btn" class="action-btn" type="button">Set player</button><input id="mud-new-player" type="text" spellcheck="false" placeholder="new_player"><button id="mud-new-player-btn" class="action-btn" type="button">Create</button></div></section>';

    html += '<section class="card"><div class="card-copy"><h4>Portals</h4><p class="subtle-copy">Open or close remote worlds with the same `open-portal` and `close-portal` spells.</p></div><div class="field-row"><input id="portal-player" type="text" spellcheck="false" placeholder="player"><input id="portal-server" type="text" spellcheck="false" placeholder="server or .onion"><input id="portal-path" type="text" spellcheck="false" placeholder="~/world"><input id="portal-mount" type="text" spellcheck="false" placeholder="/custom/mount"><label class="confirm-box"><input id="portal-tor" type="checkbox">Use Tor</label><button id="open-portal-btn" class="action-btn" type="button">Open portal</button><button id="close-portal-btn" class="action-btn" type="button">Close portal</button></div></section>';

    html += '<section class="card"><div class="card-copy"><h4>Feature Toggles</h4><p class="subtle-copy">These map directly to the MUD settings menu toggles.</p></div><div class="button-grid">';
    html += mudToggleButton('Parse', 'parse', state.mudStatus.parse_enabled === '1');
    html += mudToggleButton('Show in main menu', 'mud-menu', state.mudStatus.mud_menu_enabled === '1');
    html += mudToggleButton('Look on directory change', 'cd-look', state.mudStatus.cd_look_enabled === '1');
    html += mudToggleButton('Listen on directory change', 'cd-listen', state.mudStatus.cd_listen_enabled === '1');
    html += mudToggleButton('Avatar', 'avatar', state.mudStatus.avatar_enabled === '1');
    html += mudToggleButton('Touch hook', 'touch-hook', state.mudStatus.touch_hook_enabled === '1');
    html += mudToggleButton('Tor hosting', 'tor', state.mudStatus.tor_enabled === '1');
    html += actionButton('Enable all', 'data-mud-toggle-all', 'enable');
    html += actionButton('Disable all', 'data-mud-toggle-all', 'disable');
    html += '</div></section>';
    return html;
  }

  function mudToggleButton(label, key, enabled) {
    return '<button class="action-btn" type="button" data-mud-toggle="' + escHtml(key) + '">' + escHtml(label + (enabled ? ' on' : ' off')) + '</button>';
  }

  function renderCategory(pageId) {
    var split = pageId.split(':');
    var spells = state.spellCache[pageId] || [];
    var html = '<section class="card list-card"><div class="list-head"><h3>Category Spells</h3><p class="subtle-copy">Each row exposes the underlying spell directly, plus help and cast-menu integration.</p></div><div class="list-body">';
    if (!spells.length) {
      html += '<div class="list-row"><p class="empty-state">No executable spells were found for this category.</p></div>';
    } else {
      spells.forEach(function (item) {
        html += spellRow(item.name, item.summary, split[0], item.memorized);
      });
    }
    html += '</div></section>';
    return html;
  }

  function spellRow(name, summary, origin, memorized) {
    return '<div class="list-row"><div class="row-copy"><span class="row-title">' + escHtml(name) + '</span><span class="row-subtitle">' + escHtml(summary || 'No summary available.') + ' • ' + escHtml(origin) + '</span></div><div class="row-actions">' + (memorized ? '<span class="pill good">memorized</span>' : '') + '<button class="action-btn" type="button" data-help-spell="' + escHtml(name) + '">Help</button><button class="action-btn" type="button" data-run-spell="' + escHtml(name) + '">Run</button><button class="action-btn" type="button" data-memorize-spell="' + escHtml(name) + '">' + (memorized ? 'Forget' : 'Memorize') + '</button></div></div>';
  }

  function actionButton(label, attr, value) {
    return '<button class="action-btn" type="button" ' + attr + '="' + escHtml(value) + '">' + escHtml(label) + '</button>';
  }

  function titleCase(text) {
    return String(text || '').replace(/(^|-)([a-z])/g, function (_match, prefix, letter) {
      return (prefix === '-' ? ' ' : '') + letter.toUpperCase();
    });
  }

  function bindCommonPageEvents() {
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-nav]'), function (button) {
      button.addEventListener('click', function () {
        state.activePage = button.getAttribute('data-nav') || 'home';
        if (state.activePage !== 'spellbook') {
          state.synonymComposerOpen = false;
        }
        savePref('active_page', state.activePage);
        requestRender();
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-run-cast]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await backend('run-cast', [button.getAttribute('data-run-cast') || ''], { title: 'cast alias' });
        } catch (error) {
          toast(error.message || 'Cast failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-forget]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await runAndRefresh('forget', [button.getAttribute('data-forget') || ''], 'forget');
          toast('Removed from cast');
        } catch (error) {
          toast(error.message || 'Forget failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-run-spell]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await backend('run-spell', [button.getAttribute('data-run-spell') || ''], { title: 'run spell' });
        } catch (error) {
          toast(error.message || 'Spell failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-help-spell]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await backend('spell-help', [button.getAttribute('data-help-spell') || ''], { title: 'spell help' });
        } catch (error) {
          toast(error.message || 'Help failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-memorize-spell]'), function (button) {
      button.addEventListener('click', async function () {
        var spell = button.getAttribute('data-memorize-spell') || '';
        var alreadyMemorized = button.textContent === 'Forget';
        try {
          await runAndRefresh(alreadyMemorized ? 'forget' : 'memorize', [spell], alreadyMemorized ? 'forget spell' : 'memorize spell');
          toast(alreadyMemorized ? 'Removed from cast' : 'Added to cast');
        } catch (error) {
          toast(error.message || 'Memorize failed');
        }
      });
    });
  }

  function bindSpellActivityPageEvents() {
    var refreshBtn = document.getElementById('refresh-spell-activity-btn');
    if (refreshBtn) {
      refreshBtn.addEventListener('click', async function () {
        try {
          state.spellActivityBusy = true;
          await loadSpellActivity();
          await render();
          toast('Casting watch refreshed');
        } catch (error) {
          toast(error.message || 'Refresh failed');
        } finally {
          state.spellActivityBusy = false;
        }
      });
    }
  }

  function bindSpellbookPageEvents() {
    var createBtn = document.getElementById('create-category-btn');
    if (createBtn) {
      createBtn.addEventListener('click', async function () {
        var input = document.getElementById('create-category-name');
        try {
          await runAndRefresh('create-category', [String(input.value || '').trim()], 'create category');
          input.value = '';
          toast('Category created');
        } catch (error) {
          toast(error.message || 'Category creation failed');
        }
      });
    }
    var openSynonymComposerBtn = document.getElementById('open-synonym-composer-btn');
    if (openSynonymComposerBtn) {
      openSynonymComposerBtn.addEventListener('click', function () {
        state.synonymComposerOpen = !state.synonymComposerOpen;
        requestRender().then(function () {
          if (state.synonymComposerOpen) {
            var word = document.getElementById('synonym-word');
            if (word) {
              word.focus();
            }
          }
        });
      });
    }
    var cancelSynonymBtn = document.getElementById('cancel-synonym-btn');
    if (cancelSynonymBtn) {
      cancelSynonymBtn.addEventListener('click', function () {
        state.synonymComposerOpen = false;
        requestRender();
      });
    }
    var addSynonymBtn = document.getElementById('add-synonym-btn');
    if (addSynonymBtn) {
      var submitSynonym = async function () {
        var word = document.getElementById('synonym-word');
        var target = document.getElementById('synonym-target');
        try {
          await runAndRefresh('synonym', ['add', String(word.value || '').trim(), String(target.value || '').trim()], 'add synonym');
          state.synonymComposerOpen = false;
          await requestRender();
          toast('Synonym added');
        } catch (error) {
          toast(error.message || 'Synonym failed');
        }
      };
      addSynonymBtn.addEventListener('click', submitSynonym);
      ['synonym-word', 'synonym-target'].forEach(function (id) {
        var input = document.getElementById(id);
        if (!input) {
          return;
        }
        input.addEventListener('keydown', function (event) {
          if (event.key === 'Enter') {
            event.preventDefault();
            submitSynonym();
          }
        });
      });
    }
    var scribeBtn = document.getElementById('scribe-btn');
    if (scribeBtn) {
      scribeBtn.addEventListener('click', async function () {
        var name = document.getElementById('scribe-name');
        var category = document.getElementById('scribe-category');
        var command = document.getElementById('scribe-command');
        try {
          await runAndRefresh('scribe-spell', [String(name.value || '').trim(), String(category.value || '').trim(), String(command.value || '').trim()], 'scribe spell');
          name.value = '';
          command.value = '';
          toast('Spell written');
        } catch (error) {
          toast(error.message || 'Scribing failed');
        }
      });
    }
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-delete-synonym]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await runAndRefresh('synonym', ['delete', button.getAttribute('data-delete-synonym') || ''], 'delete synonym');
          toast('Synonym deleted');
        } catch (error) {
          toast(error.message || 'Delete failed');
        }
      });
    });
  }

  function bindComputerPageEvents() {
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-system]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await backend('system', [button.getAttribute('data-system') || ''], { title: 'system action' });
        } catch (error) {
          toast(error.message || 'System action failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-network]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await backend('network', [button.getAttribute('data-network') || ''], { title: 'network action' });
        } catch (error) {
          toast(error.message || 'Network action failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-service]'), function (button) {
      button.addEventListener('click', async function () {
        var unit = document.getElementById('service-unit');
        try {
          await backend('service', [button.getAttribute('data-service') || '', String((unit && unit.value) || '').trim()], { title: 'service action' });
        } catch (error) {
          toast(error.message || 'Service action failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-user]'), function (button) {
      button.addEventListener('click', async function () {
        var user = document.getElementById('user-name');
        var group = document.getElementById('group-name');
        try {
          await backend('user', [button.getAttribute('data-user') || '', String((user && user.value) || '').trim(), String((group && group.value) || '').trim()], { title: 'user action' });
        } catch (error) {
          toast(error.message || 'User action failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-power]'), function (button) {
      button.addEventListener('click', async function () {
        var confirm = document.getElementById('power-confirm');
        if (!confirm || !confirm.checked) {
          toast('Enable the host-action confirmation checkbox first');
          return;
        }
        try {
          await backend('power', [button.getAttribute('data-power') || ''], { title: 'power action' });
        } catch (error) {
          toast(error.message || 'Power action failed');
        }
      });
    });
  }

  function bindMudPageEvents() {
    var roomSave = document.getElementById('mud-room-save');
    if (roomSave) {
      roomSave.addEventListener('click', async function () {
        var input = document.getElementById('mud-room-input');
        try {
          await runAndRefresh('mud', ['set-room', String((input && input.value) || '').trim()], 'set MUD room');
          toast('MUD room updated');
        } catch (error) {
          toast(error.message || 'Room update failed');
        }
      });
    }
    var gotoMarker = document.getElementById('mud-goto-marker');
    if (gotoMarker) {
      gotoMarker.addEventListener('click', async function () {
        var marker = document.getElementById('mud-marker');
        try {
          await runAndRefresh('mud', ['goto-marker', String((marker && marker.value) || '1').trim() || '1'], 'jump to marker');
          toast('Marker resolved');
        } catch (error) {
          toast(error.message || 'Marker jump failed');
        }
      });
    }
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-mud]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await runAndRefresh('mud', [button.getAttribute('data-mud') || ''], 'mud action');
        } catch (error) {
          toast(error.message || 'MUD action failed');
        }
      });
    });
    var sayBtn = document.getElementById('mud-say-btn');
    if (sayBtn) {
      sayBtn.addEventListener('click', async function () {
        var input = document.getElementById('mud-message');
        try {
          await backend('mud', ['say', String((input && input.value) || '').trim()], { title: 'mud say' });
          input.value = '';
        } catch (error) {
          toast(error.message || 'Say failed');
        }
      });
    }
    var setPlayerBtn = document.getElementById('mud-set-player-btn');
    if (setPlayerBtn) {
      setPlayerBtn.addEventListener('click', async function () {
        var select = document.getElementById('mud-player-select');
        try {
          await runAndRefresh('mud', ['set-player', String((select && select.value) || '').trim()], 'set player');
          toast('Player selected');
        } catch (error) {
          toast(error.message || 'Set player failed');
        }
      });
    }
    var newPlayerBtn = document.getElementById('mud-new-player-btn');
    if (newPlayerBtn) {
      newPlayerBtn.addEventListener('click', async function () {
        var input = document.getElementById('mud-new-player');
        try {
          await runAndRefresh('mud', ['new-player', String((input && input.value) || '').trim()], 'new player');
          input.value = '';
          toast('Player created');
        } catch (error) {
          toast(error.message || 'Player creation failed');
        }
      });
    }
    var openPortalBtn = document.getElementById('open-portal-btn');
    if (openPortalBtn) {
      openPortalBtn.addEventListener('click', async function () {
        var player = document.getElementById('portal-player');
        var server = document.getElementById('portal-server');
        var path = document.getElementById('portal-path');
        var mount = document.getElementById('portal-mount');
        var tor = document.getElementById('portal-tor');
        try {
          await backend('mud', ['open-portal', String((player && player.value) || '').trim(), String((server && server.value) || '').trim(), String((path && path.value) || '').trim(), String((mount && mount.value) || '').trim(), tor && tor.checked ? '1' : '0'], { title: 'open portal' });
        } catch (error) {
          toast(error.message || 'Portal open failed');
        }
      });
    }
    var closePortalBtn = document.getElementById('close-portal-btn');
    if (closePortalBtn) {
      closePortalBtn.addEventListener('click', async function () {
        var mount = document.getElementById('portal-mount');
        try {
          await backend('mud', ['close-portal', String((mount && mount.value) || '').trim()], { title: 'close portal' });
        } catch (error) {
          toast(error.message || 'Portal close failed');
        }
      });
    }
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-mud-toggle]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await runAndRefresh('mud', ['toggle', button.getAttribute('data-mud-toggle') || ''], 'mud toggle');
          toast('Toggle applied');
        } catch (error) {
          toast(error.message || 'Toggle failed');
        }
      });
    });
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-mud-toggle-all]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await runAndRefresh('mud', ['toggle-all', button.getAttribute('data-mud-toggle-all') || ''], 'mud toggle all');
          toast('Feature set changed');
        } catch (error) {
          toast(error.message || 'Toggle-all failed');
        }
      });
    });
  }

  function bindArcanaPageEvents() {
    Array.prototype.forEach.call(els.pageContent.querySelectorAll('[data-run-arcana]'), function (button) {
      button.addEventListener('click', async function () {
        try {
          await backend('arcana', ['run', button.getAttribute('data-run-arcana') || ''], { title: 'arcana run' });
        } catch (error) {
          toast(error.message || 'Arcana action failed');
        }
      });
    });
  }

  async function render() {
    renderNav();
    var meta = pageMeta(state.activePage);
    els.pageEyebrow.textContent = meta.eyebrow;
    els.pageTitle.textContent = meta.title;
    els.pageSubtitle.textContent = meta.subtitle;
    els.pageContent.className = state.activePage === 'spell-activity'
      ? 'page-content page-content-spell-activity'
      : 'page-content';
    var html = '';
    if (state.activePage === 'home') {
      html = renderHome();
    } else if (state.activePage === 'spell-activity') {
      setBootStatus('Scanning live spell activity…');
      await loadSpellActivity();
      html = renderSpellActivity();
    } else if (state.activePage === 'cast') {
      html = renderCast();
    } else if (state.activePage === 'spellbook') {
      html = renderSpellbook();
    } else if (state.activePage === 'arcana') {
      html = renderArcana();
    } else if (state.activePage === 'computer') {
      html = renderComputer();
    } else if (state.activePage === 'mud') {
      html = renderMud();
    } else if (/^(builtin|custom):/.test(state.activePage)) {
      setBootStatus('Loading category…');
      await loadCategoryPage(state.activePage);
      html = renderCategory(state.activePage);
    }
    els.pageContent.innerHTML = html;
    bindCommonPageEvents();
    if (state.activePage === 'spell-activity') {
      bindSpellActivityPageEvents();
    } else if (state.activePage === 'spellbook') {
      bindSpellbookPageEvents();
    } else if (state.activePage === 'computer') {
      bindComputerPageEvents();
    } else if (state.activePage === 'mud') {
      bindMudPageEvents();
    } else if (state.activePage === 'arcana') {
      bindArcanaPageEvents();
    }
    syncSpellActivityMonitor();
    setBootStatus('Ready.');
  }

  function bindGlobalEvents() {
    els.settingsBtn.addEventListener('click', openSettings);
    els.settingsCloseBtn.addEventListener('click', closeSettings);
    els.settingsModal.addEventListener('click', function (event) {
      if (event.target === els.settingsModal) {
        closeSettings();
      }
    });
    els.activityToggle.addEventListener('click', toggleDrawer);
    els.clearLogBtn.addEventListener('click', function () {
      state.logs = [];
      renderLogs();
    });
    els.copyLogBtn.addEventListener('click', async function () {
      try {
        await navigator.clipboard.writeText(els.activityLog.textContent || '');
        toast('Copied activity log');
      } catch (_error) {
        toast('Clipboard unavailable');
      }
    });
    els.refreshBtn.addEventListener('click', async function () {
      try {
        await loadSnapshot();
        await render();
        toast('Snapshot refreshed');
      } catch (error) {
        toast(error.message || 'Refresh failed');
      }
    });
    els.saveWorkDirBtn.addEventListener('click', async function () {
      await savePref('work_dir', els.settingsWorkDir.value);
      await loadSnapshot();
      await render();
      toast('Working directory saved');
    });
    els.saveMudRoomBtn.addEventListener('click', async function () {
      await savePref('mud_room_path', els.settingsMudRoom.value);
      await loadSnapshot();
      await render();
      toast('MUD room saved');
    });
    els.themePickerBtn.addEventListener('click', function () {
      if (state.themeMenuOpen) {
        closeThemeMenu();
      } else {
        openThemeMenu();
      }
    });
    els.themePickerBtn.addEventListener('keydown', function (event) {
      if (event.key === 'ArrowDown') {
        event.preventDefault();
        cycleTheme(1);
      } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        cycleTheme(-1);
      } else if (event.key === 'Escape') {
        closeThemeMenu();
      }
    });
    document.addEventListener('click', function (event) {
      if (state.themeMenuOpen && !event.target.closest('.footer-theme-anchor')) {
        closeThemeMenu();
      }
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        if (state.settingsOpen) {
          closeSettings();
          return;
        }
        if (state.themeMenuOpen) {
          closeThemeMenu();
          return;
        }
        if (state.activePage === 'spellbook' && state.synonymComposerOpen) {
          state.synonymComposerOpen = false;
          requestRender();
          return;
        }
        if (state.drawerOpen) {
          state.drawerOpen = false;
          syncDrawer();
        }
      }
    });
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden && state.activePage === 'spell-activity' && !state.spellActivityBusy) {
        state.spellActivityBusy = true;
        requestRender().finally(function () {
          state.spellActivityBusy = false;
        });
      }
    });
  }

  function revealBootUi() {
    document.body.classList.remove('wizardry-desktop-booting');
    if (els.bootSplash) {
      els.bootSplash.style.display = 'none';
    }
  }

  async function signalBootReady() {
    if (state.bootReadySent || !state.bridge) {
      return;
    }
    state.bootReadySent = true;
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        execArgv(['__wizardry_host_boot_ready'], { quiet: true }).catch(function () {
          return;
        });
      });
    });
  }

  async function init() {
    els.bootSplash = document.getElementById('boot-splash');
    els.bootStatus = document.getElementById('boot-status');
    els.navGroups = document.getElementById('nav-groups');
    els.pageContent = document.getElementById('page-content');
    els.pageEyebrow = document.getElementById('page-eyebrow');
    els.pageTitle = document.getElementById('page-title');
    els.pageSubtitle = document.getElementById('page-subtitle');
    els.bridgePill = document.getElementById('bridge-pill');
    els.activityToggle = document.getElementById('activity-toggle');
    els.activityDrawer = document.getElementById('activity-drawer');
    els.activityLog = document.getElementById('activity-log');
    els.clearLogBtn = document.getElementById('clear-log-btn');
    els.copyLogBtn = document.getElementById('copy-log-btn');
    els.settingsBtn = document.getElementById('settings-btn');
    els.settingsModal = document.getElementById('settings-modal');
    els.settingsCloseBtn = document.getElementById('settings-close-btn');
    els.settingsWorkDir = document.getElementById('settings-work-dir');
    els.settingsMudRoom = document.getElementById('settings-mud-room');
    els.saveWorkDirBtn = document.getElementById('save-work-dir-btn');
    els.saveMudRoomBtn = document.getElementById('save-mud-room-btn');
    els.refreshBtn = document.getElementById('refresh-btn');
    els.doctorOutput = document.getElementById('doctor-output');
    els.toast = document.getElementById('toast');
    els.themeStylesheet = document.getElementById('wizardry-theme-stylesheet');
    els.themePickerBtn = document.getElementById('theme-picker-btn');
    els.themePickerMenu = document.getElementById('theme-picker-menu');
    els.themePickerList = document.getElementById('theme-picker-list');

    updateBridgePill();
    bindGlobalEvents();
    try {
      setBootStatus('Connecting wizardry bridge…');
      await waitForBridge();
      await loadPrefs();
      await loadSnapshot();
      await render();
      await requestWindowFit();
      revealBootUi();
      await signalBootReady();
    } catch (error) {
      console.error(error);
      setBootStatus(error.message || 'Failed to load wizardry desktop');
      toast(error.message || 'Failed to load');
      revealBootUi();
    }
  }

  init();
})();
