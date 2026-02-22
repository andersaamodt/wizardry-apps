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
<a href="/pages/admin.html#settings" class="nav-settings nav-settings-icon" style="display:none;" aria-label="Settings" title="Settings">
<svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
<path d="M12 8.8C10.23 8.8 8.8 10.23 8.8 12C8.8 13.77 10.23 15.2 12 15.2C13.77 15.2 15.2 13.77 15.2 12C15.2 10.23 13.77 8.8 12 8.8Z" stroke="currentColor" stroke-width="1.8"/>
<path d="M19.4 13.2V10.8L17.54 10.29C17.4 9.9 17.24 9.52 17.03 9.17L17.99 7.49L16.31 5.81L14.63 6.77C14.28 6.56 13.9 6.4 13.51 6.26L13 4.4H10.6L10.09 6.26C9.7 6.4 9.32 6.56 8.97 6.77L7.29 5.81L5.61 7.49L6.57 9.17C6.36 9.52 6.2 9.9 6.06 10.29L4.2 10.8V13.2L6.06 13.71C6.2 14.1 6.36 14.48 6.57 14.83L5.61 16.51L7.29 18.19L8.97 17.23C9.32 17.44 9.7 17.6 10.09 17.74L10.6 19.6H13L13.51 17.74C13.9 17.6 14.28 17.44 14.63 17.23L16.31 18.19L17.99 16.51L17.03 14.83C17.24 14.48 17.4 14.1 17.54 13.71L19.4 13.2Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>
</svg>
</a>
<a href="/pages/admin.html#compose" class="nav-compose nav-compose-icon" style="display:none;" aria-label="Compose post" title="Compose post">
<!-- Compose icon adapted from "File Pen 2" by Streamline (CC BY 4.0). -->
<svg width="24" height="24" viewBox="0 0 32 32" fill="none" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
<path d="M20.6472 14.7518L17.7605 15.8436L12.4726 23.5025L8.52618 24.3865L9.93872 20.6376L17.4563 15.1603L18.5477 12.3734M20.6472 14.7518L24.0976 11.2008M20.6472 14.7518L18.5477 12.3734M24.0976 11.2008L25.1255 10.1431C25.7078 9.5438 25.6941 8.58295 25.0947 8.00061L24.4132 7.33832C23.8138 6.75598 22.853 6.7697 22.2706 7.36907L21.1748 8.49717M24.0976 11.2008L21.1748 8.49717M18.5477 12.3734L21.1748 8.49717M8.7998 18.1538V8.94444C8.7998 7.31883 10.1186 6 11.7442 6H19.9435C20.7222 6 21.469 6.30811 22.0209 6.85653L24.8764 9.69389C25.4294 10.2434 25.7408 10.9912 25.7427 11.7709L25.7544 17.6111" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
</a>
<span id="nav-user-name" class="nav-username" style="display:none;"></span>
<div class="nav-user-menu" id="nav-user-menu" style="display:none;">
  <button class="nav-menu-btn" id="nav-menu-btn" type="button" aria-haspopup="menu" aria-expanded="false" aria-label="User menu">...</button>
  <div class="nav-menu-panel" id="nav-menu-panel" role="menu" hidden>
    <a id="nav-menu-primary-link" class="nav-menu-item" href="/pages/admin.html" role="menuitem">Admin</a>
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
    <h2 id="auth-modal-title">Sign in with passkey</h2>
    <p class="auth-modal-help">Sign in on this website is passkey-only. New users should register an SSH public key below. <a class="auth-inline-link" href="/pages/login-security.html">Learn more</a>.</p>

    <div class="auth-actions">
      <button id="auth-passkey-btn" class="auth-primary-btn" type="button">Use passkey</button>
      <span id="auth-passkey-inline-message" class="auth-passkey-inline-message" aria-live="polite"></span>
    </div>

    <div id="auth-modal-message" class="auth-modal-message" aria-live="polite"></div>

    <details id="auth-register-details" class="auth-register-details">
      <summary>Need to register first?</summary>
      <p class="auth-modal-help">Paste your SSH public key or drop a <code>.pub</code> file into the box.</p>
      <div class="auth-key-row">
        <textarea id="auth-ssh-key" class="auth-input auth-key-input" rows="4" placeholder="ssh-ed25519 AAAA..."></textarea>
        <span class="auth-key-or">or</span>
        <div id="auth-drop-zone" class="auth-drop-zone" tabindex="0">Drop SSH public key file here</div>
      </div>
      <div class="auth-actions">
        <button id="auth-register-btn" class="auth-secondary-btn" type="button">Register and bind passkey</button>
        <span id="auth-register-inline-message" class="auth-register-inline-message" aria-live="polite"></span>
      </div>
    </details>
  </div>
