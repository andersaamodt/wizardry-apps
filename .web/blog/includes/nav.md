<a class="skip-link" href="#main-content">Skip to content</a>
<nav class="site-nav">
<div class="nav-center">
<a href="/pages/index.html" data-page="index">Home</a>
<a href="/pages/about.html" data-page="about">About</a>
<a href="/pages/archive.html" data-page="archive">Archive</a>
<a href="/pages/tags.html" data-page="tags">Categories</a>
</div>
<div class="nav-right">
<form class="nav-search" method="get" action="/cgi/blog-search">
<input type="text" name="q" placeholder="Search..." />
<button type="submit" aria-label="Search">
<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
<circle cx="7" cy="7" r="5.5" stroke="currentColor" stroke-width="1.5"/>
<path d="M11 11L14.5 14.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
</svg>
</button>
</form>
<a href="/pages/admin.html#compose" class="nav-compose nav-compose-icon" style="display:none;" aria-label="Compose post" title="Compose post">
<!-- Font Awesome Free "pen-to-square" (Icons: CC BY 4.0): https://fontawesome.com/icons/pen-to-square -->
<svg width="21" height="21" viewBox="0 0 512 512" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
<path fill="currentColor" d="M471.6 21.7c-21.9-21.9-57.3-21.9-79.2 0L362.3 51.7l97.9 97.9 30.1-30.1c21.9-21.9 21.9-57.3 0-79.2L471.6 21.7zm-299.2 220c-6.1 6.1-10.8 13.6-13.5 21.9l-29.6 88.8c-2.9 8.6-.6 18.1 5.8 24.6s15.9 8.7 24.6 5.8l88.8-29.6c8.2-2.7 15.7-7.4 21.9-13.5L437.7 172.3 339.7 74.3 172.4 241.7zM96 64C43 64 0 107 0 160L0 416c0 53 43 96 96 96l256 0c53 0 96-43 96-96l0-96c0-17.7-14.3-32-32-32s-32 14.3-32 32l0 96c0 17.7-14.3 32-32 32L96 448c-17.7 0-32-14.3-32-32l0-256c0-17.7 14.3-32 32-32l96 0c17.7 0 32-14.3 32-32s-14.3-32-32-32L96 64z"/>
</svg>
</a>
<span id="nav-user-name" class="nav-username" style="display:none;"></span>
<div class="nav-user-menu" id="nav-user-menu" style="display:none;">
  <button class="nav-menu-btn" id="nav-menu-btn" type="button" aria-haspopup="menu" aria-expanded="false" aria-label="User menu">...</button>
  <div class="nav-menu-panel" id="nav-menu-panel" role="menu" hidden>
    <a id="nav-menu-primary-link" class="nav-menu-item" href="/pages/admin.html" role="menuitem">Admin</a>
    <button id="nav-menu-logout-everywhere" class="nav-menu-item" type="button" role="menuitem">Log out everywhere</button>
    <button id="nav-menu-logout" class="nav-menu-item nav-menu-item-danger" type="button" role="menuitem">Logout</button>
  </div>
</div>
<button class="btn-login" id="login-btn" type="button">Login</button>
</div>
</nav>

