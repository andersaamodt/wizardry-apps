---
title: Blog Admin
---

<div id="admin-access-message" class="admin-access-message" hidden></div>

<div id="admin-panel" class="admin-layout" style="display:none;">
<aside class="admin-sidebar">
<div class="admin-nav-title">Admin</div>
<div class="admin-nav-list" role="tablist" aria-label="Admin sections">
<button type="button" class="admin-nav-item is-compose" data-admin-nav="compose" aria-selected="false"><span class="admin-nav-icon-slot" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M6 18L7.2 13.8L15.8 5.2a2 2 0 1 1 2.8 2.8L10 16.6L6 18Z" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M5 21H19" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg></span><span class="admin-nav-label">Compose</span></button>
<button type="button" class="admin-nav-item" data-admin-nav="account" aria-selected="false"><span class="admin-nav-icon-slot" aria-hidden="true"></span><span class="admin-nav-label">Account</span></button>
<button type="button" class="admin-nav-item is-active" data-admin-nav="settings" aria-selected="true"><span class="admin-nav-icon-slot" aria-hidden="true"></span><span class="admin-nav-label">Site Settings</span></button>
<button type="button" class="admin-nav-item" data-admin-nav="nostr-bridge" aria-selected="false"><span class="admin-nav-icon-slot" aria-hidden="true"></span><span class="admin-nav-label">Nostr Bridge</span></button>
<button type="button" class="admin-nav-item" data-admin-nav="users" aria-selected="false"><span class="admin-nav-icon-slot" aria-hidden="true"></span><span class="admin-nav-label">Users</span></button>
<button type="button" class="admin-nav-item" data-admin-nav="drafts" aria-selected="false"><span class="admin-nav-icon-slot" aria-hidden="true"></span><span class="admin-nav-label">Drafts</span></button>
<button type="button" class="admin-nav-item" data-admin-nav="queue" aria-selected="false"><span class="admin-nav-icon-slot" aria-hidden="true"></span><span class="admin-nav-label">Queue</span></button>
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
<label for="site-title" title="Public title shown in your blog header and feeds."><strong title="Public title shown in your blog header and feeds.">Site Title</strong></label>
<input type="text" id="site-title" placeholder="My Blog" title="Public title shown in your blog header and feeds.">
</div>
<div class="field-row">
<label for="admin-theme" title="Visual theme for your public site and admin interface accents."><strong title="Visual theme for your public site and admin interface accents.">Theme</strong></label>
<select id="admin-theme" title="Visual theme for your public site and admin interface accents.">
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
<div class="setting-label" title="Allow new users to register with a Nostr key. Disable for single-author blogs.">
<strong title="Allow new users to register with a Nostr key. Disable for single-author blogs.">Enable User Registration</strong>
<span class="inline-tip" tabindex="0" aria-label="Allow new users to create accounts by signing in with a Nostr key.">?</span>
</div>
<label class="checkbox-control" for="registration-enabled" title="Allow new users to register with a Nostr key. Disable for single-author blogs.">
<input type="checkbox" id="registration-enabled" title="Allow new users to register with a Nostr key. Disable for single-author blogs.">
<span title="Allow new users to register with a Nostr key. Disable for single-author blogs.">Enabled</span>
</label>
</div>
</section>

<section class="sub-card">
<h4>Feeds</h4>
<div class="grid-two">
<div class="field-row checkbox-row">
<div class="setting-label" title="RSS and Atom feeds are always on. This only controls full text versus a shorter/truncated item in each feed entry.">
<strong title="RSS and Atom feeds are always on. This only controls full text versus a shorter/truncated item in each feed entry.">Full Text RSS/Atom</strong>
</div>
<label class="checkbox-control" for="feed-full-text" title="RSS and Atom feeds are always on. This only controls full text versus a shorter/truncated item in each feed entry.">
<input type="checkbox" id="feed-full-text" checked title="RSS and Atom feeds are always on. This only controls full text versus a shorter/truncated item in each feed entry.">
<span title="RSS and Atom feeds are always on. This only controls full text versus a shorter/truncated item in each feed entry.">Enabled</span>
</label>
</div>
<div class="field-row">
<label for="feed-items" title="Maximum number of recent posts included in RSS and Atom feeds."><strong title="Maximum number of recent posts included in RSS and Atom feeds.">Feed Item Count</strong></label>
<input type="number" id="feed-items" min="1" step="1" value="50" title="Maximum number of recent posts included in RSS and Atom feeds.">
</div>
</div>
</section>

