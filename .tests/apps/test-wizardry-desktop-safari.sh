#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
APP_DIR="$ROOT_DIR/apps/wizardry-desktop"
INDEX_URL="file://$APP_DIR/index.html"
BRIDGE_DIR="$APP_DIR/.host/shared"
BRIDGE_PATH="$BRIDGE_DIR/wizardry-bridge.js"
SCREENSHOT_PATH="${TMPDIR:-/tmp}/wizardry-desktop-safari-smoke.png"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

if ! command -v osascript >/dev/null 2>&1; then
  printf 'SKIP: osascript not available\n'
  exit 0
fi

JS_TMP=$(mktemp "${TMPDIR:-/tmp}/wizardry-desktop-safari.XXXXXX.js")
mkdir -p "$BRIDGE_DIR"

cleanup() {
  rm -f "$JS_TMP"
  rm -f "$BRIDGE_PATH"
}
trap cleanup EXIT INT TERM

cat > "$BRIDGE_PATH" <<'BRIDGE'
(function () {
  var prefs = {
    theme: 'psionic',
    active_page: 'home',
    work_dir: '/Users/andersaamodt/git/wizardry-apps',
    mud_room_path: '/Users/andersaamodt/.wizardry/mud/worlds/local/rooms/start'
  };
  var categories = [
    ['builtin', 'translocation', 'Translocation', '3', 'Move across machines, folders, and targets.', '/wizardry/spells/translocation'],
    ['builtin', 'observation', 'Observation', '2', 'Inspect systems and the filesystem.', '/wizardry/spells/observation'],
    ['custom', 'rituals', 'Rituals', '2', 'Custom release and deployment helpers.', '/Users/andersaamodt/.wizardry/spellbook/rituals']
  ];
  var categorySpells = {
    'builtin:translocation': [
      ['teleport-home', 'builtin', 'Jump to your working home.', '1', '/wizardry/spells/translocation/teleport-home'],
      ['portal-sync', 'builtin', 'Synchronize a mounted portal.', '0', '/wizardry/spells/translocation/portal-sync'],
      ['goto-host', 'builtin', 'Enter a named host workspace.', '0', '/wizardry/spells/translocation/goto-host']
    ],
    'builtin:observation': [
      ['see-processes', 'builtin', 'Inspect running processes.', '0', '/wizardry/spells/observation/see-processes'],
      ['read-room', 'builtin', 'Read the current room state.', '0', '/wizardry/spells/observation/read-room']
    ],
    'custom:rituals': [
      ['ship-it', 'custom', 'Commit and push current release notes.', '0', '/Users/andersaamodt/.wizardry/spellbook/rituals/ship-it'],
      ['stage-docs', 'custom', 'Prepare docs before release.', '0', '/Users/andersaamodt/.wizardry/spellbook/rituals/stage-docs']
    ]
  };
  var customRootSpells = [
    ['daily-status', 'Compose a short status update.', '/Users/andersaamodt/.wizardry/spellbook/daily-status']
  ];
  var castEntries = [
    ['ll', 'ls -lah'],
    ['gs', 'git status --short']
  ];
  var spellActivity = [
    ['builtin-spell', 'wizardry-desktop', '401', '301', '00:05', 'update-all', '/Users/andersaamodt/.wizardry/spells/system/update-all', 'update-all -v'],
    ['app-backend', 'chatroom', '402', '302', '00:09', 'chatroom-backend.sh', '/Users/andersaamodt/git/wizardry-apps/apps/chatroom/scripts/chatroom-backend.sh', 'sh /Users/andersaamodt/git/wizardry-apps/apps/chatroom/scripts/chatroom-backend.sh start-server']
  ];
  var arcana = [
    ['ripgrep', 'installed', 'Fast text search'],
    ['tmux', 'available', 'Terminal multiplexer']
  ];
  var synonyms = [
    ['ll', 'ls -lah', 'custom'],
    ['glog', 'git log --oneline --decorate -10', 'custom']
  ];
  var players = [
    ['andersaamodt', '1', '/Users/andersaamodt/.wizardry/mud/players/andersaamodt'],
    ['scribe', '0', '/Users/andersaamodt/.wizardry/mud/players/scribe']
  ];
  var mudStatus = {
    current_player: 'andersaamodt',
    parse_enabled: '1',
    mud_menu_enabled: '1',
    cd_look_enabled: '1',
    cd_listen_enabled: '0',
    avatar_enabled: '1',
    touch_hook_enabled: '0',
    tor_enabled: '0',
    torrc_path: '/Users/andersaamodt/.wizardry/tor/torrc',
    portal_location: '/Volumes/portal-room',
    room_path: prefs.mud_room_path,
    onion_address: 'off'
  };

  function nextId() {
    return Math.random().toString(36).slice(2);
  }

  function kv(obj) {
    return Object.keys(obj).map(function (key) {
      return key + '=' + String(obj[key] == null ? '' : obj[key]);
    }).join('\n');
  }

  function tsv(rows) {
    return rows.map(function (row) { return row.join('\t'); }).join('\n');
  }

  function ok(stdout, stderr) {
    return { stdout: stdout || '', stderr: stderr || '', exit_code: 0, error: null };
  }

  function err(message) {
    return { stdout: '', stderr: String(message || 'error'), exit_code: 1, error: null };
  }

  function resultFor(argv) {
    if (!Array.isArray(argv) || !argv.length) {
      return err('empty argv');
    }
    if (argv[0] === '__wizardry_host_boot_ready') {
      return ok('boot ready');
    }
    if (argv[0] !== 'sh' || argv.length < 3) {
      return ok('command: ' + argv.join(' '));
    }
    var command = argv[2];
    var args = argv.slice(3);

    if (command === 'get-ui-prefs') {
      return ok(kv(prefs));
    }
    if (command === 'set-ui-pref') {
      prefs[String(args[0] || '')] = String(args[1] || '');
      if (args[0] === 'mud_room_path') {
        mudStatus.room_path = prefs.mud_room_path;
      }
      return ok('saved ' + String(args[0] || ''));
    }
    if (command === 'doctor') {
      return ok(kv({
        app_dir: '/Users/andersaamodt/git/wizardry-apps/apps/wizardry-desktop',
        root: '/Users/andersaamodt/git/wizardry-apps',
        wizardry_dir: '/Users/andersaamodt/.wizardry',
        spellbook_dir: '/Users/andersaamodt/.wizardry/spellbook',
        work_dir: prefs.work_dir,
        mud_room_path: prefs.mud_room_path,
        category_count: String(categories.length),
        spell_count: '7',
        memorized_count: String(castEntries.length),
        arcana_count: String(arcana.length)
      }));
    }
    if (command === 'list-themes') {
      return ok(tsv([['psionic'], ['archmage'], ['druid']]));
    }
    if (command === 'list-categories') {
      return ok(tsv(categories));
    }
    if (command === 'list-custom-root-spells') {
      return ok(tsv(customRootSpells));
    }
    if (command === 'list-cast') {
      return ok(tsv(castEntries));
    }
    if (command === 'list-spell-activity') {
      return ok(tsv(spellActivity));
    }
    if (command === 'list-arcana') {
      return ok(tsv(arcana));
    }
    if (command === 'list-synonyms') {
      return ok(tsv(synonyms));
    }
    if (command === 'list-players') {
      return ok(tsv(players));
    }
    if (command === 'mud-status') {
      return ok(kv(mudStatus));
    }
    if (command === 'list-spells') {
      return ok(tsv(categorySpells[(String(args[0] || '') + ':' + String(args[1] || ''))] || []));
    }
    if (command === 'run-spell') {
      return ok('ran spell ' + String(args[0] || ''), '+ run-spell ' + String(args[0] || ''));
    }
    if (command === 'spell-help') {
      return ok('help for ' + String(args[0] || ''), '+ spell-help ' + String(args[0] || ''));
    }
    if (command === 'memorize') {
      var spell = String(args[0] || '');
      if (!castEntries.some(function (entry) { return entry[0] === spell; })) {
        castEntries.unshift([spell, spell]);
      }
      return ok('memorized ' + spell, '+ memorize ' + spell);
    }
    if (command === 'forget') {
      var alias = String(args[0] || '');
      castEntries = castEntries.filter(function (entry) { return entry[0] !== alias; });
      return ok('forgot ' + alias, '+ forget ' + alias);
    }
    if (command === 'run-cast') {
      return ok('cast ' + String(args[0] || ''), '+ run-cast ' + String(args[0] || ''));
    }
    if (command === 'create-category') {
      var name = String(args[0] || '').trim();
      if (name) {
        categories.push(['custom', name, name.charAt(0).toUpperCase() + name.slice(1), '0', 'Created from the spellbook page.', '/Users/andersaamodt/.wizardry/spellbook/' + name]);
      }
      return ok('created category ' + name, '+ create-category ' + name);
    }
    if (command === 'scribe-spell') {
      return ok('scribed ' + String(args[0] || ''), '+ scribe-spell ' + args.join(' '));
    }
    if (command === 'synonym') {
      if (args[0] === 'add') {
        synonyms.unshift([String(args[1] || ''), String(args[2] || ''), 'custom']);
      } else if (args[0] === 'delete') {
        synonyms = synonyms.filter(function (item) { return item[0] !== String(args[1] || ''); });
      }
      return ok('synonym ' + args.join(' '), '+ synonym ' + args.join(' '));
    }
    if (command === 'system' || command === 'network' || command === 'service' || command === 'user' || command === 'power') {
      return ok(command + ' ' + args.join(' '), '+ ' + command + ' ' + args.join(' '));
    }
    if (command === 'arcana') {
      return ok('arcana ' + args.join(' '), '+ arcana ' + args.join(' '));
    }
    if (command === 'mud') {
      if (args[0] === 'set-room') {
        prefs.mud_room_path = String(args[1] || '');
        mudStatus.room_path = prefs.mud_room_path;
      } else if (args[0] === 'set-player') {
        mudStatus.current_player = String(args[1] || '');
      } else if (args[0] === 'toggle') {
        var key = String(args[1] || '').replace(/-/g, '_') + '_enabled';
        if (Object.prototype.hasOwnProperty.call(mudStatus, key)) {
          mudStatus[key] = mudStatus[key] === '1' ? '0' : '1';
        }
      }
      return ok('mud ' + args.join(' '), '+ mud ' + args.join(' '));
    }
    return ok(command + ' ' + args.join(' '), '+ ' + command + ' ' + args.join(' '));
  }

  function execCommand(argv) {
    return new Promise(function (resolve) {
      var id = nextId();
      window.__wizardry_callbacks = window.__wizardry_callbacks || {};
      window.__wizardry_callbacks[id] = resolve;
      setTimeout(function () {
        window.__wizardry_callbacks[id](resultFor(argv));
      }, 10);
    });
  }

  window.wizardry = window.wizardry || {};
  window.wizardry.exec = execCommand;
})();
BRIDGE

