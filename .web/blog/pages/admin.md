---
title: Blog Admin
---

<div id="admin-access-message" class="admin-access-message" hidden></div>

<div id="admin-panel" class="admin-layout" style="display:none;">
<aside class="admin-sidebar">
<div class="admin-nav-list" role="tablist" aria-label="Admin sections">
<button type="button" class="admin-nav-item is-active" data-admin-nav="settings" aria-selected="true">Settings</button>
<button type="button" class="admin-nav-item" data-admin-nav="compose" aria-selected="false">Compose</button>
<button type="button" class="admin-nav-item" data-admin-nav="drafts" aria-selected="false">Drafts</button>
<button type="button" class="admin-nav-item" data-admin-nav="queue" aria-selected="false">Queue</button>
<button type="button" class="admin-nav-item" data-admin-nav="account" aria-selected="false">Account</button>
</div>
</aside>

<div class="admin-content">
<section class="admin-section is-active" data-admin-section="settings">
<div class="demo-box admin-card">
<div class="section-head">
<h3>Settings</h3>
</div>

<div class="settings-stack">
<section class="sub-card">
<h4>General</h4>
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
</div>
<div class="field-row checkbox-row">
<div class="setting-label">
<strong>Enable User Registration</strong>
<span class="inline-tip" tabindex="0" aria-label="Allow new users to register with MUD player SSH keys.">?</span>
</div>
<label class="checkbox-control" for="registration-enabled">
<input type="checkbox" id="registration-enabled">
<span>Enabled</span>
</label>
</div>
</section>

<section class="sub-card">
<h4>Publishing</h4>
<div class="grid-two settings-inline">
<div class="field-row">
<label for="drip-interval"><strong>Drip Interval (hours)</strong></label>
<input type="number" id="drip-interval" min="0.1" step="0.1" value="4">
</div>
<div class="field-row">
<label for="drip-randomness"><strong>Drip Randomness (minutes)</strong></label>
<input type="number" id="drip-randomness" min="0" step="1" value="0">
</div>
</div>
</section>

<section class="sub-card">
<h4>Feeds</h4>
<div class="grid-two">
<div class="field-row checkbox-row">
<div class="setting-label">
<strong>Full Text RSS/Atom</strong>
</div>
<label class="checkbox-control" for="feed-full-text">
<input type="checkbox" id="feed-full-text" checked>
<span>Enabled</span>
</label>
</div>
<div class="field-row">
<label for="feed-items"><strong>Feed Item Count</strong></label>
<input type="number" id="feed-items" min="1" step="1" value="50">
</div>
</div>
</section>
</div>

<div class="section-actions">
<button id="btn-save-config" class="primary">Save Settings</button>
</div>
<div id="output-config" class="output"></div>
</div>
</section>

<section class="admin-section" data-admin-section="compose" hidden>
<div class="demo-box admin-card compose-shell">
<div class="composer-head">
<div>
<h3>Compose</h3>
</div>
<div class="composer-head-actions">
<button type="button" id="btn-toggle-preview" class="quiet-toggle" aria-pressed="true">Hide Preview</button>
</div>
</div>

<div class="composer-grid">
<div class="compose-editor">
<div class="field-row">
<label for="post-title"><strong>Post Title</strong></label>
<input type="text" id="post-title" placeholder="My amazing post">
</div>

