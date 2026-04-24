/*
 * Emission material notice:
 * Repo-internal Wizardry use follows OWL 3.0.
 * Generated blank projects may use this file under AGPL-3.0-or-later with the Wizardry Addendum.
 *
 * Canonical reference note:
 * Treat this file as the baseline reference for new Wizardry web app shells.
 */
(function () {
  'use strict';

  var APP_SLUG = '__APP_SLUG__';
  var APP_PATH_LABEL = 'apps/__APP_SLUG__';
  var PREF_THEME_KEY = 'theme';
  var PREF_RAIL_WIDTH_KEY = 'rail_width';
  var PREF_SELECTED_VIEW_KEY = 'selected_view';

  var THEMES = {
    ember: {
      label: 'Ember',
      vars: {
        '--bg': '#f3efe6',
        '--bg-accent': 'rgba(176, 89, 37, 0.1)',
        '--panel': 'rgba(255, 250, 243, 0.9)',
        '--panel-strong': '#fffaf4',
        '--line': 'rgba(70, 49, 33, 0.14)',
        '--line-strong': 'rgba(70, 49, 33, 0.24)',
        '--ink': '#24180f',
        '--muted': '#6f5a49',
        '--accent': '#a85626',
        '--accent-strong': '#7d3d17',
        '--accent-soft': 'rgba(168, 86, 38, 0.12)',
        '--ok': '#1f6f59',
        '--ok-soft': 'rgba(31, 111, 89, 0.12)'
      }
    },
    tide: {
      label: 'Tide',
      vars: {
        '--bg': '#edf4f6',
        '--bg-accent': 'rgba(28, 108, 135, 0.11)',
        '--panel': 'rgba(247, 252, 253, 0.9)',
        '--panel-strong': '#fbfeff',
        '--line': 'rgba(38, 74, 87, 0.14)',
        '--line-strong': 'rgba(38, 74, 87, 0.24)',
        '--ink': '#10232a',
        '--muted': '#57707b',
        '--accent': '#1e6d88',
        '--accent-strong': '#154f63',
        '--accent-soft': 'rgba(30, 109, 136, 0.12)',
        '--ok': '#1f6f59',
        '--ok-soft': 'rgba(31, 111, 89, 0.12)'
      }
    },
    grove: {
      label: 'Grove',
      vars: {
        '--bg': '#eef2e8',
        '--bg-accent': 'rgba(70, 118, 60, 0.11)',
        '--panel': 'rgba(251, 253, 247, 0.9)',
        '--panel-strong': '#fdfff9',
        '--line': 'rgba(56, 82, 49, 0.14)',
        '--line-strong': 'rgba(56, 82, 49, 0.24)',
        '--ink': '#182113',
        '--muted': '#607058',
        '--accent': '#4b7c3b',
        '--accent-strong': '#365b2b',
        '--accent-soft': 'rgba(75, 124, 59, 0.12)',
        '--ok': '#2d6d52',
        '--ok-soft': 'rgba(45, 109, 82, 0.12)'
      }
    }
  };

  var VIEWS = [
    {
      id: 'overview',
      title: 'Overview',
      status: 'Ready',
      statusTone: 'ok',
      subtitle: 'Reference app with standard Wizardry startup, left-right layout, drawer settings, and bridge-safe actions.',
      render: function () {
        return [
          '<div class="content-grid">',
          '  <section class="section-card">',
          '    <header class="section-head">',
          '      <div>',
          '        <h3>Startup Contract</h3>',
          '        <p class="section-copy">Boot splash, immediate icon paint, hidden chrome until ready, and atomic handoff are already wired here.</p>',
          '      </div>',
          '      <span class="status-pill ok">Canonical</span>',
          '    </header>',
          '    <div class="section-body">',
          '      <div class="signal-grid">',
          '        <div class="signal-item"><span class="signal-label">Splash asset</span><span class="signal-value">territory-master</span></div>',
          '        <div class="signal-item"><span class="signal-label">Ready signal</span><span class="signal-value">host boot hook</span></div>',
          '        <div class="signal-item"><span class="signal-label">Chrome reveal</span><span class="signal-value">atomic</span></div>',
          '      </div>',
          '    </div>',
          '  </section>',
          '  <section class="section-card">',
          '    <header class="section-head">',
          '      <div>',
          '        <h3>Included Patterns</h3>',
          '        <p class="section-copy">Use this starter as the baseline for new Wizardry control-plane apps.</p>',
          '      </div>',
          '    </header>',
          '    <div class="section-body">',
          '      <div class="feature-list">',
          '        <div class="feature-row"><div><div class="feature-title">Left-right desktop composition</div><p class="feature-note">Bounded rail, listbox semantics, right-side action bar.</p></div><span class="status-pill ok">standard</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">Drawer settings</div><p class="feature-note">Side utility panel with compact field sizing and persistent rail width.</p></div><span class="status-pill ok">standard</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">Bridge-safe actions</div><p class="feature-note">Explicit backend actions instead of free-form shell strings from UI.</p></div><span class="status-pill ok">standard</span></div>',
          '      </div>',
          '    </div>',
          '  </section>',
          '</div>'
        ].join('\n');
      }
    },
    {
      id: 'workflow',
      title: 'Workflow',
      status: 'Sample',
      statusTone: '',
      subtitle: 'A starter route for focused actions, queue state, or per-item controls.',
      render: function () {
        return [
          '<div class="content-grid">',
          '  <section class="section-card">',
          '    <header class="section-head"><div><h3>Action Surface</h3><p class="section-copy">Keep top-level actions close to item context.</p></div></header>',
          '    <div class="section-body">',
          '      <div class="feature-list">',
          '        <div class="feature-row"><div><div class="feature-title">Primary actions</div><p class="feature-note">Reserve text buttons for the highest-impact commands.</p></div><span class="status-pill">buttons</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">Secondary helpers</div><p class="feature-note">Use icon-first controls with tooltips and aria labels.</p></div><span class="status-pill">icons</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">Live feedback</div><p class="feature-note">Prefer log/status panels over silent background work.</p></div><span class="status-pill">feedback</span></div>',
          '      </div>',
          '    </div>',
          '  </section>',
          '</div>'
        ].join('\n');
      }
    },
    {
      id: 'log',
      title: 'Log',
      status: 'Live',
      statusTone: 'ok',
      subtitle: 'Bounded, copyable operator log output belongs in the main workflow, not hidden in alerts.',
      render: function () {
        return [
          '<div class="content-grid">',
          '  <section class="section-card">',
          '    <header class="section-head"><div><h3>Operator Log</h3><p class="section-copy">Use this as the durable status surface for commands and bridge actions.</p></div></header>',
          '    <div class="section-body">',
          '      <pre id="log-output" class="mono-box" tabindex="0" role="textbox" aria-readonly="true" aria-label="Log output">Reference app ready.</pre>',
          '    </div>',
          '  </section>',
          '</div>'
        ].join('\n');
      }
    }
  ];

  var els = {};
  var state = {
    activeTheme: 'ember',
    activeView: 'overview',
    railWidth: 290,
    settingsOpen: false,
    themeMenuOpen: false,
    backendInfo: '',
    hostBootReadySent: false,
    logLines: ['Reference app ready.']
  };

  function $(id) {
    return document.getElementById(id);
  }

  function inferBackendCandidates() {
    var candidates = [];
    try {
      var pagePath = decodeURIComponent(String(window.location.pathname || ''));
      var slugMarker = '/' + APP_SLUG + '/index.html';
      var slugIndex = pagePath.lastIndexOf(slugMarker);
      if (slugIndex > 0) {
        candidates.push(pagePath.slice(0, slugIndex) + '/' + APP_SLUG + '/scripts/' + APP_SLUG + '-backend.sh');
      }
      var bundleIndex = pagePath.lastIndexOf('/index.html');
      if (bundleIndex > 0) {
        candidates.push(pagePath.slice(0, bundleIndex) + '/scripts/' + APP_SLUG + '-backend.sh');
      }
    } catch (_err) {
      // ignore
    }
    return candidates.filter(function (value, index, arr) {
      return value && arr.indexOf(value) === index;
    });
  }

  function bridgeAvailable() {
    return !!(window.wizardry && window.wizardry.exec);
  }

  async function bridgeExec(argv) {
    if (!bridgeAvailable()) {
      throw new Error('wizardry bridge unavailable');
    }
    return window.wizardry.exec(argv);
  }

  async function backendExec(action, args) {
    var candidates = inferBackendCandidates();
    var list = Array.isArray(args) ? args.slice(0) : [];
    var i;
    for (i = 0; i < candidates.length; i += 1) {
      try {
        var res = await bridgeExec(['sh', candidates[i], action].concat(list));
        if (typeof res.exit_code !== 'undefined' && res.exit_code !== 0) {
          throw new Error((res.stderr || res.stdout || 'backend error').trim());
        }
        return res;
      } catch (err) {
        var msg = String(err && err.message ? err.message : err).toLowerCase();
        if (msg.indexOf('no such file') < 0 && msg.indexOf('cannot open') < 0 && msg.indexOf('not found') < 0) {
          throw err;
        }
      }
    }

    return bridgeExec([
      'sh',
      '-c',
      'root="${WIZARDRY_APPS_ROOT:-${WIZARDRY_DIR:-}}"; script=""; if [ -n "$root" ] && [ -f "$root/apps/__APP_SLUG__/scripts/__APP_SLUG__-backend.sh" ]; then script="$root/apps/__APP_SLUG__/scripts/__APP_SLUG__-backend.sh"; fi; [ -n "$script" ] || { printf "__APP_SLUG__ backend could not be resolved\\n" >&2; exit 1; }; exec sh "$script" "$@"',
      APP_SLUG + '-backend',
      action
    ].concat(list));
  }

  function parseKeyValue(text) {
    var out = {};
    String(text || '').split('\n').forEach(function (line) {
      var idx = line.indexOf('=');
      if (idx <= 0) {
        return;
      }
      out[line.slice(0, idx)] = line.slice(idx + 1);
    });
    return out;
  }

  function appendLog(line) {
    state.logLines.push(String(line || ''));
    var log = $('log-output');
    if (log) {
      log.textContent = state.logLines.join('\n');
      log.scrollTop = log.scrollHeight;
    }
  }

  function applyTheme(themeId) {
    var theme = THEMES[themeId] || THEMES.ember;
    Object.keys(theme.vars).forEach(function (key) {
      document.documentElement.style.setProperty(key, theme.vars[key]);
    });
    state.activeTheme = themeId;
    if (els.themePickerBtn) {
      els.themePickerBtn.textContent = theme.label;
    }
    if (els.themeSummary) {
      els.themeSummary.textContent = 'Current local reference theme: ' + theme.label + '. Replace these local palettes with shared theme files when the app adopts the centralized theme system.';
    }
  }

  function viewById(viewId) {
    return VIEWS.find(function (view) { return view.id === viewId; }) || VIEWS[0];
  }

  function renderThemeMenu() {
    if (!els.themeList) {
      return;
    }
    els.themeList.innerHTML = Object.keys(THEMES).map(function (themeId) {
      var theme = THEMES[themeId];
      return [
        '<button type="button" class="menu-item',
        state.activeTheme === themeId ? ' active' : '',
        '" data-theme-id="', themeId, '">',
        '<span>', theme.label, '</span>',
        '<span class="menu-check" aria-hidden="true">✓</span>',
        '</button>'
      ].join('');
    }).join('');
    els.themePickerMenu.classList.toggle('hidden', !state.themeMenuOpen);
    els.themePickerBtn.setAttribute('aria-expanded', state.themeMenuOpen ? 'true' : 'false');
  }

  function renderWorklist() {
    if (!els.worklist) {
      return;
    }
    els.worklist.innerHTML = VIEWS.map(function (view) {
      return [
        '<button type="button" class="worklist-row',
        state.activeView === view.id ? ' is-selected' : '',
        '" role="option" aria-selected="', state.activeView === view.id ? 'true' : 'false', '" data-view-id="', view.id, '">',
        '<span class="worklist-row-title">', view.title, '</span>',
        '<span class="worklist-row-meta">', view.status, '</span>',
        '</button>'
      ].join('');
    }).join('');
  }

  function renderContent() {
    var view = viewById(state.activeView);
    if (els.pageTitle) {
      els.pageTitle.textContent = view.title;
    }
    if (els.pageSubtitle) {
      els.pageSubtitle.textContent = view.subtitle;
    }
    if (els.contentArea) {
      els.contentArea.innerHTML = view.render();
      var log = $('log-output');
      if (log) {
        log.textContent = state.logLines.join('\n');
      }
    }
  }

  function renderSettingsPanel() {
    if (!els.settingsPanel) {
      return;
    }
    els.settingsPanel.classList.toggle('hidden', !state.settingsOpen);
    if (els.railWidth) {
      els.railWidth.value = String(state.railWidth);
    }
    if (els.prefsStatus) {
      els.prefsStatus.textContent = state.backendInfo || 'Backend diagnostics unavailable.';
    }
  }

  function setRailWidth(nextWidth) {
    var width = Number(nextWidth) || 290;
    if (width < 220) {
      width = 220;
    }
    if (width > 380) {
      width = 380;
    }
    state.railWidth = width;
    document.documentElement.style.setProperty('--rail-width', width + 'px');
  }

  async function saveUiPref(key, value) {
    try {
      await backendExec('set-ui-pref', [key, value]);
    } catch (err) {
      appendLog('Preference save failed: ' + String(err && err.message ? err.message : err));
    }
  }

  async function loadPrefs() {
    try {
      var res = await backendExec('get-ui-prefs');
      var prefs = parseKeyValue((res && res.stdout) || '');
      state.backendInfo = (res && res.stdout) || 'Backend reachable.';
      applyTheme(prefs[PREF_THEME_KEY] || state.activeTheme);
      state.activeView = prefs[PREF_SELECTED_VIEW_KEY] || state.activeView;
      setRailWidth(prefs[PREF_RAIL_WIDTH_KEY] || state.railWidth);
    } catch (err) {
      state.backendInfo = 'Backend unavailable.\n' + String(err && err.message ? err.message : err);
      applyTheme(state.activeTheme);
      setRailWidth(state.railWidth);
    }
  }

  async function runSampleAction(actionName) {
    try {
      var res = await backendExec(actionName);
      var body = String((res && res.stdout) || '').trim();
      appendLog('[' + actionName + '] ' + (body || 'ok'));
    } catch (err) {
      appendLog('[' + actionName + '] ' + String(err && err.message ? err.message : err));
    }
  }

  function copyText(value) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(value).then(function () {
        appendLog('Copied: ' + value);
      }).catch(function () {
        appendLog('Copy failed.');
      });
      return;
    }
    appendLog('Clipboard API unavailable.');
  }

  function signalBootReady() {
    if (state.hostBootReadySent) {
      return;
    }
    state.hostBootReadySent = true;
    if (!bridgeAvailable()) {
      return;
    }
    bridgeExec(['__wizardry_host_boot_ready']).catch(function () {
      state.hostBootReadySent = false;
    });
  }

  function finishBoot() {
    document.documentElement.classList.remove('reference-app-booting');
    document.body.classList.remove('reference-app-booting');
    document.body.classList.add('booted');
    els.bootSplash.classList.add('hidden');
    els.appShell.classList.remove('hidden');
    els.appShell.setAttribute('aria-hidden', 'false');
    signalBootReady();
  }

  function bindEvents() {
    els.worklist.addEventListener('click', function (event) {
      var row = event.target.closest('[data-view-id]');
      if (!row) {
        return;
      }
      state.activeView = row.dataset.viewId;
      renderWorklist();
      renderContent();
      saveUiPref(PREF_SELECTED_VIEW_KEY, state.activeView);
    });

    els.settingsToggle.addEventListener('click', function () {
      state.settingsOpen = !state.settingsOpen;
      renderSettingsPanel();
    });

    els.settingsClose.addEventListener('click', function () {
      state.settingsOpen = false;
      renderSettingsPanel();
    });

    els.themePickerBtn.addEventListener('click', function () {
      state.themeMenuOpen = !state.themeMenuOpen;
      renderThemeMenu();
    });

    els.themeList.addEventListener('click', function (event) {
      var button = event.target.closest('[data-theme-id]');
      if (!button) {
        return;
      }
      state.themeMenuOpen = false;
      applyTheme(button.dataset.themeId);
      renderThemeMenu();
      saveUiPref(PREF_THEME_KEY, state.activeTheme);
    });

    els.actionPing.addEventListener('click', function () {
      runSampleAction('ping');
    });

    els.actionTimestamp.addEventListener('click', function () {
      runSampleAction('timestamp');
    });

    els.pathChip.addEventListener('click', function () {
      copyText(APP_PATH_LABEL);
    });

    els.railWidth.addEventListener('input', function () {
      setRailWidth(els.railWidth.value);
      renderSettingsPanel();
    });

    els.railWidth.addEventListener('change', function () {
      saveUiPref(PREF_RAIL_WIDTH_KEY, String(state.railWidth));
    });

    document.addEventListener('click', function (event) {
      if (!event.target.closest('.footer-theme-anchor')) {
        state.themeMenuOpen = false;
        renderThemeMenu();
      }
    });

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        state.settingsOpen = false;
        state.themeMenuOpen = false;
        renderSettingsPanel();
        renderThemeMenu();
      }
    });
  }

  function captureElements() {
    els.bootSplash = $('boot-splash');
    els.appShell = $('app-shell');
    els.worklist = $('worklist');
    els.pageTitle = $('page-title');
    els.pageSubtitle = $('page-subtitle');
    els.contentArea = $('content-area');
    els.settingsPanel = $('settings-panel');
    els.settingsToggle = $('settings-toggle');
    els.settingsClose = $('settings-close');
    els.themePickerBtn = $('theme-picker-btn');
    els.themePickerMenu = $('theme-picker-menu');
    els.themeList = $('theme-list');
    els.actionPing = $('action-ping');
    els.actionTimestamp = $('action-timestamp');
    els.pathChip = $('path-chip');
    els.railWidth = $('rail-width');
    els.themeSummary = $('theme-summary');
    els.prefsStatus = $('prefs-status');
  }

  async function boot() {
    captureElements();
    await loadPrefs();
    renderThemeMenu();
    renderWorklist();
    renderContent();
    renderSettingsPanel();
    bindEvents();
    finishBoot();
  }

  boot().catch(function (err) {
    appendLog('Boot failed: ' + String(err && err.message ? err.message : err));
    finishBoot();
  });
}());