<section class="sub-card">
<h4>Access Bootstrap</h4>
<div class="field-row checkbox-row">
<div class="setting-label" title="When enabled, newly registered accounts are granted admin rights automatically.">
<strong title="When enabled, newly registered accounts are granted admin rights automatically.">Newly Created Accounts Are Admins</strong>
<span class="inline-tip" tabindex="0" aria-label="When enabled, newly registered Nostr accounts are granted admin automatically. Turn this off after bootstrapping your initial admin team.">?</span>
</div>
<label class="checkbox-control" for="new-users-are-admins" title="When enabled, newly registered accounts are granted admin rights automatically.">
<input type="checkbox" id="new-users-are-admins" title="When enabled, newly registered accounts are granted admin rights automatically.">
<span title="When enabled, newly registered accounts are granted admin rights automatically.">Enabled</span>
</label>
</div>
</section>
</div>

<div class="section-actions">
<button id="btn-save-config" class="primary">Save Settings</button>
</div>
<div id="output-config" class="output"></div>
</div>
</section>

<section class="admin-section" data-admin-section="nostr-bridge" hidden>
<div class="demo-box admin-card">
<div class="section-head">
<h3>Nostr Bridge</h3>
</div>

<div class="settings-stack">
<section class="sub-card">
<h4>Bridge</h4>
<div class="field-row checkbox-row">
<div class="setting-label" title="Enable local Nostr mirroring and signed Nostr event publishing for posts and comments.">
<strong title="Enable local Nostr mirroring and signed Nostr event publishing for posts and comments.">Enable Nostr Bridge</strong>
<span class="inline-tip" tabindex="0" aria-label="When enabled, published posts are signed as Nostr events and local render indexes are rebuilt from mirrored events.">?</span>
</div>
<label class="checkbox-control" for="nostr-bridge-enabled" title="Enable local Nostr mirroring and signed Nostr event publishing for posts and comments.">
<input type="checkbox" id="nostr-bridge-enabled" title="Enable local Nostr mirroring and signed Nostr event publishing for posts and comments.">
<span title="Enable local Nostr mirroring and signed Nostr event publishing for posts and comments.">Enabled</span>
</label>
</div>
</section>

<section class="sub-card">
<h4>Authors</h4>
<div class="field-row">
<label for="nostr-authors" title="Allowed author pubkeys for post mirroring. Use one hex pubkey per line."><strong title="Allowed author pubkeys for post mirroring. Use one hex pubkey per line.">Allowed Authors</strong></label>
<textarea id="nostr-authors" class="bridge-textarea" rows="4" placeholder="hexpubkey1&#10;hexpubkey2" title="Allowed author pubkeys for post mirroring. Use one hex pubkey per line."></textarea>
</div>
</section>

<section class="sub-card">
<h4>Relays</h4>
<div class="field-row">
<label for="nostr-relays" title="Relays used for mirror fetch and Nostr bridge transport. Use one relay URL per line."><strong title="Relays used for mirror fetch and Nostr bridge transport. Use one relay URL per line.">Relay List</strong></label>
<textarea id="nostr-relays" class="bridge-textarea" rows="4" placeholder="wss://relay.damus.io&#10;wss://relay.primal.net" title="Relays used for mirror fetch and Nostr bridge transport. Use one relay URL per line."></textarea>
</div>
</section>