<div class="field-row">
<label for="post-content"><strong>Content</strong></label>
<div class="editor-shell">
<div class="toolbar" aria-label="Markdown toolbar">
<button type="button" data-toolbar="bold" aria-label="Bold" title="Bold">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M8 5H13.2C15.3 5 17 6.7 17 8.8C17 10.9 15.3 12.6 13.2 12.6H8V5Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M8 12.4H14.1C16.3 12.4 18 14.1 18 16.3C18 18.4 16.3 20 14.1 20H8V12.4Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>
<span class="sr-only">Bold</span>
</button>
<button type="button" data-toolbar="italic" aria-label="Italic" title="Italic">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M14 4H10" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M12 20H8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M14 4L10 20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
<span class="sr-only">Italic</span>
</button>
<button type="button" data-toolbar="h2" aria-label="Heading 2" title="Heading 2">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M3 6V18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M9 6V18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M3 12H9" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><text x="14.2" y="16.4" font-size="9.5" font-family="ui-sans-serif, system-ui, sans-serif" fill="currentColor">2</text></svg>
<span class="sr-only">Heading 2</span>
</button>
<button type="button" data-toolbar="h3" aria-label="Heading 3" title="Heading 3">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M3 6V18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M9 6V18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M3 12H9" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><text x="14.2" y="16.4" font-size="9.5" font-family="ui-sans-serif, system-ui, sans-serif" fill="currentColor">3</text></svg>
<span class="sr-only">Heading 3</span>
</button>
<button type="button" data-toolbar="code" aria-label="Inline code" title="Inline code">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M9 7L4 12L9 17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M15 7L20 12L15 17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
<span class="sr-only">Inline code</span>
</button>
<button type="button" data-toolbar="link" aria-label="Insert link" title="Insert link">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M9.4 14.6L7.2 16.8C5.5 18.5 2.8 18.5 1.2 16.8C-0.5 15.2 -0.5 12.5 1.2 10.8L3.4 8.6" stroke="currentColor" stroke-width="2" stroke-linecap="round" transform="translate(3 0)"/><path d="M14.6 9.4L16.8 7.2C18.5 5.5 21.2 5.5 22.8 7.2C24.5 8.8 24.5 11.5 22.8 13.2L20.6 15.4" stroke="currentColor" stroke-width="2" stroke-linecap="round" transform="translate(-3 0)"/><path d="M8.5 15.5L15.5 8.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
<span class="sr-only">Insert link</span>
</button>
<button type="button" data-toolbar="quote" aria-label="Quote" title="Quote">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M6 9H10V13H7V16H10" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 9H18V13H15V16H18" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
<span class="sr-only">Quote</span>
</button>
<button type="button" data-toolbar="ul" aria-label="Bullet list" title="Bullet list">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><circle cx="5" cy="7" r="1.5" fill="currentColor"/><circle cx="5" cy="12" r="1.5" fill="currentColor"/><circle cx="5" cy="17" r="1.5" fill="currentColor"/><path d="M10 7H20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M10 12H20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M10 17H20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
<span class="sr-only">Bullet list</span>
</button>
<button type="button" data-toolbar="ol" aria-label="Numbered list" title="Numbered list">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><text x="2.4" y="9.2" font-size="7.3" font-family="ui-sans-serif, system-ui, sans-serif" fill="currentColor">1</text><text x="2.2" y="18.2" font-size="7.3" font-family="ui-sans-serif, system-ui, sans-serif" fill="currentColor">2</text><path d="M10 7H20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M10 17H20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
<span class="sr-only">Numbered list</span>
</button>
<button type="button" data-toolbar="image" aria-label="Insert image" title="Insert image">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="14" rx="2" stroke="currentColor" stroke-width="2"/><circle cx="9" cy="10" r="1.6" fill="currentColor"/><path d="M5.5 17L11.5 11L14.5 14L17.5 11L20.5 14.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
<span class="sr-only">Insert image</span>
</button>
</div>
<textarea id="post-content" rows="16" placeholder="# Write in Markdown\n\nDrop images anywhere on this page to upload + insert."></textarea>
</div>
</div>

<div class="grid-two">
<div class="field-row">
<label for="post-tags"><strong>Tags (comma-separated)</strong></label>
<input type="hidden" id="post-tags" value="">
<div id="post-tags-editor" class="tag-editor" role="group" aria-label="Post tags">
<div id="post-tags-pills" class="tag-editor-pills"></div>
<input type="text" id="post-tags-input" class="tag-editor-input" placeholder="tag, tag, tag">
</div>
</div>
<div class="field-row">
<label for="post-summary"><strong>Summary</strong></label>
<input type="text" id="post-summary" placeholder="Short description for index + feeds">
</div>
</div>

<div class="field-row">
<strong>Release Mode</strong>
<div class="mode-row">
<label><input type="radio" name="publish-mode" value="draft" checked> Draft</label>
<label><input type="radio" name="publish-mode" value="scheduled"> Scheduled Date</label>
<label><input type="radio" name="publish-mode" value="drip"> Drip Queue</label>
</div>
</div>

<div class="field-row scheduled-row is-hidden" id="scheduled-row">
<label for="post-scheduled-at"><strong>Scheduled Release Date/Time</strong></label>
<input type="datetime-local" id="post-scheduled-at">
</div>

