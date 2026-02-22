---
title: Blog Admin
---

<div id="admin-access-message" class="admin-access-message" hidden></div>

<div id="admin-panel" class="admin-layout" style="display:none;">
<aside class="admin-sidebar">
<h2>Admin</h2>
<div class="admin-nav-list" role="tablist" aria-label="Admin sections">
<button type="button" class="admin-nav-item is-active" data-admin-nav="settings" aria-selected="true">Settings</button>
<button type="button" class="admin-nav-item" data-admin-nav="compose" aria-selected="false">Compose</button>
<button type="button" class="admin-nav-item" data-admin-nav="drafts" aria-selected="false">Drafts</button>
<button type="button" class="admin-nav-item" data-admin-nav="queue" aria-selected="false">Queue</button>
</div>
</aside>

<div class="admin-content">
  <section class="admin-section is-active" data-admin-section="settings">
  <div class="demo-box">
  <h3>Site Configuration</h3>

<div class="field-row">
<label for="site-title"><strong>Site Title</strong></label>
<input type="text" id="site-title" placeholder="My Blog">
</div>

<div class="field-row">
<label for="admin-theme"><strong>Theme</strong></label>
<select id="admin-theme">
<option value="adept">Adept</option>
<option value="alchemist">Alchemist</option>
<option value="archmage">Archmage</option>
<option value="chronomancer">Chronomancer</option>
<option value="conjurer">Conjurer</option>
<option value="druid">Druid</option>
<option value="empath">Empath</option>
<option value="enchanter">Enchanter</option>
<option value="geomancer">Geomancer</option>
<option value="hermeticist">Hermeticist</option>
<option value="hierophant">Hierophant</option>
<option value="illusionist">Illusionist</option>
<option value="lich">Lich</option>
<option value="necromancer">Necromancer</option>
<option value="pyromancer">Pyromancer</option>
<option value="seer">Seer</option>
<option value="shaman">Shaman</option>
<option value="sorcerer">Sorcerer</option>
<option value="sorceress">Sorceress</option>
<option value="technomancer">Technomancer</option>
<option value="thaumaturge">Thaumaturge</option>
<option value="thelemite">Thelemite</option>
<option value="theurgist">Theurgist</option>
<option value="wadjet">Wadjet</option>
<option value="warlock">Warlock</option>
<option value="wizard">Wizard</option>
</select>
<p class="muted">Theme selection moved here under Blog Settings.</p>
</div>

<div class="field-row checkbox-row">
<label>
<input type="checkbox" id="registration-enabled">
<strong>Enable User Registration</strong>
</label>
<p class="muted">Allow new users to register with MUD player SSH keys.</p>
</div>

<div class="grid-two">
<div class="field-row">
<label for="drip-interval"><strong>Drip Interval (hours)</strong></label>
<input type="number" id="drip-interval" min="0.1" step="0.1" value="4">
</div>
<div class="field-row">
<label for="drip-jitter"><strong>Drip Random Jitter (minutes)</strong></label>
<input type="number" id="drip-jitter" min="0" step="1" value="0">
</div>
</div>

<div class="grid-two">
<div class="field-row checkbox-row">
<label>
<input type="checkbox" id="feed-full-text" checked>
<strong>Full Text RSS/Atom</strong>
</label>
<p class="muted">Include full post body in feeds when available.</p>
</div>
<div class="field-row">
<label for="feed-items"><strong>Feed Item Count</strong></label>
<input type="number" id="feed-items" min="1" step="1" value="50">
</div>
</div>

  <button id="btn-save-config" class="primary">Save Settings</button>
  <div id="output-config" class="output"></div>
  </div>
  </section>

  <section class="admin-section" data-admin-section="compose" hidden>
  <div class="demo-box">
  <div class="composer-head">
  <h3>Markdown Composer</h3>
  <div id="current-draft-label" class="muted">New draft</div>
  </div>

<div class="grid-two composer-grid">
<div>
<div class="field-row">
<label for="post-title"><strong>Post Title</strong></label>
<input type="text" id="post-title" placeholder="My amazing post">
</div>