<section class="sub-card">
<h4>Blocklist</h4>
<div class="field-row">
<label for="nostr-blocklist" title="Blocked pubkeys excluded from mirrored comments and derived content. Use one pubkey per line."><strong title="Blocked pubkeys excluded from mirrored comments and derived content. Use one pubkey per line.">Blocked Pubkeys</strong></label>
<textarea id="nostr-blocklist" class="bridge-textarea" rows="4" placeholder="hexpubkey_to_block" title="Blocked pubkeys excluded from mirrored comments and derived content. Use one pubkey per line."></textarea>
</div>
</section>
</div>

<p class="muted">These settings are stored in <code>site/nostr/state/</code> as <code>authors.txt</code>, <code>relays.txt</code>, and <code>blocklist.txt</code>.</p>

<div class="section-actions">
<button id="btn-save-nostr-bridge" class="primary">Save Nostr Bridge Settings</button>
</div>
<div id="output-nostr-bridge" class="output"></div>
</div>
</section>

<section class="admin-section" data-admin-section="users" hidden>
<div class="demo-box admin-card">
<div class="section-head">
<h3>Users</h3>
</div>
<div id="users-list" class="users-list"></div>
<div id="output-users" class="output"></div>
</div>
</section>

<section class="admin-section" data-admin-section="compose" hidden>
<div class="demo-box admin-card compose-shell">
<div class="composer-head">
<div>
<h3>Compose</h3>
</div>
<div class="composer-head-actions">
<button type="button" id="btn-toggle-preview" class="quiet-toggle" aria-pressed="true" aria-label="Hide preview" title="Hide preview">
<svg class="preview-icon preview-icon-visible" viewBox="0 0 24 24" fill="none" aria-hidden="true">
<path d="M2.5 12C4.7 8 8.1 6 12 6C15.9 6 19.3 8 21.5 12C19.3 16 15.9 18 12 18C8.1 18 4.7 16 2.5 12Z" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.8"/>
</svg>
<svg class="preview-icon preview-icon-hidden" viewBox="0 0 24 24" fill="none" aria-hidden="true">
<path d="M3.2 4.2L20.8 19.8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
<path d="M9.9 6.4C10.6 6.1 11.3 6 12 6C15.9 6 19.3 8 21.5 12C20.8 13.3 19.9 14.5 18.9 15.4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M14.1 17.6C13.4 17.9 12.7 18 12 18C8.1 18 4.7 16 2.5 12C3.2 10.7 4.1 9.5 5.1 8.6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M12 9C13.7 9 15 10.3 15 12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>
<span class="sr-only">Toggle preview</span>
</button>
</div>
</div>

<div class="composer-grid">
<div class="compose-editor">
<div class="field-row">
<label for="post-title"><strong>Post Title</strong></label>
<input type="text" id="post-title" placeholder="My post">
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
<button type="button" data-toolbar="code_block" aria-label="Code block" title="Code block">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M8 6L5 12L8 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M16 6L19 12L16 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 4L10 20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
<span class="sr-only">Code block</span>
</button>
<button type="button" data-toolbar="link" aria-label="Insert link" title="Insert link">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M10 8L8 10C6.9 11.1 6.9 12.9 8 14C9.1 15.1 10.9 15.1 12 14L14 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M14 8L16 6C17.1 4.9 18.9 4.9 20 6C21.1 7.1 21.1 8.9 20 10L18 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" transform="translate(-4 4)"/><path d="M9 12H15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
<span class="sr-only">Insert link</span>
</button>
<button type="button" data-toolbar="quote" aria-label="Quote" title="Quote">
<svg class="tb-icon" viewBox="0 0 24 24" fill="none"><path d="M7 10H11V14H8.6C8.7 15 9.2 15.7 10.1 16.2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 10H18V14H15.6C15.7 15 16.2 15.7 17.1 16.2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
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
<div id="autosave-status" class="autosave-indicator" hidden></div>
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
</div>

<div class="field-row">
<strong>Release Mode</strong>
<div class="mode-row">
<label><input type="radio" name="publish-mode" value="draft" checked> Draft</label>
<label><input type="radio" name="publish-mode" value="scheduled"> Scheduled Date</label>
<label><input type="radio" name="publish-mode" value="drip"> Drip Queue <span id="drip-queue-pill" class="drip-queue-pill" hidden></span></label>
</div>
</div>

