(function () {
  const state = {
    sessionToken: localStorage.getItem('session_token') || '',
    csrfToken: localStorage.getItem('csrf_token') || '',
    username: '',
    currentDraftId: '',
    autosaveTimer: null,
    suspendAutosave: false
  };

  const els = {
    authStatus: document.getElementById('admin-access-message'),
    adminPanel: document.getElementById('admin-panel'),
    outputConfig: document.getElementById('output-config'),
    outputCompose: document.getElementById('output-compose'),
    outputQueue: document.getElementById('output-queue'),
    siteTitle: document.getElementById('site-title'),
    adminTheme: document.getElementById('admin-theme'),
    registrationEnabled: document.getElementById('registration-enabled'),
    dripInterval: document.getElementById('drip-interval'),
    dripJitter: document.getElementById('drip-jitter'),
    feedFullText: document.getElementById('feed-full-text'),
    feedItems: document.getElementById('feed-items'),
    postTitle: document.getElementById('post-title'),
    postTags: document.getElementById('post-tags'),
    postSummary: document.getElementById('post-summary'),
    postContent: document.getElementById('post-content'),
    postScheduleAt: document.getElementById('post-scheduled-at'),
    markdownPreview: document.getElementById('markdown-preview'),
    draftsList: document.getElementById('drafts-list'),
    queueList: document.getElementById('queue-list'),
    currentDraftLabel: document.getElementById('current-draft-label'),
    autosaveStatus: document.getElementById('autosave-status'),
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
      return 'settings';
    }
    const known = els.sections.some(function (section) {
      return section.getAttribute('data-admin-section') === name;
    });
    return known ? name : 'settings';
  }

  function activateSection(name, updateHash) {
    const sectionName = name || 'settings';
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

  function setOutput(target, message, kind) {
    const bg = kind === 'ok' ? '#e8f5e9' : (kind === 'warn' ? '#fff8e1' : '#ffebee');
    const border = kind === 'ok' ? '#4caf50' : (kind === 'warn' ? '#f9a825' : '#e53935');
    target.innerHTML = '<div class="notice" style="background:' + bg + ';border-color:' + border + ';">' + message + '</div>';
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
    els.postTags.value = draft.tags || '';
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
    els.postTags.value = '';
    els.postSummary.value = '';
    els.postContent.value = '';
    els.postScheduleAt.value = '';
    setPublishMode('draft');
    renderPreview();
    refreshDraftLabel();
  }

  function refreshDraftLabel() {
    if (state.currentDraftId) {
      els.currentDraftLabel.textContent = 'Editing draft: ' + state.currentDraftId;
    } else {
      els.currentDraftLabel.textContent = 'New draft';
    }
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
    queueAutosave();
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
      setAuthMessage('Not logged in. Use the Login button in the top navigation to sign in with passkey.', 'error');
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

      if (!data.is_admin) {
        setAuthMessage('Logged in as <strong>' + data.username + '</strong>, but no admin permissions.', 'warn');
        return;
      }

      state.username = data.username;
      state.csrfToken = data.csrf_token || state.csrfToken;
      localStorage.setItem('csrf_token', state.csrfToken || '');
      setAuthMessage('', '');
      els.adminPanel.style.display = 'block';

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
    els.registrationEnabled.checked = data.registration_enabled !== false;
    if (typeof data.drip_interval_hours !== 'undefined') {
      els.dripInterval.value = String(data.drip_interval_hours);
    } else {
      const legacyMinutes = Number(data.drip_interval_minutes || 240);
      els.dripInterval.value = String(Math.max(legacyMinutes / 60, 1 / 60));
    }
    els.dripJitter.value = String(data.drip_jitter_minutes || 0);
    els.feedFullText.checked = data.feed_full_text !== false;
    els.feedItems.value = String(data.feed_items || 50);
  }

  async function saveConfig() {
    try {
      const data = await apiPost('/cgi/blog-update-config', {
        site_title: els.siteTitle.value.trim(),
        theme: els.adminTheme ? els.adminTheme.value : '',
        registration_enabled: els.registrationEnabled.checked ? 'true' : 'false',
        drip_interval_hours: els.dripInterval.value.trim(),
        drip_jitter_minutes: els.dripJitter.value.trim(),
        feed_full_text: els.feedFullText.checked ? 'true' : 'false',
        feed_items: els.feedItems.value.trim()
      }, true);
      if (!data.success) {
        throw new Error(data.error || 'Failed to save config');
      }
      setOutput(els.outputConfig, 'Settings saved.', 'ok');
      await loadQueue();
    } catch (err) {
      setOutput(els.outputConfig, 'Error: ' + err.message, 'error');
    }
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
    let html = '<p class="muted">Global drip: every ' + escapeHtml(String(intervalHours)) + ' hour(s), jitter up to ' + escapeHtml(String(data.drip_jitter_minutes)) + ' min. Next drip: ' + escapeHtml(nextDripText) + '</p>';
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

  function queueAutosave() {
    if (state.suspendAutosave) {
      return;
    }
    if (state.autosaveTimer) {
      clearTimeout(state.autosaveTimer);
    }
    els.autosaveStatus.textContent = 'Typing...';
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

    document.getElementById('btn-new-draft').addEventListener('click', function () {
      resetComposer();
      els.autosaveStatus.textContent = 'New draft';
    });
    document.getElementById('btn-save-draft').addEventListener('click', function () { saveComposer('save_draft'); });
    document.getElementById('btn-queue-scheduled').addEventListener('click', function () { saveComposer('queue_scheduled'); });
    document.getElementById('btn-queue-drip').addEventListener('click', function () { saveComposer('queue_drip'); });
    document.getElementById('btn-publish-now').addEventListener('click', function () { saveComposer('publish_now'); });
    document.getElementById('btn-delete-current').addEventListener('click', function () {
      if (!state.currentDraftId) {
        setOutput(els.outputCompose, 'No current draft selected.', 'warn');
        return;
      }
      deleteDraft(state.currentDraftId).catch(function (err) {
        setOutput(els.outputCompose, 'Error: ' + err.message, 'error');
      });
    });

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

    [els.postTitle, els.postTags, els.postSummary, els.postContent, els.postScheduleAt].forEach(function (el) {
      el.addEventListener('input', function () {
        renderPreview();
        queueAutosave();
      });
    });

    publishModeInputs.forEach(function (input) {
      input.addEventListener('change', queueAutosave);
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
  renderPreview();
})();