<input type="file" id="image-picker" accept="image/*" multiple style="display:none;">

<div class="compose-actions">
<button id="btn-delete-current" type="button" class="icon-danger" aria-label="Delete draft" title="Delete draft">
<svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
<path d="M4 7H20" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
<path d="M9 7V5.5C9 4.67 9.67 4 10.5 4H13.5C14.33 4 15 4.67 15 5.5V7" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
<path d="M7.5 7L8.2 18.2C8.25 19.02 8.93 19.66 9.75 19.66H14.25C15.07 19.66 15.75 19.02 15.8 18.2L16.5 7" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
<path d="M10 10.5V16" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
<path d="M14 10.5V16" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
</svg>
</button>
<button id="btn-publish-now" type="button" class="primary">Publish Now</button>
</div>

<div id="autosave-status" class="muted">Autosave idle</div>
<div id="output-compose" class="output"></div>
</div>

<aside class="preview-panel">
<h4>Live Preview</h4>
<div id="markdown-preview" class="preview-box">
<p class="placeholder">Preview will appear here...</p>
</div>
</aside>
</div>
</div>
</section>

<section class="admin-section" data-admin-section="drafts" hidden>
<div class="demo-box admin-card">
<div class="row-head">
<div>
<h3>Drafts</h3>
<p class="muted">Manage saved, scheduled, and queued drafts.</p>
</div>
<button id="btn-refresh-drafts" type="button">Refresh</button>
</div>
<div id="drafts-list"></div>
</div>
</section>

<section class="admin-section" data-admin-section="queue" hidden>
<div class="demo-box admin-card">
<div class="row-head">
<div>
<h3>Queue</h3>
<p class="muted">See what will publish next and run the scheduler manually.</p>
</div>
<div class="row-actions">
<button id="btn-refresh-queue" type="button">Refresh</button>
<button id="btn-run-scheduler" type="button" class="primary">Run Scheduler</button>
</div>
</div>
<div id="queue-list"></div>
<div id="output-queue" class="output"></div>
</div>
</section>

<section class="admin-section" data-admin-section="account" hidden>
<div class="demo-box admin-card">
<div class="row-head">
<div>
<h3>Account</h3>
<p class="muted">Update your player name shown in the blog UI.</p>
</div>
</div>

<div class="field-row">
<label for="account-player-name"><strong>Player Name</strong></label>
<div class="account-row">
<input type="text" id="account-player-name" placeholder="Your name">
<button id="btn-save-account" type="button" class="primary">Save</button>
</div>
<div id="output-account" class="output"></div>
</div>
</div>
</section>
</div>
</div>

<div id="drop-overlay" class="drop-overlay">Drop images to upload and insert into your draft</div>

<script src="https://cdn.jsdelivr.net/npm/marked@11.0.0/marked.min.js"></script>
<script src="/static/admin.js"></script>

<style>
body {
  max-width: 1240px;
  padding: 0 0 2rem;
}

.admin-access-message {
  margin: 0.15rem 0 1rem;
  padding: 0.72rem 0.9rem;
  border-radius: 12px;
  border: 1px solid #d8deec;
  font-size: 0.93rem;
  line-height: 1.4;
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
  grid-template-columns: 248px minmax(0, 1fr);
  gap: 0;
  align-items: stretch;
  min-height: calc(100vh - 3.25rem);
}

.admin-sidebar {
  position: static;
  border: 0;
  border-right: 1px solid #c7d6f3;
  border-radius: 0;
  background: #ffffff;
  box-shadow: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  min-height: calc(100vh - 3.25rem);
  align-self: stretch;
}

.admin-nav-list {
  display: flex;
  flex-direction: column;
  flex: 1 1 auto;
  margin: 0;
  padding: 0;
  border: 0;
  border-radius: 0;
  overflow: visible;
  background: #ffffff;
}

.admin-nav-item {
  display: block;
  width: 100%;
  appearance: none;
  -webkit-appearance: none;
  text-align: left;
  border: 0;
  border-radius: 0;
  border-bottom: 0;
  background: transparent;
  color: #1e2d4e;
  padding: 0.56rem 0.4rem;
  font-size: 0.93rem;
  font-weight: 650;
  line-height: 1.25;
  transition: background-color 0.18s ease, color 0.18s ease;
}