<div class="field-row scheduled-row is-hidden" id="scheduled-row">
<label for="post-scheduled-at"><strong>Scheduled Release Date/Time</strong></label>
<input type="datetime-local" id="post-scheduled-at">
</div>

<input type="file" id="image-picker" accept="image/*" multiple style="display:none;">
</div>

<aside class="preview-panel">
<h4>Live Preview</h4>
<div id="markdown-preview" class="preview-box">
<p class="placeholder">Preview will appear here...</p>
</div>
</aside>
</div>

<div class="compose-footer">
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

<div id="output-compose" class="output"></div>
</div>
</div>
</section>

<section class="admin-section" data-admin-section="drafts" hidden>
<div class="demo-box admin-card">
<div class="row-head">
<div>
<h3>Drafts</h3>
</div>
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
<button id="btn-save-drip" type="button">Save Drip Settings</button>
<button id="btn-refresh-queue" type="button">Refresh</button>
<button id="btn-mirror-nostr" type="button">Mirror Nostr</button>
<button id="btn-run-scheduler" type="button" class="primary">Run Scheduler</button>
</div>
</div>
<div class="grid-two settings-inline queue-drip-settings">
<div class="field-row">
<label for="drip-interval" title="How often queued drip posts are published."><strong title="How often queued drip posts are published.">Drip Interval (hours)</strong></label>
<input type="number" id="drip-interval" min="0.1" step="0.1" value="4" title="How often queued drip posts are published.">
</div>
<div class="field-row">
<label for="drip-randomness" title="Adds up to this many random minutes to each drip cycle time."><strong title="Adds up to this many random minutes to each drip cycle time.">Drip Randomness (minutes)</strong></label>
<input type="number" id="drip-randomness" min="0" step="1" value="0" title="Adds up to this many random minutes to each drip cycle time.">
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
<p class="muted">Your account is Nostr-based. You can bind a passkey and link an SSH key for MUD compatibility.</p>
</div>
</div>

<div class="field-row">
<label for="account-nostr-pubkey"><strong>Nostr Pubkey</strong></label>
<div class="account-row account-nostr-row">
<input type="text" id="account-nostr-pubkey" readonly>
<button id="btn-account-pubkey-copy" type="button" class="account-icon-button" aria-label="Copy Nostr pubkey" title="Copy Nostr pubkey">
<svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
<path d="M9 9H19V19H9V9Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
<path d="M5 15H4.8C3.8 15 3 14.2 3 13.2V4.8C3 3.8 3.8 3 4.8 3H13.2C14.2 3 15 3.8 15 4.8V5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
</button>
<button id="btn-account-pubkey-toggle" type="button">Show</button>
</div>
<p class="muted account-note">This key is account-bound and cannot be edited directly.</p>
</div>

<div class="field-row">
<label for="account-player-name"><strong>Player Name</strong></label>
<div class="account-row">
<input type="text" id="account-player-name" placeholder="Your name">
<button id="btn-save-account" type="button" class="primary">Save</button>
</div>
</div>

<div class="field-row">
<label><strong>Passkey</strong></label>
<div class="account-row">
<button id="btn-bind-passkey" type="button">Bind passkey</button>
</div>
</div>

<details class="account-ssh-optional">
<summary>SSH key for MUD and terminal login</summary>
<p class="muted account-ssh-description">Link your SSH public key for terminal access.</p>
<div class="field-row">
<label for="account-ssh-public-key"><strong>SSH Public Key</strong></label>
<textarea id="account-ssh-public-key" rows="3" placeholder="ssh-ed25519 AAAA..."></textarea>
<div class="account-row">
<button id="btn-generate-ssh" type="button">Generate SSH Key Pair (Browser)</button>
<button id="btn-link-ssh" type="button">Link SSH Key</button>
</div>
<p class="muted">When generated in-browser, private key download starts locally. Keep it secret and back it up.</p>
</div>
</details>