cat > "$JS_TMP" <<'JSCODE'
(function () {
  window.__wizardrySmoke = { done: false, ok: false, issues: [] };

  var issues = [];
  var slack = 2;

  function finish() {
    window.__wizardrySmoke = {
      done: true,
      ok: issues.length === 0,
      issues: issues
    };
  }

  function expect(cond, msg) {
    if (!cond) issues.push(msg);
  }

  function noOverflowX() {
    return document.documentElement.scrollWidth <= document.documentElement.clientWidth + slack;
  }

  function noOverflowY() {
    return document.documentElement.scrollHeight <= document.documentElement.clientHeight + slack;
  }

  function click(selector) {
    var el = document.querySelector(selector);
    if (!el) {
      issues.push('missing:' + selector);
      return null;
    }
    el.click();
    return el;
  }

  function step(delayMs, fn) {
    window.setTimeout(function () {
      try {
        fn();
      } catch (_error) {
        issues.push('step-failed');
        finish();
      }
    }, delayMs);
  }

  expect(!document.body.classList.contains('wizardry-desktop-booting'), 'booting-class-present');
  expect(!!document.querySelector('#nav-groups[role="listbox"]'), 'nav-listbox');
  expect(document.querySelectorAll('.nav-row').length >= 6, 'nav-row-count');
  expect(!!document.getElementById('activity-drawer'), 'activity-drawer-present');
  expect(String((document.getElementById('activity-toggle') || {}).textContent || '').trim() === '', 'activity-toggle-icon-only');
  expect(!!(document.getElementById('activity-toggle') || {}).getAttribute('aria-label'), 'activity-toggle-aria');
  expect(noOverflowX(), 'horizontal-overflow');
  expect(noOverflowY(), 'vertical-overflow');

  var sidebar = document.querySelector('.sidebar');
  expect(!!sidebar, 'sidebar-present');
  if (sidebar) {
    expect(Math.abs(sidebar.getBoundingClientRect().height - window.innerHeight) <= 2, 'sidebar-full-height');
  }

  var themeBtn = document.getElementById('theme-picker-btn');
  expect(!!themeBtn, 'theme-button-present');
  var themeBefore = themeBtn ? String(themeBtn.textContent || '').trim() : '';
  if (themeBtn) {
    themeBtn.focus();
    themeBtn.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
  }

  step(60, function () {
    if (themeBtn) {
      var themeAfter = String(themeBtn.textContent || '').trim();
      expect(themeAfter !== themeBefore, 'theme-arrow-cycle');
    }

    var watchRow = click('.nav-row[data-page="spell-activity"]');
    expect(!!watchRow, 'watch-row-present');

    step(90, function () {
      expect(document.getElementById('page-title').textContent.indexOf('Casting Watch') >= 0, 'watch-page-title');
      expect(!!document.getElementById('refresh-spell-activity-btn'), 'watch-refresh-button');
      expect(document.querySelectorAll('.list-row').length >= 2, 'watch-rows-rendered');
      expect(String(document.getElementById('page-content').textContent || '').indexOf('chatroom-backend.sh') >= 0, 'watch-backend-row');
      expect(String(document.getElementById('page-content').textContent || '').indexOf('update-all') >= 0, 'watch-spell-row');

      var spellbookRow = click('.nav-row[data-page="spellbook"]');
      expect(!!spellbookRow, 'spellbook-row-present');

      step(90, function () {
        var activeSpellbookRow = document.querySelector('.nav-row.active[data-page="spellbook"]');
        if (activeSpellbookRow) {
          expect(activeSpellbookRow.classList.contains('active'), 'nav-row-active');
          expect(activeSpellbookRow.getAttribute('aria-selected') === 'true', 'nav-row-selected');
          expect(getComputedStyle(activeSpellbookRow).cursor === 'default', 'nav-row-default-cursor');
          expect(Math.abs(activeSpellbookRow.getBoundingClientRect().left - document.querySelector('.nav-groups').getBoundingClientRect().left) <= 1, 'nav-row-full-width');
        } else {
          issues.push('nav-row-active');
        }
        expect(document.getElementById('page-title').textContent.indexOf('Scribe') >= 0, 'spellbook-page-title');

        click('#settings-btn');
        step(50, function () {
          var settings = document.getElementById('settings-modal');
          expect(!!settings && !settings.classList.contains('hidden'), 'settings-open');
          expect(String((document.getElementById('doctor-output') || {}).textContent || '').indexOf('wizardry_dir=') >= 0, 'doctor-output-loaded');
          click('#settings-close-btn');

          step(60, function () {
            expect(document.getElementById('settings-modal').classList.contains('hidden'), 'settings-close');
            click('.nav-row[data-page="computer"]');

            step(80, function () {
              click('[data-system="update-all"]');

              step(110, function () {
                click('#activity-toggle');

                step(260, function () {
                  expect(document.body.classList.contains('drawer-open'), 'drawer-open');
                  var logText = String((document.getElementById('activity-log') || {}).textContent || '');
                  expect(logText.indexOf('system action') >= 0, 'activity-title-logged');
                  expect(logText.indexOf("'system' 'update-all'") >= 0, 'activity-command-logged');
                  click('#clear-log-btn');

                  step(40, function () {
                    expect(String(document.getElementById('activity-log').textContent || '').trim() === 'Waiting for activity.', 'activity-clear');
                    click('#activity-toggle');

                    step(260, function () {
                      expect(!document.body.classList.contains('drawer-open'), 'drawer-close');
                      click('.nav-row[data-page="builtin:translocation"]');

                      step(110, function () {
                        expect(document.querySelectorAll('[data-run-spell]').length >= 2, 'category-spells-rendered');
                        finish();
                      });
                    });
                  });
                });
              });
            });
          });
        });
      });
    });
  });
})();
JSCODE