.admin-nav-item:hover {
  background: #dde8ff;
  color: #173f85;
}

.admin-nav-item.is-active {
  background: #cfdfff;
  color: #153878;
  box-shadow: none;
}

#admin-panel .admin-nav-list .admin-nav-item {
  width: 100% !important;
  display: block !important;
  border: 0 !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  margin: 0 !important;
}

#admin-panel .admin-nav-list .admin-nav-item:hover {
  border: 0 !important;
}

#admin-panel .admin-nav-list .admin-nav-item.is-active {
  border: 0 !important;
}

.admin-content {
  min-width: 0;
  padding-left: 1.25rem;
}

#admin-panel.account-only {
  grid-template-columns: minmax(0, 1fr);
}

#admin-panel.account-only .admin-sidebar {
  display: none;
}

.admin-section {
  display: none;
}

.admin-section.is-active {
  display: block;
  animation: admin-fade-in 0.2s ease;
}

@keyframes admin-fade-in {
  from {
    opacity: 0;
    transform: translateY(4px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.demo-box {
  margin: 0;
  padding: 1.12rem;
  border-radius: 18px;
  border: 1px solid #c8d6f2;
  background: linear-gradient(180deg, #f8fbff 0%, #f2f7ff 100%);
  box-shadow: 0 16px 34px rgba(30, 58, 138, 0.09);
}

.admin-card {
  min-height: 300px;
}

.section-head {
  margin-bottom: 0.95rem;
}

.demo-box h3 {
  margin: 0;
  font-size: 1.2rem;
  line-height: 1.22;
  color: #1a2f5a;
}

.demo-box h4 {
  margin: 0 0 0.65rem;
  font-size: 0.96rem;
  line-height: 1.25;
  color: #273f74;
  letter-spacing: 0.01em;
}

.settings-stack {
  display: grid;
  gap: 0.88rem;
}

.sub-card {
  border: 1px solid #d1ddf5;
  border-radius: 14px;
  background: #ffffff;
  padding: 0.86rem 0.88rem;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8);
}

.section-actions {
  margin-top: 1rem;
}

.field-row {
  margin-bottom: 0.85rem;
}

.field-row label {
  display: block;
  margin-bottom: 0.32rem;
  color: #1f335f;
  font-size: 0.87rem;
  font-weight: 700;
  letter-spacing: 0.01em;
}

[data-admin-section="settings"] .field-row {
  display: grid;
  grid-template-columns: minmax(12rem, max-content) minmax(0, 1fr);
  align-items: center;
  gap: 0.45rem 1rem;
}

[data-admin-section="settings"] .field-row > label {
  margin-bottom: 0;
}

[data-admin-section="settings"] .field-row > input,
[data-admin-section="settings"] .field-row > select {
  justify-self: start;
}

[data-admin-section="settings"] .setting-label {
  display: inline-flex;
  align-items: center;
  gap: 0.38rem;
  color: #1f335f;
  font-size: 0.87rem;
  font-weight: 700;
  letter-spacing: 0.01em;
}

[data-admin-section="settings"] .checkbox-row .checkbox-control {
  display: inline-flex;
  align-items: center;
  gap: 0.46rem;
  color: #1d3566;
  font-size: 0.87rem;
  font-weight: 600;
}

.inline-tip {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1rem;
  height: 1rem;
  border-radius: 999px;
  border: 1px solid #a9bde5;
  color: #2a4d90;
  font-size: 0.74rem;
  font-weight: 700;
  line-height: 1;
  cursor: help;
  user-select: none;
}

.inline-tip::after {
  content: attr(aria-label);
  position: absolute;
  left: calc(100% + 0.45rem);
  top: 50%;
  transform: translateY(-50%);
  background: #102246;
  color: #fff;
  font-size: 0.75rem;
  font-weight: 500;
  line-height: 1.3;
  padding: 0.35rem 0.45rem;
  border-radius: 7px;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.14s ease;
  z-index: 40;
}

.inline-tip:hover::after,
.inline-tip:focus-visible::after {
  opacity: 1;
}

#admin-panel input[type="text"],
#admin-panel input[type="number"],
#admin-panel input[type="datetime-local"],
#admin-panel select,
#admin-panel textarea {
  inline-size: clamp(12rem, 32vw, 24rem);
  max-inline-size: 100%;
  border: 1px solid #b8caeb;
  border-radius: 11px;
  background: #fff;
  color: #102246;
  font-size: 0.96rem;
  line-height: 1.35;
  padding: 0.62rem 0.74rem;
  box-shadow: inset 0 1px 2px rgba(15, 23, 42, 0.05);
}

#admin-panel input[type="checkbox"],
#admin-panel input[type="radio"] {
  accent-color: #2559b7;
}

#admin-panel input:focus,
#admin-panel select:focus,
#admin-panel textarea:focus {
  outline: none;
  border-color: #5b7ed8;
  box-shadow: 0 0 0 3px rgba(91, 126, 216, 0.2);
}