</div>

<script>
(function () {
  var loginBtn = document.getElementById('login-btn');
  var composeLink = document.querySelector('.nav-compose');
  var settingsLink = document.querySelector('.nav-settings');
  var userMenu = document.getElementById('nav-user-menu');
  var menuBtn = document.getElementById('nav-menu-btn');
  var menuPanel = document.getElementById('nav-menu-panel');
  var menuPrimaryLink = document.getElementById('nav-menu-primary-link');
  var menuLogoutBtn = document.getElementById('nav-menu-logout');
  var userName = document.getElementById('nav-user-name');
  var authModal = document.getElementById('auth-modal');
  var authPasskeyBtn = document.getElementById('auth-passkey-btn');
  var authRegisterBtn = document.getElementById('auth-register-btn');
  var authRegisterDetails = document.getElementById('auth-register-details');
  var authDropZone = document.getElementById('auth-drop-zone');
  var authSshKey = document.getElementById('auth-ssh-key');
  var authMessage = document.getElementById('auth-modal-message');
  var authRegisterInlineMessage = document.getElementById('auth-register-inline-message');
  var authPasskeyInlineMessage = document.getElementById('auth-passkey-inline-message');
  var authModalHideTimer = null;
  var noPasskeyMessage = 'No passkey is registered yet. Register below first.';
  var defaultTheme = 'archmage';
  var currentTheme = defaultTheme;
  var loginInFlight = false;
  var isAuthenticated = false;

  function getSessionToken() {
    return localStorage.getItem('session_token') || '';
  }

  function getCsrfToken() {
    return localStorage.getItem('csrf_token') || '';
  }

  function getLastAuthUsername() {
    return localStorage.getItem('last_auth_username') || '';
  }

  function fromBase64(base64) {
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  function fromBase64url(base64url) {
    var normalized = base64url.replace(/-/g, '+').replace(/_/g, '/');
    var padLen = (4 - (normalized.length % 4)) % 4;
    return fromBase64(normalized + '='.repeat(padLen));
  }

  function toBase64(buffer) {
    var bytes = new Uint8Array(buffer);
    var binary = '';
    for (var i = 0; i < bytes.length; i += 1) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  function fetchJson(url, options) {
    return fetch(url, options)
      .then(function (res) {
        return res.text().then(function (text) {
          return { res: res, text: text };
        });
      })
      .then(function (payload) {
        var text = payload.text;
        try {
          return JSON.parse(text);
        } catch (_) {
          var compact = String(text || '').replace(/\s+/g, ' ').trim();
          if (compact) {
            throw new Error('Unexpected server response: ' + compact.slice(0, 140));
          }
          throw new Error('Invalid JSON response');
        }
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

  function setAuthMessage(msg, kind) {
    var text = msg || '';
    var isNoPasskeyNotice = text === noPasskeyMessage;
    if (authPasskeyInlineMessage) {
      if (isNoPasskeyNotice) {
        authPasskeyInlineMessage.textContent = text;
        authPasskeyInlineMessage.classList.add('is-visible');
      } else {
        authPasskeyInlineMessage.textContent = '';
        authPasskeyInlineMessage.classList.remove('is-visible');
      }
    }
    if (!authMessage) {
      return;
    }
    authMessage.textContent = isNoPasskeyNotice ? '' : text;
    authMessage.className = 'auth-modal-message';
    if (kind && !isNoPasskeyNotice) {
      authMessage.classList.add('is-' + kind);
    }
  }

  function setRegisterInlineMessage(msg, kind) {
    if (!authRegisterInlineMessage) {
      return;
    }
    authRegisterInlineMessage.textContent = msg || '';
    authRegisterInlineMessage.className = 'auth-register-inline-message';
    if (kind && msg) {
      authRegisterInlineMessage.classList.add('is-' + kind);
      authRegisterInlineMessage.classList.add('is-visible');
    }
  }

  function setPasskeyButtonEnabled(isEnabled) {
    if (!authPasskeyBtn) {
      return;
    }
    authPasskeyBtn.disabled = !isEnabled;
    authPasskeyBtn.setAttribute('aria-disabled', isEnabled ? 'false' : 'true');
  }

  function closeUserMenu() {
    if (!menuPanel || !menuBtn) {
      return;
    }
    menuPanel.hidden = true;
    menuBtn.setAttribute('aria-expanded', 'false');
  }

  function openUserMenu() {
    if (!menuPanel || !menuBtn) {
      return;
    }
    menuPanel.hidden = false;
    menuBtn.setAttribute('aria-expanded', 'true');
  }

  function configureUserMenu(isAdmin) {
    if (!menuPrimaryLink) {
      return;
    }
    if (isAdmin) {
      menuPrimaryLink.textContent = 'Admin';
      menuPrimaryLink.href = '/pages/admin.html';
    } else {
      menuPrimaryLink.textContent = 'Account';
      menuPrimaryLink.href = '/pages/admin.html#account';
    }
  }

  function setLoggedInUI(isLoggedIn, isAdmin, username, playerName) {
    var displayName = playerName || username || '';
    isAuthenticated = !!isLoggedIn;
    if (isLoggedIn) {
      loginBtn.textContent = 'Logout';
      loginBtn.style.display = 'none';
      if (composeLink) {
        composeLink.style.display = isAdmin ? 'inline-block' : 'none';
      }
      if (settingsLink) {
        settingsLink.style.display = 'inline-flex';
        settingsLink.href = isAdmin ? '/pages/admin.html#settings' : '/pages/admin.html#account';
      }
      if (userMenu) {
        configureUserMenu(isAdmin);
        userMenu.style.display = 'inline-flex';
      }
      if (userName) {
        userName.style.display = 'inline-block';
        userName.textContent = displayName || 'signed-in';
      }
    } else {
      loginBtn.textContent = 'Login';
      loginBtn.style.display = 'inline-block';
      if (composeLink) {
        composeLink.style.display = 'none';
      }
      if (settingsLink) {
        settingsLink.style.display = 'none';
      }
      if (userMenu) {
        userMenu.style.display = 'none';
        closeUserMenu();
      }
      if (userName) {
        userName.style.display = 'none';
        userName.textContent = '';
      }
    }
  }

  function checkAuth() {
    var token = getSessionToken();
    if (!token) {
      setLoggedInUI(false, false, '');
      return;
    }

    fetch('/cgi/ssh-auth-check-session?session_token=' + encodeURIComponent(token))
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (!data || !data.authenticated) {
          localStorage.removeItem('session_token');
          localStorage.removeItem('csrf_token');
          setLoggedInUI(false, false, '');
          return;
        }
        if (data.csrf_token) {
          localStorage.setItem('csrf_token', data.csrf_token);
        }
        setLoggedInUI(true, !!data.is_admin, data.username || '', data.player_name || '');
      })
      .catch(function () {
        setLoggedInUI(false, false, '');
      });
  }

  function logout() {
    var token = getSessionToken();
    if (!token) {
      localStorage.removeItem('session_token');
      localStorage.removeItem('csrf_token');
      setLoggedInUI(false, false, '');
      return;
    }

    var body = new URLSearchParams({
      session_token: token,
      csrf_token: getCsrfToken()
    });

    fetch('/cgi/ssh-auth-logout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    }).finally(function () {
      localStorage.removeItem('session_token');
      localStorage.removeItem('csrf_token');
      isAuthenticated = false;
      setLoggedInUI(false, false, '');
      window.location.reload();
    });
  }

  function showAuthModal() {
    if (!authModal) {
      return;
    }
    if (authModalHideTimer) {
      clearTimeout(authModalHideTimer);
      authModalHideTimer = null;
    }
    authModal.hidden = false;
    requestAnimationFrame(function () {
      authModal.classList.add('is-open');
    });
    document.body.classList.add('auth-modal-open');
    setPasskeyButtonEnabled(true);
    if (authPasskeyBtn) {
      authPasskeyBtn.focus();
    }
  }

  function hideAuthModal() {
    if (!authModal) {
      return;
    }
    authModal.classList.remove('is-open');
    document.body.classList.remove('auth-modal-open');
    setAuthMessage('', '');
    setRegisterInlineMessage('', '');
    if (authModalHideTimer) {
      clearTimeout(authModalHideTimer);
    }
    authModalHideTimer = setTimeout(function () {
      if (!authModal.classList.contains('is-open')) {
        authModal.hidden = true;
      }
      authModalHideTimer = null;
    }, 210);
  }

  function createPasskey(username, fingerprint, challenge) {
    var userId = new TextEncoder().encode(fingerprint);
    function createOptions(preferSecurityKey) {
      var publicKey = {
        challenge: fromBase64(challenge),
        rp: {
          name: 'Wizardry Blog',
          id: window.location.hostname
        },
        user: {
          id: userId,
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
      };

      if (preferSecurityKey) {
        publicKey.authenticatorSelection.authenticatorAttachment = 'cross-platform';
        publicKey.authenticatorSelection.residentKey = 'discouraged';
        publicKey.authenticatorSelection.requireResidentKey = false;
        publicKey.hints = ['security-key'];
      }

      return { publicKey: publicKey };
    }

    return navigator.credentials.create(createOptions(true)).catch(function (err) {
      if (err && (err.name === 'NotSupportedError' || err.name === 'ConstraintError')) {
        return navigator.credentials.create(createOptions(false));
      }
      throw err;
    });
  }

  function loginWithPasskey(fallbackToModal) {
    if (!window.PublicKeyCredential) {
      if (fallbackToModal) {
        showAuthModal();
      }
      setPasskeyButtonEnabled(false);
      setAuthMessage('WebAuthn passkeys are not supported in this browser.', 'error');
      return Promise.reject(new Error('webauthn_unsupported'));
    }

    return postForm('/cgi/ssh-auth-login-begin', {})
      .then(function (begin) {
        if (!begin || !begin.success) {
          if (fallbackToModal) {
            showAuthModal();
            if (authRegisterDetails && (begin.code === 'user_not_found' || begin.code === 'no_credentials')) {
              authRegisterDetails.open = true;
              setPasskeyButtonEnabled(false);
              setAuthMessage(noPasskeyMessage, 'warn');
            } else {
              setPasskeyButtonEnabled(true);
              setAuthMessage((begin && begin.error) || 'Unable to start login challenge.', 'error');
            }
          }
          throw new Error((begin && begin.error) || 'Unable to start login');
        }

        var allowCredentials = (begin.allow_credentials || []).map(function (id) {
          return {
            id: fromBase64url(id),
            type: 'public-key'
          };
        });

        return navigator.credentials.get({
          publicKey: {
            challenge: fromBase64(begin.challenge),
            allowCredentials: allowCredentials,
            userVerification: 'preferred',
            timeout: 60000
          }
        }).then(function (assertion) {
          return { assertion: assertion, requestId: begin.request_id || '' };
        });
      })
      .then(function (loginPayload) {
        var assertion = loginPayload.assertion;
        return postForm('/cgi/ssh-auth-login-finish', {
          request_id: loginPayload.requestId,
          credential_id: assertion.id,
          authenticator_data: toBase64(assertion.response.authenticatorData),
          client_data_json: toBase64(assertion.response.clientDataJSON),
          signature: toBase64(assertion.response.signature)
        });
      })
      .then(function (finish) {
        if (!finish || !finish.success) {
          throw new Error((finish && finish.error) || 'Login failed');
        }
        localStorage.setItem('session_token', finish.session_token || '');
        localStorage.setItem('csrf_token', finish.csrf_token || '');
        localStorage.setItem('last_auth_username', finish.username || '');
        hideAuthModal();
        window.location.reload();
      });
  }

  function normalizeSshPublicKeyInput(raw) {
    return String(raw || '').replace(/\r/g, ' ').replace(/\n+/g, ' ').replace(/\t+/g, ' ').replace(/\s+/g, ' ').trim();
  }

  function registerAndBind(sshKey) {
    var normalizedKey = normalizeSshPublicKeyInput(sshKey);
    if (authSshKey) {
      authSshKey.value = normalizedKey;
    }
    if (!normalizedKey) {
      setRegisterInlineMessage('Paste or drop an SSH public key first.', 'warn');
      return Promise.resolve();
    }

    if (droppedKeyLooksPrivate('', normalizedKey)) {
      setRegisterInlineMessage('That appears to be a private key. Do not upload it; use your .pub key.', 'error');
      return Promise.resolve();
    }

    if (!droppedKeyLooksPublic(normalizedKey)) {
      setRegisterInlineMessage('That does not look like a valid SSH public key. Please use your .pub key.', 'warn');
      return Promise.resolve();
    }

    if (!window.PublicKeyCredential) {
      setRegisterInlineMessage('WebAuthn passkeys are not supported in this browser.', 'error');
      return Promise.resolve();
    }

    setRegisterInlineMessage('Registering SSH key...', 'warn');
    var username = getLastAuthUsername() || '';
    return postForm('/cgi/ssh-auth-register', {
      username: username,
      ssh_public_key: normalizedKey
    }).then(function (data) {
      if (!data || !data.success) {
        throw new Error((data && data.error) || 'Registration failed');
      }
      setRegisterInlineMessage('Creating passkey credential...', 'warn');
      return createPasskey(data.username, data.fingerprint, data.challenge).then(function (credential) {
        var publicKey = credential.response.getPublicKey ? credential.response.getPublicKey() : null;
        if (!publicKey) {
          throw new Error('Passkey registration requires a newer browser.');
        }
        return postForm('/cgi/ssh-auth-bind-webauthn', {
          username: data.username,
          fingerprint: data.fingerprint,
          credential_id: credential.id,
          public_key: toBase64(publicKey),
          client_data_json: toBase64(credential.response.clientDataJSON)
        });
      });
    }).then(function (bindData) {
      if (!bindData || !bindData.success) {
        throw new Error((bindData && bindData.error) || 'Passkey binding failed');
      }
      localStorage.setItem('last_auth_username', bindData.username || username);
      setPasskeyButtonEnabled(true);
      setRegisterInlineMessage('Registered as ' + (bindData.username || username) + '. Click "Use passkey" to sign in.', 'ok');
    }).catch(function (err) {
      setRegisterInlineMessage(err.message || 'Registration failed', 'error');
    });
  }

  function droppedKeyLooksPrivate(fileName, keyText) {
    var name = String(fileName || '').toLowerCase();
    var text = String(keyText || '').trim();
    var upper = text.toUpperCase();
    var privateNameHints = [
      'id_rsa', 'id_ed25519', 'id_ecdsa', 'id_dsa', 'identity'
    ];
    var privateMarkers = [
      '-----BEGIN OPENSSH PRIVATE KEY-----',
      '-----BEGIN RSA PRIVATE KEY-----',
      '-----BEGIN EC PRIVATE KEY-----',
      '-----BEGIN DSA PRIVATE KEY-----',
      '-----BEGIN PRIVATE KEY-----',
      'PUTTY-USER-KEY-FILE-'
    ];

    if (name && !name.endsWith('.pub')) {
      for (var i = 0; i < privateNameHints.length; i += 1) {
        if (name === privateNameHints[i] || name.endsWith('/' + privateNameHints[i])) {
          return true;
        }
      }
    }

    for (var j = 0; j < privateMarkers.length; j += 1) {
      if (upper.indexOf(privateMarkers[j]) !== -1) {
        return true;
      }
    }

    return false;
  }

  function droppedKeyLooksPublic(keyText) {
    var text = String(keyText || '').trim();
    return /^(ssh-(ed25519|rsa|dss)|ecdsa-sha2-|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-)/.test(text);
  }

  function bindLoginButton() {
    if (!loginBtn) {
      return;
    }

    function setLoginBusy(isBusy) {
      if (isBusy) {
        loginBtn.disabled = true;
      } else {
        loginBtn.disabled = false;
      }
    }

    loginBtn.addEventListener('click', function () {
      if (loginInFlight) {
        return;
      }
      if (isAuthenticated) {
        logout();
        return;
      }

      localStorage.removeItem('session_token');
      localStorage.removeItem('csrf_token');
      loginInFlight = true;
      setLoginBusy(true);
      loginWithPasskey(true)
        .catch(function () {
          // Error is surfaced in modal when needed.
        })
        .finally(function () {
          loginInFlight = false;
          setLoginBusy(false);
        });
    });

    if (menuBtn && menuPanel) {
      menuBtn.addEventListener('click', function (event) {
        event.stopPropagation();
        if (menuPanel.hidden) {
          openUserMenu();
        } else {
          closeUserMenu();
        }
      });
      document.addEventListener('click', function (event) {
        if (!userMenu || !menuPanel || !menuBtn) {
          return;
        }
        if (!userMenu.contains(event.target)) {
          closeUserMenu();
        }
      });
    }

    if (menuLogoutBtn) {
      menuLogoutBtn.addEventListener('click', function () {
        closeUserMenu();
        logout();
      });
    }

    if (authModal) {
      authModal.addEventListener('click', function (event) {
        if (event.target && event.target.hasAttribute('data-close-auth-modal')) {
          hideAuthModal();
        }
      });
    }

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        closeUserMenu();
      }
      if (event.key === 'Escape' && authModal && !authModal.hidden) {
        hideAuthModal();
      }
    });

    if (authPasskeyBtn) {
      authPasskeyBtn.addEventListener('click', function () {
        setAuthMessage('Requesting passkey...', 'warn');
        loginWithPasskey(true).catch(function () {
          // handled through modal message
        });
      });
    }

    if (authRegisterBtn) {
      authRegisterBtn.addEventListener('click', function () {
        setRegisterInlineMessage('', '');
        var sshKey = authSshKey ? authSshKey.value.trim() : '';
        registerAndBind(sshKey);
      });
    }

    if (authDropZone && authSshKey) {
      ['dragenter', 'dragover'].forEach(function (ev) {
        authDropZone.addEventListener(ev, function (event) {
          event.preventDefault();
          authDropZone.classList.add('is-over');
        });
      });
      ['dragleave', 'drop'].forEach(function (ev) {
        authDropZone.addEventListener(ev, function (event) {
          event.preventDefault();
          authDropZone.classList.remove('is-over');
        });
      });
      authDropZone.addEventListener('drop', function (event) {
        var file = event.dataTransfer && event.dataTransfer.files ? event.dataTransfer.files[0] : null;
        if (!file) {
          return;
        }
        var reader = new FileReader();
        reader.onload = function () {
          var content = String(reader.result || '').trim();
          if (droppedKeyLooksPrivate(file.name, content)) {
            authSshKey.value = '';
            setAuthMessage(
              'You just dropped a private key file. This was checked locally in your browser and was not uploaded anywhere. Do not drop your private key here; drop your .pub file instead.',
              'error'
            );
            return;
          }
          if (!droppedKeyLooksPublic(content)) {
            authSshKey.value = '';
            setAuthMessage('That file does not look like an SSH public key. Please drop a .pub file.', 'warn');
            return;
          }
          authSshKey.value = content;
          setRegisterInlineMessage('', '');
          setAuthMessage('SSH public key loaded locally. Nothing uploaded yet.', 'ok');
        };
        reader.readAsText(file);
      });
    }
  }

  function highlightCurrentPage() {
    var currentPath = window.location.pathname;
    var navLinks = document.querySelectorAll('.nav-center a[data-page]');
    navLinks.forEach(function (link) {
      var href = link.getAttribute('href');
      if (currentPath.indexOf(href) !== -1 ||
          (currentPath === '/' && href.indexOf('index.html') !== -1) ||
          (currentPath.endsWith('/') && href.indexOf('index.html') !== -1)) {
        link.classList.add('active');
      }
    });
  }

  function updateThemeSelect() {
    var themeSelect = document.getElementById('theme-select');
    if (themeSelect) {
      themeSelect.value = currentTheme;
    }
  }

  function updateThemeStylesheet(theme) {
    var themeLink = document.getElementById('theme-stylesheet');
    if (themeLink) {
      themeLink.href = '/static/themes/' + theme + '.css';
    }
  }

  function loadTheme() {
    fetch('/cgi/blog-get-config')
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data && data.theme) {
          currentTheme = data.theme;
          updateThemeStylesheet(currentTheme);
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
      // ignore and keep local style
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
      currentTheme = nextTheme;
      updateThemeStylesheet(nextTheme);
      saveTheme(nextTheme);
      preserveFocus();
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    highlightCurrentPage();
    bindLoginButton();
    bindThemeSelect();
    loadTheme();
    checkAuth();
  });
})();
</script>
