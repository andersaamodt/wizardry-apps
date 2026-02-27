(function () {
  'use strict';

  var AUTH_KIND = 22242;
  var NIP46_KIND = 24133;
  var NIP46_RELAYS = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.primal.net'
  ];

  var IDB_DB_NAME = 'wizardry-blog-auth';
  var IDB_STORE_NAME = 'kv';
  var KEY_DEVICE_SESSION = 'nostr_device_session_v1';
  var KEY_NIP46_PAIR = 'nostr_nip46_pair_v1';
  var NAV_TOAST_KEY = 'wizardry_blog_nav_toast_v1';
  var COMPOSE_ICON_KEY = 'wizardry_blog_compose_icon_idx_v1';

  var state = {
    currentTheme: 'archmage',
    isAuthenticated: false,
    manualChallenge: null,
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
    loginSplit: document.getElementById('nav-login-split'),
    loginMoreBtn: document.getElementById('login-more-btn'),
    loginMenu: document.getElementById('nav-login-menu'),
    loginMenuRegister: document.getElementById('login-menu-register'),
    loginMenuPhone: document.getElementById('login-menu-phone'),
    loginMenuManual: document.getElementById('login-menu-manual'),
    loginMenuLearn: document.getElementById('login-menu-learn'),
    navToastHost: document.getElementById('nav-top-toast-host'),
    composeTools: document.getElementById('nav-compose-tools'),
    composeLink: document.querySelector('.nav-compose'),
    composeIconCycleBtn: document.getElementById('compose-icon-cycle-btn'),
    userMenu: document.getElementById('nav-user-menu'),
    menuBtn: document.getElementById('nav-menu-btn'),
    menuPanel: document.getElementById('nav-menu-panel'),
    menuPrimaryLink: document.getElementById('nav-menu-primary-link'),
    menuLogoutBtn: document.getElementById('nav-menu-logout'),
    menuLogoutEverywhereBtn: document.getElementById('nav-menu-logout-everywhere'),
    userName: document.getElementById('nav-user-name'),

    authModal: document.getElementById('auth-modal'),
    authInfoModal: document.getElementById('nostr-info-modal'),
    authModalTitle: document.getElementById('auth-modal-title'),
    authMessage: document.getElementById('auth-modal-message'),
    authRegisterBtn: document.getElementById('auth-register-btn'),
    authRegisterUsername: document.getElementById('auth-register-username'),
    authPhoneConnectBtn: document.getElementById('auth-phone-connect-btn'),
    authPhoneBtn: document.getElementById('auth-phone-btn'),
    authTabRegister: document.getElementById('auth-tab-register'),
    authTabPhone: document.getElementById('auth-tab-phone'),
    authTabManual: document.getElementById('auth-tab-manual'),

    authRegisterPanel: document.getElementById('auth-register-panel'),
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
    authManualEvent: document.getElementById('auth-manual-event'),
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

  function composeIconSvgPaths() {
    return [
      { id: 'mdi:file-document-edit', viewBox: '0 0 24 24', body: "<path fill=\"currentColor\" d=\"M6 2c-1.11 0-2 .89-2 2v16a2 2 0 0 0 2 2h4v-1.91L12.09 18H6v-2h8.09l2-2H6v-2h12.09L20 10.09V8l-6-6zm7 1.5L18.5 9H13zm7.15 9.5a.55.55 0 0 0-.4.16l-1.02 1.02l2.09 2.08l1.02-1.01c.21-.22.21-.58 0-.79l-1.3-1.3a.54.54 0 0 0-.39-.16m-2.01 1.77L12 20.92V23h2.08l6.15-6.15z\"/>" },
      { id: 'game-icons:quill', viewBox: '0 0 512 512', body: "<path fill=\"currentColor\" d=\"M492.47 21.938c-82.74-.256-167.442 12.5-242.814 45.093c5.205 13.166 9.578 28.48 13.188 45.532C242.55 97.27 217.167 92.385 194.72 95.5c-46.22 28.432-87.13 66.305-119.44 115.594c25.193 7.756 51.57 22.81 72.845 43.844c-31.87-7.045-68.907-5.895-99.188 3c-13.743 28.688-25.008 60.48-33.343 95.687c128.71-30.668 130.522 3.514 50.75 140.438c16.877 12.614 42.182 13.77 61.906-1.563C134 267.936 231.43 326.246 254.188 354.562c14.288-40.59 34.77-82.54 62.906-126.468c-17.29-14.667-39.21-24.838-63.813-32.375c25.364-5.256 50.91-10.928 74.126-11.22c6.482-.082 12.78.272 18.844 1.156c17.57-24.007 37.408-48.612 59.75-73.97c-12.538-6.31-25.476-11.454-38.125-14.967c17.132-5.76 35.274-8.34 52.844-8.157c2.01.02 4.004.095 6 .187c20.07-21.708 41.927-43.976 65.75-66.813zM426.72 47.28c-130.93 65.394-226.626 162.926-281.784 286.25C172.34 184.41 287.048 84.57 426.72 47.28\"/>" },
      { id: 'icomoon-free:quill', viewBox: '0 0 24 24', body: "<path fill=\"currentColor\" d=\"M0 16C2 10 7.234 0 16 0c-4.109 3.297-6 11-9 11H4l-3 5z\"/>" },
      { id: 'mingcute:quill-pen-line', viewBox: '0 0 24 24', body: "<g fill=\"none\" fill-rule=\"evenodd\"><path d=\"m12.593 23.258l-.011.002l-.071.035l-.02.004l-.014-.004l-.071-.035q-.016-.005-.024.005l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427q-.004-.016-.017-.018m.265-.113l-.013.002l-.185.093l-.01.01l-.003.011l.018.43l.005.012l.008.007l.201.093q.019.005.029-.008l.004-.014l-.034-.614q-.005-.018-.02-.022m-.715.002a.02.02 0 0 0-.027.006l-.006.014l-.034.614q.001.018.017.024l.015-.002l.201-.093l.01-.008l.004-.011l.017-.43l-.003-.012l-.01-.01z\"/><path fill=\"currentColor\" d=\"M5.708 13.35c.625-1.92 1.75-4.379 3.757-6.386c3.934-3.934 9.652-4.515 9.797-4.53a1 1 0 0 1 .944.454c.208.313 1.38 2.283-.191 4.663a2.6 2.6 0 0 1-.276.344a1 1 0 0 1-.03.37c-.19.689-.434 1.412-.75 2.135c-.551 1.263-1.328 2.54-2.423 3.636c-2.05 2.05-4.742 2.991-6.844 3.43a19.4 19.4 0 0 1-2.883.378C6.778 18.09 6.5 20.57 6.5 21a1 1 0 1 1-2 0c0-.571.116-1.67.221-2.56c.205-1.732.446-3.427.987-5.09m12.637-6.9c.527-.8.52-1.48.415-1.92c-1.527.275-5.219 1.186-7.881 3.849c-1.704 1.703-2.7 3.84-3.269 5.59a18 18 0 0 0-.494 1.85a17 17 0 0 0 2.167-.31c1.92-.402 4.179-1.228 5.838-2.888c.85-.85 1.484-1.857 1.954-2.905c-.976.52-2.018.986-2.759 1.233a1 1 0 1 1-.632-1.898c.674-.225 1.758-.713 2.754-1.265c.494-.274.946-.553 1.301-.808c.384-.276.56-.46.606-.529Z\"/></g>" },
      { id: 'ri:quill-pen-line', viewBox: '0 0 24 24', body: "<path fill=\"currentColor\" d=\"M6.94 14.033a30 30 0 0 0-.606 1.783c.96-.697 2.101-1.14 3.418-1.304c2.513-.314 4.746-1.973 5.876-4.058l-1.456-1.455l1.413-1.415l1-1.002c.43-.429.915-1.224 1.428-2.367c-5.593.867-9.018 4.291-11.074 9.818M17 8.997l1 1c-1 3-4 6-8 6.5q-4.003.5-5.002 5.5H3c1-6 3-20 18-20q-1.5 4.496-2.997 5.997z\"/>" },
      { id: 'tdesign:pen-quill', viewBox: '0 0 24 24', body: "<g fill=\"none\"><path d=\"M15.5 2L17 7l5 1.5l-9.5 9.5l-6-.5l-.5-6z\"/><path stroke=\"currentColor\" stroke-linecap=\"square\" stroke-width=\"2\" d=\"m6.5 17.5l6 .5L22 8.5L17 7M6.5 17.5l-.5-6L15.5 2L17 7M6.5 17.5L3 21m3.5-3.5L17 7\"/></g>" },
      { id: 'hugeicons:quill-write-01', viewBox: '0 0 24 24', body: "<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"><path d=\"M5.076 17C4.089 4.545 12.912 1.012 19.973 2.224c.286 4.128-1.734 5.673-5.58 6.387c.742.776 2.055 1.753 1.913 2.974c-.1.868-.69 1.295-1.87 2.147C11.85 15.6 8.854 16.78 5.076 17\"/><path d=\"M4 22c0-6.5 3.848-9.818 6.5-12\"/></g>" },
      { id: 'streamline-freehand:notes-quill', viewBox: '0 0 24 24', body: "<g fill=\"currentColor\" fill-rule=\"evenodd\" clip-rule=\"evenodd\"><path d=\"M22.471 11.098c-.24-.38-.72-.39-1.17-.33a9.85 9.85 0 0 0-5.005 2.382a6.74 6.74 0 0 0-2.913 5.845a5.7 5.7 0 0 0 .39 2.192a21 21 0 0 0-1.771 2.512c0 .23.29.42.62.21a45 45 0 0 0 3.303-3.843a43 43 0 0 0 2.433-4.074a.3.3 0 0 0-.5-.32c-3.874 5.114-3.324 4.404-3.754 5.004a4 4 0 0 1 0-.5a6 6 0 0 1 1.611-5.295c2.002-2.002 4.915-3.093 5.735-3.003c0 3.153 0 2.853-.07 3.353l-1.541 1.001c-.18.1-.63.22-.76.6c-.221.661.59.722 1.12 1.252c-1.27.74-1.431.5-1.821.78a.58.58 0 0 0-.23.791q.474.459 1 .861c-2.682 2.252-3.433 1.472-3.883 1.772a.35.35 0 0 0 .17.64c2.002.32 4.604-2.001 4.694-2.232c.16-.42-.33-.75-.79-1.17a18 18 0 0 0 1.941-.892a.55.55 0 0 0 .12-.91l-.82-.731c1.13-.62 1.701-.92 1.901-1.471c.12-.3.31-3.934-.01-4.424\"/><path d=\"M11.061 18.995c-7.467.11-4.294.12-7.557-.27c-.49-.05-.71-.42-.85-.851c-.26-.851-.19-1.001-.07-9.339a19.7 19.7 0 0 1 .21-5.004c.25-1.001 0-1.381 1.42-1.361c0 .34-.13 1.631-.1 1.851c.09.761.841.65 1.132.73c1.521.361 2.092-.78 2.002-2.371c.476.143.984.143 1.46 0c0 .11-.1 1.381-.07 1.561c.09.76.832.64 1.132.72c1.501.361 2.072-.74 2.002-2.301c.68.2.73.17 1.731-.06c0 .1-.08 1.381-.06 1.501a.69.69 0 0 0 .52.63c1.602.431 2.543 0 2.593-1.73q.504.012 1 .09c.241 0 .441.08.461.28l.37 6.936a.301.301 0 0 0 .527.246a.3.3 0 0 0 .064-.246c.44-2.352.44-4.765 0-7.117c-.24-1-1.321-1-2.382-.91a5.5 5.5 0 0 0-.54-1.612a1.43 1.43 0 0 0-2.052.14a2.9 2.9 0 0 0-.4 1.001a3.3 3.3 0 0 0-2.002.15a3.2 3.2 0 0 0-.32-1.16a1.44 1.44 0 0 0-2.103.15a2.8 2.8 0 0 0-.35.85a3.3 3.3 0 0 0-1.722.12a3.2 3.2 0 0 0-.32-1.07a1.15 1.15 0 0 0-1.19-.371c-.802.12-1.102.67-1.282 1.451a2.33 2.33 0 0 0-1.562.25c-.51.34-.54 1.061-.68 1.522a20.4 20.4 0 0 0-.51 5.164c-.19 4.695-.14 3.193-.21 6.696c0 1.902 0 4.334 2.061 4.484c3.343.25.12.37 7.657-.05a.35.35 0 1 0-.01-.7m3.383-17.256c.08-1.491 1-1.12 1.061-.83c.117.737.1 1.49-.05 2.221c-.16.551-.44.42-1.001.41q.04-.9-.01-1.8M9.84 1.03c.2-.4.78-.13.86-.16a6.2 6.2 0 0 1 0 2.402c-.09.3-.27.51-.65.4h-.36c0-.12.06-.25.06-.3a5.6 5.6 0 0 1 .09-2.342m-4.494.05c.2-.4.78-.13.86-.16c.151.79.151 1.601 0 2.392c-.09.3-.27.52-.65.4h-.36c0-.12.06-.25.06-.3a5.6 5.6 0 0 1 .09-2.332\"/><path d=\"M15.135 8.245a.38.38 0 0 0 .06-.54c-.19-.31-5.675-.721-8.338-.611c-3.003.2-2.572.7-2.092.81c1.041.321 10.35.361 10.37.341m-3.133 3.103c-.31-.08-2.743-.21-3.203-.21s-3.843.1-4.004.48a.28.28 0 0 0 .06.24c.607.22 1.247.335 1.892.34c1.752.123 3.511.08 5.255-.13c.41 0 .54-.59 0-.72m-6.926 4.644a11.5 11.5 0 0 0 4.584.08a.34.34 0 0 0 0-.48a8.6 8.6 0 0 0-2.903-.42c-2.292.14-2.762.64-1.681.82\"/></g>" },
      { id: 'streamline-pixel:content-files-quill-ink', viewBox: '0 0 32 32', body: "<path fill=\"currentColor\" d=\"M27.435 3.05h1.52V1.52h1.52V0h-9.14v1.52h6.1zm-1.53 0h1.53v1.52h-1.53Zm-1.52 1.52h1.52V6.1h-1.52Zm-1.52 1.53h1.52v1.52h-1.52Zm-1.53 1.52h1.53v3.05h-1.53Zm0-4.57h1.53v1.52h-1.53Zm-1.52 7.62h1.52v1.52h-1.52Zm0-6.1h1.52V6.1h-1.52Z\"/><path fill=\"currentColor\" d=\"M18.285 1.52h3.05v1.53h-3.05Zm0 4.58h1.53v1.52h-1.53Zm-1.52 6.09h3.05v1.53h-3.05Zm0-4.57h1.52v1.52h-1.52Zm0-4.57h1.52v1.52h-1.52ZM3.055 32h13.71v-1.52h1.52v-6.1h-1.52v1.53h-7.62v-1.53H6.1v-1.52H3.055v1.52h-1.53v6.1h1.53Zm1.52-6.09H6.1v3.04h3.05v1.53H6.1v-1.53H4.575Zm10.67-16.77h1.52v1.53h-1.52Zm0-4.57h1.52V6.1h-1.52Z\"/><path fill=\"currentColor\" d=\"M13.715 22.86h3.05v1.52h-3.05Zm3.05-9.14h-3.05v-1.53h-1.52v-1.52h-1.52v4.57h6.09z\"/><path fill=\"currentColor\" d=\"M13.715 10.67h1.53v1.52h-1.53Zm0-4.57h1.53v1.52h-1.53Zm-1.52 1.52h1.52v3.05h-1.52Zm-4.57 12.19h4.57v3.05h1.52v-3.05h1.53v-1.52h-4.57v-3.05h-1.53v3.05h-4.57v1.52h1.52v3.05h1.53z\"/>" },
      { id: 'lucide:file-pen', viewBox: '0 0 24 24', body: "<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M12.659 22H18a2 2 0 0 0 2-2V8a2.4 2.4 0 0 0-.706-1.706l-3.588-3.588A2.4 2.4 0 0 0 14 2H6a2 2 0 0 0-2 2v9.34\"/><path d=\"M14 2v5a1 1 0 0 0 1 1h5m-9.622 4.622a1 1 0 0 1 3 3.003L8.36 20.637a2 2 0 0 1-.854.506l-2.867.837a.5.5 0 0 1-.62-.62l.836-2.869a2 2 0 0 1 .506-.853z\"/></g>" },
      { id: 'tabler:file-pencil', viewBox: '0 0 24 24', body: "<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M14 3v4a1 1 0 0 0 1 1h4\"/><path d=\"M17 21H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7l5 5v11a2 2 0 0 1-2 2\"/><path d=\"m10 18l5-5a1.414 1.414 0 0 0-2-2l-5 5v2z\"/></g>" },
      { id: 'lineicons:file-pencil', viewBox: '0 0 24 24', body: "<g fill=\"currentColor\" fill-rule=\"evenodd\" clip-rule=\"evenodd\"><path d=\"M9.75 20.5V22h-3a2.25 2.25 0 0 1-2.25-2.25V9.621c0-.596.237-1.169.659-1.59l5.367-5.371A2.25 2.25 0 0 1 12.118 2h5.132a2.25 2.25 0 0 1 2.25 2.25v5.5H18v-5.5a.75.75 0 0 0-.75-.75h-5.002l.003 3.998A2.25 2.25 0 0 1 10 9.75H6v10c0 .414.336.75.75.75zm.999-15.941L7.059 8.25h2.942a.75.75 0 0 0 .75-.75z\"/><path d=\"M20.299 12.339a1.75 1.75 0 0 0-2.475 0l-5.158 5.158a2.25 2.25 0 0 0-.646 1.35l-.19 1.746a.75.75 0 0 0 .827.826l1.747-.189a2.25 2.25 0 0 0 1.349-.646l5.158-5.158a1.75 1.75 0 0 0 0-2.475zm-2.277 1.923l.966.966l-4.296 4.296a.75.75 0 0 1-.45.215l-.82.089l.089-.82a.75.75 0 0 1 .215-.45z\"/></g>" },
      { id: 'prime:file-edit', viewBox: '0 0 24 24', body: "<path fill=\"currentColor\" d=\"M8 18.75H6.5c-.69 0-1.25-.56-1.25-1.25v-12c0-.69.56-1.25 1.25-1.25h3.75V9c0 .41.34.75.75.75h4.8c.1.29.37.5.7.5c.41 0 .75-.34.75-.75V9a.78.78 0 0 0-.22-.53l-5.5-5.5a.78.78 0 0 0-.53-.22H6.5c-1.52 0-2.75 1.23-2.75 2.75v12c0 1.52 1.23 2.75 2.75 2.75H8c.41 0 .75-.34.75-.75s-.34-.75-.75-.75m3.75-13.44l2.94 2.94h-2.94zm7.86 6.06c-.38-.38-.94-.61-1.52-.62c-.6-.03-1.17.2-1.55.59l-6.39 6.4c-.13.13-.2.29-.22.47l-.18 2.23c-.02.22.06.44.22.59c.14.14.33.22.53.22h.07l2.25-.21a.74.74 0 0 0 .46-.22l6.39-6.4c.8-.79.77-2.22-.06-3.05m-1 1.99l-6.2 6.21l-1.09.1l.08-1.06l6.2-6.21c.1-.1.28-.14.46-.15c.2 0 .38.07.49.18c.24.23.27.72.06.93\"/>" },
      { id: 'ci:file-edit', viewBox: '0 0 24 24', body: "<path fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M6 11V6.2c0-1.12 0-1.68.218-2.108c.192-.377.497-.682.874-.874C7.52 3 8.08 3 9.2 3H14m6 6v8.804c0 1.118 0 1.677-.218 2.104a2 2 0 0 1-.874.874C18.48 21 17.92 21 16.803 21H13m7-12c-.004-.285-.014-.466-.056-.639q-.074-.308-.24-.578c-.123-.202-.295-.374-.641-.72l-3.125-3.125c-.346-.346-.52-.52-.721-.643a2 2 0 0 0-.578-.24c-.173-.041-.353-.052-.639-.054M20 9h-2.803c-1.118 0-1.678 0-2.105-.218a2 2 0 0 1-.874-.874C14 7.48 14 6.92 14 5.8V3M9 14l2 2m-7 5v-2.5l7.5-7.5l2.5 2.5L6.5 21z\"/>" },
      { id: 'uil:file-edit-alt', viewBox: '0 0 24 24', body: "<path fill=\"currentColor\" d=\"m20.71 16.71l-2.42-2.42a1 1 0 0 0-1.42 0l-3.58 3.58a1 1 0 0 0-.29.71V21a1 1 0 0 0 1 1h2.42a1 1 0 0 0 .71-.29l3.58-3.58a1 1 0 0 0 0-1.42M16 20h-1v-1l2.58-2.58l1 1Zm-6 0H6a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h5v3a3 3 0 0 0 3 3h3v1a1 1 0 0 0 2 0V8.94a1.3 1.3 0 0 0-.06-.27v-.09a1 1 0 0 0-.19-.28l-6-6a1 1 0 0 0-.28-.19a.3.3 0 0 0-.09 0L12.06 2H6a3 3 0 0 0-3 3v14a3 3 0 0 0 3 3h4a1 1 0 0 0 0-2m3-14.59L15.59 8H14a1 1 0 0 1-1-1ZM8 14h6a1 1 0 0 0 0-2H8a1 1 0 0 0 0 2m0-4h1a1 1 0 0 0 0-2H8a1 1 0 0 0 0 2m2 6H8a1 1 0 0 0 0 2h2a1 1 0 0 0 0-2\"/>" },
      { id: 'icon-park-outline:file-editing', viewBox: '0 0 48 48', body: "<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"4\"><path d=\"M10 44h28a2 2 0 0 0 2-2V14H30V4H10a2 2 0 0 0-2 2v36a2 2 0 0 0 2 2M30 4l10 10\"/><path d=\"m21 35l10-10l-4-4l-10 10v4z\"/></g>" },
      { id: 'material-symbols:edit-note', viewBox: '0 0 24 24', body: "<path fill=\"currentColor\" d=\"M4 14v-2h7v2zm0-4V8h11v2zm0-4V4h11v2zm9 14v-3.075l5.525-5.5q.225-.225.5-.325t.55-.1q.3 0 .575.113t.5.337l.925.925q.2.225.313.5t.112.55t-.1.563t-.325.512l-5.5 5.5zm6.575-5.6l.925-.975l-.925-.925l-.95.95z\"/>" },
      { id: 'fluent:document-edit-24-regular', viewBox: '0 0 20 20', body: "<path fill=\"currentColor\" d=\"M6.25 3.5a.75.75 0 0 0-.75.75v15.5c0 .414.336.75.75.75h3.78a2.08 2.08 0 0 0 .27 1.5H6.25A2.25 2.25 0 0 1 4 19.75V4.25A2.25 2.25 0 0 1 6.25 2h6.086c.464 0 .909.184 1.237.513l5.914 5.914c.329.328.513.773.513 1.237V10h-6a2 2 0 0 1-2-2V3.5zm7.25 1.06V8a.5.5 0 0 0 .5.5h3.44zM19.713 11h.002a2.286 2.286 0 0 1 1.615 3.902l-5.902 5.902a2.7 2.7 0 0 1-1.247.707l-1.831.457a1.087 1.087 0 0 1-1.318-1.318l.457-1.83c.118-.473.362-.904.707-1.248l5.902-5.902a2.28 2.28 0 0 1 1.615-.67\"/>" },
      { id: 'clarity:note-edit-line', viewBox: '0 0 36 36', body: "<path fill=\"currentColor\" d=\"M28 30H6V8h13.22l2-2H6a2 2 0 0 0-2 2v22a2 2 0 0 0 2 2h22a2 2 0 0 0 2-2V15l-2 2Z\" class=\"clr-i-outline clr-i-outline-path-1\"/><path fill=\"currentColor\" d=\"m33.53 5.84l-3.37-3.37a1.61 1.61 0 0 0-2.28 0L14.17 16.26l-1.11 4.81A1.61 1.61 0 0 0 14.63 23a1.7 1.7 0 0 0 .37 0l4.85-1.07L33.53 8.12a1.61 1.61 0 0 0 0-2.28M18.81 20.08l-3.66.81l.85-3.63L26.32 6.87l2.82 2.82ZM30.27 8.56l-2.82-2.82L29 4.16L31.84 7Z\" class=\"clr-i-outline clr-i-outline-path-2\"/><path fill=\"none\" d=\"M0 0h36v36H0z\"/>" },
      { id: 'ix:edit-document', viewBox: '0 0 512 512', body: "<path fill=\"currentColor\" d=\"M234.667 106.667h-128v298.666h298.666v-128H448V448H64V64h170.667zM478.167 128L264.833 341.333h-94.166v-94.166L384 33.833zM213.333 264.833v33.834h33.834l117.332-117.334l-33.833-33.833zm147.5-147.5l33.833 33.833L417.833 128L384 94.167z\"/>" },
    ];
  }

  function readComposeIconIndex(total) {
    var count = Number(total || 1);
    if (!isFinite(count) || count < 1) {
      count = 1;
    }
    var raw = localStorage.getItem(COMPOSE_ICON_KEY) || '0';
    var idx = Number(raw);
    if (!isFinite(idx) || idx < 0) {
      idx = 0;
    }
    return idx % count;
  }

  function renderComposeIcon(index) {
    if (!els.composeLink) {
      return;
    }
    var icons = composeIconSvgPaths();
    var count = icons.length;
    var idx = Number(index || 0);
    if (!isFinite(idx) || idx < 0) {
      idx = 0;
    }
    idx = idx % count;
    var icon = icons[idx];
    var body = typeof icon === 'string' ? icon : (icon && icon.body ? icon.body : '');
    var viewBox = (icon && icon.viewBox) ? icon.viewBox : '0 0 24 24';
    els.composeLink.innerHTML = '<svg width="21" height="21" viewBox="' + viewBox + '" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" style="color:#111">' + body + '</svg>';
    localStorage.setItem(COMPOSE_ICON_KEY, String(idx));
  }

  function waitMs(ms) {
    var delay = Number(ms || 0);
    if (!isFinite(delay) || delay < 0) {
      delay = 0;
    }
    return new Promise(function (resolve) {
      setTimeout(resolve, delay);
    });
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

  function ensureAuthMessageEl() {
    if (els.authMessage) {
      return els.authMessage;
    }
    if (!els.authModal || !els.authModal.querySelector) {
      return null;
    }
    var panel = els.authModal.querySelector('.auth-modal-panel');
    if (!panel) {
      return null;
    }
    var existing = panel.querySelector('#auth-modal-message');
    if (existing) {
      els.authMessage = existing;
      return els.authMessage;
    }
    var node = document.createElement('div');
    node.id = 'auth-modal-message';
    node.className = 'auth-modal-message';
    node.setAttribute('aria-live', 'polite');
    panel.appendChild(node);
    els.authMessage = node;
    return els.authMessage;
  }

  function setAuthMessage(message, kind) {
    var target = ensureAuthMessageEl();
    if (!target) {
      return;
    }
    var text = String(message || '');
    target.textContent = text;
    target.className = 'auth-modal-message';
    if (text && kind) {
      target.classList.add('is-' + kind);
    }
  }

  function rememberNavToast(message, tone, durationMs) {
    try {
      sessionStorage.setItem(NAV_TOAST_KEY, JSON.stringify({
        message: String(message || ''),
        tone: String(tone || 'info'),
        durationMs: Number(durationMs || 3600),
        at: Date.now()
      }));
    } catch (_err) {
      // Ignore storage write failures; in-place toasts still work.
    }
  }

  function showNavToast(message, tone, durationMs) {
    var text = String(message || '').trim();
    if (!text) {
      return;
    }
    var host = els.navToastHost;
    if (!host) {
      host = document.createElement('div');
      host.id = 'nav-top-toast-host';
      host.className = 'nav-top-toast-host';
      host.setAttribute('aria-live', 'polite');
      host.setAttribute('aria-atomic', 'true');
      document.body.appendChild(host);
      els.navToastHost = host;
    }
    host.innerHTML = '';
    var toast = document.createElement('div');
    toast.className = 'nav-top-toast';
    if (tone) {
      toast.classList.add('is-' + String(tone));
    }
    toast.textContent = text;
    host.appendChild(toast);
    requestAnimationFrame(function () {
      toast.classList.add('is-visible');
    });
    var stay = Number(durationMs || 3600);
    if (!isFinite(stay) || stay < 1200) {
      stay = 3600;
    }
    setTimeout(function () {
      toast.classList.add('is-closing');
      setTimeout(function () {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast);
        }
      }, 230);
    }, stay);
  }

  function flushRememberedNavToast() {
    var raw = '';
    try {
      raw = sessionStorage.getItem(NAV_TOAST_KEY) || '';
      if (raw) {
        sessionStorage.removeItem(NAV_TOAST_KEY);
      }
    } catch (_err) {
      raw = '';
    }
    if (!raw) {
      return;
    }
    try {
      var payload = JSON.parse(raw);
      if (!payload || typeof payload !== 'object') {
        return;
      }
      showNavToast(payload.message || '', payload.tone || 'info', payload.durationMs || 3600);
    } catch (_err2) {
      // Ignore malformed persisted toasts.
    }
  }

  function requestSignerApproval(signEventFn, template, waitingMessage, timeoutMs) {
    var waitText = String(waitingMessage || 'Waiting for signer approval...');
    var timeout = Number(timeoutMs || 70000);
    if (!isFinite(timeout) || timeout < 1000) {
      timeout = 70000;
    }
    var settled = false;
    var hintTimer = setTimeout(function () {
      if (settled) {
        return;
      }
      setAuthMessage(waitText + ' If the signer window is already open, switch to it and approve.', 'warn');
      try {
        if (typeof window.focus === 'function') {
          window.focus();
        }
      } catch (_focusErr) {
        // noop
      }
    }, 1200);
    var timeoutTimer = setTimeout(function () {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(hintTimer);
    }, timeout);
    return Promise.resolve(signEventFn(template)).then(function (result) {
      if (settled) {
        throw new Error('Signer approval timed out.');
      }
      settled = true;
      clearTimeout(hintTimer);
      clearTimeout(timeoutTimer);
      return result;
    }).catch(function (err) {
      clearTimeout(hintTimer);
      clearTimeout(timeoutTimer);
      if (settled && (!err || !err.message)) {
        throw new Error('Signer approval timed out.');
      }
      throw err;
    });
  }

  function setAuthControlsDisabled(disabled) {
    var isDisabled = !!disabled;
    [
      els.authRegisterBtn,
      els.authPhoneConnectBtn,
      els.authPhoneBtn,
      els.authManualStart,
      els.authManualSubmit,
      els.authTabRegister,
      els.authTabPhone,
      els.authTabManual
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

  function resetAuthPanels() {
    showPanel(els.authRegisterPanel, false);
    showPanel(els.authPhonePanel, false);
    showPanel(els.authManualPanel, false);
    state.manualChallenge = null;
    if (els.authManualRequestId) { els.authManualRequestId.value = ''; }
    if (els.authManualChallenge) { els.authManualChallenge.value = ''; }
    if (els.authManualExpires) { els.authManualExpires.value = ''; }
    if (els.authManualTemplate) { els.authManualTemplate.value = ''; }
    if (els.authManualEvent) { els.authManualEvent.value = ''; }
  }

  function setActiveAuthTab(tabName) {
    var tab = String(tabName || 'register');
    if (tab !== 'register' && tab !== 'phone' && tab !== 'manual') {
      tab = 'register';
    }
    if (els.authModalTitle) {
      els.authModalTitle.textContent = (tab === 'register') ? 'Register' : 'Sign in';
    }

    if (els.authTabRegister) {
      var activeRegister = tab === 'register';
      els.authTabRegister.classList.toggle('is-active', activeRegister);
      els.authTabRegister.setAttribute('aria-selected', activeRegister ? 'true' : 'false');
    }
    if (els.authTabPhone) {
      var activePhone = tab === 'phone';
      els.authTabPhone.classList.toggle('is-active', activePhone);
      els.authTabPhone.setAttribute('aria-selected', activePhone ? 'true' : 'false');
    }
    if (els.authTabManual) {
      var activeManual = tab === 'manual';
      els.authTabManual.classList.toggle('is-active', activeManual);
      els.authTabManual.setAttribute('aria-selected', activeManual ? 'true' : 'false');
    }

    showPanel(els.authRegisterPanel, tab === 'register');
    showPanel(els.authPhonePanel, tab === 'phone');
    showPanel(els.authManualPanel, tab === 'manual');

    if (tab === 'phone') {
      updatePhoneContinueState();
      initNip46Pairing().then(function () {
        setAuthMessage('Scan QR in your signer app. Continue unlocks after pairing.', 'warn');
      }).catch(function (err) {
        setAuthMessage(err.message || 'Unable to prepare phone signer QR.', 'error');
      });
      return;
    }
    if (tab === 'manual') {
      setAuthMessage('Create a challenge, then paste the signed event JSON.', 'warn');
      return;
    }
    setAuthMessage('Register uses your Nostr signer and creates your account on first successful sign-in.', 'warn');
  }

  function showAuthModal(initialTab) {
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
    setActiveAuthTab(initialTab || 'register');
  }

  function hideAuthModal() {
    if (!els.authModal) {
      return;
    }
    els.authModal.classList.remove('is-open');
    if (!els.authInfoModal || !els.authInfoModal.classList.contains('is-open')) {
      document.body.classList.remove('auth-modal-open');
    }
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

  function showInfoModal() {
    if (!els.authInfoModal) {
      return;
    }
    els.authInfoModal.hidden = false;
    requestAnimationFrame(function () {
      els.authInfoModal.classList.add('is-open');
    });
    document.body.classList.add('auth-modal-open');
  }

  function hideInfoModal() {
    if (!els.authInfoModal) {
      return;
    }
    els.authInfoModal.classList.remove('is-open');
    if (!els.authModal || !els.authModal.classList.contains('is-open')) {
      document.body.classList.remove('auth-modal-open');
    }
    setTimeout(function () {
      if (!els.authInfoModal.classList.contains('is-open')) {
        els.authInfoModal.hidden = true;
      }
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

  function authEventTemplate(challenge, action, pubkey) {
    var eventAction = action || 'login';
    var signerPubkey = String(pubkey || '').trim();
    var tags = [
      ['challenge', String(challenge || '')],
      ['relay', currentOrigin()],
      ['domain', currentHost()]
    ];
    if (eventAction && eventAction !== 'login') {
      tags.push(['action', eventAction]);
    }
    return {
      kind: AUTH_KIND,
      created_at: nowEpoch(),
      tags: tags,
      content: '',
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

  function finishLogin(requestId, signedEvent, delegationEvent, forceInteractive, usernameHint) {
    var payload = {
      request_id: requestId,
      event_json: JSON.stringify(normalizeSignedEvent(signedEvent)),
      force_interactive: forceInteractive ? 'true' : 'false'
    };
    var desiredUsername = String(usernameHint || '').trim();
    if (desiredUsername) {
      payload.username_hint = desiredUsername;
    }
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

  function applyLoggedInUi(isLoggedIn, isAdmin, username) {
    var displayName = String(username || '');
    state.isAuthenticated = !!isLoggedIn;

    if (isLoggedIn) {
      if (els.loginSplit) {
        els.loginSplit.style.display = 'none';
      } else if (els.loginBtn) {
        els.loginBtn.style.display = 'none';
      }
      if (els.composeTools) {
        els.composeTools.style.display = isAdmin ? 'inline-flex' : 'none';
      } else if (els.composeLink) {
        els.composeLink.style.display = isAdmin ? 'inline-flex' : 'none';
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

    if (els.loginSplit) {
      els.loginSplit.style.display = 'inline-flex';
      closeLoginMenu();
    } else if (els.loginBtn) {
      els.loginBtn.style.display = 'inline-block';
    }
    if (els.composeTools) {
      els.composeTools.style.display = 'none';
    } else if (els.composeLink) {
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
    updateLogoutOtherSessionsUi(0);
  }

  function updateLogoutOtherSessionsUi(countRaw) {
    if (!els.menuLogoutEverywhereBtn) {
      return;
    }
    var count = Number(countRaw || 0);
    if (!isFinite(count) || count < 0) {
      count = 0;
    }
    if (count < 1) {
      els.menuLogoutEverywhereBtn.style.display = 'none';
      els.menuLogoutEverywhereBtn.textContent = 'Log out other sessions';
      return;
    }
    els.menuLogoutEverywhereBtn.style.display = 'block';
    els.menuLogoutEverywhereBtn.textContent = 'Log out other sessions (' + String(count) + ')';
  }

  function checkAuth() {
    var token = getSessionToken();
    if (!token) {
      applyLoggedInUi(false, false, '');
      return Promise.resolve(false);
    }

    return fetch('/cgi/ssh-auth-check-session?session_token=' + encodeURIComponent(token))
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (!data || !data.authenticated) {
          clearLocalStorageAuth();
          applyLoggedInUi(false, false, '');
          return false;
        }
        if (data.csrf_token) {
          localStorage.setItem('csrf_token', data.csrf_token);
        }
        if (data.nostr_pubkey) {
          localStorage.setItem('last_auth_pubkey', data.nostr_pubkey);
        }
        applyLoggedInUi(true, !!data.is_admin, data.player_name || data.username || '');
        updateLogoutOtherSessionsUi(data.other_sessions_count || 0);
        return true;
      })
      .catch(function () {
        if (!state.isAuthenticated) {
          applyLoggedInUi(false, false, '');
        }
        updateLogoutOtherSessionsUi(0);
        return false;
      });
  }

  function verifySessionWithRetry(remainingAttempts, delayMs) {
    var attempts = Number(remainingAttempts || 0);
    if (!isFinite(attempts) || attempts < 1) {
      attempts = 1;
    }
    return checkAuth().then(function (ok) {
      if (ok) {
        return true;
      }
      if (attempts <= 1) {
        return false;
      }
      return waitMs(delayMs).then(function () {
        return verifySessionWithRetry(attempts - 1, delayMs);
      });
    });
  }

  function finalizeLoginUiAfterSuccess(finishData) {
    var data = finishData && typeof finishData === 'object' ? finishData : {};
    var optimisticName = data.player_name || data.username || localStorage.getItem('last_auth_username') || 'signed-in';
    applyLoggedInUi(true, !!data.is_admin, optimisticName);
    return verifySessionWithRetry(6, 180).then(function (ok) {
      if (!ok) {
        clearLocalStorageAuth();
        applyLoggedInUi(false, false, '');
        throw new Error('Login was signed, but session validation failed. Please try again.');
      }
      hideAuthModal();
      return true;
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

  function openLoginMenu() {
    if (!els.loginMenu || !els.loginMoreBtn) {
      return;
    }
    els.loginMenu.hidden = false;
    els.loginMoreBtn.setAttribute('aria-expanded', 'true');
  }

  function closeLoginMenu() {
    if (!els.loginMenu || !els.loginMoreBtn) {
      return;
    }
    els.loginMenu.hidden = true;
    els.loginMoreBtn.setAttribute('aria-expanded', 'false');
  }

  function hasDesktopSigner() {
    return !!(window.nostr && typeof window.nostr.signEvent === 'function');
  }

  function pageRequiresAuthorization() {
    var path = String(window.location.pathname || '').replace(/\/+$/, '') || '/';
    if (path === '/pages/admin.html' || path === '/pages/admin' || path === '/admin.html' || path === '/admin') {
      return true;
    }
    if (document.body && document.body.getAttribute('data-requires-auth') === 'true') {
      return true;
    }
    return false;
  }

  function handlePostLogoutNavigation(toastMessage) {
    var message = String(toastMessage || 'Logged out.');
    if (pageRequiresAuthorization()) {
      rememberNavToast(message, 'info', 3800);
      window.location.assign('/');
      return;
    }
    if (els.authModal && !els.authModal.hidden) {
      hideAuthModal();
    }
    showNavToast(message, 'info', 3800);
  }

  function logout() {
    var token = getSessionToken();
    if (!token) {
      clearLocalStorageAuth();
      return clearLocalKeyMaterial().finally(function () {
        applyLoggedInUi(false, false, '');
        handlePostLogoutNavigation('Logged out.');
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
        handlePostLogoutNavigation('Logged out.');
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

  function signInWithSigner(signEventFn, options) {
    var opts = options && typeof options === 'object' ? options : {};
    var getPubkeyFn = typeof opts.getPubkeyFn === 'function' ? opts.getPubkeyFn : null;
    var pubkeyHint = String(opts.pubkeyHint || '').trim();
    var registerAttempt = !!opts.registerAttempt;
    var usernameHint = String(opts.usernameHint || '').trim();
    setAuthMessage('Creating a single-use login challenge...', 'warn');
    return beginChallenge(pubkeyHint || localStorage.getItem('last_auth_pubkey') || '')
      .then(function (begin) {
        var authTemplate = authEventTemplate(begin.challenge, 'login', pubkeyHint);
        setAuthMessage('Sign the login challenge event...', 'warn');
        return requestSignerApproval(
          signEventFn,
          authTemplate,
          'Approve login in your signer',
          70000
        ).then(function (signedAuth) {
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
        if (!payload.userPubkey) {
          throw new Error('Signed auth event is missing pubkey.');
        }
        localStorage.setItem('last_auth_pubkey', payload.userPubkey);
        return finishLogin(
          payload.begin.request_id,
          payload.signedAuth,
          null,
          false,
          usernameHint
        );
      })
      .then(function (finish) {
        rememberAuth(finish);
        return idbDelete(KEY_DEVICE_SESSION).then(function () {
          var created = !!(finish && (finish.account_created === true || finish.account_created === 'true'));
          if (registerAttempt && !created) {
            showNavToast('You were logged in because this account already exists.', 'ok', 4200);
          }
          return finalizeLoginUiAfterSuccess(finish);
        });
      });
  }

  function loginWithNip07(options) {
    var signer = getBrowserSigner();
    var opts = options && typeof options === 'object' ? options : {};
    try {
      if (typeof window.focus === 'function') {
        window.focus();
      }
    } catch (_focusErr) {
      // noop
    }
    return signInWithSigner(
      function (template) {
        return Promise.resolve(signer.signEvent(template));
      },
      {
        getPubkeyFn: typeof signer.getPublicKey === 'function'
          ? function () { return Promise.resolve(signer.getPublicKey()); }
          : null,
        pubkeyHint: '',
        registerAttempt: !!opts.registerAttempt,
        usernameHint: String(opts.usernameHint || '').trim()
      }
    );
  }

  function startPhonePairingFlow() {
    setAuthMessage('Preparing phone signer pairing QR...', 'warn');
    setAuthControlsDisabled(true);
    return initNip46Pairing().then(function () {
      showPanel(els.authPhonePanel, true);
      showPanel(els.authManualPanel, false);
      setAuthMessage('Scan QR in your signer app. Continue unlocks after pairing.', 'warn');
      return waitForPhonePairing(90000);
    }).then(function () {
      updatePhoneContinueState();
      setAuthMessage('Phone signer paired. Continue is ready.', 'ok');
    }).finally(function () {
      setAuthControlsDisabled(false);
    });
  }

  function startDesktopSignerLogin(registerAttempt, usernameHint) {
    var asRegister = !!registerAttempt;
    if (!hasDesktopSigner()) {
      return Promise.reject(new Error('No desktop signer detected. Use the login menu for phone QR or signed challenge login.'));
    }
    setAuthControlsDisabled(true);
    return loginWithNip07({
      registerAttempt: asRegister,
      usernameHint: String(usernameHint || '').trim()
    }).finally(function () {
      setAuthControlsDisabled(false);
    });
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

    var signedAuth;
    try {
      signedAuth = parseJsonResponse(signedAuthRaw);
    } catch (_) {
      throw new Error('Signed auth event JSON is invalid.');
    }

    return finishLogin(
      state.manualChallenge.request_id,
      signedAuth,
      null,
      false
    ).then(function (finish) {
      rememberAuth(finish);
      return idbDelete(KEY_DEVICE_SESSION).then(function () {
        return finalizeLoginUiAfterSuccess(finish);
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
        applyLoggedInUi(false, false, '');
        handlePostLogoutNavigation('Logged out other sessions.');
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

    return Promise.reject(new Error('Fresh signer approval is required. Use Login or the phone signer flow first.'));
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
    if (els.composeIconCycleBtn) {
      els.composeIconCycleBtn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        var icons = composeIconSvgPaths();
        var current = readComposeIconIndex(icons.length);
        renderComposeIcon((current + 1) % icons.length);
      });
    }

    if (els.loginBtn) {
      els.loginBtn.addEventListener('click', function () {
        closeLoginMenu();
        startDesktopSignerLogin(false, '').catch(function (err) {
          showNavToast(err.message || 'Desktop signer login failed.', 'info', 4200);
          openLoginMenu();
        });
      });
    }

    if (els.loginMoreBtn && els.loginMenu) {
      els.loginMoreBtn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (els.loginMenu.hidden) {
          openLoginMenu();
        } else {
          closeLoginMenu();
        }
      });
    }

    if (els.loginMenuRegister) {
      els.loginMenuRegister.addEventListener('click', function () {
        closeLoginMenu();
        showAuthModal('register');
      });
    }

    if (els.loginMenuPhone) {
      els.loginMenuPhone.addEventListener('click', function () {
        closeLoginMenu();
        showAuthModal('phone');
      });
    }

    if (els.loginMenuManual) {
      els.loginMenuManual.addEventListener('click', function () {
        closeLoginMenu();
        showAuthModal('manual');
        setAuthControlsDisabled(true);
        prepareManualLogin().catch(function (err) {
          setAuthMessage(err.message || 'Failed to prepare manual login.', 'error');
        }).finally(function () {
          setAuthControlsDisabled(false);
        });
      });
    }

    if (els.loginMenuLearn) {
      els.loginMenuLearn.addEventListener('click', function () {
        closeLoginMenu();
        showInfoModal();
      });
    }

    if (els.authModal) {
      els.authModal.addEventListener('click', function (event) {
        if (event.target && event.target.hasAttribute('data-close-auth-modal')) {
          hideAuthModal();
        }
      });
    }
    if (els.authInfoModal) {
      els.authInfoModal.addEventListener('click', function (event) {
        if (event.target && event.target.hasAttribute('data-close-auth-info')) {
          hideInfoModal();
        }
      });
    }

    if (els.menuBtn && els.menuPanel) {
      els.menuBtn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        closeLoginMenu();
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
        setAuthMessage('Preparing log out other sessions challenge...', 'warn');
        logoutEverywhere().catch(function (err) {
          setAuthMessage(err.message || 'Log out other sessions failed.', 'error');
          showAuthModal('register');
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
        if (els.loginSplit && els.loginMenu && !els.loginMenu.hidden && !els.loginSplit.contains(event.target)) {
          closeLoginMenu();
        }
        return;
      }
      if (!els.userMenu.contains(event.target)) {
        closeUserMenu();
      }
      if (els.loginSplit && els.loginMenu && !els.loginMenu.hidden && !els.loginSplit.contains(event.target)) {
        closeLoginMenu();
      }
    });

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && els.authModal && !els.authModal.hidden) {
        hideAuthModal();
        return;
      }
      if (event.key === 'Escape' && els.authInfoModal && !els.authInfoModal.hidden) {
        hideInfoModal();
        return;
      }
      if (event.key === 'Escape' && els.loginMenu && !els.loginMenu.hidden) {
        closeLoginMenu();
      }
    });

    if (els.authRegisterBtn) {
      els.authRegisterBtn.addEventListener('click', function () {
        var usernameHint = els.authRegisterUsername ? String(els.authRegisterUsername.value || '').trim() : '';
        startDesktopSignerLogin(true, usernameHint).catch(function (err) {
          setAuthMessage(err.message || 'Desktop signer login failed.', 'error');
        });
      });
    }

    if (els.authTabRegister) {
      els.authTabRegister.addEventListener('click', function () {
        setActiveAuthTab('register');
      });
    }
    if (els.authTabPhone) {
      els.authTabPhone.addEventListener('click', function () {
        setActiveAuthTab('phone');
      });
    }
    if (els.authTabManual) {
      els.authTabManual.addEventListener('click', function () {
        setActiveAuthTab('manual');
      });
    }

    if (els.authPhoneConnectBtn) {
      els.authPhoneConnectBtn.addEventListener('click', function () {
        startPhonePairingFlow().catch(function (err) {
          setAuthMessage(err.message || 'Phone pairing setup failed.', 'error');
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
    renderComposeIcon(readComposeIconIndex(composeIconSvgPaths().length));
    highlightCurrentPage();
    window.addEventListener('hashchange', highlightCurrentPage);
    bindThemeSelect();
    bindUiEvents();
    window.blogAuth = window.blogAuth || {};
    window.blogAuth.openLoginModal = showAuthModal;
    window.blogAuth.showToast = showNavToast;
    flushRememberedNavToast();
    loadTheme();
    checkAuth();
  }

  document.addEventListener('DOMContentLoaded', bootstrap);
})();