#admin-panel textarea#post-content {
  inline-size: min(100%, 56rem);
  min-height: 390px;
  resize: vertical;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.91rem;
  line-height: 1.5;
}

.editor-shell {
  inline-size: min(100%, 56rem);
  border: 1px solid #c9d7f2;
  border-radius: 12px;
  background: #f9fbff;
  overflow: hidden;
}

.grid-two {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.86rem 0.96rem;
}

.settings-inline {
  align-items: end;
}

[data-admin-section="settings"] .grid-two {
  grid-template-columns: 1fr;
  justify-content: start;
}

[data-admin-section="settings"] #site-title {
  inline-size: clamp(12rem, 24vw, 20rem);
}

[data-admin-section="settings"] #admin-theme {
  inline-size: clamp(9.5rem, 14vw, 12rem);
}

[data-admin-section="settings"] #drip-interval,
[data-admin-section="settings"] #drip-randomness,
[data-admin-section="settings"] #feed-items {
  inline-size: 7.75rem !important;
  width: 7.75rem !important;
  max-inline-size: 7.75rem !important;
}

[data-admin-section="account"] #account-player-name {
  inline-size: clamp(12rem, 22vw, 18rem);
}

.account-row {
  display: inline-flex;
  align-items: center;
  gap: 0.55rem;
}

.composer-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.45fr) minmax(280px, 1fr);
  gap: 1.05rem;
  align-items: start;
}

.mode-row {
  display: flex;
  gap: 0.65rem;
  flex-wrap: wrap;
  margin-top: 0.42rem;
  padding: 0.1rem 0;
  border: 0;
  border-radius: 0;
  background: transparent;
}

.mode-row label {
  display: inline-flex;
  gap: 0.35rem;
  align-items: center;
  margin: 0;
  font-size: 0.85rem;
  font-weight: 600;
  border: 0;
  border-radius: 0;
  background: transparent;
  padding: 0;
}

.scheduled-row {
  overflow: hidden;
  max-height: 5.5rem;
  opacity: 1;
  transform: translateY(0);
  transition: max-height 0.24s ease, opacity 0.2s ease, transform 0.2s ease, margin 0.2s ease;
}

.scheduled-row.is-hidden {
  max-height: 0;
  opacity: 0;
  transform: translateY(-8px);
  margin: 0;
  pointer-events: none;
}

.toolbar {
  display: flex;
  gap: 0.18rem;
  flex-wrap: wrap;
  margin-bottom: 0;
  padding: 0.28rem 0.34rem;
  border: 0;
  border-bottom: 1px solid #d4e0f5;
  border-radius: 0;
  background: linear-gradient(180deg, #f9fbff 0%, #f2f6ff 100%);
}

.toolbar button {
  width: 2rem;
  min-width: 2rem;
  height: 2rem;
  border: 0;
  border-radius: 6px;
  background: transparent;
  color: #1e396e;
  font-size: 0.8rem;
  font-weight: 650;
  padding: 0;
  box-shadow: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.toolbar button:hover {
  background: #e8f0ff;
  color: #14356f;
}

.toolbar button:focus-visible {
  outline: 0;
  background: #e8f0ff;
  box-shadow: inset 0 0 0 1px #a9c1f0;
}

.toolbar .tb-icon {
  width: 1rem;
  height: 1rem;
  stroke: currentColor;
  flex: 0 0 auto;
}

.toolbar .sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.editor-shell #post-content {
  border: 0;
  border-radius: 0;
  background: #ffffff;
  box-shadow: none;
  display: block;
  inline-size: 100%;
}

.editor-shell #post-content:focus {
  box-shadow: none;
}