<div class="field-row">
<label for="post-tags"><strong>Tags (comma-separated)</strong></label>
<input type="text" id="post-tags" placeholder="tech, tutorial, notes">
</div>

<div class="field-row">
<label for="post-summary"><strong>Summary</strong></label>
<input type="text" id="post-summary" placeholder="Short description for index + feeds">
</div>

<div class="field-row">
<strong>Release Mode</strong>
<div class="mode-row">
<label><input type="radio" name="publish-mode" value="draft" checked> Draft</label>
<label><input type="radio" name="publish-mode" value="scheduled"> Scheduled Date</label>
<label><input type="radio" name="publish-mode" value="drip"> Drip Queue</label>
</div>
</div>

<div class="field-row">
<label for="post-scheduled-at"><strong>Scheduled Release Date/Time</strong></label>
<input type="datetime-local" id="post-scheduled-at">
</div>

<div class="toolbar">
<button type="button" data-toolbar="bold"><strong>B</strong></button>
<button type="button" data-toolbar="italic"><em>I</em></button>
<button type="button" data-toolbar="h2">H2</button>
<button type="button" data-toolbar="h3">H3</button>
<button type="button" data-toolbar="code">Code</button>
<button type="button" data-toolbar="link">Link</button>
<button type="button" data-toolbar="quote">Quote</button>
<button type="button" data-toolbar="ul">UL</button>
<button type="button" data-toolbar="ol">OL</button>
<button type="button" data-toolbar="image">Image</button>
</div>

<div class="field-row">
<label for="post-content"><strong>Content</strong></label>
<textarea id="post-content" rows="16" placeholder="# Write in Markdown\n\nDrop images anywhere on this page to upload + insert."></textarea>
</div>

<input type="file" id="image-picker" accept="image/*" multiple style="display:none;">

<div class="button-row">
<button id="btn-new-draft" type="button">New</button>
<button id="btn-save-draft" type="button">Save Draft</button>
<button id="btn-queue-scheduled" type="button">Queue Scheduled</button>
<button id="btn-queue-drip" type="button">Queue Drip</button>
<button id="btn-publish-now" type="button" class="primary">Publish Now</button>
<button id="btn-delete-current" type="button" class="danger">Delete Draft</button>
</div>

<div id="autosave-status" class="muted">Autosave idle</div>
<div id="output-compose" class="output"></div>
</div>

<div>
<h4 style="margin-top:0;">Live Preview</h4>
<div id="markdown-preview" class="preview-box">
<p class="placeholder">Preview will appear here...</p>
</div>
</div>
  </div>
  </div>
  </section>

  <section class="admin-section" data-admin-section="drafts" hidden>
  <div class="demo-box">
  <div class="row-head">
  <h3>Draft Manager</h3>
  <button id="btn-refresh-drafts" type="button">Refresh</button>
  </div>
  <div id="drafts-list"></div>
  </div>
  </section>

  <section class="admin-section" data-admin-section="queue" hidden>
  <div class="demo-box">
  <div class="row-head">
  <h3>Publish Queue</h3>
  <div>
  <button id="btn-refresh-queue" type="button">Refresh</button>
  <button id="btn-run-scheduler" type="button" class="primary">Run Scheduler</button>
  </div>
  </div>
  <div id="queue-list"></div>
  <div id="output-queue" class="output"></div>
  </div>
  </section>
</div>
</div>

<div id="drop-overlay" class="drop-overlay">Drop images to upload and insert into your draft</div>

<script src="https://cdn.jsdelivr.net/npm/marked@11.0.0/marked.min.js"></script>
<script src="/static/admin.js"></script>

<style>
.admin-access-message {
  margin-bottom: 0.8rem;
  padding: 0.55rem 0.75rem;
  border-radius: 8px;
  border: 1px solid #d9dee8;
  font-size: 0.92rem;
}

.admin-access-message.is-warn {
  background: #fff8e1;
  border-color: #f9a825;
  color: #7c5a00;
}