<div class="field-row">
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
  max-width: none;
  margin: 0;
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
  width: 100%;
  box-sizing: border-box;
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
  width: 100%;
  box-sizing: border-box;
}

.admin-nav-title {
  display: block;
  width: 100%;
  box-sizing: border-box;
  margin: 0;
  padding: 0.5rem 0.22rem;
  border-bottom: 1px solid #d7e1f4;
  background: #f4f6fa;
  color: #2a3650;
  font-size: 0.9rem;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: 0.01em;
  text-align: center;
}

.admin-nav-item {
  display: flex;
  align-items: center;
  gap: 0.38rem;
  width: 100%;
  appearance: none;
  -webkit-appearance: none;
  text-align: left;
  border: 0;
  border-radius: 0;
  border-bottom: 0;
  background: transparent;
  color: #1e2d4e;
  margin: 0;
  padding: 0.56rem 0.22rem;
  font-size: 0.93rem;
  font-weight: 650;
  line-height: 1.25;
  transition: background-color 0.18s ease, color 0.18s ease;
}

.admin-nav-icon-slot {
  width: 1rem;
  min-width: 1rem;
  height: 1rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #2d4f8d;
  flex: 0 0 1rem;
}

.admin-nav-icon-slot svg {
  width: 1rem;
  height: 1rem;
}

.admin-nav-label {
  display: inline-block;
}

.admin-nav-item.is-compose {
  background: #ecf3ff;
}

.admin-nav-item.is-compose:hover {
  background: #e2ecff;
}

.admin-nav-item:hover {
  background: #e9f1ff;
  color: #153878;
}

.admin-nav-item.is-active {
  background: #cfdfff;
  color: #153878;
  box-shadow: none;
  cursor: default;
}

.admin-nav-item[aria-selected="true"],
.admin-nav-item[aria-current="page"] {
  background: #c7d9ff;
  color: #0f326f;
  box-shadow: none;
  font-weight: 700;
}

#admin-panel .admin-nav-list .admin-nav-item {
  width: 100% !important;
  display: flex !important;
  align-items: center !important;
  border: 0 !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  margin: 0 !important;
}

#admin-panel .admin-nav-list .admin-nav-item:hover {
  border: 0 !important;
  background: #e9f1ff !important;
  color: #153878 !important;
  transform: none !important;
}

#admin-panel .admin-nav-list .admin-nav-item.is-active {
  border: 0 !important;
}

#admin-panel .admin-nav-list .admin-nav-item[aria-selected="true"],
#admin-panel .admin-nav-list .admin-nav-item[aria-current="page"] {
  border: 0 !important;
  background: #c7d9ff !important;
  color: #0f326f !important;
  box-shadow: none !important;
  transform: none !important;
  cursor: default !important;
}

#admin-panel .admin-nav-list .admin-nav-item[aria-selected="true"]:hover,
#admin-panel .admin-nav-list .admin-nav-item[aria-current="page"]:hover {
  background: #c7d9ff !important;
  color: #0f326f !important;
}

.admin-content {
  min-width: 0;
  min-height: calc(100vh - 3.25rem);
  padding: 0.45rem 0.72rem 0.95rem 0.7rem;
  background: #f4f7fd;
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
  padding: 0.62rem 0.7rem 0.8rem;
  border: 0;
  border-radius: 0;
  background: transparent;
  box-shadow: none;
}

.admin-card {
  min-height: 0;
}

.section-head {
  margin-bottom: 0.6rem;
}

.demo-box h3 {
  margin: 0;
  font-size: 1.2rem;
  line-height: 1.22;
  color: #1a2f5a;
}

.demo-box h4 {
  margin: 0 0 0.4rem;
  font-size: 0.96rem;
  line-height: 1.25;
  color: #273f74;
  letter-spacing: 0.01em;
}

.settings-stack {
  display: grid;
  gap: 0.08rem;
}

.sub-card {
  border: 0;
  border-top: 1px solid #d7e1f4;
  border-radius: 0;
  background: transparent;
  padding: 0.14rem 0 0.02rem;
  box-shadow: none;
}

