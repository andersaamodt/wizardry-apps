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
      { id: "streamline-pixel:content-files-quill-ink", viewBox: "0 0 32 32", body: "<path fill=\"currentColor\" d=\"M27.435 3.05h1.52V1.52h1.52V0h-9.14v1.52h6.1zm-1.53 0h1.53v1.52h-1.53Zm-1.52 1.52h1.52V6.1h-1.52Zm-1.52 1.53h1.52v1.52h-1.52Zm-1.53 1.52h1.53v3.05h-1.53Zm0-4.57h1.53v1.52h-1.53Zm-1.52 7.62h1.52v1.52h-1.52Zm0-6.1h1.52V6.1h-1.52Z\"/><path fill=\"currentColor\" d=\"M18.285 1.52h3.05v1.53h-3.05Zm0 4.58h1.53v1.52h-1.53Zm-1.52 6.09h3.05v1.53h-3.05Zm0-4.57h1.52v1.52h-1.52Zm0-4.57h1.52v1.52h-1.52ZM3.055 32h13.71v-1.52h1.52v-6.1h-1.52v1.53h-7.62v-1.53H6.1v-1.52H3.055v1.52h-1.53v6.1h1.53Zm1.52-6.09H6.1v3.04h3.05v1.53H6.1v-1.53H4.575Zm10.67-16.77h1.52v1.53h-1.52Zm0-4.57h1.52V6.1h-1.52Z\"/><path fill=\"currentColor\" d=\"M13.715 22.86h3.05v1.52h-3.05Zm3.05-9.14h-3.05v-1.53h-1.52v-1.52h-1.52v4.57h6.09z\"/><path fill=\"currentColor\" d=\"M13.715 10.67h1.53v1.52h-1.53Zm0-4.57h1.53v1.52h-1.53Zm-1.52 1.52h1.52v3.05h-1.52Zm-4.57 12.19h4.57v3.05h1.52v-3.05h1.53v-1.52h-4.57v-3.05h-1.53v3.05h-4.57v1.52h1.52v3.05h1.53z\"/>" },
      { id: "mdi:quill", viewBox: "0 0 24 24", body: "<path fill=\"currentColor\" d=\"M22 2s-7.64-.37-13.66 7.88C3.72 16.21 2 22 2 22l1.94-1c1.44-2.5 2.19-3.53 3.6-5c2.53.74 5.17.65 7.46-2c-2-.56-3.6-.43-5.96-.19C11.69 12 13.5 11.6 16 12l1-2c-1.8-.34-3-.37-4.78.04C14.19 8.65 15.56 7.87 18 8l1.21-1.93c-1.56-.11-2.5.06-4.29.5c1.61-1.46 3.08-2.12 5.22-2.25c0 0 1.05-1.89 1.86-2.32\"/>" },
      { id: "streamline-cyber:quill", viewBox: "0 0 24 24", body: "<path fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-miterlimit=\"10\" d=\"m.5 23.5l23-23M4.139 19.86L14 18.5l9.5-18l-18 9.5zm11.563-4.585l-3.195.46m4.673-3.261l-2.201.282\"/>" },
      { id: "game-icons:quill", viewBox: "0 0 512 512", body: "<path fill=\"currentColor\" d=\"M492.47 21.938c-82.74-.256-167.442 12.5-242.814 45.093c5.205 13.166 9.578 28.48 13.188 45.532C242.55 97.27 217.167 92.385 194.72 95.5c-46.22 28.432-87.13 66.305-119.44 115.594c25.193 7.756 51.57 22.81 72.845 43.844c-31.87-7.045-68.907-5.895-99.188 3c-13.743 28.688-25.008 60.48-33.343 95.687c128.71-30.668 130.522 3.514 50.75 140.438c16.877 12.614 42.182 13.77 61.906-1.563C134 267.936 231.43 326.246 254.188 354.562c14.288-40.59 34.77-82.54 62.906-126.468c-17.29-14.667-39.21-24.838-63.813-32.375c25.364-5.256 50.91-10.928 74.126-11.22c6.482-.082 12.78.272 18.844 1.156c17.57-24.007 37.408-48.612 59.75-73.97c-12.538-6.31-25.476-11.454-38.125-14.967c17.132-5.76 35.274-8.34 52.844-8.157c2.01.02 4.004.095 6 .187c20.07-21.708 41.927-43.976 65.75-66.813zM426.72 47.28c-130.93 65.394-226.626 162.926-281.784 286.25C172.34 184.41 287.048 84.57 426.72 47.28\"/>" },
      { id: "icomoon-free:quill", viewBox: "0 0 16 16", body: "<path fill=\"currentColor\" d=\"M0 16C2 10 7.234 0 16 0c-4.109 3.297-6 11-9 11H4l-3 5z\"/>" },
      { id: "mingcute:quill-pen-fill", viewBox: "0 0 24 24", body: "<g fill=\"none\" fill-rule=\"evenodd\"><path d=\"m12.593 23.258l-.011.002l-.071.035l-.02.004l-.014-.004l-.071-.035q-.016-.005-.024.005l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427q-.004-.016-.017-.018m.265-.113l-.013.002l-.185.093l-.01.01l-.003.011l.018.43l.005.012l.008.007l.201.093q.019.005.029-.008l.004-.014l-.034-.614q-.005-.018-.02-.022m-.715.002a.02.02 0 0 0-.027.006l-.006.014l-.034.614q.001.018.017.024l.015-.002l.201-.093l.01-.008l.004-.011l.017-.43l-.003-.012l-.01-.01z\"/><path fill=\"currentColor\" d=\"M6.81 17.844c-.032.247-.273 2.729-.31 3.156c-.047.54-.448 1-1 1a1 1 0 0 1-1-1c0-.571.116-1.67.221-2.56c.205-1.732.446-3.427.987-5.09c.625-1.92 1.75-4.379 3.757-6.386c3.934-3.934 9.652-4.515 9.797-4.53a1 1 0 0 1 .944.454c.991 1.49.747 3.71-.467 5.007a1 1 0 0 1-.03.37a16 16 0 0 1-.75 2.135c-.551 1.263-1.328 2.54-2.423 3.636c-2.05 2.05-4.742 2.991-6.844 3.43a19.4 19.4 0 0 1-2.883.378Z\"/></g>" },
      { id: "mingcute:quill-pen-line", viewBox: "0 0 24 24", body: "<g fill=\"none\" fill-rule=\"evenodd\"><path d=\"m12.593 23.258l-.011.002l-.071.035l-.02.004l-.014-.004l-.071-.035q-.016-.005-.024.005l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427q-.004-.016-.017-.018m.265-.113l-.013.002l-.185.093l-.01.01l-.003.011l.018.43l.005.012l.008.007l.201.093q.019.005.029-.008l.004-.014l-.034-.614q-.005-.018-.02-.022m-.715.002a.02.02 0 0 0-.027.006l-.006.014l-.034.614q.001.018.017.024l.015-.002l.201-.093l.01-.008l.004-.011l.017-.43l-.003-.012l-.01-.01z\"/><path fill=\"currentColor\" d=\"M5.708 13.35c.625-1.92 1.75-4.379 3.757-6.386c3.934-3.934 9.652-4.515 9.797-4.53a1 1 0 0 1 .944.454c.208.313 1.38 2.283-.191 4.663a2.6 2.6 0 0 1-.276.344a1 1 0 0 1-.03.37c-.19.689-.434 1.412-.75 2.135c-.551 1.263-1.328 2.54-2.423 3.636c-2.05 2.05-4.742 2.991-6.844 3.43a19.4 19.4 0 0 1-2.883.378C6.778 18.09 6.5 20.57 6.5 21a1 1 0 1 1-2 0c0-.571.116-1.67.221-2.56c.205-1.732.446-3.427.987-5.09m12.637-6.9c.527-.8.52-1.48.415-1.92c-1.527.275-5.219 1.186-7.881 3.849c-1.704 1.703-2.7 3.84-3.269 5.59a18 18 0 0 0-.494 1.85a17 17 0 0 0 2.167-.31c1.92-.402 4.179-1.228 5.838-2.888c.85-.85 1.484-1.857 1.954-2.905c-.976.52-2.018.986-2.759 1.233a1 1 0 1 1-.632-1.898c.674-.225 1.758-.713 2.754-1.265c.494-.274.946-.553 1.301-.808c.384-.276.56-.46.606-.529Z\"/></g>" },
      { id: "ri:quill-pen-fill", viewBox: "0 0 24 24", body: "<path fill=\"currentColor\" d=\"M21 1.997c-15 0-17 14-18 20h1.998q.999-5 5.002-5.5c4-.5 7-4 8-7l-1.5-1l1-1c1-1 2.004-2.5 3.5-5.5\"/>" },
      { id: "ri:quill-pen-line", viewBox: "0 0 24 24", body: "<path fill=\"currentColor\" d=\"M6.94 14.033a30 30 0 0 0-.606 1.783c.96-.697 2.101-1.14 3.418-1.304c2.513-.314 4.746-1.973 5.876-4.058l-1.456-1.455l1.413-1.415l1-1.002c.43-.429.915-1.224 1.428-2.367c-5.593.867-9.018 4.291-11.074 9.818M17 8.997l1 1c-1 3-4 6-8 6.5q-4.003.5-5.002 5.5H3c1-6 3-20 18-20q-1.5 4.496-2.997 5.997z\"/>" },
      { id: "tdesign:pen-quill", viewBox: "0 0 24 24", body: "<g fill=\"none\"><path d=\"M15.5 2L17 7l5 1.5l-9.5 9.5l-6-.5l-.5-6z\"/><path stroke=\"currentColor\" stroke-linecap=\"square\" stroke-width=\"2\" d=\"m6.5 17.5l6 .5L22 8.5L17 7M6.5 17.5l-.5-6L15.5 2L17 7M6.5 17.5L3 21m3.5-3.5L17 7\"/></g>" },
      { id: "tdesign:pen-quill-filled", viewBox: "0 0 24 24", body: "<path fill=\"currentColor\" d=\"M23.301 8.118L12.162 19.212l-5.416-.697l-3.673 3.673l-1.414-1.414l3.669-3.67l-.742-5.41L15.672.565l1.816 5.787z\"/>" },
      { id: "game-icons:quill-ink", viewBox: "0 0 512 512", body: "<path fill=\"currentColor\" d=\"M496.938 14.063c-95.14 3.496-172.297 24.08-231.282 55.812l-29.47 49.28l-4.967-28.093c-10.535 7.402-20.314 15.222-29.314 23.407l-14.687 45.06l-5.032-25.155c-40.65 45.507-60.41 99.864-58.938 155.906c47.273-93.667 132.404-172.727 211.97-221.155l9.717 15.97c-75.312 45.838-156.387 121.202-202.187 208.25h12.156c19.78-12.02 39.16-26.858 58.406-43.44l-30.28 1.595l54.218-23.094c46.875-43.637 93.465-94.974 143.313-138.28l-24.47-5.19l56.5-21.03c26.853-20.485 54.8-37.844 84.344-49.843zM59.53 312.03v30.408H194V312.03zm20.376 49.095L47.25 389.813L24.97 474.78l14.53 15.876h177.22l14.56-15.875L209 389.814l-30.906-28.688H79.906z\"/>" },
      { id: "streamline-freehand:notes-quill", viewBox: "0 0 24 24", body: "<g fill=\"currentColor\" fill-rule=\"evenodd\" clip-rule=\"evenodd\"><path d=\"M22.471 11.098c-.24-.38-.72-.39-1.17-.33a9.85 9.85 0 0 0-5.005 2.382a6.74 6.74 0 0 0-2.913 5.845a5.7 5.7 0 0 0 .39 2.192a21 21 0 0 0-1.771 2.512c0 .23.29.42.62.21a45 45 0 0 0 3.303-3.843a43 43 0 0 0 2.433-4.074a.3.3 0 0 0-.5-.32c-3.874 5.114-3.324 4.404-3.754 5.004a4 4 0 0 1 0-.5a6 6 0 0 1 1.611-5.295c2.002-2.002 4.915-3.093 5.735-3.003c0 3.153 0 2.853-.07 3.353l-1.541 1.001c-.18.1-.63.22-.76.6c-.221.661.59.722 1.12 1.252c-1.27.74-1.431.5-1.821.78a.58.58 0 0 0-.23.791q.474.459 1 .861c-2.682 2.252-3.433 1.472-3.883 1.772a.35.35 0 0 0 .17.64c2.002.32 4.604-2.001 4.694-2.232c.16-.42-.33-.75-.79-1.17a18 18 0 0 0 1.941-.892a.55.55 0 0 0 .12-.91l-.82-.731c1.13-.62 1.701-.92 1.901-1.471c.12-.3.31-3.934-.01-4.424\"/><path d=\"M11.061 18.995c-7.467.11-4.294.12-7.557-.27c-.49-.05-.71-.42-.85-.851c-.26-.851-.19-1.001-.07-9.339a19.7 19.7 0 0 1 .21-5.004c.25-1.001 0-1.381 1.42-1.361c0 .34-.13 1.631-.1 1.851c.09.761.841.65 1.132.73c1.521.361 2.092-.78 2.002-2.371c.476.143.984.143 1.46 0c0 .11-.1 1.381-.07 1.561c.09.76.832.64 1.132.72c1.501.361 2.072-.74 2.002-2.301c.68.2.73.17 1.731-.06c0 .1-.08 1.381-.06 1.501a.69.69 0 0 0 .52.63c1.602.431 2.543 0 2.593-1.73q.504.012 1 .09c.241 0 .441.08.461.28l.37 6.936a.301.301 0 0 0 .527.246a.3.3 0 0 0 .064-.246c.44-2.352.44-4.765 0-7.117c-.24-1-1.321-1-2.382-.91a5.5 5.5 0 0 0-.54-1.612a1.43 1.43 0 0 0-2.052.14a2.9 2.9 0 0 0-.4 1.001a3.3 3.3 0 0 0-2.002.15a3.2 3.2 0 0 0-.32-1.16a1.44 1.44 0 0 0-2.103.15a2.8 2.8 0 0 0-.35.85a3.3 3.3 0 0 0-1.722.12a3.2 3.2 0 0 0-.32-1.07a1.15 1.15 0 0 0-1.19-.371c-.802.12-1.102.67-1.282 1.451a2.33 2.33 0 0 0-1.562.25c-.51.34-.54 1.061-.68 1.522a20.4 20.4 0 0 0-.51 5.164c-.19 4.695-.14 3.193-.21 6.696c0 1.902 0 4.334 2.061 4.484c3.343.25.12.37 7.657-.05a.35.35 0 1 0-.01-.7m3.383-17.256c.08-1.491 1-1.12 1.061-.83c.117.737.1 1.49-.05 2.221c-.16.551-.44.42-1.001.41q.04-.9-.01-1.8M9.84 1.03c.2-.4.78-.13.86-.16a6.2 6.2 0 0 1 0 2.402c-.09.3-.27.51-.65.4h-.36c0-.12.06-.25.06-.3a5.6 5.6 0 0 1 .09-2.342m-4.494.05c.2-.4.78-.13.86-.16c.151.79.151 1.601 0 2.392c-.09.3-.27.52-.65.4h-.36c0-.12.06-.25.06-.3a5.6 5.6 0 0 1 .09-2.332\"/><path d=\"M15.135 8.245a.38.38 0 0 0 .06-.54c-.19-.31-5.675-.721-8.338-.611c-3.003.2-2.572.7-2.092.81c1.041.321 10.35.361 10.37.341m-3.133 3.103c-.31-.08-2.743-.21-3.203-.21s-3.843.1-4.004.48a.28.28 0 0 0 .06.24c.607.22 1.247.335 1.892.34c1.752.123 3.511.08 5.255-.13c.41 0 .54-.59 0-.72m-6.926 4.644a11.5 11.5 0 0 0 4.584.08a.34.34 0 0 0 0-.48a8.6 8.6 0 0 0-2.903-.42c-2.292.14-2.762.64-1.681.82\"/></g>" },
      { id: "streamline-kameleon-color:quill-paper", viewBox: "0 0 48 48", body: "<g fill=\"none\"><path fill=\"#25b7d3\" d=\"M24 47.998c13.255 0 24-10.745 24-24C48 10.746 37.255 0 24 0S0 10.745 0 23.999s10.745 23.999 24 23.999\"/><path fill=\"#fff\" d=\"M10.037 11.712c0-.926.75-1.676 1.675-1.676H24l6.982 5.865v20.386c0 .925-.75 1.675-1.676 1.675H11.712c-.925 0-1.675-.75-1.675-1.675z\"/><path fill=\"#f0f1f1\" d=\"M24 10.036v4.189c0 .926.75 1.676 1.676 1.676h5.306z\"/><path fill=\"#e2e4e5\" d=\"M22.255 17.89a.437.437 0 0 1-.437.437h-7.854a.437.437 0 0 1 0-.873h7.854c.241 0 .437.196.437.436m5.236 3.491a.436.436 0 0 1-.436.436H13.964a.437.437 0 0 1 0-.872h13.09c.242 0 .437.195.437.436m0 3.491c0 .24-.195.436-.436.436H13.964a.436.436 0 0 1 0-.872h13.09c.242 0 .437.195.437.436m0 3.491c0 .24-.195.436-.436.436H13.964a.437.437 0 0 1 0-.873h13.09c.242 0 .437.196.437.437\"/><path fill=\"#3e3e3f\" d=\"M37.964 13.09c0 2.876-.51 5.307-1.362 7.358v.004c-.838.624-2.592 1.802-3.875 1.802c.782.262 1.794.445 2.81.314c-1.304 2.19-2.93 4.183-5.44 3.8c.449.232.985.446 1.57.581c-2.91 2.325-6.478 3.24-9.849 3.596c0-6.982 5.16-17.454 16.146-17.454\"/><path fill=\"#5b5c5f\" d=\"M37.964 13.09c-10.627 0-16.146 10.034-16.146 17.455L37.963 13.16z\"/><path fill=\"#e2e4e5\" d=\"m18.764 34.012l19.2-20.921l-17.455 20.508z\"/><path fill=\"#f0f1f1\" d=\"m37.964 13.09l-19.2 19.2v1.722z\"/></g>" },
      { id: "streamline-kameleon-color:quill-paper-duo", viewBox: "0 0 48 48", body: "<g fill=\"none\"><path fill=\"#deeeff\" d=\"M23.999 47.997c13.255 0 24-10.745 24-24s-10.745-24-24-24s-24 10.745-24 24s10.745 24 24 24\"/><path fill=\"#2e3ecd\" fill-rule=\"evenodd\" d=\"M11.71 10.033c-.925 0-1.675.75-1.675 1.676v24.576c0 .925.75 1.675 1.676 1.675h17.594c.925 0 1.676-.75 1.676-1.675V27.05h-1.746v-1.309h1.746v-9.844l-6.982-5.865z\" clip-rule=\"evenodd\"/><path fill=\"#6bafff\" fill-rule=\"evenodd\" d=\"M23.999 14.222v-4.189l5.453 4.58q-.927.59-1.75 1.285h-2.027c-.926 0-1.676-.75-1.676-1.676m-.417 6.72h-9.62a.437.437 0 0 0 0 .873h9.157q.22-.44.463-.873m-1.56 3.491h-8.06a.437.437 0 0 0 0 .873h7.781q.13-.436.278-.873m-.868 3.491h-7.191a.437.437 0 0 0 0 .873h7.056l.023-.023q.046-.42.112-.85m.663-9.6a.437.437 0 0 0 0-.873h-7.854a.437.437 0 0 0 0 .873z\" clip-rule=\"evenodd\"/><path fill=\"#6bafff\" d=\"m37.963 13.088l-19.2 19.2v1.722z\"/><path fill=\"#6bafff\" fill-rule=\"evenodd\" d=\"M21.959 30.527c3.328-.366 6.837-1.288 9.707-3.58a6.8 6.8 0 0 1-1.571-.58c2.51.382 4.137-1.611 5.441-3.801c-1.016.13-2.029-.053-2.81-.314c1.283 0 3.037-1.179 3.875-1.803v-.004c.851-2.051 1.362-4.481 1.362-7.357c-10.288 0-15.465 9.182-16.083 16.082l-3.117 3.118v1.722z\" clip-rule=\"evenodd\"/><path fill=\"#2e3ecd\" fill-rule=\"evenodd\" d=\"m21.997 30.523l12.567-13.715l-11.21 13.532q-.681.108-1.357.183\" clip-rule=\"evenodd\"/></g>" },
      { id: "mingcute:quill-pen-ai-fill", viewBox: "0 0 24 24", body: "<g fill=\"none\"><path d=\"m12.594 23.258l-.012.002l-.071.035l-.02.004l-.014-.004l-.071-.036q-.016-.004-.024.006l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427q-.004-.016-.016-.018m.264-.113l-.014.002l-.184.093l-.01.01l-.003.011l.018.43l.005.012l.008.008l.201.092q.019.005.029-.008l.004-.014l-.034-.614q-.005-.019-.02-.022m-.715.002a.02.02 0 0 0-.027.006l-.006.014l-.034.614q.001.018.017.024l.015-.002l.201-.093l.01-.008l.003-.011l.018-.43l-.003-.012l-.01-.01z\"/><path fill=\"currentColor\" d=\"M20.262 2.434a1 1 0 0 1 .944.454c.991 1.49.747 3.71-.467 5.007a1 1 0 0 1-.03.37a16 16 0 0 1-.75 2.135c-.551 1.263-1.328 2.54-2.423 3.636c-2.05 2.05-4.742 2.991-6.844 3.43a19 19 0 0 1-1.491.25l-.52.06l-.466.041q-.219.016-.406.027l-.101.83l-.064.593l-.027.29L7.5 21c-.047.54-.448 1-1 1a1 1 0 0 1-1-1c0-.156.009-.35.023-.57l.037-.467l.048-.505l.085-.77l.028-.248c.205-1.732.446-3.427.987-5.09c.625-1.92 1.75-4.379 3.756-6.386c1.574-1.573 3.433-2.61 5.107-3.29l.452-.176l.44-.16q.108-.038.215-.073l.42-.136l.402-.12l.568-.155l.519-.126l.315-.069l.546-.105l.577-.091zM5 1a1 1 0 0 1 .898.56l.048.117l.13.378a3 3 0 0 0 1.684 1.8l.185.07l.378.129a1 1 0 0 1 .117 1.844l-.117.048l-.378.13a3 3 0 0 0-1.8 1.684l-.07.185l-.129.378a1 1 0 0 1-1.844.117l-.048-.117l-.13-.378a3 3 0 0 0-1.684-1.8l-.185-.07l-.378-.129a1 1 0 0 1-.117-1.844l.117-.048l.378-.13a3 3 0 0 0 1.8-1.684l.07-.185l.129-.378A1 1 0 0 1 5 1\"/></g>" },
      { id: "mingcute:quill-pen-ai-line", viewBox: "0 0 24 24", body: "<g fill=\"none\" fill-rule=\"evenodd\"><path d=\"m12.594 23.258l-.012.002l-.071.035l-.02.004l-.014-.004l-.071-.036q-.016-.004-.024.006l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427q-.004-.016-.016-.018m.264-.113l-.014.002l-.184.093l-.01.01l-.003.011l.018.43l.005.012l.008.008l.201.092q.019.005.029-.008l.004-.014l-.034-.614q-.005-.019-.02-.022m-.715.002a.02.02 0 0 0-.027.006l-.006.014l-.034.614q.001.018.017.024l.015-.002l.201-.093l.01-.008l.003-.011l.018-.43l-.003-.012l-.01-.01z\"/><path fill=\"currentColor\" d=\"M20.262 2.434a1 1 0 0 1 .944.454l.078.126l.109.202l.081.174l.083.205c.315.838.552 2.297-.542 3.956a2.6 2.6 0 0 1-.276.345a1 1 0 0 1-.03.368a16 16 0 0 1-.75 2.136c-.551 1.263-1.328 2.54-2.423 3.636c-2.05 2.05-4.742 2.991-6.844 3.43c-.825.173-1.576.271-2.186.327l-.487.038l-.21.013l-.128 1.063l-.098.906l-.038.412l-.037.518A5 5 0 0 0 7.5 21a1 1 0 1 1-2 0q0-.157.01-.36l.03-.437l.043-.489l.08-.772l.058-.502c.205-1.732.446-3.426.987-5.09c.625-1.92 1.75-4.379 3.757-6.385c1.573-1.574 3.432-2.611 5.106-3.29l.452-.177l.44-.16q.108-.038.215-.073l.42-.136l.402-.12l.384-.107l.363-.093l.34-.08l.315-.07l.546-.105l.577-.091zM19.76 4.53l-.322.062l-.37.079l-.415.098l-.222.058l-.47.13q-.244.072-.501.156l-.527.18c-1.615.584-3.508 1.54-5.054 3.086c-1.704 1.703-2.7 3.84-3.269 5.59c-.165.507-.293.977-.39 1.388l-.104.462l.465-.043a17 17 0 0 0 1.702-.267c1.92-.401 4.179-1.228 5.838-2.888c.85-.849 1.484-1.857 1.954-2.905c-.976.52-2.018.986-2.759 1.233a1 1 0 0 1-.632-1.898c.674-.224 1.758-.713 2.754-1.265c.494-.274.946-.552 1.301-.808l.226-.17l.17-.141l.065-.06l.095-.095l.05-.063c.527-.798.52-1.48.415-1.919M5 1a1 1 0 0 1 .898.56l.048.117l.13.378a3 3 0 0 0 1.684 1.8l.185.07l.378.129a1 1 0 0 1 .117 1.844l-.117.048l-.378.13a3 3 0 0 0-1.8 1.684l-.07.185l-.129.378a1 1 0 0 1-1.844.117l-.048-.117l-.13-.378a3 3 0 0 0-1.684-1.8l-.185-.07l-.378-.129a1 1 0 0 1-.117-1.844l.117-.048l.378-.13a3 3 0 0 0 1.8-1.684l.07-.185l.129-.378A1 1 0 0 1 5 1m0 3.196A5 5 0 0 1 4.196 5q.448.355.804.804q.355-.448.804-.804A5 5 0 0 1 5 4.196\"/></g>" },
      { id: "ri:quill-pen-ai-fill", viewBox: "0 0 24 24", body: "<path fill=\"currentColor\" d=\"m4.713 7.128l-.246.566a.506.506 0 0 1-.934 0l-.246-.566a4.36 4.36 0 0 0-2.22-2.25l-.759-.339a.53.53 0 0 1 0-.963l.717-.319A4.37 4.37 0 0 0 3.276.931L3.53.32a.506.506 0 0 1 .942 0l.253.61a4.37 4.37 0 0 0 2.25 2.327l.718.32a.53.53 0 0 1 0 .962l-.76.338a4.36 4.36 0 0 0-2.219 2.251m-1.65 14.485C4.09 15.422 6.312 1.997 21 1.997c-1.496 3-2.5 4.5-3.5 5.5l-1 1l1.5 1c-1 3-4 6.5-8 7q-4.003.5-5.002 5.5H3z\"/>" },
      { id: "ri:quill-pen-ai-line", viewBox: "0 0 24 24", body: "<path fill=\"currentColor\" d=\"m4.713 7.128l-.246.566a.506.506 0 0 1-.934 0l-.246-.566a4.36 4.36 0 0 0-2.22-2.25l-.759-.339a.53.53 0 0 1 0-.963l.717-.319A4.37 4.37 0 0 0 3.276.931L3.53.32a.506.506 0 0 1 .942 0l.253.61a4.37 4.37 0 0 0 2.25 2.327l.718.32a.53.53 0 0 1 0 .962l-.76.338a4.36 4.36 0 0 0-2.219 2.251m1.621 8.687c.176-.582.373-1.159.605-1.782c2.056-5.527 5.48-8.951 11.074-9.818c-.513 1.143-.998 1.938-1.427 2.367l-1.001 1.002L14.172 9l1.456 1.454c-1.13 2.085-3.363 3.745-5.876 4.059c-1.317.165-2.459.607-3.418 1.303M18 9.997l-1-1l1.003-1.003Q19.502 6.493 21 1.997c-14.689 0-16.911 13.425-17.936 19.616L3 21.997h1.998q.999-5 5.002-5.5c4-.5 7-3.5 8-6.5\"/>" },
      { id: "game-icons:scroll-quill", viewBox: "0 0 512 512", body: "<path fill=\"currentColor\" d=\"M311.9 47.95c-17.6 0-34.6.7-50.7 2.43L244.6 93.5l-4.9-40.04c-2.5.46-5 .94-7.5 1.47c-9.1 1.94-15.1 7.22-20.3 14.87s-8.9 17.5-12.1 26.6C191 121.5 184 148 178.4 175c6 5.1 12 10.3 17.9 15.4l30.7-17.6l33.8 26.1l51.9-19.7l61 24.5l-6.8 16.7l-54.4-21.8l-54.7 20.7l-32.2-24.9l-14.9 8.5c19.6 17.3 38.6 34.4 56.5 51.2l14-6.4l33.9 16.1l31.2-13.1l24.2 23.3l-12.4 13l-15.8-15.1l-27.6 11.7l-33-15.8c6.9 6.7 13.6 13.2 20.1 19.7l1.7 1.8l19.5 76.3l-7.8-5.7l-53 .4l-38.1-17.8l-42.4 14.6l-5.8-17l49.2-17l41.1 19.2l24.7-.2l-70.7-51.7c-19.7 4.6-39.4 2.8-58.1-3.7c-4.2 44.4-5.9 85.7-7 118.7c-.4 10.7 2.7 23 7.5 32.5c4.9 9.5 11.7 15.4 15 16.1c5.2 1.2 19 3.2 37.7 5.1l12.4-39l19.1 41.7c16.7 1.2 35 2 53.5 2.2c28.2.3 57.1-.9 82-4.7c15.8-2.3 29.6-6 40.7-10.4c-11.8-5.1-21.6-10.6-29.1-16.6c-11.1-8.9-18.2-19.3-17.3-30.9v.2c5.4-96.4 10.8-188.8 30.3-286l.1-.4l.1-.4c5.3-17.9 17.9-39.86 36.1-55.83c-13.9-2.06-28.6-4-43.7-5.66l-22.3 25.3l-2.2-27.7c-19-1.64-38.4-2.71-57.4-2.92h-5.7zm148.5 20.44c-4.7 3.69-9.2 8.03-13.3 12.73c12.1 8.18 21.4 23.38 21.8 36.98c.3 7.8-1.9 14.9-7.7 21.4c-5.8 6.4-15.6 12.4-31.6 15.8l3.8 17.6c18.6-4 32.3-11.5 41.2-21.4c9-9.9 12.7-22.2 12.3-34c-.6-19.3-11.1-37.59-26.5-49.11M25.44 71.91c-.24 1.61-.38 3.43-.38 5.62c.1 7.69 2.03 18.17 5.83 30.17c3.41 10.7 8.27 22.5 14.35 34.8c10.63-5.3 20.59-11 28.41-18.1c-4.42 12.5-10.15 24.7-18.6 36.5c4.14 7.2 8.63 14.4 13.45 21.5c10.64-5.3 20.72-13 29.52-26.1c-3.3 16-8.47 30.6-18.27 41.8c6.53 8.5 13.5 16.8 20.75 24.5c8.7-9.3 15.6-21 20.7-34.9c3.8 18.5 2.6 35.3-5.7 49.4c8 7.2 16.3 13.7 24.8 19.1c6.1-14 8.9-30.6 8.5-49.7c9.2 23.7 11.3 42.9 9.6 59.5c20.2 9.2 40.8 12 61.3 6.1l4.2-1.3l69.3 50.6l-5.9-22.8c-73-72.8-175.4-156.7-261.86-226.69M312.8 123.9l33.2 13.8l31.3-9.9l5.4 17.2l-37.5 11.9l-33.6-14l-28.8 8.1l-4.8-17.4zm107.3 236.2c-.7 0-1.3.1-2 .1c-3.5.1-7.2.5-11.1 1.3l3.4 17.6c12.2-2.3 20-.4 24.5 2.5c4.4 2.9 6.3 6.8 6.4 12.5c.1 9.3-7 23-23.3 32.5c5.4 2.9 11.9 5.9 19.3 8.7c14.4-11.6 22.1-26.8 22-41.4c-.1-10.7-5.2-21.2-14.6-27.4c-6.7-4.3-15-6.5-24.6-6.4\"/>" },
      { id: "hugeicons:quill-write-01", viewBox: "0 0 24 24", body: "<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"><path d=\"M5.076 17C4.089 4.545 12.912 1.012 19.973 2.224c.286 4.128-1.734 5.673-5.58 6.387c.742.776 2.055 1.753 1.913 2.974c-.1.868-.69 1.295-1.87 2.147C11.85 15.6 8.854 16.78 5.076 17\"/><path d=\"M4 22c0-6.5 3.848-9.818 6.5-12\"/></g>" },
      { id: "hugeicons:quill-write-02", viewBox: "0 0 24 24", body: "<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"><path d=\"M10.55 3c-3.852.007-5.87.102-7.159 1.39C2 5.783 2 8.022 2 12.5s0 6.717 1.391 8.109C4.783 22 7.021 22 11.501 22c4.478 0 6.717 0 8.108-1.391c1.29-1.29 1.384-3.307 1.391-7.16\"/><path d=\"M11.056 13C10.332 3.866 16.802 1.276 21.98 2.164c.209 3.027-1.273 4.16-4.093 4.684c.545.57 1.507 1.286 1.403 2.18c-.074.638-.506.95-1.372 1.576c-1.896 1.37-4.093 2.234-6.863 2.396\"/><path d=\"M9 17c2-5.5 3.96-7.364 6-9\"/></g>" },
      { id: "streamline-freehand:design-tool-quill", viewBox: "0 0 24 24", body: "<g fill=\"currentColor\" fill-rule=\"evenodd\" clip-rule=\"evenodd\"><path d=\"M23.225 0a30 30 0 0 0-4.507.901c-1.082.331-2.143.762-3.225 1.112c-1.773.571-1.372.17-3.756 4.467a7.2 7.2 0 0 0-1.002-2.494c-1.001-1.001-2.003.511-2.714 1.663c-2.114 3.456-4.047 6.56-4.447 11.76a.302.302 0 0 0 .6.05c.441-4.949 2.404-8.014 4.558-11.35a4.7 4.7 0 0 1 1.252-1.502c.06.1.12 0 .38.682c.261.68.461 2.103.852 2.403s.881 0 1.192-.43s1.963-3.636 2.584-3.917q.433-.177.891-.27a32.7 32.7 0 0 1 6.882-1.823a8.6 8.6 0 0 1-.3 2.504a39 39 0 0 1-2.355 7.081c-.3.672-.78 2.204-1.462 2.695c-.07-.1-.28-.18-.34-.24a8.7 8.7 0 0 0-2.855-1.703c-1.282-.17-.631 2.684-.691 3.365c-.741-.51-2.574-1.442-2.905-.66c-.22.52.1 1.191.2 1.602c.23.871.792 2.554.12 3.175a6.78 6.78 0 0 1-4.797 1.192c-2.404-.23-1.653-1.232-2.174-.852c-.2.08-.42.26-.2.521c.292.426.73.73 1.232.852c1.893.55 4.898.24 6.43-1.112c1.122-1.002.441-3.175 0-4.718c.82.242 1.557.703 2.134 1.332a.58.58 0 0 0 .741 0c.38-.43 0-2.283.08-3.495h.19q.893.553 1.693 1.232c.2.237.436.44.701.6c.611.251 1.302-.39 1.673-.89C21.132 12.078 25.63.26 23.225 0\"/><path d=\"M7.04 16.256C13.99 8.444 17.385 6.12 19.55 4.517a.344.344 0 0 0-.401-.56c-1.402 1.001-2.775 1.852-4.067 2.894C7.77 12.861 5.116 16.867.88 22.416l-.771 1.142a.31.31 0 0 0 .51.34c2.024-2.644 5.28-6.36 6.421-7.642\"/></g>" },
      { id: "streamline-freehand:edit-quill-feather-1", viewBox: "0 0 24 24", body: "<g fill=\"currentColor\" fill-rule=\"evenodd\" clip-rule=\"evenodd\"><path d=\"M23.283 7.196a10.73 10.73 0 0 0-6.3-5.84a17.4 17.4 0 0 0-8.6-1a9.93 9.93 0 0 0-7.77 7.23a14.1 14.1 0 0 0 1 10.66c1.55 2.91 4.9 4.79 8.55 5.35a13 13 0 0 0 9.82-2.18a.34.34 0 0 0 0-.43a.33.33 0 0 0-.47-.06a12.25 12.25 0 0 1-9.27 1.89c-3.34-.56-6.42-2.3-7.8-5a13.14 13.14 0 0 1-.76-9.85c1-3.21 3.36-5.84 6.88-6.43a16.3 16.3 0 0 1 8.05.81a9.83 9.83 0 0 1 5.89 5.22a12.4 12.4 0 0 1 .66 5.73a14.25 14.25 0 0 1-1.66 5.61a.3.3 0 1 0 .52.3a14.75 14.75 0 0 0 1.84-5.83a13.2 13.2 0 0 0-.58-6.18\"/><path d=\"M6.752 13.987v.39a1 1 0 0 0 .1.39s.48 1.06.88.89c.22-.1.18-1.23.18-1.25a3.5 3.5 0 0 0-.16-.58c-.31-.68-.31-.63-.31-.63c-.64-.83-.68.79-.69.79m1.85-2.78c-.06 0-.22.07-.31.34c0 .08-.07.3-.08.33a1.9 1.9 0 0 0-.06.87q.03.203.12.39q.108.178.24.34l.29.36c.06.06.08.11.1.12c.2.11.33.11.4 0s.1-.17 0-.84a14 14 0 0 0-.32-1.62a.35.35 0 0 0-.38-.29m8.471 2.419a1.55 1.55 0 0 0 .58-1.05a9 9 0 0 0 .12-2a19.7 19.7 0 0 0-.86-4.52a8 8 0 0 0-.74-1.74a.9.9 0 0 0-.42-.33a.7.7 0 0 0-.47 0c-.307.16-.59.361-.84.6a36 36 0 0 0-2.66 2.75a1.12 1.12 0 0 0-.17.84c0 .36.21.81.31 1.22v.11c-.39-.16-.88-.39-1.14-.48a.52.52 0 0 0-.65.18a3 3 0 0 0-.15 1.06q.042.725.17 1.44c0 .21 0 .49.1.74q.035.198.14.37a.299.299 0 0 0 .548-.073a.3.3 0 0 0-.038-.227a.8.8 0 0 1-.07-.29c0-.2 0-.42-.05-.59q-.09-.687-.1-1.38a3 3 0 0 1 0-.44c.39.18 1 .49 1.28.62a.59.59 0 0 0 .72-.16a1.4 1.4 0 0 0 .08-.74c0-.36-.18-.82-.26-1.21c0-.17.07-.39 0-.44a35 35 0 0 1 2.84-2.67s0 .1.05.14c.36.918.641 1.864.84 2.83c.186.799.307 1.612.36 2.43q.039.64 0 1.28a4 4 0 0 1-.1.68c0 .07-.1.13-.08.17l-1.27.24a.48.48 0 0 0-.38.28a.49.49 0 0 0 0 .47l.85 1.33a8.6 8.6 0 0 1-2.07 2.05a6.2 6.2 0 0 1-3 .93a.34.34 0 1 0 0 .68a6.83 6.83 0 0 0 3.44-.93a10.2 10.2 0 0 0 2.57-2.4a.45.45 0 0 0 0-.53l-.58-1l.57-.09q.276-.036.53-.15\"/><path d=\"M5.612 18.686a.29.29 0 0 0 .4.13s1.07-.47 2.09-1c.52-.26 1-.54 1.39-.77c.53-.38 1.06-.78 1.55-1.21q.74-.65 1.39-1.39a17.5 17.5 0 0 0 2.28-3.19a.339.339 0 0 0-.36-.512a.34.34 0 0 0-.21.142a19.5 19.5 0 0 1-1.93 2.31c-.53.53-1.08 1-1.64 1.53s-1.13 1-1.72 1.46c-.31.26-.74.57-1.19.88c-.94.63-1.92 1.22-1.92 1.22a.29.29 0 0 0-.13.4\"/></g>" },
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