.editor-shell:focus-within {
  border-color: #5b7ed8;
  box-shadow: 0 0 0 3px rgba(91, 126, 216, 0.18);
}

.tag-editor {
  inline-size: min(100%, 24rem);
  min-height: 2.2rem;
  height: 2.2rem;
  border: 1px solid #b8caeb;
  border-radius: 11px;
  background: #fff;
  padding: 0.18rem 0.38rem;
  display: flex;
  flex-wrap: nowrap;
  align-items: center;
  gap: 0.34rem;
  overflow: hidden;
}

.tag-editor:focus-within {
  border-color: #5b7ed8;
  box-shadow: 0 0 0 3px rgba(91, 126, 216, 0.2);
}

.tag-editor-pills {
  display: inline-flex;
  align-items: center;
  flex-wrap: nowrap;
  overflow: hidden;
  gap: 0.3rem;
  max-width: 65%;
}

.tag-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.32rem;
  padding: 0.12rem 0.44rem;
  border-radius: 999px;
  border: 1px solid #c4d3f0;
  background: #edf3ff;
  color: #244a8f;
  font-size: 0.8rem;
  line-height: 1.2;
}

.tag-pill-remove {
  border: 0;
  background: transparent;
  color: #3a5da1;
  border-radius: 999px;
  width: 1rem;
  height: 1rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  font-size: 0.76rem;
  font-weight: 700;
}

.tag-pill-remove:hover {
  background: rgba(36, 74, 143, 0.12);
  color: #1a3d7c;
}

.tag-editor-input {
  border: 0 !important;
  box-shadow: none !important;
  padding: 0.12rem 0.16rem !important;
  min-width: 0;
  inline-size: auto !important;
  flex: 1 1 auto;
  width: 100% !important;
  background: transparent !important;
}

#admin-panel .tag-pill-remove {
  border: 0 !important;
  border-radius: 999px !important;
  background: transparent !important;
  padding: 0 !important;
  min-width: 1rem !important;
  width: 1rem !important;
  height: 1rem !important;
  line-height: 1 !important;
}

#admin-panel .tag-editor-input {
  border: 0 !important;
  border-radius: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  padding: 0.12rem 0.16rem !important;
  inline-size: auto !important;
  min-width: 0 !important;
  width: 100% !important;
  flex: 1 1 auto !important;
}

.button-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(148px, 1fr));
  gap: 0.52rem;
  margin-top: 0.72rem;
}

.compose-actions {
  margin-top: 0.74rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem;
  inline-size: min(100%, 56rem);
}

.compose-actions #btn-publish-now {
  min-width: 11rem;
}

#admin-panel button.icon-danger {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 2.25rem;
  width: 2.25rem;
  height: 2.25rem;
  padding: 0;
  border-radius: 9px;
  border: 1px solid #d7b6b6;
  background: #fff;
  color: #a23a39;
}

#admin-panel button.icon-danger:hover {
  border-color: #c27c7b;
  background: #fff2f2;
  color: #8f2f2d;
}

#admin-panel button {
  border: 1px solid #b8c9ea;
  border-radius: 10px;
  background: #fff;
  color: #183260;
  font-size: 0.88rem;
  font-weight: 650;
  padding: 0.58rem 0.8rem;
  line-height: 1.25;
  transition: background-color 0.18s ease, border-color 0.18s ease, color 0.18s ease, transform 0.15s ease;
}

#admin-panel button:hover {
  background: #eaf2ff;
  border-color: #8ca9e2;
  color: #102c5f;
  transform: translateY(-1px);
}

#admin-panel button.primary {
  background: linear-gradient(180deg, #2f58b1 0%, #29499b 100%);
  border-color: #2b4ea3;
  color: #fff;
}

#admin-panel button.primary:hover {
  background: linear-gradient(180deg, #2a4ea0 0%, #243f85 100%);
  border-color: #24458f;
  color: #fff;
}

#admin-panel button.danger {
  background: linear-gradient(180deg, #c44745 0%, #a93734 100%);
  border-color: #a93a37;
  color: #fff;
}