.admin-access-message.is-error {
  background: #ffebee;
  border-color: #e53935;
  color: #8f1316;
}

.admin-layout {
  display: grid;
  grid-template-columns: 220px 1fr;
  gap: 1.15rem;
  align-items: start;
}

.admin-sidebar {
  border: 1px solid #d4dbe7;
  border-radius: 12px;
  background: #f3f6fb;
  padding: 0.8rem;
  position: sticky;
  top: 0.9rem;
}

.admin-sidebar h2 {
  margin: 0 0 0.6rem;
  padding: 0 0 0.45rem;
  font-size: 1rem;
  border-bottom: 1px solid #d7deea;
}

.admin-nav-list {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.admin-nav-item {
  width: 100%;
  text-align: left;
  border: 1px solid transparent;
  background: transparent;
  color: #1e293b;
  border-radius: 8px;
  padding: 0.45rem 0.55rem;
  font-size: 0.92rem;
  font-weight: 600;
}

.admin-nav-item:hover {
  background: #e8eef8;
  border-color: #cfdae9;
}

.admin-nav-item.is-active {
  background: #dbe7ff;
  border-color: #7f9fe8;
  color: #163d86;
}

.admin-content {
  min-width: 0;
}

.admin-section {
  display: none;
}

.admin-section.is-active {
  display: block;
}

.demo-box {
  background: #f6f8fb;
  border: 2px solid #3498db;
  border-radius: 10px;
  padding: 1.25rem;
  margin: 0;
}

.field-row {
  margin-bottom: 0.9rem;
}

.field-row label {
  display: block;
  margin-bottom: 0.35rem;
}

.checkbox-row label {
  display: inline-flex;
  gap: 0.5rem;
  align-items: center;
}

.grid-two {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.composer-grid {
  align-items: start;
}

.mode-row {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  margin-top: 0.4rem;
}

.mode-row label {
  display: inline-flex;
  gap: 0.4rem;
  align-items: center;
  margin: 0;
}

.toolbar {
  display: flex;
  gap: 0.45rem;
  flex-wrap: wrap;
  margin-bottom: 0.7rem;
}

.toolbar button {
  min-width: 44px;
  padding: 0.45rem 0.6rem;
}

.button-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  margin-top: 0.6rem;
}

.primary {
  background: #2e7d32;
  color: #fff;
}

.danger {
  background: #c62828;
  color: #fff;
}

.notice {
  border: 1px solid;
  border-radius: 6px;
  padding: 0.65rem 0.75rem;
  margin-top: 0.65rem;
}

.output {
  min-height: 14px;
}

.preview-box {
  min-height: 420px;
  border: 2px solid #d9dfe8;
  border-radius: 8px;
  padding: 1rem;
  background: #fff;
  overflow: auto;
  max-height: 700px;
}

.placeholder,
.muted {
  color: #6d7680;
  font-size: 0.92rem;
}

.row-head,
.composer-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  margin-bottom: 0.8rem;
}

.draft-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 0.75rem;
}

.draft-card {
  border: 1px solid #d8dde8;
  border-radius: 8px;
  background: #fff;
  padding: 0.75rem;
}

.draft-card-head {
  margin-bottom: 0.25rem;
}

.draft-actions {
  display: flex;
  gap: 0.45rem;
  margin-top: 0.65rem;
}

.drop-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.75);
  color: #fff;
  display: none;
  align-items: center;
  justify-content: center;
  font-size: 1.15rem;
  z-index: 9999;
  text-align: center;
  padding: 2rem;
}

.drop-overlay.show {
  display: flex;
}

@media (max-width: 700px) {
  .admin-layout {
    grid-template-columns: 1fr;
  }

  .admin-sidebar {
    position: static;
  }

  .admin-nav-list {
    flex-direction: row;
    flex-wrap: wrap;
  }

  .admin-nav-item {
    width: auto;
  }

  .grid-two {
    grid-template-columns: 1fr;
  }
}
</style>
