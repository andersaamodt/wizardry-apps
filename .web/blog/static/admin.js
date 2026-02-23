(function () {
  const state = {
    sessionToken: localStorage.getItem('session_token') || '',
    csrfToken: localStorage.getItem('csrf_token') || '',
    username: '',
    playerName: '',
    nostrPubkey: '',
    sshFingerprint: '',
    isAdmin: false,
    composeTags: [],
    currentDraftId: '',
    autosaveTimer: null,
    suspendAutosave: false,
    previewVisible: localStorage.getItem('blog_admin_preview_hidden') !== '1',
    nostrBridgeEnabled: false
  };

  const els = {
    authStatus: document.getElementById('admin-access-message'),
    adminPanel: document.getElementById('admin-panel'),
    outputConfig: document.getElementById('output-config'),
    outputCompose: document.getElementById('output-compose'),
    outputQueue: document.getElementById('output-queue'),
    outputAccount: document.getElementById('output-account'),
    siteTitle: document.getElementById('site-title'),
    adminTheme: document.getElementById('admin-theme'),
    registrationEnabled: document.getElementById('registration-enabled'),
    dripInterval: document.getElementById('drip-interval'),
    dripRandomness: document.getElementById('drip-randomness'),
    feedFullText: document.getElementById('feed-full-text'),
    feedItems: document.getElementById('feed-items'),
    nostrBridgeEnabled: document.getElementById('nostr-bridge-enabled'),
    postTitle: document.getElementById('post-title'),
    postTags: document.getElementById('post-tags'),
    postTagsInput: document.getElementById('post-tags-input'),
    postTagsEditor: document.getElementById('post-tags-editor'),
    postTagsPills: document.getElementById('post-tags-pills'),
    postSummary: document.getElementById('post-summary'),
    postContent: document.getElementById('post-content'),
    postScheduleAt: document.getElementById('post-scheduled-at'),
    scheduledRow: document.getElementById('scheduled-row'),
    markdownPreview: document.getElementById('markdown-preview'),
    composeShell: document.querySelector('.compose-shell'),
    togglePreviewButton: document.getElementById('btn-toggle-preview'),
    draftsList: document.getElementById('drafts-list'),
    queueList: document.getElementById('queue-list'),
    currentDraftLabel: document.getElementById('current-draft-label'),
    accountPlayerName: document.getElementById('account-player-name'),
    accountNostrPubkey: document.getElementById('account-nostr-pubkey'),
    accountSshPublicKey: document.getElementById('account-ssh-public-key'),
    autosaveStatus: document.getElementById('autosave-status'),
    publishNowButton: document.getElementById('btn-publish-now'),
    mirrorNostrButton: document.getElementById('btn-mirror-nostr'),
    bindPasskeyButton: document.getElementById('btn-bind-passkey'),
    generateSshButton: document.getElementById('btn-generate-ssh'),
    linkSshButton: document.getElementById('btn-link-ssh'),
    imagePicker: document.getElementById('image-picker'),
    dropOverlay: document.getElementById('drop-overlay'),
    sectionButtons: Array.from(document.querySelectorAll('[data-admin-nav]')),
    sections: Array.from(document.querySelectorAll('[data-admin-section]'))
  };

  const publishModeInputs = Array.from(document.querySelectorAll('input[name="publish-mode"]'));

  function setAuthMessage(message, type) {
    if (!els.authStatus) {
      return;
    }
    if (!message) {
      els.authStatus.hidden = true;
      els.authStatus.className = 'admin-access-message';
      els.authStatus.innerHTML = '';
      return;
    }
    els.authStatus.hidden = false;
    els.authStatus.className = 'admin-access-message';
    if (type) {
      els.authStatus.classList.add('is-' + type);
    }
    els.authStatus.innerHTML = message;
  }

  function getSectionFromHash() {
    const name = (window.location.hash || '').replace(/^#/, '');
    if (!name) {
      return state.isAdmin ? 'settings' : 'account';
    }
    const known = els.sections.some(function (section) {
      return section.getAttribute('data-admin-section') === name;
    });
    if (!known) {
      return state.isAdmin ? 'settings' : 'account';
    }
    if (!state.isAdmin && name !== 'account') {
      return 'account';
    }
    return name;
  }

  function activateSection(name, updateHash) {
    const sectionName = (!state.isAdmin ? 'account' : (name || 'settings'));
    els.sectionButtons.forEach(function (button) {
      const active = button.getAttribute('data-admin-nav') === sectionName;
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-selected', active ? 'true' : 'false');
    });
    els.sections.forEach(function (section) {
      const active = section.getAttribute('data-admin-section') === sectionName;
      section.classList.toggle('is-active', active);
      section.hidden = !active;
    });
    if (updateHash) {
      if (window.location.hash !== '#' + sectionName) {
        history.replaceState(null, '', '#' + sectionName);
      }
    }
  }

  function initSectionNavigation() {
    if (!els.sectionButtons.length || !els.sections.length) {
      return;
    }
    activateSection(getSectionFromHash(), false);
    els.sectionButtons.forEach(function (button) {
      button.addEventListener('click', function () {
        activateSection(button.getAttribute('data-admin-nav') || 'settings', true);
      });
    });
    window.addEventListener('hashchange', function () {
      activateSection(getSectionFromHash(), false);
    });
  }

  function setAccountOnlyMode(enabled) {
    if (!els.adminPanel) {
      return;
    }
    els.adminPanel.classList.toggle('account-only', !!enabled);
    els.sectionButtons.forEach(function (button) {
      const section = button.getAttribute('data-admin-nav') || '';
      const visible = !enabled || section === 'account';
      button.hidden = !visible;
      button.setAttribute('aria-hidden', visible ? 'false' : 'true');
    });
  }

  function setOutput(target, message, kind) {
    const bg = kind === 'ok' ? '#e8f5e9' : (kind === 'warn' ? '#fff8e1' : '#ffebee');
    const border = kind === 'ok' ? '#4caf50' : (kind === 'warn' ? '#f9a825' : '#e53935');
    target.innerHTML = '<div class="notice" style="background:' + bg + ';border-color:' + border + ';">' + message + '</div>';
  }

  function applyThemePreview(theme) {
    const pickedTheme = (theme || '').trim() || 'adept';
    const themeLink = document.getElementById('theme-stylesheet');
    if (themeLink) {
      themeLink.href = '/static/themes/' + encodeURIComponent(pickedTheme) + '.css';
    }
    const navThemeSelect = document.getElementById('theme-select');
    if (navThemeSelect && navThemeSelect.value !== pickedTheme) {
      navThemeSelect.value = pickedTheme;
    }
  }

  async function fetchJson(url, options) {
    const res = await fetch(url, options);
    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch (_) {
      throw new Error('Invalid JSON response');
    }
    return data;
  }

  function arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i += 1) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  function base64ToArrayBuffer(base64) {
    const binary = atob(String(base64 || ''));
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  function buildAuthPayload(data) {
    return Object.assign({}, data, {
      session_token: state.sessionToken,
      csrf_token: state.csrfToken
    });
  }

  async function apiPost(url, data, includeAuth) {
    const payload = includeAuth ? buildAuthPayload(data || {}) : (data || {});
    const body = new URLSearchParams(payload);
    return fetchJson(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    });
  }

  function getPublishMode() {
    const picked = publishModeInputs.find(function (input) { return input.checked; });
    return picked ? picked.value : 'draft';
  }

  function setPublishMode(mode) {
    publishModeInputs.forEach(function (input) {
      input.checked = input.value === mode;
    });
    updatePrimaryPublishButton(mode);
    updateScheduledRowVisibility(mode);
  }

  function updatePrimaryPublishButton(mode) {
    if (!els.publishNowButton) {
      return;
    }
    const picked = mode || getPublishMode();
    if (picked === 'scheduled') {
      els.publishNowButton.textContent = 'Schedule Post';
      return;
    }
    if (picked === 'drip') {
      els.publishNowButton.textContent = 'In Queue Post';
      return;
    }
    els.publishNowButton.textContent = 'Publish Now';
  }

  function updateScheduledRowVisibility(mode) {
    if (!els.scheduledRow) {
      return;
    }
    const picked = mode || getPublishMode();
    els.scheduledRow.classList.toggle('is-hidden', picked !== 'scheduled');
  }

  function setPreviewVisibility(visible) {
    state.previewVisible = !!visible;
    if (els.composeShell) {
      els.composeShell.classList.toggle('preview-hidden', !state.previewVisible);
    }
    if (els.togglePreviewButton) {
      const label = state.previewVisible ? 'Hide preview' : 'Show preview';
      els.togglePreviewButton.setAttribute('aria-pressed', state.previewVisible ? 'true' : 'false');
      els.togglePreviewButton.setAttribute('aria-label', label);
      els.togglePreviewButton.setAttribute('title', label);
    }
    localStorage.setItem('blog_admin_preview_hidden', state.previewVisible ? '0' : '1');
  }

  function localToIso(value) {
    if (!value) {
      return '';
    }
    const dt = new Date(value);
    if (Number.isNaN(dt.getTime())) {
      return '';
    }
    return dt.toISOString().replace('.000Z', 'Z');
  }

  function isoToLocal(isoValue) {
    if (!isoValue) {
      return '';
    }
    const dt = new Date(isoValue);
    if (Number.isNaN(dt.getTime())) {
      return '';
    }
    const local = new Date(dt.getTime() - dt.getTimezoneOffset() * 60000);
    return local.toISOString().slice(0, 16);
  }

  function readComposer() {
    commitTagInput();
    return {
      draft_id: state.currentDraftId,
      title: els.postTitle.value.trim(),
      tags: els.postTags.value.trim(),
      summary: els.postSummary.value.trim(),
      content: els.postContent.value,
      scheduled_at: localToIso(els.postScheduleAt.value),
      publish_mode: getPublishMode()
    };
  }

  function populateComposer(draft) {
    state.suspendAutosave = true;
    state.currentDraftId = draft.draft_id || '';
    els.postTitle.value = draft.title || '';
    setComposeTagsFromString(draft.tags || '');
    els.postSummary.value = draft.summary || '';
    els.postContent.value = draft.content || '';
    setPublishMode(draft.publish_mode || 'draft');
    els.postScheduleAt.value = isoToLocal(draft.scheduled_at || '');
    renderPreview();
    refreshDraftLabel();
    setTimeout(function () {
      state.suspendAutosave = false;
    }, 0);
  }

  function resetComposer() {
    state.currentDraftId = '';
    els.postTitle.value = '';
    setComposeTags([]);
    els.postSummary.value = '';
    els.postContent.value = '';
    els.postScheduleAt.value = '';
    setPublishMode('draft');
    renderPreview();
    refreshDraftLabel();
  }

  function refreshDraftLabel() {
    if (!els.currentDraftLabel) {
      return;
    }
    if (state.currentDraftId) {
      els.currentDraftLabel.textContent = 'Editing draft: ' + state.currentDraftId;
    } else {
      els.currentDraftLabel.textContent = 'New draft';
    }
  }

  function syncComposeTagsField() {
    if (!els.postTags) {
      return;
    }
    els.postTags.value = state.composeTags.join(', ');
  }

  function escapeAttr(value) {
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function renderComposeTags() {
    if (!els.postTagsPills) {
      return;
    }
    if (!state.composeTags.length) {
      els.postTagsPills.innerHTML = '';
      return;
    }
    let html = '';
    state.composeTags.forEach(function (tag) {
      html += '<span class="tag-pill">';
      html += '<span>' + escapeHtml(tag) + '</span>';
      html += '<button type="button" class="tag-pill-remove" data-remove-tag="' + escapeAttr(tag) + '" aria-label="Remove tag ' + escapeAttr(tag) + '">×</button>';
      html += '</span>';
    });
    els.postTagsPills.innerHTML = html;
  }

  function normalizeTagValue(tag) {
    return String(tag || '').trim().replace(/\s+/g, '-');
  }

  function setComposeTags(tags) {
    const list = Array.from(tags || [])
      .map(normalizeTagValue)
      .filter(function (tag) { return !!tag; });
    state.composeTags = list.filter(function (tag, idx) {
      return list.indexOf(tag) === idx;
    });
    syncComposeTagsField();
    renderComposeTags();
  }

  function setComposeTagsFromString(tagsValue) {
    const list = String(tagsValue || '')
      .split(',')
      .map(normalizeTagValue)
      .filter(function (tag) { return !!tag; });
    setComposeTags(list);
  }

  function addComposeTag(rawTag) {
    const tag = normalizeTagValue(rawTag);
    if (!tag) {
      return false;
    }
    if (state.composeTags.indexOf(tag) !== -1) {
      return false;
    }
    state.composeTags.push(tag);
    syncComposeTagsField();
    renderComposeTags();
    return true;
  }

  function removeComposeTag(tag) {
    const next = state.composeTags.filter(function (item) { return item !== tag; });
    setComposeTags(next);
  }

  function commitTagInput() {
    if (!els.postTagsInput) {
      return false;
    }
    const raw = els.postTagsInput.value || '';
    const parts = raw.split(',');
    let changed = false;
    parts.forEach(function (part) {
      if (addComposeTag(part)) {
        changed = true;
      }
    });
    els.postTagsInput.value = '';
    return changed;
  }

  function renderPreview() {
    const md = els.postContent.value;
    if (!md.trim()) {
      els.markdownPreview.innerHTML = '<p class="placeholder">Preview will appear here...</p>';
      return;
    }
    els.markdownPreview.innerHTML = marked.parse(md);
  }

  function placeCursor(textarea, start, end) {
    textarea.focus();
    textarea.setSelectionRange(start, end);
  }

  function replaceSelection(transformer) {
    const textarea = els.postContent;
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const selected = textarea.value.slice(start, end);
    const updated = transformer(selected);
    const prefix = textarea.value.slice(0, start);
    const suffix = textarea.value.slice(end);
    textarea.value = prefix + updated.text + suffix;
    placeCursor(textarea, start + updated.cursorStart, start + updated.cursorEnd);
    renderPreview();
    queueAutosave('saving');
  }

  function toggleWrap(left, right) {
    replaceSelection(function (selected) {
      const s = selected || 'text';
      if (s.startsWith(left) && s.endsWith(right)) {
        const unwrapped = s.slice(left.length, s.length - right.length);
        return {
          text: unwrapped,
          cursorStart: 0,
          cursorEnd: unwrapped.length
        };
      }
      const wrapped = left + s + right;
      return {
        text: wrapped,
        cursorStart: left.length,
        cursorEnd: left.length + s.length
      };
    });
  }

  function prependLine(prefix) {
    replaceSelection(function (selected) {
      const source = selected || 'item';
      const lines = source.split('\n').map(function (line) {
        return prefix + line;
      });
      const text = lines.join('\n');
      return {
        text: text,
        cursorStart: 0,
        cursorEnd: text.length
      };
    });
  }

  function insertLink() {
    replaceSelection(function (selected) {
      const label = selected || 'link text';
      const text = '[' + label + '](https://)';
      return {
        text: text,
        cursorStart: text.indexOf('https://'),
        cursorEnd: text.indexOf('https://') + 8
      };
    });
  }

  function insertImage(url, alt) {
    replaceSelection(function (selected) {
      const label = alt || selected || 'image';
      const text = '![' + label + '](' + url + ')';
      return {
        text: text,
        cursorStart: text.length,
        cursorEnd: text.length
      };
    });
  }

  async function checkAuth() {
    if (!state.sessionToken) {
      setAuthMessage('Not logged in. Use the Login button in the top navigation to sign in with Nostr or passkey.', 'error');
      return;
    }

    try {
      const data = await fetchJson('/cgi/ssh-auth-check-session?session_token=' + encodeURIComponent(state.sessionToken));
      if (!data.authenticated) {
        localStorage.removeItem('session_token');
        localStorage.removeItem('csrf_token');
        setAuthMessage('Session expired. Use the Login button in the top navigation to sign in again.', 'error');
        return;
      }

      state.username = data.username;
      state.playerName = data.player_name || data.username || '';
      state.nostrPubkey = data.nostr_pubkey || '';
      state.sshFingerprint = data.ssh_fingerprint || '';
      state.isAdmin = !!data.is_admin;
      state.csrfToken = data.csrf_token || state.csrfToken;
      localStorage.setItem('csrf_token', state.csrfToken || '');
      setAuthMessage('', '');
      els.adminPanel.style.display = 'grid';
      if (els.accountPlayerName) {
        els.accountPlayerName.value = state.playerName;
      }
      if (els.accountNostrPubkey) {
        els.accountNostrPubkey.value = state.nostrPubkey;
      }
      if (els.accountSshPublicKey) {
        els.accountSshPublicKey.placeholder = state.sshFingerprint
          ? ('SSH linked (' + state.sshFingerprint.slice(0, 16) + '...)')
          : 'ssh-ed25519 AAAA...';
      }

      if (!state.isAdmin) {
        setAccountOnlyMode(true);
        activateSection('account', true);
        return;
      }

      setAccountOnlyMode(false);
      activateSection(getSectionFromHash(), false);

      await Promise.all([loadConfig(), loadDrafts(), loadQueue()]);
      renderPreview();
    } catch (err) {
      setAuthMessage('Authentication check failed: ' + err.message, 'error');
    }
  }

  async function loadConfig() {
    const data = await fetchJson('/cgi/blog-get-config');
    if (!data.success) {
      throw new Error(data.error || 'Failed to load configuration');
    }
    els.siteTitle.value = data.site_title || 'My Blog';
    if (els.adminTheme && data.theme) {
      els.adminTheme.value = data.theme;
    }
    if (els.adminTheme) {
      applyThemePreview(els.adminTheme.value);
    }
    els.registrationEnabled.checked = data.registration_enabled !== false;
    if (typeof data.drip_interval_hours !== 'undefined') {
      els.dripInterval.value = String(data.drip_interval_hours);
    } else {
      const legacyMinutes = Number(data.drip_interval_minutes || 240);
      els.dripInterval.value = String(Math.max(legacyMinutes / 60, 1 / 60));
    }
    if (typeof data.drip_randomness_minutes !== 'undefined') {
      els.dripRandomness.value = String(data.drip_randomness_minutes || 0);
    } else {
      els.dripRandomness.value = String(data.drip_jitter_minutes || 0);
    }
    els.feedFullText.checked = data.feed_full_text !== false;
    els.feedItems.value = String(data.feed_items || 50);
    state.nostrBridgeEnabled = !!data.nostr_bridge_enabled;
    if (els.nostrBridgeEnabled) {
      els.nostrBridgeEnabled.checked = state.nostrBridgeEnabled;
    }
    if (els.mirrorNostrButton) {
      els.mirrorNostrButton.disabled = !state.nostrBridgeEnabled;
    }
  }

  async function saveConfig() {
    try {
      const data = await apiPost('/cgi/blog-update-config', {
        site_title: els.siteTitle.value.trim(),
        theme: els.adminTheme ? els.adminTheme.value : '',
        registration_enabled: els.registrationEnabled.checked ? 'true' : 'false',
        drip_interval_hours: els.dripInterval.value.trim(),
        drip_randomness_minutes: els.dripRandomness.value.trim(),
        feed_full_text: els.feedFullText.checked ? 'true' : 'false',
        feed_items: els.feedItems.value.trim(),
        nostr_bridge_enabled: (els.nostrBridgeEnabled && els.nostrBridgeEnabled.checked) ? 'true' : 'false'
      }, true);
      if (!data.success) {
        throw new Error(data.error || 'Failed to save config');
      }
      state.nostrBridgeEnabled = !!(els.nostrBridgeEnabled && els.nostrBridgeEnabled.checked);
      if (els.mirrorNostrButton) {
        els.mirrorNostrButton.disabled = !state.nostrBridgeEnabled;
      }
      setOutput(els.outputConfig, 'Settings saved.', 'ok');
      await loadQueue();
    } catch (err) {
      setOutput(els.outputConfig, 'Error: ' + err.message, 'error');
    }
  }

  async function saveAccount() {
    if (!els.accountPlayerName) {
      return;
    }
    try {
      const data = await apiPost('/cgi/blog-update-account', {
        player_name: els.accountPlayerName.value.trim()
      }, true);
      if (!data.success) {
        throw new Error(data.error || 'Failed to save account');
      }
      state.playerName = data.player_name || state.username;
      const navName = document.getElementById('nav-user-name');
      if (navName) {
        navName.textContent = state.playerName;
      }
      setOutput(els.outputAccount, 'Account updated.', 'ok');
    } catch (err) {
      setOutput(els.outputAccount, 'Error: ' + err.message, 'error');
    }
  }

  function concatUint8Arrays(parts) {
    let total = 0;
    parts.forEach(function (part) { total += part.length; });
    const out = new Uint8Array(total);
    let offset = 0;
    parts.forEach(function (part) {
      out.set(part, offset);
      offset += part.length;
    });
    return out;
  }

  function u32be(value) {
    return new Uint8Array([
      (value >>> 24) & 0xff,
      (value >>> 16) & 0xff,
      (value >>> 8) & 0xff,
      value & 0xff
    ]);
  }

  function packSshString(bytes) {
    return concatUint8Arrays([u32be(bytes.length), bytes]);
  }

  function normalizeMpint(bytes) {
    let start = 0;
    while (start < bytes.length - 1 && bytes[start] === 0) {
      start += 1;
    }
    let out = bytes.slice(start);
    if (!out.length) {
      out = new Uint8Array([0]);
    }
    if (out[0] & 0x80) {
      const prefixed = new Uint8Array(out.length + 1);
      prefixed[0] = 0;
      prefixed.set(out, 1);
      out = prefixed;
    }
    return out;
  }

  function base64urlToBytes(input) {
    const normalized = String(input || '').replace(/-/g, '+').replace(/_/g, '/');
    const padLen = (4 - (normalized.length % 4)) % 4;
    const binary = atob(normalized + '='.repeat(padLen));
    const out = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      out[i] = binary.charCodeAt(i);
    }
    return out;
  }

  function pemEncode(label, buffer) {
    const b64 = arrayBufferToBase64(buffer);
    const chunks = b64.match(/.{1,64}/g) || [];
    return '-----BEGIN ' + label + '-----\n' + chunks.join('\n') + '\n-----END ' + label + '-----\n';
  }

  function triggerTextDownload(filename, content) {
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  async function generateBrowserSshKeyPair() {
    if (!window.crypto || !window.crypto.subtle) {
      throw new Error('Web Crypto API is unavailable in this browser.');
    }
    const keyPair = await window.crypto.subtle.generateKey({
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256'
    }, true, ['sign', 'verify']);

    const jwk = await window.crypto.subtle.exportKey('jwk', keyPair.publicKey);
    const pkcs8 = await window.crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
    const nBytes = normalizeMpint(base64urlToBytes(jwk.n || ''));
    const eBytes = normalizeMpint(base64urlToBytes(jwk.e || ''));
    const algo = new TextEncoder().encode('ssh-rsa');
    const blob = concatUint8Arrays([
      packSshString(algo),
      packSshString(eBytes),
      packSshString(nBytes)
    ]);
    const comment = (state.username || 'player') + '@wizardry';
    const publicKey = 'ssh-rsa ' + arrayBufferToBase64(blob.buffer) + ' ' + comment;
    const privateKeyPem = pemEncode('PRIVATE KEY', pkcs8);
    return {
      publicKey: publicKey,
      privateKeyPem: privateKeyPem
    };
  }

  function createPasskeyOptions(username, fingerprint, challengeB64) {
    return {
      publicKey: {
        challenge: base64ToArrayBuffer(challengeB64),
        rp: {
          name: 'Wizardry Blog',
          id: window.location.hostname
        },
        user: {
          id: new TextEncoder().encode(fingerprint),
          name: username,
          displayName: username
        },
        pubKeyCredParams: [
          { type: 'public-key', alg: -7 },
          { type: 'public-key', alg: -257 }
        ],
        authenticatorSelection: {
          userVerification: 'preferred'
        },
        timeout: 60000,
        attestation: 'none'
      }
    };
  }

  async function bindPasskeyForAccount() {
    if (!window.PublicKeyCredential) {
      throw new Error('WebAuthn is not supported in this browser.');
    }
    const begin = await apiPost('/cgi/nostr-auth-passkey-begin', {}, true);
    if (!begin.success) {
      throw new Error(begin.error || 'Unable to start passkey binding.');
    }
    const credential = await navigator.credentials.create(createPasskeyOptions(begin.username, begin.fingerprint, begin.challenge));
    const publicKey = credential.response.getPublicKey ? credential.response.getPublicKey() : null;
    if (!publicKey) {
      throw new Error('Passkey registration requires a newer browser.');
    }
    const finish = await apiPost('/cgi/ssh-auth-bind-webauthn', {
      username: begin.username,
      fingerprint: begin.fingerprint,
      credential_id: credential.id,
      public_key: arrayBufferToBase64(publicKey),
      client_data_json: arrayBufferToBase64(credential.response.clientDataJSON)
    }, false);
    if (!finish.success) {
      throw new Error(finish.error || 'Passkey bind failed.');
    }
  }

  async function linkSshForAccount() {
    const raw = els.accountSshPublicKey ? String(els.accountSshPublicKey.value || '').trim() : '';
    if (!raw) {
      throw new Error('Enter or generate an SSH public key first.');
    }
    const data = await apiPost('/cgi/nostr-auth-link-ssh', {
      ssh_public_key: raw
    }, true);
    if (!data.success) {
      throw new Error(data.error || 'SSH link failed.');
    }
    state.sshFingerprint = data.ssh_fingerprint || '';
  }

  function renderDraftList(drafts) {
    if (!drafts.length) {
      els.draftsList.innerHTML = '<p class="placeholder">No drafts yet.</p>';
      return;
    }

    let html = '<div class="draft-grid">';
    drafts.forEach(function (draft) {
      html += '<div class="draft-card">';
      html += '<div class="draft-card-head"><strong>' + escapeHtml(draft.title || 'Untitled') + '</strong></div>';
      html += '<div class="muted">' + escapeHtml(draft.draft_id) + '</div>';
      html += '<div class="muted">Mode: ' + escapeHtml(draft.publish_mode || 'draft') + ' | Status: ' + escapeHtml(draft.status || 'draft') + '</div>';
      if (draft.scheduled_at) {
        html += '<div class="muted">Scheduled: ' + escapeHtml(draft.scheduled_at) + '</div>';
      }
      html += '<div class="draft-actions">';
      html += '<button type="button" data-action="edit" data-id="' + escapeHtml(draft.draft_id) + '">Edit</button>';
      html += '<button type="button" class="danger" data-action="delete" data-id="' + escapeHtml(draft.draft_id) + '">Delete</button>';
      html += '</div>';
      html += '</div>';
    });
    html += '</div>';
    els.draftsList.innerHTML = html;
  }

  function renderQueue(data) {
    const queue = data.queue || [];
    if (!queue.length) {
      els.queueList.innerHTML = '<p class="placeholder">Queue is empty.</p>';
      return;
    }

    const nextDripText = data.next_drip_epoch && Number(data.next_drip_epoch) > 0
      ? new Date(Number(data.next_drip_epoch) * 1000).toLocaleString()
      : 'ready immediately';

    const intervalHours = typeof data.drip_interval_hours !== 'undefined'
      ? data.drip_interval_hours
      : (Number(data.drip_interval_minutes || 240) / 60);
    const randomnessMinutes = typeof data.drip_randomness_minutes !== 'undefined'
      ? data.drip_randomness_minutes
      : data.drip_jitter_minutes;
    let html = '<p class="muted">Global drip: every ' + escapeHtml(String(intervalHours)) + ' hour(s), randomness up to ' + escapeHtml(String(randomnessMinutes || 0)) + ' min. Next drip: ' + escapeHtml(nextDripText) + '</p>';
    html += '<div class="draft-grid">';
    queue.forEach(function (item) {
      html += '<div class="draft-card">';
      html += '<div class="draft-card-head"><strong>' + escapeHtml(item.title || 'Untitled') + '</strong></div>';
      html += '<div class="muted">' + escapeHtml(item.draft_id) + '</div>';
      html += '<div class="muted">' + escapeHtml(item.publish_mode) + ' / ' + escapeHtml(item.status) + '</div>';
      if (item.scheduled_at) {
        html += '<div class="muted">Scheduled: ' + escapeHtml(item.scheduled_at) + '</div>';
      }
      html += '</div>';
    });
    html += '</div>';
    els.queueList.innerHTML = html;
  }

  async function loadDrafts() {
    const data = await apiPost('/cgi/blog-list-drafts', {}, true);
    if (!data.success) {
      throw new Error(data.error || 'Failed to load drafts');
    }
    renderDraftList(data.drafts || []);
  }

  async function loadQueue() {
    const data = await apiPost('/cgi/blog-list-queue', {}, true);
    if (!data.success) {
      throw new Error(data.error || 'Failed to load queue');
    }
    renderQueue(data);
  }

  async function loadDraft(draftId) {
    const data = await apiPost('/cgi/blog-get-draft', { draft_id: draftId }, true);
    if (!data.success || !data.draft) {
      throw new Error(data.error || 'Failed to load draft');
    }
    populateComposer(data.draft);
    setOutput(els.outputCompose, 'Draft loaded.', 'ok');
  }

  async function deleteDraft(draftId) {
    const confirmed = window.confirm('Delete this draft? This cannot be undone.');
    if (!confirmed) {
      return;
    }
    const data = await apiPost('/cgi/blog-delete-draft', { draft_id: draftId }, true);
    if (!data.success) {
      throw new Error(data.error || 'Failed to delete draft');
    }
    if (state.currentDraftId === draftId) {
      resetComposer();
    }
    await Promise.all([loadDrafts(), loadQueue()]);
    setOutput(els.outputCompose, 'Draft deleted.', 'ok');
  }

  async function saveComposer(action) {
    const payload = readComposer();
    payload.action = action;

    if (action === 'queue_scheduled' && !payload.scheduled_at) {
      setOutput(els.outputCompose, 'Scheduled posts need a release date/time.', 'warn');
      return;
    }

    if (action === 'publish_now' && !payload.content.trim()) {
      setOutput(els.outputCompose, 'Cannot publish an empty post.', 'warn');
      return;
    }

    try {
      const data = await apiPost('/cgi/blog-save-post', payload, true);
      if (!data.success) {
        throw new Error(data.error || 'Save failed');
      }

      if (data.draft_id) {
        state.currentDraftId = data.draft_id;
        refreshDraftLabel();
      }

      if (action === 'publish_now') {
        setOutput(els.outputCompose, 'Published: <code>' + escapeHtml(data.filename || '') + '</code>', 'ok');
        resetComposer();
      } else {
        setOutput(els.outputCompose, data.message || 'Saved.', 'ok');
      }

      await Promise.all([loadDrafts(), loadQueue()]);
      els.autosaveStatus.textContent = 'Saved at ' + new Date().toLocaleTimeString();
    } catch (err) {
      setOutput(els.outputCompose, 'Error: ' + err.message, 'error');
    }
  }

  async function autosave() {
    if (state.suspendAutosave) {
      return;
    }
    const payload = readComposer();
    if (!payload.title.trim() && !payload.content.trim()) {
      return;
    }
    payload.action = 'autosave';

    try {
      const data = await apiPost('/cgi/blog-save-post', payload, true);
      if (data.success && data.draft_id) {
        state.currentDraftId = data.draft_id;
        refreshDraftLabel();
        els.autosaveStatus.textContent = 'Autosaved at ' + new Date().toLocaleTimeString();
      }
    } catch (err) {
      els.autosaveStatus.textContent = 'Autosave failed (' + err.message + ')';
    }
  }

  function queueAutosave(reason) {
    if (state.suspendAutosave) {
      return;
    }
    if (state.autosaveTimer) {
      clearTimeout(state.autosaveTimer);
    }
    els.autosaveStatus.textContent = reason === 'typing' ? 'Typing...' : 'Saving...';
    state.autosaveTimer = setTimeout(autosave, 1500);
  }

  async function runSchedulerNow() {
    try {
      const data = await apiPost('/cgi/blog-run-scheduler', {}, true);
      if (!data.success) {
        throw new Error(data.error || 'Scheduler failed');
      }
      await Promise.all([loadDrafts(), loadQueue()]);
      setOutput(els.outputQueue, 'Scheduler ran. Scheduled published: ' + data.scheduled_published + ', drip published: ' + data.drip_published + '.', 'ok');
    } catch (err) {
      setOutput(els.outputQueue, 'Error: ' + err.message, 'error');
    }
  }

  async function runNostrMirror() {
    try {
      const data = await apiPost('/cgi/blog-nostr-mirror', {}, true);
      if (!data.success) {
        throw new Error(data.error || 'Nostr mirror failed');
      }
      await Promise.all([loadDrafts(), loadQueue()]);
      setOutput(
        els.outputQueue,
        'Nostr mirror complete. Posts mirrored: ' + String(data.posts_mirrored || 0) +
          ', comments mirrored: ' + String(data.comments_mirrored || 0) + '.',
        'ok'
      );
    } catch (err) {
      setOutput(els.outputQueue, 'Error: ' + err.message, 'error');
    }
  }

  async function uploadImageFile(file) {
    const dataUrl = await readFileAsDataUrl(file);
    const data = await apiPost('/cgi/blog-upload-media', {
      filename: file.name,
      mime_type: file.type,
      data_base64: dataUrl
    }, true);
    if (!data.success) {
      throw new Error(data.error || 'Upload failed');
    }
    insertImage(data.url, file.name.replace(/\.[^.]+$/, ''));
    return data.url;
  }

  function readFileAsDataUrl(file) {
    return new Promise(function (resolve, reject) {
      const reader = new FileReader();
      reader.onload = function () { resolve(String(reader.result || '')); };
      reader.onerror = function () { reject(new Error('Failed to read file')); };
      reader.readAsDataURL(file);
    });
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  async function handleDroppedFiles(files) {
    const imageFiles = Array.from(files || []).filter(function (file) {
      return file && file.type && file.type.indexOf('image/') === 0;
    });
    if (!imageFiles.length) {
      return;
    }

    setOutput(els.outputCompose, 'Uploading ' + imageFiles.length + ' image(s)...', 'warn');
    try {
      for (const file of imageFiles) {
        await uploadImageFile(file);
      }
      setOutput(els.outputCompose, 'Images inserted into markdown.', 'ok');
    } catch (err) {
      setOutput(els.outputCompose, 'Upload error: ' + err.message, 'error');
    }
  }

  function bindEvents() {
    document.getElementById('btn-save-config').addEventListener('click', saveConfig);
    if (els.adminTheme) {
      els.adminTheme.addEventListener('change', function () {
        applyThemePreview(els.adminTheme.value);
      });
    }

    if (els.postTagsInput) {
      els.postTagsInput.addEventListener('keydown', function (event) {
        if (event.key === ',' || event.key === 'Enter') {
          event.preventDefault();
          if (commitTagInput()) {
            queueAutosave('saving');
          }
          return;
        }
        if (event.key === 'Backspace' && !els.postTagsInput.value && state.composeTags.length) {
          removeComposeTag(state.composeTags[state.composeTags.length - 1]);
          queueAutosave('saving');
        }
      });

      els.postTagsInput.addEventListener('blur', function () {
        if (commitTagInput()) {
          queueAutosave('saving');
        }
      });
    }

    if (els.postTagsPills) {
      els.postTagsPills.addEventListener('click', function (event) {
        const target = event.target;
        if (!(target instanceof HTMLElement)) {
          return;
        }
        const tag = target.getAttribute('data-remove-tag');
        if (!tag) {
          return;
        }
        removeComposeTag(tag);
        queueAutosave('saving');
      });
    }

    document.getElementById('btn-publish-now').addEventListener('click', function () {
      const mode = getPublishMode();
      if (mode === 'scheduled') {
        saveComposer('queue_scheduled');
        return;
      }
      if (mode === 'drip') {
        saveComposer('queue_drip');
        return;
      }
      saveComposer('publish_now');
    });
    document.getElementById('btn-delete-current').addEventListener('click', function () {
      if (!state.currentDraftId) {
        setOutput(els.outputCompose, 'No current draft selected.', 'warn');
        return;
      }
      deleteDraft(state.currentDraftId).catch(function (err) {
        setOutput(els.outputCompose, 'Error: ' + err.message, 'error');
      });
    });
    if (els.togglePreviewButton) {
      els.togglePreviewButton.addEventListener('click', function () {
        setPreviewVisibility(!state.previewVisible);
      });
    }

    document.getElementById('btn-refresh-drafts').addEventListener('click', function () {
      loadDrafts().catch(function (err) {
        setOutput(els.outputCompose, 'Error: ' + err.message, 'error');
      });
    });

    document.getElementById('btn-refresh-queue').addEventListener('click', function () {
      loadQueue().catch(function (err) {
        setOutput(els.outputQueue, 'Error: ' + err.message, 'error');
      });
    });

    document.getElementById('btn-run-scheduler').addEventListener('click', runSchedulerNow);
    if (els.mirrorNostrButton) {
      els.mirrorNostrButton.addEventListener('click', runNostrMirror);
    }
    const saveAccountBtn = document.getElementById('btn-save-account');
    if (saveAccountBtn) {
      saveAccountBtn.addEventListener('click', saveAccount);
    }
    if (els.bindPasskeyButton) {
      els.bindPasskeyButton.addEventListener('click', function () {
        bindPasskeyForAccount()
          .then(function () {
            setOutput(els.outputAccount, 'Passkey bound to your Nostr account.', 'ok');
          })
          .catch(function (err) {
            setOutput(els.outputAccount, 'Error: ' + err.message, 'error');
          });
      });
    }
    if (els.generateSshButton) {
      els.generateSshButton.addEventListener('click', function () {
        generateBrowserSshKeyPair()
          .then(function (keyPair) {
            if (els.accountSshPublicKey) {
              els.accountSshPublicKey.value = keyPair.publicKey;
            }
            triggerTextDownload('id_rsa', keyPair.privateKeyPem);
            triggerTextDownload('id_rsa.pub', keyPair.publicKey + '\n');
            setOutput(els.outputAccount, 'SSH keypair generated in-browser and downloaded. Private key was never sent to the server.', 'ok');
          })
          .catch(function (err) {
            setOutput(els.outputAccount, 'Error: ' + err.message, 'error');
          });
      });
    }
    if (els.linkSshButton) {
      els.linkSshButton.addEventListener('click', function () {
        linkSshForAccount()
          .then(function () {
            setOutput(els.outputAccount, 'SSH key linked to your Nostr account.', 'ok');
          })
          .catch(function (err) {
            setOutput(els.outputAccount, 'Error: ' + err.message, 'error');
          });
      });
    }

    document.querySelectorAll('[data-toolbar]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        const action = btn.getAttribute('data-toolbar');
        if (action === 'bold') { toggleWrap('**', '**'); return; }
        if (action === 'italic') { toggleWrap('*', '*'); return; }
        if (action === 'code') { toggleWrap('`', '`'); return; }
        if (action === 'h2') { prependLine('## '); return; }
        if (action === 'h3') { prependLine('### '); return; }
        if (action === 'quote') { prependLine('> '); return; }
        if (action === 'ul') { prependLine('- '); return; }
        if (action === 'ol') { prependLine('1. '); return; }
        if (action === 'link') { insertLink(); return; }
        if (action === 'image') { els.imagePicker.click(); return; }
      });
    });

    els.imagePicker.addEventListener('change', function () {
      if (els.imagePicker.files && els.imagePicker.files.length) {
        handleDroppedFiles(els.imagePicker.files).finally(function () {
          els.imagePicker.value = '';
        });
      }
    });

    [els.postTitle, els.postSummary, els.postContent, els.postScheduleAt].forEach(function (el) {
      el.addEventListener('input', function () {
        renderPreview();
        const typing = (el === els.postTitle || el === els.postSummary || el === els.postContent);
        queueAutosave(typing ? 'typing' : 'saving');
      });
    });

    publishModeInputs.forEach(function (input) {
      input.addEventListener('change', function () {
        updatePrimaryPublishButton();
        queueAutosave('saving');
      });
    });

    els.draftsList.addEventListener('click', function (event) {
      const target = event.target;
      if (!(target instanceof HTMLElement)) {
        return;
      }
      const action = target.getAttribute('data-action');
      const draftId = target.getAttribute('data-id');
      if (!action || !draftId) {
        return;
      }

      if (action === 'edit') {
        loadDraft(draftId).catch(function (err) {
          setOutput(els.outputCompose, 'Error: ' + err.message, 'error');
        });
      }
      if (action === 'delete') {
        deleteDraft(draftId).catch(function (err) {
          setOutput(els.outputCompose, 'Error: ' + err.message, 'error');
        });
      }
    });

    let dragDepth = 0;
    document.addEventListener('dragenter', function (event) {
      if (event.dataTransfer && Array.from(event.dataTransfer.types || []).includes('Files')) {
        dragDepth += 1;
        els.dropOverlay.classList.add('show');
      }
    });

    document.addEventListener('dragleave', function () {
      dragDepth = Math.max(0, dragDepth - 1);
      if (dragDepth === 0) {
        els.dropOverlay.classList.remove('show');
      }
    });

    document.addEventListener('dragover', function (event) {
      event.preventDefault();
      if (event.dataTransfer) {
        event.dataTransfer.dropEffect = 'copy';
      }
    });

    document.addEventListener('drop', function (event) {
      event.preventDefault();
      dragDepth = 0;
      els.dropOverlay.classList.remove('show');
      handleDroppedFiles(event.dataTransfer ? event.dataTransfer.files : []);
    });
  }

  bindEvents();
  initSectionNavigation();
  checkAuth();
  refreshDraftLabel();
  updatePrimaryPublishButton();
  updateScheduledRowVisibility();
  setPreviewVisibility(state.previewVisible);
  renderPreview();
})();