#admin-panel button.danger:hover {
  background: linear-gradient(180deg, #b23c3a 0%, #96312f 100%);
  border-color: #983330;
}

#admin-panel button:disabled {
  opacity: 0.64;
  transform: none;
}

.notice {
  border: 1px solid;
  border-radius: 10px;
  padding: 0.64rem 0.76rem;
  margin-top: 0.64rem;
  font-size: 0.87rem;
}

.output {
  min-height: 18px;
  margin-top: 0.45rem;
}

.preview-panel {
  position: sticky;
  top: 0.9rem;
  border: 0;
  border-radius: 14px;
  background: transparent;
  padding: 0.82rem;
  box-shadow: none;
}

.compose-shell.preview-hidden .composer-grid {
  grid-template-columns: minmax(0, 1fr);
}

.compose-shell.preview-hidden .preview-panel {
  display: none;
}

.preview-box {
  min-height: 390px;
  max-height: 640px;
  overflow: auto;
  border: 1px solid #c9d8f2;
  border-radius: 12px;
  padding: 0.9rem;
  background: linear-gradient(180deg, #ffffff 0%, #f8fbff 100%);
}

.placeholder,
.muted {
  color: #5f6f86;
  font-size: 0.86rem;
}

.muted code {
  color: #3f4f68;
}

.row-head,
.composer-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 0.95rem;
  margin-bottom: 0.92rem;
}

.composer-head-actions {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
}

#admin-panel button.quiet-toggle {
  border: 1px solid #c4d4f1;
  border-radius: 999px;
  background: #f4f8ff;
  color: #29457f;
  font-size: 0.8rem;
  font-weight: 620;
  padding: 0.28rem 0.62rem;
}

#admin-panel button.quiet-toggle:hover {
  background: #e9f1ff;
  border-color: #a8c0ea;
  color: #1e3f7b;
}

.row-actions {
  display: flex;
  gap: 0.48rem;
}

.draft-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(270px, 1fr));
  gap: 0.78rem;
}

.draft-card {
  border: 1px solid #d2def3;
  border-radius: 13px;
  background: #fff;
  box-shadow: 0 8px 22px rgba(15, 23, 42, 0.06);
  padding: 0.8rem;
}

.draft-card-head {
  margin-bottom: 0.28rem;
  font-size: 0.98rem;
  color: #1f335f;
}

.draft-actions {
  display: flex;
  gap: 0.5rem;
  margin-top: 0.7rem;
}

.draft-actions button {
  flex: 1 1 auto;
}

.drop-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.75);
  color: #fff;
  display: none;
  align-items: center;
  justify-content: center;
  font-size: 1.08rem;
  z-index: 9999;
  text-align: center;
  padding: 2rem;
}

.drop-overlay.show {
  display: flex;
}

@media (max-width: 1180px) {
  body {
    max-width: 1080px;
    padding: 0 1rem 2rem;
  }

  .composer-grid {
    grid-template-columns: 1fr;
  }

  .preview-panel {
    position: static;
  }

  .preview-box {
    max-height: 460px;
  }
}

@media (max-width: 620px) {
  .admin-layout {
    grid-template-columns: 1fr;
    min-height: 0;
  }

  .admin-sidebar {
    position: static;
    min-height: 0;
    border-right: 0;
  }

  .admin-content {
    padding-left: 0;
  }
}

@media (max-width: 520px) {
  body {
    padding: 0 0.84rem 1.6rem;
  }

  .grid-two {
    grid-template-columns: 1fr;
  }

  [data-admin-section="settings"] .field-row {
    grid-template-columns: 1fr;
    align-items: start;
  }

  .row-head,
  .composer-head {
    flex-direction: column;
    align-items: stretch;
  }

  .row-actions {
    inline-size: auto;
  }

  .row-actions button {
    flex: 1 1 0;
  }

  .compose-actions {
    inline-size: 100%;
  }
}

@media (max-width: 480px) {
  .demo-box {
    padding: 0.85rem;
  }

  .toolbar button {
    width: 1.95rem;
    min-width: 1.95rem;
    height: 1.95rem;
    padding: 0;
  }

  .compose-actions #btn-publish-now {
    min-width: 0;
    width: 100%;
  }
}
</style>