.settings-stack .sub-card:first-child {
  border-top: 0;
  padding-top: 0;
}

.section-actions {
  margin-top: 0.22rem;
}

.field-row {
  margin-bottom: 0.18rem;
}

.field-row:last-child {
  margin-bottom: 0;
}

.field-row label {
  display: block;
  margin-bottom: 0.18rem;
  color: #1f335f;
  font-size: 0.84rem;
  font-weight: 700;
  letter-spacing: 0.01em;
}

[data-admin-section="settings"] .field-row {
  display: grid;
  grid-template-columns: minmax(12rem, max-content) minmax(0, 1fr);
  align-items: center;
  gap: 0.04rem 0.44rem;
  margin-bottom: 0.08rem;
}

[data-admin-section="nostr-bridge"] .field-row {
  display: grid;
  gap: 0.24rem;
  margin-bottom: 0.08rem;
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
  font-size: 0.82rem;
  font-weight: 700;
  letter-spacing: 0.01em;
}

[data-admin-section="nostr-bridge"] .setting-label {
  display: inline-flex;
  align-items: center;
  gap: 0.38rem;
  color: #1f335f;
  font-size: 0.82rem;
  font-weight: 700;
  letter-spacing: 0.01em;
}

[data-admin-section="settings"] .checkbox-row .checkbox-control {
  display: inline-flex;
  align-items: center;
  gap: 0.36rem;
  color: #1d3566;
  font-size: 0.82rem;
  font-weight: 600;
}

[data-admin-section="nostr-bridge"] .checkbox-row .checkbox-control {
  display: inline-flex;
  align-items: center;
  gap: 0.36rem;
  color: #1d3566;
  font-size: 0.82rem;
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
  border-radius: 9px;
  background: #fff;
  color: #102246;
  font-size: 0.92rem;
  line-height: 1.3;
  padding: 0.46rem 0.62rem;
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
  position: relative;
}

.grid-two {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.55rem 0.75rem;
}

.settings-inline {
  align-items: end;
}

[data-admin-section="settings"] .grid-two {
  grid-template-columns: 1fr;
  justify-content: start;
}

[data-admin-section="settings"] #site-title {
  inline-size: clamp(11rem, 23vw, 18rem);
}

[data-admin-section="nostr-bridge"] .bridge-textarea {
  inline-size: min(100%, 42rem) !important;
  width: min(100%, 42rem) !important;
  max-inline-size: 100% !important;
  min-height: 5.6rem;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.86rem;
  line-height: 1.35;
}

[data-admin-section="settings"] #admin-theme {
  inline-size: clamp(8.5rem, 13vw, 10.5rem);
}

[data-admin-section="queue"] #drip-interval,
[data-admin-section="queue"] #drip-randomness,
[data-admin-section="settings"] #feed-items {
  inline-size: 5.7rem !important;
  width: 5.7rem !important;
  max-inline-size: 5.7rem !important;
}

[data-admin-section="settings"] h4 {
  margin-bottom: 0.26rem;
}

[data-admin-section="settings"] .grid-two {
  gap: 0.3rem 0.62rem;
}

[data-admin-section="queue"] .queue-drip-settings {
  margin: 0.1rem 0 0.5rem;
  gap: 0.34rem 0.62rem;
}

[data-admin-section="queue"] .queue-drip-settings .field-row {
  margin-bottom: 0;
}

[data-admin-section="settings"] input[type="text"],
[data-admin-section="settings"] input[type="number"],
[data-admin-section="settings"] select {
  font-size: 0.88rem;
  line-height: 1.2;
  padding: 0.34rem 0.56rem;
  min-height: 2.06rem;
  border-radius: 8px;
}

[data-admin-section="account"] #account-player-name {
  inline-size: clamp(12rem, 22vw, 18rem);
}

[data-admin-section="account"] #account-nostr-pubkey,
[data-admin-section="account"] #account-ssh-public-key {
  inline-size: min(100%, 42rem);
}

.account-note {
  margin: 0.28rem 0 0.34rem;
}