RESULT=$(osascript <<APPLESCRIPT
set pageUrl to "$INDEX_URL"
set jsPath to "$JS_TMP"
set jsScript to do shell script "cat " & quoted form of jsPath

tell application "Safari"
  activate
  if (count of windows) = 0 then
    make new document
  end if
  set bounds of front window to {80, 40, 1500, 980}
  set URL of front document to pageUrl
  set ready to false
  repeat with i from 1 to 60
    delay 0.2
    try
      set marker to do JavaScript "!!document.querySelectorAll('.nav-row').length && !document.body.classList.contains('wizardry-desktop-booting')" in front document
      if marker is true then
        set ready to true
        exit repeat
      end if
    on error
      set ready to false
    end try
  end repeat
  if ready is false then
    return "{\"ok\":false,\"issues\":[\"app-marker-timeout\"]}"
  end if
  try
    do JavaScript jsScript in front document
  on error
    return "{\"ok\":false,\"issues\":[\"safari-js-prime-error\"]}"
  end try
  repeat with i from 1 to 60
    delay 0.2
    try
      set resultJson to do JavaScript "JSON.stringify(window.__wizardrySmoke || { done: false, ok: false, issues: ['smoke-missing'] })" in front document
      if resultJson contains "\"done\":true" then
        return resultJson
      end if
    on error
      return "{\"ok\":false,\"issues\":[\"safari-js-poll-error\"]}"
    end try
  end repeat
  return "{\"ok\":false,\"issues\":[\"safari-js-timeout\"]}"
end tell
APPLESCRIPT
)

printf '%s\n' "$RESULT"
printf '%s\n' "$RESULT" | grep -F '"ok":true' >/dev/null 2>&1 || fail "Safari UI smoke checks failed"

screencapture -x -R80,40,1420,940 "$SCREENSHOT_PATH"
printf 'SCREENSHOT: %s\n' "$SCREENSHOT_PATH"
printf 'PASS: wizardry-desktop Safari smoke checks\n'
