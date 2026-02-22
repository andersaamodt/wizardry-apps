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
    <p class="auth-modal-help">Use your Nostr key, or use passkey if you already bound one to your account. <a class="auth-inline-link" href="/pages/login-security.html">Learn more</a>.</p>

    <div class="auth-actions">
      <button id="auth-nostr-btn" class="auth-primary-btn" type="button">Use Nostr key</button>
      <button id="auth-passkey-btn" class="auth-secondary-btn" type="button">Use passkey (optional)</button>
      <span id="auth-passkey-inline-message" class="auth-passkey-inline-message" aria-live="polite"></span>
    </div>

    <div id="auth-modal-message" class="auth-modal-message" aria-live="polite"></div>

    <details id="auth-register-details" class="auth-register-details">
      <summary>First time here?</summary>
      <p class="auth-modal-help">Click below and sign the login challenge with your Nostr key. This creates your account automatically.</p>
      <div class="auth-actions">
        <button id="auth-register-btn" class="auth-secondary-btn" type="button">Create account with Nostr</button>
        <span id="auth-register-inline-message" class="auth-register-inline-message" aria-live="polite"></span>
      </div>
    </details>
  </div>
</div>

<script>
(function () {
  var loginBtn = document.getElementById('login-btn');
  var composeLink = document.querySelector('.nav-compose');
  var userMenu = document.getElementById('nav-user-menu');
  var menuBtn = document.getElementById('nav-menu-btn');
  var menuPanel = document.getElementById('nav-menu-panel');
  var menuPrimaryLink = document.getElementById('nav-menu-primary-link');
  var menuLogoutBtn = document.getElementById('nav-menu-logout');
  var userName = document.getElementById('nav-user-name');
  var authModal = document.getElementById('auth-modal');
  var authNostrBtn = document.getElementById('auth-nostr-btn');
  var authPasskeyBtn = document.getElementById('auth-passkey-btn');
  var authRegisterBtn = document.getElementById('auth-register-btn');
  var authRegisterDetails = document.getElementById('auth-register-details');
  var authMessage = document.getElementById('auth-modal-message');
  var authRegisterInlineMessage = document.getElementById('auth-register-inline-message');
  var authPasskeyInlineMessage = document.getElementById('auth-passkey-inline-message');
  var authModalHideTimer = null;
  var noPasskeyMessage = 'No passkey is registered yet. Use your Nostr key and then bind a passkey in Account.';
  var defaultTheme = 'archmage';
  var currentTheme = defaultTheme;
  var isAuthenticated = false;

  function getSessionToken() {
    return localStorage.getItem('session_token') || '';
  }

  function getCsrfToken() {
    return localStorage.getItem('csrf_token') || '';
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

  function setLoggedInUI(isLoggedIn, isAdmin, username) {
    var displayName = username || '';
    isAuthenticated = !!isLoggedIn;
    if (isLoggedIn) {
      loginBtn.textContent = 'Login';
      loginBtn.style.display = 'none';
      if (composeLink) {
        composeLink.style.display = isAdmin ? 'inline-block' : 'none';
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
        setLoggedInUI(true, !!data.is_admin, data.username || '');
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
    if (authNostrBtn) {
      authNostrBtn.focus();
    } else if (authPasskeyBtn) {
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

  function browserNostr() {
    var api = window.nostr || window.nosterAPI || null;
    if (!api) {
      throw new Error('No browser Nostr signer detected.');
    }
    if (typeof api.getPublicKey !== 'function' || typeof api.signEvent !== 'function') {
      throw new Error('Browser signer is missing getPublicKey/signEvent support.');
    }
    return api;
  }

  function loginWithNostr(showModalOnError) {
    var signer;
    try {
      signer = browserNostr();
    } catch (err) {
      if (showModalOnError) {
        showAuthModal();
        setAuthMessage(err.message, 'warn');
      }
      return Promise.reject(err);
    }

    setAuthMessage('Requesting Nostr pubkey...', 'warn');
    return Promise.resolve(signer.getPublicKey())
      .then(function (pubkey) {
        if (!pubkey) {
          throw new Error('No pubkey returned by signer.');
        }
        return postForm('/cgi/nostr-auth-login-begin', {
          pubkey: pubkey
        }).then(function (begin) {
          return {
            begin: begin,
            pubkey: pubkey
          };
        });
      })
      .then(function (payload) {
        var begin = payload.begin || {};
        if (!begin.success) {
          throw new Error(begin.error || 'Unable to start Nostr login.');
        }
        var eventDraft = {
          kind: 22242,
          created_at: Math.floor(Date.now() / 1000),
          tags: [
            ['challenge', begin.challenge || ''],
            ['origin', window.location.host]
          ],
          content: 'wizardry login challenge'
        };
        setAuthMessage('Sign the Nostr login challenge...', 'warn');
        return Promise.resolve(signer.signEvent(eventDraft)).then(function (signedEvent) {
          return {
            requestId: begin.request_id || '',
            signedEvent: signedEvent
          };
        });
      })
      .then(function (payload) {
        return postForm('/cgi/nostr-auth-login-finish', {
          request_id: payload.requestId,
          event_json: JSON.stringify(payload.signedEvent || {})
        });
      })
      .then(function (finish) {
        if (!finish || !finish.success) {
          throw new Error((finish && finish.error) || 'Nostr login failed.');
        }
        localStorage.setItem('session_token', finish.session_token || '');
        localStorage.setItem('csrf_token', finish.csrf_token || '');
        localStorage.setItem('last_auth_username', finish.username || '');
        hideAuthModal();
        window.location.reload();
      })
      .catch(function (err) {
        if (showModalOnError) {
          showAuthModal();
        }
        setAuthMessage(err.message || 'Nostr login failed.', 'error');
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

  function registerWithNostr() {
    setRegisterInlineMessage('Signing Nostr login challenge...', 'warn');
    return loginWithNostr(true).then(function () {
      setRegisterInlineMessage('Signed in with Nostr.', 'ok');
    }).catch(function (err) {
      setRegisterInlineMessage(err.message || 'Nostr account creation failed.', 'error');
    });
  }

  function bindLoginButton() {
    if (!loginBtn) {
      return;
    }

    loginBtn.addEventListener('click', function () {
      showAuthModal();
    });

    if (authModal) {
      authModal.addEventListener('click', function (event) {
        if (event.target && event.target.hasAttribute('data-close-auth-modal')) {
          hideAuthModal();
        }
      });
    }

    if (menuBtn && menuPanel) {
      menuBtn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (menuPanel.hidden) {
          openUserMenu();
        } else {
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

    document.addEventListener('click', function (event) {
      if (!userMenu || userMenu.style.display === 'none') {
        return;
      }
      if (!userMenu.contains(event.target)) {
        closeUserMenu();
      }
    });

    document.addEventListener('keydown', function (event) {
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

    if (authNostrBtn) {
      authNostrBtn.addEventListener('click', function () {
        setAuthMessage('Signing in with Nostr...', 'warn');
        loginWithNostr(true).catch(function () {
          // handled through modal message
        });
      });
    }

    if (authRegisterBtn) {
      authRegisterBtn.addEventListener('click', function () {
        setRegisterInlineMessage('', '');
        registerWithNostr();
      });
    }
  }

  function highlightCurrentPage() {
    var currentPath = window.location.pathname;
    var currentHash = window.location.hash || '';
    var navLinks = document.querySelectorAll('.nav-center a[data-page]');
    navLinks.forEach(function (link) {
      var href = link.getAttribute('href');
      if (currentPath.indexOf(href) !== -1 ||
          (currentPath === '/' && href.indexOf('index.html') !== -1) ||
          (currentPath.endsWith('/') && href.indexOf('index.html') !== -1)) {
        link.classList.add('active');
      }
    });

    if (composeLink) {
      var onCompose = currentPath.indexOf('/pages/admin.html') !== -1 && currentHash === '#compose';
      composeLink.classList.toggle('active', onCompose);
      composeLink.setAttribute('aria-disabled', onCompose ? 'true' : 'false');
      if (onCompose) {
        composeLink.setAttribute('tabindex', '-1');
      } else {
        composeLink.removeAttribute('tabindex');
      }
    }
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
    window.addEventListener('hashchange', highlightCurrentPage);
    bindLoginButton();
    bindThemeSelect();
    loadTheme();
    checkAuth();
  });
})();
</script>