<div class="auth-modal" id="auth-modal" hidden>
  <div class="auth-modal-backdrop" data-close-auth-modal></div>
  <div class="auth-modal-panel" role="dialog" aria-modal="true" aria-labelledby="auth-modal-title">
    <button class="auth-modal-close" type="button" aria-label="Close login" data-close-auth-modal>&times;</button>
    <h2 id="auth-modal-title">Sign in</h2>
    <p class="auth-modal-help">Accounts are Nostr-key based only. No email, password, or recovery. If your Nostr key is lost, the account is lost by design.</p>
    <p class="auth-modal-help">Desktop login uses NIP-07 when available. Phone login uses NIP-46 pairing via QR/deep-link.</p>

    <div class="auth-intent">
      <div class="auth-intent-row">
        <label><input type="radio" id="auth-mode-once" name="auth-mode" value="once"> One-time login</label>
        <label><input type="radio" id="auth-mode-approve" name="auth-mode" value="approve" checked> Approve this device</label>
      </div>
      <div class="auth-intent-row auth-intent-days" id="auth-intent-days-row">
        <label for="auth-delegation-days">Delegation days (1-90)</label>
        <input class="auth-input auth-days-input" type="number" id="auth-delegation-days" min="1" max="90" step="1" value="30">
      </div>
      <label class="auth-intent-row">
        <input type="checkbox" id="auth-force-interactive">
        Require direct signer approval for sensitive actions
      </label>
    </div>

    <div class="auth-actions auth-actions-primary auth-actions-stack">
      <div class="auth-action-row">
        <button id="auth-nip07-btn" class="auth-secondary-btn" type="button">Login with desktop signer</button>
        <span class="auth-action-reco">Recommended: <a class="auth-inline-link" href="https://addons.mozilla.org/en-US/firefox/addon/nos2x-fox/" target="_blank" rel="noopener noreferrer">nos2x-fox</a></span>
      </div>
      <div class="auth-action-row">
        <button id="auth-phone-connect-btn" class="auth-secondary-btn" type="button">Connect phone signer (QR)</button>
        <span class="auth-action-reco">Recommended: <a class="auth-inline-link" href="https://play.google.com/store/apps/details?id=com.vitorpamplona.amethyst" target="_blank" rel="noopener noreferrer">Amethyst</a></span>
      </div>
      <div class="auth-action-row">
        <button id="auth-phone-btn" class="auth-primary-btn" type="button" disabled>Continue with phone signer</button>
      </div>
      <div class="auth-action-row">
        <button id="auth-paste-btn" class="auth-secondary-btn" type="button">Paste signed login</button>
      </div>
    </div>

    <div id="auth-phone-panel" class="auth-panel" hidden>
      <p class="auth-modal-help">Scan this with your phone signer app (Nostr Connect / NIP-46), or open via deep link.</p>
      <div id="auth-nip46-qr" class="auth-qr" aria-label="Nostr Connect QR code"></div>
      <a id="auth-nip46-open" class="auth-inline-link" href="#" target="_blank" rel="noopener noreferrer">Open nostrconnect:// link</a>
      <p class="auth-nip46-uri" id="auth-nip46-uri"></p>
    </div>

    <div id="auth-manual-panel" class="auth-panel" hidden>
      <p class="auth-modal-help">Manual fallback: sign the challenge event outside this page and paste signed JSON.</p>
      <div class="auth-actions">
        <button id="auth-manual-start" class="auth-secondary-btn" type="button">Create challenge</button>
      </div>
      <div class="auth-manual-grid">
        <label for="auth-manual-request-id"><strong>Request ID</strong></label>
        <input class="auth-input" id="auth-manual-request-id" type="text" readonly>
        <label for="auth-manual-challenge"><strong>Challenge</strong></label>
        <input class="auth-input" id="auth-manual-challenge" type="text" readonly>
        <label for="auth-manual-expires"><strong>Expires At (epoch)</strong></label>
        <input class="auth-input" id="auth-manual-expires" type="text" readonly>
      </div>
      <label for="auth-manual-template"><strong>Unsigned Auth Event Template</strong></label>
      <textarea id="auth-manual-template" class="auth-input auth-key-input" readonly></textarea>
      <label for="auth-manual-delegation-template"><strong>Unsigned Delegation Template (approve mode)</strong></label>
      <textarea id="auth-manual-delegation-template" class="auth-input auth-key-input" readonly></textarea>
      <label for="auth-manual-event"><strong>Signed Auth Event JSON</strong></label>
      <textarea id="auth-manual-event" class="auth-input auth-key-input" placeholder='{"kind":22242,...,"sig":"..."}'></textarea>
      <label for="auth-manual-delegation"><strong>Signed Delegation JSON (optional)</strong></label>
      <textarea id="auth-manual-delegation" class="auth-input auth-key-input" placeholder='{"kind":27235,...,"sig":"..."}'></textarea>
      <div class="auth-actions">
        <button id="auth-manual-submit" class="auth-primary-btn" type="button">Submit signed login</button>
      </div>
    </div>

    <div id="auth-modal-message" class="auth-modal-message" aria-live="polite"></div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/nostr-tools@2.7.2/lib/nostr.bundle.js"></script>
<script src="https://cdn.jsdelivr.net/npm/qrcodejs/qrcode.min.js"></script>
<script src="/static/nav-auth.js"></script>
