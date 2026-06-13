/*
 * Emission material notice:
 * Repo-internal Wizardry use follows OWL 3.1.
 * Generated blank projects may use this file under AGPL-3.0-or-later with the Wizardry Addendum.
 *
 * Canonical reference note:
 * Treat this file as the baseline reference for new cross-platform apps that
 * keep a web UI while opting into a Theurgy runtime boundary.
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
      subtitle: 'Cross-platform app starter with standard startup, local bridge actions, and a first-class Theurgy preparation path.',
      render: function () {
        return [
          '<div class="content-grid">',
          '  <section class="section-card">',
          '    <header class="section-head"><div><h3>Theurgy Boundary</h3><p class="section-copy">Keep the UI in ordinary web files while moving heavier runtime behavior behind a typed Theurgy boundary when shell fan-out stops scaling.</p></div><span class="status-pill ok">standard</span></header>',
          '    <div class="section-body">',
          '      <div class="signal-grid">',
          '        <div class="signal-item"><span class="signal-label">UI layer</span><span class="signal-value">HTML/CSS/JS</span></div>',
          '        <div class="signal-item"><span class="signal-label">Runtime seam</span><span class="signal-value">Theurgy wrapper</span></div>',
          '        <div class="signal-item"><span class="signal-label">Rebuild path</span><span class="signal-value">prepare script</span></div>',
          '      </div>',
          '    </div>',
          '  </section>',
          '  <section class="section-card">',
          '    <header class="section-head"><div><h3>When To Choose This</h3><p class="section-copy">Use this starter when one app should stay cross-platform but you already know it needs a stronger runtime than ad hoc shell can carry.</p></div></header>',
          '    <div class="section-body">',
          '      <div class="feature-list">',
          '        <div class="feature-row"><div><div class="feature-title">Shared desktop and web product</div><p class="feature-note">One UI codebase, with room to introduce typed runtime actions as the app grows.</p></div><span class="status-pill ok">fit</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">Robust prototype</div><p class="feature-note">Start file-first, but with an explicit path toward a resident runtime before complexity becomes a rat&#39;s nest.</p></div><span class="status-pill ok">fit</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">Operator-facing workflows</div><p class="feature-note">Good for tools that will need reliable actions, typed status, logs, caches, or background work.</p></div><span class="status-pill ok">fit</span></div>',
          '      </div>',
          '    </div>',
          '  </section>',
          '</div>'
        ].join('\n');
      }
    },
    {
      id: 'runtime',
      title: 'Runtime',
      status: 'Theurgy',
      statusTone: '',
      subtitle: 'The generated workspace keeps a clean preparation script and backend wrapper so runtime adoption stays explicit.',
      render: function () {
        return [
          '<div class="content-grid">',
          '  <section class="section-card">',
          '    <header class="section-head"><div><h3>Runtime Preparation</h3><p class="section-copy">Forge rebuild calls <code>scripts/prepare-theurgy-runtime.sh</code> so the app can verify its Theurgy dependency through the canonical wrapper.</p></div></header>',
          '    <div class="section-body">',
          '      <div class="feature-list">',
          '        <div class="feature-row"><div><div class="feature-title">UI stays inspectable</div><p class="feature-note">Frontend files remain ordinary and easy to relaunch quickly from Forge.</p></div><span class="status-pill">ui</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">Runtime stays explicit</div><p class="feature-note">The backend wrapper does not hide whether Theurgy is installed or where the status check came from.</p></div><span class="status-pill">runtime</span></div>',
          '        <div class="feature-row"><div><div class="feature-title">No second app rewrite</div><p class="feature-note">A browser-first app can stay the same product while it gains a stronger backend.</p></div><span class="status-pill">scope</span></div>',
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
          '    <header class="section-head"><div><h3>Operator Log</h3><p class="section-copy">Use this as the durable status surface for preparation checks and runtime actions.</p></div></header>',
          '    <div class="section-body">',
          '      <pre id="log-output" class="mono-box" tabindex="0" role="textbox" aria-readonly="true" aria-label="Log output">Theurgy reference app ready.</pre>',
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
    hostBootReadySent: false,
    logLines: ['Theurgy reference app ready.']
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
    if (els.logOutput) {
      els.logOutput.textContent = state.logLines.join('\n');
      els.logOutput.scrollTop = els.logOutput.scrollHeight;
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
      els.themeSummary.textContent = 'Current local theme: ' + theme.label + '. Replace these local palettes with shared theme files when the app adopts the centralized theme system.';
    }
  }

  function viewById(viewId) {
    var i;
    for (i = 0; i < VIEWS.length; i += 1) {
      if (VIEWS[i].id === viewId) {
        return VIEWS[i];
      }
    }
    return VIEWS[0];
  }

  function renderThemeMenu() {
    if (!els.themeList) {
      return;
    }
    els.themeList.innerHTML = Object.keys(THEMES).map(function (themeId) {
      var theme = THEMES[themeId];
      return '<button type="button" class="menu-item' + (state.activeTheme === themeId ? ' active' : '') + '" data-theme-id="' + themeId + '"><span>' + theme.label + '</span><span class="menu-check" aria-hidden="true">✓</span></button>';
    }).join('');
    els.themePickerMenu.classList.toggle('hidden', !state.themeMenuOpen);
    els.themePickerBtn.setAttribute('aria-expanded', state.themeMenuOpen ? 'true' : 'false');
  }

  function renderWorklist() {
    if (!els.worklist) {
      return;
    }
    els.worklist.innerHTML = VIEWS.map(function (view) {
      return '<button type="button" class="worklist-row' + (state.activeView === view.id ? ' is-selected' : '') + '" role="option" aria-selected="' + (state.activeView === view.id ? 'true' : 'false') + '" data-view-id="' + view.id + '"><span class="worklist-row-title">' + view.title + '</span><span class="worklist-row-meta">' + view.status + '</span></button>';
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
    }
    els.logOutput = $('log-output');
    if (els.logOutput) {
      els.logOutput.textContent = state.logLines.join('\n');
    }
  }

  function setRailWidth(width) {
    var next = Math.max(220, Math.min(380, Number(width) || 290));
    state.railWidth = next;
    document.documentElement.style.setProperty('--rail-width', next + 'px');
    if (els.railWidth) {
      els.railWidth.value = String(next);
    }
  }

  function closeThemeMenu() {
    state.themeMenuOpen = false;
    renderThemeMenu();
  }

  function toggleSettings(forceOpen) {
    state.settingsOpen = typeof forceOpen === 'boolean' ? forceOpen : !state.settingsOpen;
    els.settingsPanel.classList.toggle('hidden', !state.settingsOpen);
  }

  function syncShellVisibility() {
    document.documentElement.classList.remove('reference-app-booting');
    document.body.classList.remove('reference-app-booting');
    document.body.classList.add('booted');
    if (els.bootSplash) {
      els.bootSplash.classList.add('hidden');
    }
    if (els.appShell) {
      els.appShell.classList.remove('hidden');
      els.appShell.setAttribute('aria-hidden', 'false');
    }
  }

  function sendHostBootReady() {
    if (state.hostBootReadySent) {
      return;
    }
    if (window.wizardry && typeof window.wizardry.hostBootReady === 'function') {
      window.wizardry.hostBootReady();
    } else if (typeof window.__wizardry_host_boot_ready === 'function') {
      window.__wizardry_host_boot_ready();
    }
    state.hostBootReadySent = true;
  }

  async function loadPrefs() {
    try {
      var res = await backendExec('get-ui-prefs');
      var data = parseKeyValue(res.stdout || '');
      if (data[PREF_THEME_KEY] && THEMES[data[PREF_THEME_KEY]]) {
        state.activeTheme = data[PREF_THEME_KEY];
      }
      if (data[PREF_RAIL_WIDTH_KEY]) {
        state.railWidth = Number(data[PREF_RAIL_WIDTH_KEY]) || state.railWidth;
      }
      if (data[PREF_SELECTED_VIEW_KEY]) {
        state.activeView = data[PREF_SELECTED_VIEW_KEY];
      }
    } catch (_err) {
      appendLog('UI preferences unavailable; using defaults.');
    }
  }

  async function savePref(key, value) {
    try {
      await backendExec('set-ui-pref', [key, String(value)]);
    } catch (_err) {
      // ignore local pref save failures
    }
  }

  async function refreshBackendDiagnostics() {
    try {
      var res = await backendExec('theurgy-status');
      var text = String(res.stdout || '').trim();
      if (els.prefsStatus) {
        els.prefsStatus.textContent = text || 'Theurgy runtime status returned no output.';
      }
    } catch (err) {
      if (els.prefsStatus) {
        els.prefsStatus.textContent = 'Runtime status unavailable.\n' + String(err && err.message ? err.message : err);
      }
    }
  }

  async function runPrepareTheurgyAction() {
    try {
      var res = await backendExec('prepare-theurgy');
      var data = parseKeyValue(res.stdout || '');
      var line = 'Prepared Theurgy runtime.';
      if (data.status_file) {
        line += ' Status file: ' + data.status_file;
      }
      appendLog(line);
      await refreshBackendDiagnostics();
    } catch (err) {
      appendLog('Theurgy preparation failed: ' + String(err && err.message ? err.message : err));
    }
  }

  async function runRuntimeStatusAction() {
    try {
      var res = await backendExec('theurgy-status');
      var text = String(res.stdout || '').trim();
      appendLog(text || 'Theurgy runtime status returned no output.');
      await refreshBackendDiagnostics();
    } catch (err) {
      appendLog('Runtime status failed: ' + String(err && err.message ? err.message : err));
    }
  }

  function attachEvents() {
    els.worklist.addEventListener('click', function (event) {
      var row = event.target.closest('[data-view-id]');
      if (!row) {
        return;
      }
      state.activeView = row.getAttribute('data-view-id') || 'overview';
      savePref(PREF_SELECTED_VIEW_KEY, state.activeView);
      renderWorklist();
      renderContent();
    });

    els.themePickerBtn.addEventListener('click', function () {
      state.themeMenuOpen = !state.themeMenuOpen;
      renderThemeMenu();
    });

    els.themeList.addEventListener('click', function (event) {
      var btn = event.target.closest('[data-theme-id]');
      if (!btn) {
        return;
      }
      var themeId = btn.getAttribute('data-theme-id');
      applyTheme(themeId);
      savePref(PREF_THEME_KEY, themeId);
      appendLog('Theme set to ' + THEMES[themeId].label + '.');
      closeThemeMenu();
    });

    document.addEventListener('click', function (event) {
      if (!state.themeMenuOpen) {
        return;
      }
      if (!event.target.closest('.footer-theme-anchor')) {
        closeThemeMenu();
      }
    });

    els.settingsToggle.addEventListener('click', function () {
      toggleSettings();
    });
    els.settingsClose.addEventListener('click', function () {
      toggleSettings(false);
    });
    els.pathChip.addEventListener('click', function () {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(APP_PATH_LABEL);
      }
      appendLog('Copied app path label: ' + APP_PATH_LABEL);
    });
    els.railWidth.addEventListener('input', function () {
      setRailWidth(els.railWidth.value);
      savePref(PREF_RAIL_WIDTH_KEY, state.railWidth);
    });
    els.actionPrepareTheurgy.addEventListener('click', runPrepareTheurgyAction);
    els.actionRuntimeStatus.addEventListener('click', runRuntimeStatusAction);
  }

  async function init() {
    els.bootSplash = $('boot-splash');
    els.appShell = $('app-shell');
    els.worklist = $('worklist');
    els.pageTitle = $('page-title');
    els.pageSubtitle = $('page-subtitle');
    els.contentArea = $('content-area');
    els.pathChip = $('path-chip');
    els.themePickerBtn = $('theme-picker-btn');
    els.themePickerMenu = $('theme-picker-menu');
    els.themeList = $('theme-list');
    els.settingsToggle = $('settings-toggle');
    els.settingsPanel = $('settings-panel');
    els.settingsClose = $('settings-close');
    els.themeSummary = $('theme-summary');
    els.prefsStatus = $('prefs-status');
    els.railWidth = $('rail-width');
    els.actionPrepareTheurgy = $('action-prepare-theurgy');
    els.actionRuntimeStatus = $('action-runtime-status');

    await loadPrefs();
    setRailWidth(state.railWidth);
    applyTheme(state.activeTheme);
    renderThemeMenu();
    renderWorklist();
    renderContent();
    attachEvents();
    await refreshBackendDiagnostics();
    syncShellVisibility();
    sendHostBootReady();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
}());