[data-admin-section="account"] #account-nostr-pubkey {
  background: #eef2fb;
  color: #334155;
  border-style: dashed;
  cursor: not-allowed;
  filter: blur(1.7px);
  transition: filter 0.15s ease;
}

[data-admin-section="account"] #account-nostr-pubkey.is-visible {
  filter: none;
}

[data-admin-section="account"] .account-nostr-row {
  align-items: stretch;
  gap: 0.36rem;
}

[data-admin-section="account"] .account-nostr-row #account-nostr-pubkey {
  min-width: min(100%, 32rem);
}

#admin-panel button.account-icon-button {
  min-width: 2.15rem;
  width: 2.15rem;
  height: 2.15rem;
  padding: 0;
  border-radius: 8px;
}

#admin-panel button.account-icon-button svg {
  width: 0.95rem;
  height: 0.95rem;
}

#admin-panel #btn-account-pubkey-toggle {
  min-width: 4.1rem;
}

.account-ssh-optional {
  margin-top: 0.74rem;
}

.account-ssh-description {
  margin: 0.32rem 0 0.42rem;
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
  padding-bottom: 2.15rem;
}

.editor-shell #post-content:focus {
  box-shadow: none;
}

.editor-shell:focus-within {
  border-color: #5b7ed8;
  box-shadow: 0 0 0 3px rgba(91, 126, 216, 0.18);
}

.autosave-indicator {
  position: absolute;
  right: 0.5rem;
  bottom: 0.45rem;
  display: inline-flex;
  align-items: center;
  gap: 0.22rem;
  padding: 0.08rem 0.38rem;
  border-radius: 999px;
  border: 1px solid #bcd0f2;
  background: #f3f7ff;
  color: #2b4c86;
  font-size: 0.74rem;
  line-height: 1.2;
  z-index: 3;
  cursor: default;
}

.autosave-indicator.is-saving {
  border-color: #c6d3e9;
  background: #f6f8fd;
  color: #4f6180;
}

.autosave-indicator.is-error {
  border-color: #e2b6b6;
  background: #fff2f2;
  color: #8a2e2e;
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
  overflow: visible;
  gap: 0.3rem;
  flex: 1 1 auto;
  min-width: 0;
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

.tag-editor.has-tags .tag-editor-input::placeholder {
  color: transparent;
}

.compose-editor .grid-two {
  align-items: start;
}

.compose-editor .grid-two .field-row {
  margin-bottom: 0;
}

.button-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(148px, 1fr));
  gap: 0.52rem;
  margin-top: 0.72rem;
}

.compose-actions {
  margin-top: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem;
  inline-size: min(100%, 56rem);
}

.compose-actions #btn-publish-now {
  min-width: 11rem;
}

.compose-footer {
  margin-top: 0.25rem;
}

.drip-queue-pill {
  display: inline-flex;
  align-items: center;
  margin-left: 0.2rem;
  padding: 0.07rem 0.36rem;
  border-radius: 999px;
  border: 1px solid #9eb7eb;
  background: #edf3ff;
  color: #234a93;
  font-size: 0.73rem;
  line-height: 1.2;
  animation: drip-pill-pop 170ms ease;
}

@keyframes drip-pill-pop {
  from {
    transform: scale(0.92);
    opacity: 0.65;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
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

.compose-shell {
  display: flex;
  flex-direction: column;
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
  border: 1px solid #b8c9ea;
  border-radius: 8px;
  background: #f8fbff;
  color: #24457f;
  font-size: 0.8rem;
  font-weight: 620;
  width: 2rem;
  min-width: 2rem;
  height: 2rem;
  padding: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

#admin-panel button.quiet-toggle:hover {
  background: #e9f1ff;
  border-color: #9fb9ea;
  color: #1e3f7b;
}

#admin-panel button.quiet-toggle[aria-pressed="true"] {
  background: #dbe8ff;
  border-color: #7ea2e6;
  color: #153b76;
  box-shadow: inset 0 0 0 1px rgba(126, 162, 230, 0.25);
}

#admin-panel button.quiet-toggle[aria-pressed="true"]:hover {
  background: #d3e3ff;
  border-color: #739bdd;
  color: #12376f;
}

