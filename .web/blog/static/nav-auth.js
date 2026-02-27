(function () {
  'use strict';

  var AUTH_KIND = 22242;
  var DELEGATION_KIND = 27235;
  var NIP46_KIND = 24133;
  var DEFAULT_DELEGATION_DAYS = 30;
  var MIN_DELEGATION_DAYS = 1;
  var MAX_DELEGATION_DAYS = 90;
  var NIP46_RELAYS = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.primal.net'
  ];

  var IDB_DB_NAME = 'wizardry-blog-auth';
  var IDB_STORE_NAME = 'kv';
  var KEY_DEVICE_SESSION = 'nostr_device_session_v1';
  var KEY_NIP46_PAIR = 'nostr_nip46_pair_v1';

  var state = {
    currentTheme: 'archmage',
    isAuthenticated: false,
    manualChallenge: null,
    pendingDeviceSession: null,
    idbPromise: null,
    nip46: {
      active: false,
      appSecretHex: '',
      appPubkey: '',
      pairSecret: '',
      signerPubkey: '',
      relays: NIP46_RELAYS.slice(),
      pool: null,
      subscription: null,
      pending: {},
      pendingTimers: {},
      seenEvents: {}
    }
  };

  var els = {
    loginBtn: document.getElementById('login-btn'),
    composeLink: document.querySelector('.nav-compose'),
    userMenu: document.getElementById('nav-user-menu'),
    menuBtn: document.getElementById('nav-menu-btn'),
    menuPanel: document.getElementById('nav-menu-panel'),
    menuPrimaryLink: document.getElementById('nav-menu-primary-link'),
    menuLogoutBtn: document.getElementById('nav-menu-logout'),
    menuLogoutEverywhereBtn: document.getElementById('nav-menu-logout-everywhere'),
    userName: document.getElementById('nav-user-name'),

    authModal: document.getElementById('auth-modal'),
    authMessage: document.getElementById('auth-modal-message'),
    authNostrBtn: document.getElementById('auth-nostr-btn'),
    authNip07Btn: document.getElementById('auth-nip07-btn'),
    authPhoneConnectBtn: document.getElementById('auth-phone-connect-btn'),
    authPhoneBtn: document.getElementById('auth-phone-btn'),
    authPasteBtn: document.getElementById('auth-paste-btn'),

    authModeOnce: document.getElementById('auth-mode-once'),
    authModeApprove: document.getElementById('auth-mode-approve'),
    authIntentDaysRow: document.getElementById('auth-intent-days-row'),
    authDelegationDays: document.getElementById('auth-delegation-days'),
    authForceInteractive: document.getElementById('auth-force-interactive'),

    authPhonePanel: document.getElementById('auth-phone-panel'),
    authNip46Qr: document.getElementById('auth-nip46-qr'),
    authNip46Uri: document.getElementById('auth-nip46-uri'),
    authNip46Open: document.getElementById('auth-nip46-open'),

    authManualPanel: document.getElementById('auth-manual-panel'),
    authManualStart: document.getElementById('auth-manual-start'),
    authManualRequestId: document.getElementById('auth-manual-request-id'),
    authManualChallenge: document.getElementById('auth-manual-challenge'),
    authManualExpires: document.getElementById('auth-manual-expires'),
    authManualTemplate: document.getElementById('auth-manual-template'),
    authManualDelegationTemplate: document.getElementById('auth-manual-delegation-template'),
    authManualEvent: document.getElementById('auth-manual-event'),
    authManualDelegation: document.getElementById('auth-manual-delegation'),
    authManualSubmit: document.getElementById('auth-manual-submit')
  };

  var authModalHideTimer = null;

  function nowEpoch() {
    return Math.floor(Date.now() / 1000);
  }

  function randomHex(bytesLen) {
    var size = Number(bytesLen || 16);
    var bytes = new Uint8Array(size);
    window.crypto.getRandomValues(bytes);
    return bytesToHex(bytes);
  }

  function bytesToHex(bytes) {
    return Array.from(bytes || []).map(function (b) {
      return b.toString(16).padStart(2, '0');
    }).join('');
  }

  function hexToBytes(hex) {
    var raw = String(hex || '').trim();
    if (!/^[0-9a-fA-F]+$/.test(raw) || raw.length % 2 !== 0) {
      throw new Error('Invalid hex input');
    }
    var out = new Uint8Array(raw.length / 2);
    for (var i = 0; i < raw.length; i += 2) {
      out[i / 2] = parseInt(raw.slice(i, i + 2), 16);
    }
    return out;
  }

  function compact(text) {
    return String(text || '').replace(/\s+/g, ' ').trim();
  }

  function clampDays(value) {
    var n = Number(value || DEFAULT_DELEGATION_DAYS);
    if (!Number.isFinite(n)) {
      n = DEFAULT_DELEGATION_DAYS;
    }
    n = Math.round(n);
    if (n < MIN_DELEGATION_DAYS) {
      n = MIN_DELEGATION_DAYS;
    }
    if (n > MAX_DELEGATION_DAYS) {
      n = MAX_DELEGATION_DAYS;
    }
    return n;
  }

  function currentHost() {
    return window.location.host;
  }

  function currentOrigin() {
    return window.location.origin;
  }

  function hasNostrTools() {
    return !!(window.NostrTools &&
      typeof window.NostrTools.generateSecretKey === 'function' &&
      typeof window.NostrTools.getPublicKey === 'function' &&
      typeof window.NostrTools.finalizeEvent === 'function' &&
      window.NostrTools.nip04 &&
      typeof window.NostrTools.nip04.encrypt === 'function' &&
      typeof window.NostrTools.nip04.decrypt === 'function' &&
      typeof window.NostrTools.SimplePool === 'function');
  }

  function getBrowserSigner() {
    var signer = window.nostr || null;
    if (!signer) {
      throw new Error('No browser signer detected. Install nos2x-fox or use phone/manual login.');
    }
    if (typeof signer.signEvent !== 'function') {
      throw new Error('Browser signer is missing signEvent.');
    }
    return signer;
  }

  function setAuthMessage(message, kind) {
    if (!els.authMessage) {
      return;
    }
    var text = String(message || '');
    els.authMessage.textContent = text;
    els.authMessage.className = 'auth-modal-message';
    if (text && kind) {
      els.authMessage.classList.add('is-' + kind);
    }
  }

  function setAuthControlsDisabled(disabled) {
    var isDisabled = !!disabled;
    [
      els.authNostrBtn,
      els.authNip07Btn,
      els.authPhoneConnectBtn,
      els.authPhoneBtn,
      els.authPasteBtn,
      els.authManualStart,
      els.authManualSubmit,
      els.authModeOnce,
      els.authModeApprove,
      els.authDelegationDays,
      els.authForceInteractive
    ].forEach(function (node) {
      if (node) {
        node.disabled = isDisabled;
      }
    });
    if (!isDisabled) {
      updatePhoneContinueState();
    }
  }

  function updatePhoneContinueState() {
    if (!els.authPhoneBtn) {
      return;
    }
    var paired = !!state.nip46.signerPubkey;
    els.authPhoneBtn.disabled = !paired;
    els.authPhoneBtn.setAttribute('aria-disabled', paired ? 'false' : 'true');
  }

  function prepareDefaultAuthView() {
    showPanel(els.authPhonePanel, true);
    showPanel(els.authManualPanel, false);
    setAuthMessage('Connect your phone signer first. Continue becomes available after pairing.', 'warn');
    state.nip46.signerPubkey = '';
    updatePhoneContinueState();
    initNip46Pairing().catch(function (err) {
      setAuthMessage(err.message || 'Unable to prepare phone signer QR.', 'error');
    });
  }

  function resetAuthPanels() {
    showPanel(els.authPhonePanel, false);
    showPanel(els.authManualPanel, false);
    state.manualChallenge = null;
    state.pendingDeviceSession = null;
    if (els.authManualRequestId) { els.authManualRequestId.value = ''; }
    if (els.authManualChallenge) { els.authManualChallenge.value = ''; }
    if (els.authManualExpires) { els.authManualExpires.value = ''; }
    if (els.authManualTemplate) { els.authManualTemplate.value = ''; }
    if (els.authManualDelegationTemplate) { els.authManualDelegationTemplate.value = ''; }
    if (els.authManualEvent) { els.authManualEvent.value = ''; }
    if (els.authManualDelegation) { els.authManualDelegation.value = ''; }
  }

  function showAuthModal() {
    if (!els.authModal) {
      return;
    }
    if (authModalHideTimer) {
      clearTimeout(authModalHideTimer);
      authModalHideTimer = null;
    }
    els.authModal.hidden = false;
    requestAnimationFrame(function () {
      els.authModal.classList.add('is-open');
    });
    document.body.classList.add('auth-modal-open');
    resetAuthPanels();
    setAuthControlsDisabled(false);
    prepareDefaultAuthView();
    refreshAuthIntentUi();
  }

  function hideAuthModal() {
    if (!els.authModal) {
      return;
    }
    els.authModal.classList.remove('is-open');
    document.body.classList.remove('auth-modal-open');
    setAuthMessage('', '');
    setAuthControlsDisabled(false);
    if (authModalHideTimer) {
      clearTimeout(authModalHideTimer);
    }
    authModalHideTimer = setTimeout(function () {
      if (!els.authModal.classList.contains('is-open')) {
        els.authModal.hidden = true;
      }
      authModalHideTimer = null;
    }, 210);
  }

  function showPanel(panel, show) {
    if (!panel) {
      return;
    }
    panel.hidden = !show;
  }

  function parseJsonResponse(text) {
    try {
      return JSON.parse(text);
    } catch (_) {
      var c = compact(text || '');
      if (!c) {
        throw new Error('Invalid JSON response');
      }
      throw new Error('Unexpected server response: ' + c.slice(0, 180));
    }
  }

  function fetchJson(url, options) {
    return fetch(url, options)
      .then(function (res) {
        return res.text().then(function (text) {
          return parseJsonResponse(text);
        });
      });
  }

  function postForm(url, payload) {
    var body = new URLSearchParams(payload || {});
    return fetchJson(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    });
  }

  function getSessionToken() {
    return localStorage.getItem('session_token') || '';
  }

  function getCsrfToken() {
    return localStorage.getItem('csrf_token') || '';
  }

  function rememberAuth(data) {
    localStorage.setItem('session_token', data.session_token || '');
    localStorage.setItem('csrf_token', data.csrf_token || '');
    if (data.username) {
      localStorage.setItem('last_auth_username', data.username);
    }
    if (data.pubkey) {
      localStorage.setItem('last_auth_pubkey', data.pubkey);
    }
  }

  function clearLocalStorageAuth() {
    localStorage.removeItem('session_token');
    localStorage.removeItem('csrf_token');
  }

  function openAuthDb() {
    if (!window.indexedDB) {
      return Promise.resolve(null);
    }
    if (state.idbPromise) {
      return state.idbPromise;
    }
    state.idbPromise = new Promise(function (resolve, reject) {
      var req = window.indexedDB.open(IDB_DB_NAME, 1);
      req.onupgradeneeded = function () {
        var db = req.result;
        if (!db.objectStoreNames.contains(IDB_STORE_NAME)) {
          db.createObjectStore(IDB_STORE_NAME);
        }
      };
      req.onsuccess = function () {
        resolve(req.result);
      };
      req.onerror = function () {
        reject(req.error || new Error('IndexedDB unavailable'));
      };
    }).catch(function () {
      return null;
    });
    return state.idbPromise;
  }

  function fallbackKey(key) {
    return 'wizardry_blog_auth_fallback_' + key;
  }

  function idbSet(key, value) {
    return openAuthDb().then(function (db) {
      if (!db) {
        localStorage.setItem(fallbackKey(key), JSON.stringify(value));
        return;
      }
      return new Promise(function (resolve, reject) {
        var tx = db.transaction(IDB_STORE_NAME, 'readwrite');
        tx.objectStore(IDB_STORE_NAME).put(value, key);
        tx.oncomplete = function () { resolve(); };
        tx.onerror = function () { reject(tx.error || new Error('IndexedDB write failed')); };
      });
    });
  }

  function idbGet(key) {
    return openAuthDb().then(function (db) {
      if (!db) {
        var raw = localStorage.getItem(fallbackKey(key));
        if (!raw) {
          return null;
        }
        try {
          return JSON.parse(raw);
        } catch (_) {
          return null;
        }
      }
      return new Promise(function (resolve, reject) {
        var tx = db.transaction(IDB_STORE_NAME, 'readonly');
        var req = tx.objectStore(IDB_STORE_NAME).get(key);
        req.onsuccess = function () { resolve(req.result || null); };
        req.onerror = function () { reject(req.error || new Error('IndexedDB read failed')); };
      });
    });
  }

  function idbDelete(key) {
    return openAuthDb().then(function (db) {
      if (!db) {
        localStorage.removeItem(fallbackKey(key));
        return;
      }
      return new Promise(function (resolve, reject) {
        var tx = db.transaction(IDB_STORE_NAME, 'readwrite');
        tx.objectStore(IDB_STORE_NAME).delete(key);
        tx.oncomplete = function () { resolve(); };
        tx.onerror = function () { reject(tx.error || new Error('IndexedDB delete failed')); };
      });
    });
  }

  function clearLocalKeyMaterial() {
    return Promise.all([
      idbDelete(KEY_DEVICE_SESSION),
      idbDelete(KEY_NIP46_PAIR)
    ]).then(function () {
      state.nip46.active = false;
      state.nip46.signerPubkey = '';
      state.nip46.appSecretHex = '';
      state.nip46.appPubkey = '';
      state.nip46.pairSecret = '';
      state.nip46.pending = {};
      state.nip46.pendingTimers = {};
      state.nip46.seenEvents = {};
      if (state.nip46.subscription && typeof state.nip46.subscription.close === 'function') {
        state.nip46.subscription.close();
      }
      state.nip46.subscription = null;
      if (state.nip46.pool && typeof state.nip46.pool.destroy === 'function') {
        state.nip46.pool.destroy();
      }
      state.nip46.pool = null;
    });
  }

  function loadDeviceSession() {
    return idbGet(KEY_DEVICE_SESSION).then(function (record) {
      if (!record || typeof record !== 'object') {
        return null;
      }
      if (record.domain !== currentHost()) {
        return null;
      }
      if (!record.expiresAt || Number(record.expiresAt) <= nowEpoch()) {
        return null;
      }
      if (!record.sessionSecretHex || !record.sessionPubkey || !record.userPubkey) {
        return null;
      }
      return record;
    });
  }

  function saveDeviceSession(record) {
    return idbSet(KEY_DEVICE_SESSION, record);
  }

  function createSessionRecord(userPubkey, days) {
    if (!hasNostrTools()) {
      throw new Error('Nostr tools are unavailable in this browser.');
    }
    var durationDays = clampDays(days);
    var secretBytes = window.NostrTools.generateSecretKey();
    var sessionPubkey = window.NostrTools.getPublicKey(secretBytes);
    var expiresAt = nowEpoch() + durationDays * 86400;
    return {
      version: 1,
      domain: currentHost(),
      createdAt: nowEpoch(),
      expiresAt: expiresAt,
      days: durationDays,
      userPubkey: String(userPubkey || ''),
      sessionPubkey: sessionPubkey,
      sessionSecretHex: bytesToHex(secretBytes)
    };
  }

  function authEventTemplate(challenge, action, pubkey) {
    var eventAction = action || 'login';
    var signerPubkey = String(pubkey || '').trim();
    return {
      kind: AUTH_KIND,
      created_at: nowEpoch(),
      tags: [
        ['challenge', String(challenge || '')],
        ['relay', currentOrigin()],
        ['origin', currentHost()],
        ['domain', currentHost()],
        ['action', eventAction]
      ],
      content: '',
      pubkey: signerPubkey || undefined
    };
  }

  function delegationEventTemplate(record, pubkey) {
    var signerPubkey = String(pubkey || '').trim();
    return {
      kind: DELEGATION_KIND,
      created_at: nowEpoch(),
      tags: [
        ['session_pubkey', String(record.sessionPubkey || '')],
        ['domain', currentHost()],
        ['expires_at', String(record.expiresAt || 0)],
        ['scope', 'auth'],
        ['action', 'delegate_session']
      ],
      content: 'wizardry delegated session authorization',
      pubkey: signerPubkey || undefined
    };
  }

  function normalizeSignedEvent(result) {
    if (typeof result === 'string') {
      return parseJsonResponse(result);
    }
    if (result && typeof result === 'object') {
      return result;
    }
    throw new Error('Signer did not return a valid signed event.');
  }

  function signedEventPubkey(result) {
    var normalized = normalizeSignedEvent(result);
    return String((normalized && normalized.pubkey) || '').trim();
  }

  function signWithLocalSecret(template, secretHex) {
    if (!hasNostrTools()) {
      throw new Error('Nostr tools are unavailable in this browser.');
    }
    var secretBytes = hexToBytes(secretHex);
    return window.NostrTools.finalizeEvent(template, secretBytes);
  }

  function beginChallenge(pubkeyHint) {
    var payload = {};
    if (pubkeyHint) {
      payload.pubkey_hint = pubkeyHint;
    }
    return postForm('/cgi/nostr-auth-login-begin', payload)
      .then(function (data) {
        if (!data || !data.success) {
          throw new Error((data && data.error) || 'Unable to create login challenge.');
        }
        return data;
      });
  }

  function finishLogin(requestId, signedEvent, delegationEvent, forceInteractive) {
    var payload = {
      request_id: requestId,
      event_json: JSON.stringify(normalizeSignedEvent(signedEvent)),
      force_interactive: forceInteractive ? 'true' : 'false'
    };
    if (delegationEvent) {
      payload.delegation_json = JSON.stringify(normalizeSignedEvent(delegationEvent));
    }
    return postForm('/cgi/nostr-auth-login-finish', payload)
      .then(function (data) {
        if (!data || !data.success) {
          throw new Error((data && data.error) || 'Nostr login failed.');
        }
        return data;
      });
  }

  function getAuthIntent() {
    var approve = !!(els.authModeApprove && els.authModeApprove.checked);
    var days = clampDays(els.authDelegationDays ? els.authDelegationDays.value : DEFAULT_DELEGATION_DAYS);
    if (els.authDelegationDays) {
      els.authDelegationDays.value = String(days);
    }
    return {
      mode: approve ? 'approve' : 'once',
      days: days,
      forceInteractive: !!(els.authForceInteractive && els.authForceInteractive.checked)
    };
  }

  function refreshAuthIntentUi() {
    var intent = getAuthIntent();
    if (els.authIntentDaysRow) {
      els.authIntentDaysRow.hidden = intent.mode !== 'approve';
    }
  }

  function applyLoggedInUi(isLoggedIn, isAdmin, username) {
    var displayName = String(username || '');
    state.isAuthenticated = !!isLoggedIn;

    if (isLoggedIn) {
      if (els.loginBtn) {
        els.loginBtn.style.display = 'none';
      }
      if (els.composeLink) {
        els.composeLink.style.display = isAdmin ? 'inline-block' : 'none';
      }
      if (els.userMenu) {
        if (els.menuPrimaryLink) {
          if (isAdmin) {
            els.menuPrimaryLink.textContent = 'Admin';
            els.menuPrimaryLink.href = '/pages/admin.html';
          } else {
            els.menuPrimaryLink.textContent = 'Account';
            els.menuPrimaryLink.href = '/pages/admin.html#account';
          }
        }
        els.userMenu.style.display = 'inline-flex';
      }
      if (els.userName) {
        els.userName.style.display = 'inline-block';
        els.userName.textContent = displayName || 'signed-in';
        els.userName.setAttribute('role', 'link');
        els.userName.setAttribute('tabindex', '0');
        els.userName.setAttribute('aria-label', 'Open account settings');
      }
      return;
    }

    if (els.loginBtn) {
      els.loginBtn.style.display = 'inline-block';
    }
    if (els.composeLink) {
      els.composeLink.style.display = 'none';
    }
    if (els.userMenu) {
      els.userMenu.style.display = 'none';
      closeUserMenu();
    }
    if (els.userName) {
      els.userName.style.display = 'none';
      els.userName.textContent = '';
      els.userName.removeAttribute('role');
      els.userName.removeAttribute('tabindex');
      els.userName.removeAttribute('aria-label');
    }
  }

  function checkAuth() {
    var token = getSessionToken();
    if (!token) {
      applyLoggedInUi(false, false, '');
      return Promise.resolve();
    }

    return fetch('/cgi/ssh-auth-check-session?session_token=' + encodeURIComponent(token))
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (!data || !data.authenticated) {
          clearLocalStorageAuth();
          applyLoggedInUi(false, false, '');
          return;
        }
        if (data.csrf_token) {
          localStorage.setItem('csrf_token', data.csrf_token);
        }
        if (data.nostr_pubkey) {
          localStorage.setItem('last_auth_pubkey', data.nostr_pubkey);
        }
        applyLoggedInUi(true, !!data.is_admin, data.player_name || data.username || '');
      })
      .catch(function () {
        applyLoggedInUi(false, false, '');
      });
  }

  function finalizeLoginUiAfterSuccess() {
    return checkAuth().then(function () {
      if (!state.isAuthenticated) {
        throw new Error('Login signature was accepted, but no active session was established. Try again and check signer permissions for this domain.');
      }
      hideAuthModal();
      window.location.reload();
    });
  }

  function openUserMenu() {
    if (!els.menuPanel || !els.menuBtn) {
      return;
    }
    els.menuPanel.hidden = false;
    els.menuBtn.setAttribute('aria-expanded', 'true');
  }

  function closeUserMenu() {
    if (!els.menuPanel || !els.menuBtn) {
      return;
    }
    els.menuPanel.hidden = true;
    els.menuBtn.setAttribute('aria-expanded', 'false');
  }

  function logout() {
    var token = getSessionToken();
    if (!token) {
      clearLocalStorageAuth();
      return clearLocalKeyMaterial().finally(function () {
        applyLoggedInUi(false, false, '');
      });
    }

    var body = new URLSearchParams({
      session_token: token,
      csrf_token: getCsrfToken()
    });

    return fetch('/cgi/ssh-auth-logout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    }).catch(function () {
      return null;
    }).finally(function () {
      clearLocalStorageAuth();
      return clearLocalKeyMaterial().finally(function () {
        applyLoggedInUi(false, false, '');
        window.location.reload();
      });
    });
  }

  function buildNostrConnectUri(appPubkey, pairSecret, relays) {
    var params = new URLSearchParams();
    relays.forEach(function (relay) {
      params.append('relay', relay);
    });
    params.set('secret', pairSecret);
    params.set('name', 'Wizardry Blog');
    return 'nostrconnect://' + appPubkey + '?' + params.toString();
  }

  function renderQrCode(value) {
    if (!els.authNip46Qr) {
      return;
    }
    els.authNip46Qr.innerHTML = '';
    if (typeof window.QRCode === 'function') {
      new window.QRCode(els.authNip46Qr, {
        text: value,
        width: 196,
        height: 196,
        colorDark: '#0f172a',
        colorLight: '#ffffff',
        correctLevel: window.QRCode.CorrectLevel.M
      });
      return;
    }
    var pre = document.createElement('pre');
    pre.textContent = value;
    els.authNip46Qr.appendChild(pre);
  }

  function initNip46Pairing() {
    if (!hasNostrTools()) {
      throw new Error('NIP-46 requires nostr-tools support in this browser.');
    }

    if (state.nip46.active) {
      return Promise.resolve();
    }

    return idbGet(KEY_NIP46_PAIR).then(function (saved) {
      var appSecretHex = '';
      var pairSecret = '';
      var relays = NIP46_RELAYS.slice();

      if (saved && typeof saved === 'object' && saved.domain === currentHost()) {
        appSecretHex = String(saved.appSecretHex || '');
        pairSecret = String(saved.pairSecret || '');
        if (Array.isArray(saved.relays) && saved.relays.length) {
          relays = saved.relays.map(function (item) { return String(item || '').trim(); }).filter(Boolean).slice(0, 3);
        }
      }

      if (!appSecretHex) {
        appSecretHex = bytesToHex(window.NostrTools.generateSecretKey());
      }
      if (!pairSecret) {
        pairSecret = randomHex(16);
      }

      var appPubkey = window.NostrTools.getPublicKey(hexToBytes(appSecretHex));

      state.nip46.active = true;
      state.nip46.appSecretHex = appSecretHex;
      state.nip46.appPubkey = appPubkey;
      state.nip46.pairSecret = pairSecret;
      state.nip46.relays = relays;
      state.nip46.signerPubkey = '';
      state.nip46.pool = new window.NostrTools.SimplePool();
      state.nip46.pending = {};
      state.nip46.pendingTimers = {};
      state.nip46.seenEvents = {};

      state.nip46.subscription = state.nip46.pool.subscribeMany(
        state.nip46.relays,
        [{ kinds: [NIP46_KIND], '#p': [state.nip46.appPubkey], since: nowEpoch() - 30 }],
        {
          onevent: function (event) {
            handleNip46RelayEvent(event);
          }
        }
      );

      return idbSet(KEY_NIP46_PAIR, {
        version: 1,
        domain: currentHost(),
        appSecretHex: appSecretHex,
        appPubkey: appPubkey,
        pairSecret: pairSecret,
        relays: state.nip46.relays,
        createdAt: nowEpoch()
      });
    }).then(function () {
      var uri = buildNostrConnectUri(state.nip46.appPubkey, state.nip46.pairSecret, state.nip46.relays);
      if (els.authNip46Uri) {
        els.authNip46Uri.textContent = uri;
      }
      if (els.authNip46Open) {
        els.authNip46Open.href = uri;
      }
      renderQrCode(uri);
    });
  }

  function resolveNip46Pending(id, payload, isError) {
    var entry = state.nip46.pending[id];
    if (!entry) {
      return;
    }
    delete state.nip46.pending[id];
    if (state.nip46.pendingTimers[id]) {
      clearTimeout(state.nip46.pendingTimers[id]);
      delete state.nip46.pendingTimers[id];
    }
    if (isError) {
      entry.reject(new Error(payload || 'NIP-46 request failed'));
    } else {
      entry.resolve(payload);
    }
  }

  function extractConnectSecret(msg) {
    if (!msg) {
      return '';
    }
    if (typeof msg.secret === 'string') {
      return msg.secret;
    }
    if (Array.isArray(msg.params)) {
      if (typeof msg.params[1] === 'string') {
        return msg.params[1];
      }
      if (typeof msg.params[0] === 'string' && msg.params.length === 1) {
        return msg.params[0];
      }
      if (msg.params[0] && typeof msg.params[0] === 'object' && typeof msg.params[0].secret === 'string') {
        return msg.params[0].secret;
      }
    }
    return '';
  }

  function handleNip46RelayEvent(event) {
    if (!event || !event.id || state.nip46.seenEvents[event.id]) {
      return;
    }
    state.nip46.seenEvents[event.id] = true;

    window.NostrTools.nip04.decrypt(hexToBytes(state.nip46.appSecretHex), event.pubkey, event.content)
      .then(function (plain) {
        var msg = parseJsonResponse(plain);

        if (msg && msg.method === 'connect') {
          var secret = extractConnectSecret(msg);
          if (secret && secret !== state.nip46.pairSecret) {
            return;
          }
          state.nip46.signerPubkey = String(event.pubkey || '');
          updatePhoneContinueState();
          setAuthMessage('Phone signer paired. You can continue login now.', 'ok');
          return;
        }

        if (msg && msg.id && state.nip46.pending[msg.id]) {
          if (msg.error) {
            resolveNip46Pending(msg.id, typeof msg.error === 'string' ? msg.error : JSON.stringify(msg.error), true);
            return;
          }
          resolveNip46Pending(msg.id, msg.result, false);
        }
      })
      .catch(function () {
        // Ignore malformed or unrelated relay events.
      });
  }

  function sendNip46Rpc(method, params, timeoutMs) {
    if (!state.nip46.signerPubkey) {
      return Promise.reject(new Error('Phone signer is not paired yet. Scan QR first.'));
    }

    var requestId = randomHex(12);
    var timeout = Number(timeoutMs || 60000);
    var rpc = {
      id: requestId,
      method: method,
      params: params || []
    };

    return window.NostrTools.nip04.encrypt(
      hexToBytes(state.nip46.appSecretHex),
      state.nip46.signerPubkey,
      JSON.stringify(rpc)
    ).then(function (ciphertext) {
      var eventTemplate = {
        kind: NIP46_KIND,
        created_at: nowEpoch(),
        tags: [['p', state.nip46.signerPubkey]],
        content: ciphertext
      };
      var signed = window.NostrTools.finalizeEvent(eventTemplate, hexToBytes(state.nip46.appSecretHex));

      return new Promise(function (resolve, reject) {
        state.nip46.pending[requestId] = { resolve: resolve, reject: reject };
        state.nip46.pendingTimers[requestId] = setTimeout(function () {
          resolveNip46Pending(requestId, 'Phone signer timed out. Try again.', true);
        }, timeout);

        state.nip46.pool.publish(state.nip46.relays, signed);
      });
    });
  }

  function nip46SignEvent(template) {
    return sendNip46Rpc('sign_event', [template], 70000)
      .then(function (result) {
        if (typeof result === 'string') {
          return parseJsonResponse(result);
        }
        return normalizeSignedEvent(result);
      });
  }

  function waitForPhonePairing(timeoutMs) {
    var timeout = Number(timeoutMs || 90000);
    if (state.nip46.signerPubkey) {
      return Promise.resolve(state.nip46.signerPubkey);
    }

    return new Promise(function (resolve, reject) {
      var started = Date.now();
      var timer = setInterval(function () {
        if (state.nip46.signerPubkey) {
          clearInterval(timer);
          resolve(state.nip46.signerPubkey);
          return;
        }
        if (Date.now() - started > timeout) {
          clearInterval(timer);
          reject(new Error('Phone pairing timed out. Scan the QR and try again.'));
        }
      }, 350);
    });
  }

  function tryDelegatedSessionLogin(intent) {
    if (!intent || intent.mode !== 'approve') {
      return Promise.resolve(false);
    }

    return loadDeviceSession()
      .then(function (record) {
        if (!record) {
          return false;
        }
        return beginChallenge(record.userPubkey)
          .then(function (begin) {
            var signed = signWithLocalSecret(authEventTemplate(begin.challenge, 'login', record.sessionPubkey), record.sessionSecretHex);
            return finishLogin(begin.request_id, signed, null, intent.forceInteractive)
              .then(function (finish) {
                rememberAuth(finish);
                return finalizeLoginUiAfterSuccess().then(function () {
                  return true;
                });
              });
          })
          .catch(function () {
            return idbDelete(KEY_DEVICE_SESSION).then(function () {
              return false;
            });
          });
      });
  }

  function signInWithSigner(signEventFn, options) {
    var opts = options && typeof options === 'object' ? options : {};
    var getPubkeyFn = typeof opts.getPubkeyFn === 'function' ? opts.getPubkeyFn : null;
    var pubkeyHint = String(opts.pubkeyHint || '').trim();
    var intent = getAuthIntent();

    return tryDelegatedSessionLogin(intent)
      .then(function (usedDelegated) {
        if (usedDelegated) {
          return;
        }

        setAuthMessage('Creating a single-use login challenge...', 'warn');
        return beginChallenge(pubkeyHint || localStorage.getItem('last_auth_pubkey') || '')
          .then(function (begin) {
            var authTemplate = authEventTemplate(begin.challenge, 'login', pubkeyHint);
            setAuthMessage('Sign the login challenge event...', 'warn');
            return Promise.resolve(signEventFn(authTemplate)).then(function (signedAuth) {
              var userPubkey = signedEventPubkey(signedAuth);
              if (!userPubkey && getPubkeyFn) {
                return Promise.resolve(getPubkeyFn()).then(function (fallbackPubkey) {
                  return {
                    begin: begin,
                    userPubkey: String(fallbackPubkey || '').trim(),
                    signedAuth: signedAuth
                  };
                });
              }
              return {
                begin: begin,
                userPubkey: userPubkey,
                signedAuth: signedAuth
              };
            });
          })
          .then(function (payload) {
            var delegationSigned = null;
            state.pendingDeviceSession = null;
            if (!payload.userPubkey) {
              throw new Error('Signed auth event is missing pubkey.');
            }
            localStorage.setItem('last_auth_pubkey', payload.userPubkey);

            if (intent.mode === 'approve') {
              state.pendingDeviceSession = createSessionRecord(payload.userPubkey, intent.days);
              var delegationTemplate = delegationEventTemplate(state.pendingDeviceSession, payload.userPubkey);
              setAuthMessage('Sign delegation for approved device session...', 'warn');
              return Promise.resolve(signEventFn(delegationTemplate)).then(function (signedDelegation) {
                delegationSigned = signedDelegation;
                return {
                  begin: payload.begin,
                  signedAuth: payload.signedAuth,
                  delegationSigned: delegationSigned
                };
              });
            }

            return {
              begin: payload.begin,
              signedAuth: payload.signedAuth,
              delegationSigned: null
            };
          })
          .then(function (payload) {
            return finishLogin(
              payload.begin.request_id,
              payload.signedAuth,
              payload.delegationSigned,
              intent.forceInteractive
            );
          })
          .then(function (finish) {
            rememberAuth(finish);
            if (intent.mode === 'approve' && state.pendingDeviceSession) {
              state.pendingDeviceSession.delegationId = finish.delegation_id || '';
              return saveDeviceSession(state.pendingDeviceSession).then(function () {
                state.pendingDeviceSession = null;
              });
            }
            return idbDelete(KEY_DEVICE_SESSION);
          })
          .then(function () {
            return finalizeLoginUiAfterSuccess();
          });
      });
  }

  function loginWithNip07() {
    var signer = getBrowserSigner();
    return signInWithSigner(
      function (template) {
        return Promise.resolve(signer.signEvent(template));
      },
      {
        getPubkeyFn: typeof signer.getPublicKey === 'function'
          ? function () { return Promise.resolve(signer.getPublicKey()); }
          : null,
        pubkeyHint: localStorage.getItem('last_auth_pubkey') || ''
      }
    );
  }

  function loginWithPhoneSigner() {
    if (!hasNostrTools()) {
      return Promise.reject(new Error('Phone signer pairing requires nostr-tools support.'));
    }

    showPanel(els.authPhonePanel, true);
    showPanel(els.authManualPanel, false);

    return initNip46Pairing()
      .then(function () {
        if (!state.nip46.signerPubkey) {
          throw new Error('Phone signer is not paired yet. Connect it first via QR.');
        }
        return signInWithSigner(
          function (template) {
            return nip46SignEvent(template);
          },
          {
            pubkeyHint: state.nip46.signerPubkey
          }
        );
      });
  }

  function prepareManualLogin() {
    var intent = getAuthIntent();
    state.pendingDeviceSession = null;

    setAuthMessage('Creating a single-use login challenge...', 'warn');
    showPanel(els.authManualPanel, true);
    showPanel(els.authPhonePanel, false);

    return beginChallenge(localStorage.getItem('last_auth_pubkey') || '')
      .then(function (begin) {
        state.manualChallenge = begin;

        if (els.authManualRequestId) {
          els.authManualRequestId.value = begin.request_id || '';
        }
        if (els.authManualChallenge) {
          els.authManualChallenge.value = begin.challenge || '';
        }
        if (els.authManualExpires) {
          els.authManualExpires.value = String(begin.expires_at || '');
        }

        var authTemplate = authEventTemplate(begin.challenge, 'login', localStorage.getItem('last_auth_pubkey') || '');
        if (els.authManualTemplate) {
          els.authManualTemplate.value = JSON.stringify(authTemplate, null, 2);
        }

        if (intent.mode === 'approve') {
          var pubkeyHint = localStorage.getItem('last_auth_pubkey') || '';
          state.pendingDeviceSession = createSessionRecord(pubkeyHint, intent.days);
          var dTemplate = delegationEventTemplate(state.pendingDeviceSession, pubkeyHint);
          if (els.authManualDelegationTemplate) {
            els.authManualDelegationTemplate.value = JSON.stringify(dTemplate, null, 2);
          }
        } else if (els.authManualDelegationTemplate) {
          els.authManualDelegationTemplate.value = '';
        }

        setAuthMessage('Challenge created. Sign the auth event and paste JSON below.', 'ok');
      });
  }

  function submitManualLogin() {
    if (!state.manualChallenge || !state.manualChallenge.request_id) {
      return Promise.reject(new Error('Create a challenge first.'));
    }

    var signedAuthRaw = els.authManualEvent ? String(els.authManualEvent.value || '').trim() : '';
    if (!signedAuthRaw) {
      return Promise.reject(new Error('Signed auth event JSON is required.'));
    }

    var signedDelegationRaw = els.authManualDelegation ? String(els.authManualDelegation.value || '').trim() : '';
    var intent = getAuthIntent();
    if (intent.mode === 'approve' && !signedDelegationRaw) {
      return Promise.reject(new Error('Signed delegation JSON is required for approved-device mode.'));
    }

    var signedAuth;
    var signedDelegation = null;
    try {
      signedAuth = parseJsonResponse(signedAuthRaw);
    } catch (_) {
      throw new Error('Signed auth event JSON is invalid.');
    }
    if (signedDelegationRaw) {
      try {
        signedDelegation = parseJsonResponse(signedDelegationRaw);
      } catch (_) {
        throw new Error('Signed delegation JSON is invalid.');
      }
    }

    return finishLogin(
      state.manualChallenge.request_id,
      signedAuth,
      signedDelegation,
      intent.forceInteractive
    ).then(function (finish) {
      rememberAuth(finish);

      if (intent.mode === 'approve' && state.pendingDeviceSession) {
        state.pendingDeviceSession.userPubkey = finish.pubkey || state.pendingDeviceSession.userPubkey;
        state.pendingDeviceSession.delegationId = finish.delegation_id || '';
        return saveDeviceSession(state.pendingDeviceSession).then(function () {
          state.pendingDeviceSession = null;
          return finalizeLoginUiAfterSuccess();
        });
      }

      return idbDelete(KEY_DEVICE_SESSION).then(function () {
        return finalizeLoginUiAfterSuccess();
      });
    });
  }

  function revokeEverywhereWithSigner(signEventFn) {
    var token = getSessionToken();
    var csrf = getCsrfToken();
    if (!token || !csrf) {
      return Promise.reject(new Error('You are not currently signed in.'));
    }

    return postForm('/cgi/nostr-auth-revoke-all-begin', {
      session_token: token,
      csrf_token: csrf
    }).then(function (begin) {
      if (!begin || !begin.success) {
        throw new Error((begin && begin.error) || 'Unable to start revocation challenge.');
      }

      var revokeTemplate = authEventTemplate(begin.challenge, 'revoke_all', begin.pubkey || '');
      return Promise.resolve(signEventFn(revokeTemplate))
        .then(function (signed) {
          return postForm('/cgi/nostr-auth-revoke-all-finish', {
            session_token: token,
            csrf_token: csrf,
            request_id: begin.request_id,
            event_json: JSON.stringify(normalizeSignedEvent(signed))
          });
        });
    }).then(function (finish) {
      if (!finish || !finish.success) {
        throw new Error((finish && finish.error) || 'Revocation failed.');
      }
      setAuthMessage('All active delegated sessions were revoked.', 'ok');
      clearLocalStorageAuth();
      return clearLocalKeyMaterial().finally(function () {
        window.location.reload();
      });
    });
  }

  function logoutEverywhere() {
    if (typeof window.nostr !== 'undefined' && window.nostr && typeof window.nostr.signEvent === 'function') {
      return revokeEverywhereWithSigner(function (template) {
        return Promise.resolve(window.nostr.signEvent(template));
      });
    }

    if (state.nip46.signerPubkey) {
      return revokeEverywhereWithSigner(function (template) {
        return nip46SignEvent(template);
      });
    }

    return Promise.reject(new Error('Fresh signer approval is required. Use Login with Nostr or phone signer first.'));
  }

  function goToAccountSettings() {
    window.location.href = '/pages/admin.html#account';
  }

  function highlightCurrentPage() {
    var currentPath = window.location.pathname;
    var currentHash = window.location.hash || '';
    var navLinks = document.querySelectorAll('.nav-center a[data-page]');

    navLinks.forEach(function (link) {
      var href = link.getAttribute('href') || '';
      if (currentPath.indexOf(href) !== -1 ||
          (currentPath === '/' && href.indexOf('index.html') !== -1) ||
          (currentPath.endsWith('/') && href.indexOf('index.html') !== -1)) {
        link.classList.add('active');
      }
    });

    if (els.composeLink) {
      var onCompose = currentPath.indexOf('/pages/admin.html') !== -1 && currentHash === '#compose';
      els.composeLink.classList.toggle('active', onCompose);
      els.composeLink.setAttribute('aria-disabled', onCompose ? 'true' : 'false');
      if (onCompose) {
        els.composeLink.setAttribute('tabindex', '-1');
      } else {
        els.composeLink.removeAttribute('tabindex');
      }
    }
  }

  function updateThemeSelect() {
    var themeSelect = document.getElementById('theme-select');
    if (themeSelect) {
      themeSelect.value = state.currentTheme;
    }
  }

  function updateThemeStylesheet(theme) {
    var themeLink = document.getElementById('theme-stylesheet');
    if (themeLink) {
      themeLink.href = '/static/themes/' + theme + '.css';
    }
  }

  function loadTheme() {
    return fetch('/cgi/blog-get-config')
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data && data.theme) {
          state.currentTheme = data.theme;
          updateThemeStylesheet(state.currentTheme);
        }
        updateThemeSelect();
      })
      .catch(function () {
        updateThemeSelect();
      });
  }

  function saveTheme(theme) {
    var params = new URLSearchParams({ theme: theme });
    fetch('/cgi/blog-set-theme', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString()
    }).catch(function () {
      // Keep local style even if persistence fails.
    });
  }

  function bindThemeSelect() {
    var themeSelect = document.getElementById('theme-select');
    if (!themeSelect) {
      return;
    }

    function preserveFocus() {
      if (document.activeElement === themeSelect) {
        return;
      }
      setTimeout(function () {
        try {
          themeSelect.focus({ preventScroll: true });
        } catch (_) {
          themeSelect.focus();
        }
      }, 0);
    }

    themeSelect.addEventListener('change', function (event) {
      var nextTheme = event.target.value;
      state.currentTheme = nextTheme;
      updateThemeStylesheet(nextTheme);
      saveTheme(nextTheme);
      preserveFocus();
    });
  }

  function bindUiEvents() {
    if (els.loginBtn) {
      els.loginBtn.addEventListener('click', function () {
        showAuthModal();
      });
    }

    if (els.authModal) {
      els.authModal.addEventListener('click', function (event) {
        if (event.target && event.target.hasAttribute('data-close-auth-modal')) {
          hideAuthModal();
        }
      });
    }

    if (els.menuBtn && els.menuPanel) {
      els.menuBtn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (els.menuPanel.hidden) {
          openUserMenu();
        } else {
          closeUserMenu();
        }
      });
    }

    if (els.menuLogoutBtn) {
      els.menuLogoutBtn.addEventListener('click', function () {
        closeUserMenu();
        logout();
      });
    }

    if (els.menuLogoutEverywhereBtn) {
      els.menuLogoutEverywhereBtn.addEventListener('click', function () {
        closeUserMenu();
        setAuthMessage('Preparing log out everywhere challenge...', 'warn');
        logoutEverywhere().catch(function (err) {
          setAuthMessage(err.message || 'Log out everywhere failed.', 'error');
          showAuthModal();
        });
      });
    }

    if (els.userName) {
      els.userName.addEventListener('click', function () {
        if (state.isAuthenticated) {
          closeUserMenu();
          goToAccountSettings();
        }
      });

      els.userName.addEventListener('keydown', function (event) {
        if (!state.isAuthenticated) {
          return;
        }
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          closeUserMenu();
          goToAccountSettings();
        }
      });
    }

    document.addEventListener('click', function (event) {
      if (!els.userMenu || els.userMenu.style.display === 'none') {
        return;
      }
      if (!els.userMenu.contains(event.target)) {
        closeUserMenu();
      }
    });

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && els.authModal && !els.authModal.hidden) {
        hideAuthModal();
      }
    });

    if (els.authModeOnce) {
      els.authModeOnce.addEventListener('change', refreshAuthIntentUi);
    }
    if (els.authModeApprove) {
      els.authModeApprove.addEventListener('change', refreshAuthIntentUi);
    }
    if (els.authDelegationDays) {
      els.authDelegationDays.addEventListener('input', refreshAuthIntentUi);
    }

    if (els.authNip07Btn) {
      els.authNip07Btn.addEventListener('click', function () {
        setAuthMessage('Starting desktop signer login...', 'warn');
        setAuthControlsDisabled(true);
        loginWithNip07().catch(function (err) {
          setAuthMessage(err.message || 'Desktop signer login failed.', 'error');
        }).finally(function () {
          setAuthControlsDisabled(false);
        });
      });
    }

    if (els.authPhoneConnectBtn) {
      els.authPhoneConnectBtn.addEventListener('click', function () {
        setAuthMessage('Preparing phone signer pairing QR...', 'warn');
        setAuthControlsDisabled(true);
        initNip46Pairing().then(function () {
          showPanel(els.authPhonePanel, true);
          showPanel(els.authManualPanel, false);
          setAuthMessage('Scan QR in your signer app. Continue unlocks after pairing.', 'warn');
          return waitForPhonePairing(90000);
        }).then(function () {
          updatePhoneContinueState();
          setAuthMessage('Phone signer paired. Continue is ready.', 'ok');
        }).catch(function (err) {
          setAuthMessage(err.message || 'Phone pairing setup failed.', 'error');
        }).finally(function () {
          setAuthControlsDisabled(false);
        });
      });
    }

    if (els.authPhoneBtn) {
      els.authPhoneBtn.addEventListener('click', function () {
        setAuthMessage('Starting phone signer login...', 'warn');
        setAuthControlsDisabled(true);
        loginWithPhoneSigner().catch(function (err) {
          setAuthMessage(err.message || 'Phone signer login failed.', 'error');
        }).finally(function () {
          setAuthControlsDisabled(false);
        });
      });
    }

    if (els.authPasteBtn) {
      els.authPasteBtn.addEventListener('click', function () {
        setAuthControlsDisabled(true);
        prepareManualLogin().catch(function (err) {
          setAuthMessage(err.message || 'Failed to prepare manual login.', 'error');
        }).finally(function () {
          setAuthControlsDisabled(false);
        });
      });
    }

    if (els.authManualStart) {
      els.authManualStart.addEventListener('click', function () {
        setAuthControlsDisabled(true);
        prepareManualLogin().catch(function (err) {
          setAuthMessage(err.message || 'Failed to create manual challenge.', 'error');
        }).finally(function () {
          setAuthControlsDisabled(false);
        });
      });
    }

    if (els.authManualSubmit) {
      els.authManualSubmit.addEventListener('click', function () {
        setAuthMessage('Verifying pasted signed login...', 'warn');
        setAuthControlsDisabled(true);
        Promise.resolve()
          .then(function () {
            return submitManualLogin();
          })
          .catch(function (err) {
            setAuthMessage(err.message || 'Manual login failed.', 'error');
          })
          .finally(function () {
            setAuthControlsDisabled(false);
          });
      });
    }
  }

  function bootstrap() {
    highlightCurrentPage();
    window.addEventListener('hashchange', highlightCurrentPage);
    bindThemeSelect();
    bindUiEvents();
    window.blogAuth = window.blogAuth || {};
    window.blogAuth.openLoginModal = showAuthModal;
    refreshAuthIntentUi();
    loadTheme();
    checkAuth();
  }

  document.addEventListener('DOMContentLoaded', bootstrap);
})();