#admin-panel button.quiet-toggle .preview-icon {
  width: 1rem;
  height: 1rem;
}

#admin-panel button.quiet-toggle .preview-icon-hidden {
  display: none;
}

#admin-panel button.quiet-toggle[aria-pressed="false"] .preview-icon-visible {
  display: none;
}

#admin-panel button.quiet-toggle[aria-pressed="false"] .preview-icon-hidden {
  display: block;
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

.users-list {
  display: block;
  border: 1px solid #d2def3;
  border-radius: 10px;
  overflow: hidden;
  background: #fff;
}

.user-card {
  border: 0;
  border-bottom: 1px solid #d9e3f4;
  border-radius: 0;
  background: #fff;
  padding: 0.5rem 0.68rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  min-height: 3rem;
}

.user-card:last-of-type {
  border-bottom: 0;
}

.user-card.user-row-alt {
  background: #f5f8ff;
}

.users-list.is-dragging .user-card.is-draggable {
  cursor: grabbing;
}

.user-card.is-draggable {
  cursor: grab;
}

.user-card.is-dragging {
  opacity: 0.58;
}

.user-card-main {
  min-width: 0;
  display: grid;
  gap: 0.08rem;
}

.user-card-name {
  display: inline-flex;
  align-items: center;
  gap: 0.42rem;
  font-weight: 700;
  color: #163161;
}

.user-pill {
  display: inline-flex;
  align-items: center;
  padding: 0.08rem 0.45rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  border: 1px solid #c1d1f0;
  color: #32508f;
  background: #f2f6ff;
}

.user-pill.is-admin {
  border-color: #95b2ea;
  color: #1f3f7d;
  background: #e8f0ff;
}

.user-card-meta {
  font-size: 0.81rem;
  color: #5e6d86;
}

.user-card-actions {
  display: inline-flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  align-items: center;
  gap: 0.38rem;
}

#admin-panel button.user-menu-trigger {
  min-width: 2rem;
  width: 2rem;
  height: 2rem;
  border-radius: 8px;
  padding: 0;
}

#admin-panel .user-menu {
  position: relative;
}

#admin-panel .user-menu-panel {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  z-index: 30;
  min-width: 13.5rem;
  background: #fff;
  border: 1px solid #c8d7f1;
  border-radius: 10px;
  box-shadow: 0 14px 30px rgba(16, 28, 56, 0.16);
  padding: 0.3rem;
}

#admin-panel .user-menu-panel button {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  width: 100%;
  text-align: left;
  border: 0;
  border-radius: 8px;
  background: transparent;
  padding: 0.5rem 0.55rem;
  font-weight: 620;
}

#admin-panel .user-menu-panel button:hover {
  background: #eef4ff;
}

#admin-panel .user-menu-panel button.user-delete {
  color: #a52c2a;
}

#admin-panel .user-menu-panel button.user-delete .trash-icon-svg {
  width: 0.98rem;
  height: 0.98rem;
  color: #111;
  flex: 0 0 auto;
}

#admin-panel .user-menu-panel button.user-delete:hover {
  background: #fff1f1;
}

.user-drop-zone {
  height: 0;
  border-top: 2px solid transparent;
  margin: 0;
  transition: border-color 120ms ease, margin 120ms ease;
}

.users-list.is-dragging .user-drop-zone {
  margin: -1px 0 4px;
}

.users-list.is-dragging .user-drop-zone.is-target {
  border-top-color: #5a83d8;
  margin: 4px 0 7px;
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
    max-width: none;
    margin: 0;
    padding: 0 0 2rem;
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
    min-height: 0;
    padding: 0.4rem 0.5rem 0.75rem;
  }
}

@media (max-width: 520px) {
  body {
    margin: 0;
    padding: 0 0 1.6rem;
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
    padding: 0.45rem 0.42rem 0.6rem;
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
