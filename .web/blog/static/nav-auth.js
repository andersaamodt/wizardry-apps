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
      '<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M12.659 22H18a2 2 0 0 0 2-2V8a2.4 2.4 0 0 0-.706-1.706l-3.588-3.588A2.4 2.4 0 0 0 14 2H6a2 2 0 0 0-2 2v9.34\"/><path d=\"M14 2v5a1 1 0 0 0 1 1h5m-9.622 4.622a1 1 0 0 1 3 3.003L8.36 20.637a2 2 0 0 1-.854.506l-2.867.837a.5.5 0 0 1-.62-.62l.836-2.869a2 2 0 0 1 .506-.853z\"/></g>',
      '<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M14 3v4a1 1 0 0 0 1 1h4\"/><path d=\"M17 21H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7l5 5v11a2 2 0 0 1-2 2\"/><path d=\"m10 18l5-5a1.414 1.414 0 0 0-2-2l-5 5v2z\"/></g>',
      '<g fill=\"currentColor\" fill-rule=\"evenodd\" clip-rule=\"evenodd\"><path d=\"M9.75 20.5V22h-3a2.25 2.25 0 0 1-2.25-2.25V9.621c0-.596.237-1.169.659-1.59l5.367-5.371A2.25 2.25 0 0 1 12.118 2h5.132a2.25 2.25 0 0 1 2.25 2.25v5.5H18v-5.5a.75.75 0 0 0-.75-.75h-5.002l.003 3.998A2.25 2.25 0 0 1 10 9.75H6v10c0 .414.336.75.75.75zm.999-15.941L7.059 8.25h2.942a.75.75 0 0 0 .75-.75z\"/><path d=\"M20.299 12.339a1.75 1.75 0 0 0-2.475 0l-5.158 5.158a2.25 2.25 0 0 0-.646 1.35l-.19 1.746a.75.75 0 0 0 .827.826l1.747-.189a2.25 2.25 0 0 0 1.349-.646l5.158-5.158a1.75 1.75 0 0 0 0-2.475zm-2.277 1.923l.966.966l-4.296 4.296a.75.75 0 0 1-.45.215l-.82.089l.089-.82a.75.75 0 0 1 .215-.45z\"/></g>',
      '<path fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M18 5V4a1 1 0 0 0-1-1H8.914a1 1 0 0 0-.707.293L4.293 7.207A1 1 0 0 0 4 7.914V20a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-5M9 3v4a1 1 0 0 1-1 1H4m11.383.772l2.745 2.746m1.215-3.906a2.09 2.09 0 0 1 0 2.953l-6.65 6.646L9 17.95l.739-3.692l6.646-6.646a2.087 2.087 0 0 1 2.958 0\"/>',
      '<path fill=\"currentColor\" d=\"M0 64C0 28.7 28.7 0 64 0h160v128c0 17.7 14.3 32 32 32h128v125.7l-86.8 86.8c-10.3 10.3-17.5 23.1-21 37.2l-18.7 74.9c-2.3 9.2-1.8 18.8 1.3 27.5L64 512c-35.3 0-64-28.7-64-64zm384 64H256V0zm165.8 107.7l14.4 14.4c15.6 15.6 15.6 40.9 0 56.6l-29.4 29.4l-71-71l29.4-29.4c15.6-15.6 40.9-15.6 56.6 0M311.9 417l129.2-129.2l71 71l-129.2 129.1c-4.1 4.1-9.2 7-14.9 8.4l-60.1 15c-5.5 1.4-11.2-.2-15.2-4.2s-5.6-9.7-4.2-15.2l15-60.1c1.4-5.6 4.3-10.8 8.4-14.9z\"/>',
      '<path fill=\"currentColor\" d=\"M6 22q-.825 0-1.412-.587T4 20V4q0-.825.588-1.412T6 2h8l6 6v3q-.575.125-1.075.4t-.925.7l-6 5.975V22zm8 0v-3.075l5.525-5.5q.225-.225.5-.325t.55-.1q.3 0 .575.113t.5.337l.925.925q.2.225.313.5t.112.55t-.1.563t-.325.512l-5.5 5.5zm6.575-5.6l.925-.975l-.925-.925l-.95.95zM13 9h5l-5-5l5 5l-5-5z\"/>',
      '<path fill=\"currentColor\" d=\"M13.654 20.192V19.12q0-.161.056-.3q.055-.14.186-.271l5.09-5.065q.148-.13.308-.19q.16-.062.32-.062q.165 0 .334.064q.17.065.298.194l.925.944q.123.148.188.308q.064.159.064.319t-.061.322t-.19.31l-5.066 5.066q-.131.13-.27.186q-.14.056-.302.056h-1.073q-.348 0-.577-.23q-.23-.23-.23-.578m6.884-5.132l-.925-.945zm-6 5.056h.95l3.468-3.474l-.925-.963l-3.493 3.487zM6.616 21q-.691 0-1.153-.462T5 19.385V4.615q0-.69.463-1.152T6.616 3h7.213q.323 0 .628.13t.522.349L18.52 7.02q.217.218.348.522t.131.628v1.675q0 .214-.143.357q-.144.143-.357.143t-.357-.143T18 9.846V8h-3.192q-.349 0-.578-.23T14 7.192V4H6.616q-.231 0-.424.192T6 4.615v14.77q0 .23.192.423t.423.192h4.154q.214 0 .357.143t.143.357t-.143.357t-.357.143zM6 20V4zm12.506-3.852l-.475-.47l.925.964z\"/>',
      '<path fill=\"currentColor\" d=\"M6.25 3.5a.75.75 0 0 0-.75.75v15.5c0 .414.336.75.75.75h3.78a2.08 2.08 0 0 0 .27 1.5H6.25A2.25 2.25 0 0 1 4 19.75V4.25A2.25 2.25 0 0 1 6.25 2h6.086c.464 0 .909.184 1.237.513l5.914 5.914c.329.328.513.773.513 1.237V10h-6a2 2 0 0 1-2-2V3.5zm7.25 1.06V8a.5.5 0 0 0 .5.5h3.44zM19.713 11h.002a2.286 2.286 0 0 1 1.615 3.902l-5.902 5.902a2.7 2.7 0 0 1-1.247.707l-1.831.457a1.087 1.087 0 0 1-1.318-1.318l.457-1.83c.118-.473.362-.904.707-1.248l5.902-5.902a2.28 2.28 0 0 1 1.615-.67\"/>',
      '<path fill=\"currentColor\" d=\"M234.667 106.667h-128v298.666h298.666v-128H448V448H64V64h170.667zM478.167 128L264.833 341.333h-94.166v-94.166L384 33.833zM213.333 264.833v33.834h33.834l117.332-117.334l-33.833-33.833zm147.5-147.5l33.833 33.833L417.833 128L384 94.167z\"/>',
      '<path fill=\"currentColor\" d=\"m8.505 8.995l6.453-6.44l-1.5-1.5l-6.453 6.44zM12.968.19c.258-.238.657-.26.91 0l1.928 1.929a.64.64 0 0 1 0 .909l-6.78 6.784A.64.64 0 0 1 8.57 10H6.643A.643.643 0 0 1 6 9.357V7.43c0-.17.067-.335.188-.455zM4.5 13a.5.5 0 1 1 0-1h7a.5.5 0 1 1 0 1zm4-12a.5.5 0 0 1 0 1H2v13h12V7.5a.5.5 0 1 1 1 0V15a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1z\"/>',
      '<path fill=\"currentColor\" d=\"M8 12h8v2H8zm2 8H6V4h7v5h5v3.1l2-2V8l-6-6H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h4zm-2-2h4.1l.9-.9V16H8zm12.2-5c.1 0 .3.1.4.2l1.3 1.3c.2.2.2.6 0 .8l-1 1l-2.1-2.1l1-1c.1-.1.2-.2.4-.2m0 3.9L14.1 23H12v-2.1l6.1-6.1z\"/>',
      '<path fill=\"currentColor\" d=\"m21 6.757l-2 2V4h-9v5H5v11h14v-2.757l2-2v5.765a.993.993 0 0 1-.993.992H3.993A1 1 0 0 1 3 20.993V8l6.003-6h10.995C20.55 2 21 2.455 21 2.992zm.778 2.05l1.414 1.415L15.414 18l-1.416-.002l.002-1.412z\"/>',
      '<g fill=\"none\"><path d=\"M13.5 22.5v-2.713l6.287-6.287l2.713 2.713l-6.287 6.287z\"/><path stroke=\"currentColor\" stroke-linecap=\"square\" stroke-width=\"2\" d=\"M20 10V7l-5-5H4v20h5.5M14 2v6h6\"/><path stroke=\"currentColor\" stroke-width=\"2\" d=\"m17.45 15.836l-3.95 3.95V22.5h2.713l3.951-3.95m-2.713-2.714l2.336-2.336l2.713 2.713l-2.336 2.336m-2.713-2.713l2.713 2.713\"/></g>',
      '<path fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M6 11V6.2c0-1.12 0-1.68.218-2.108c.192-.377.497-.682.874-.874C7.52 3 8.08 3 9.2 3H14m6 6v8.804c0 1.118 0 1.677-.218 2.104a2 2 0 0 1-.874.874C18.48 21 17.92 21 16.803 21H13m7-12c-.004-.285-.014-.466-.056-.639q-.074-.308-.24-.578c-.123-.202-.295-.374-.641-.72l-3.125-3.125c-.346-.346-.52-.52-.721-.643a2 2 0 0 0-.578-.24c-.173-.041-.353-.052-.639-.054M20 9h-2.803c-1.118 0-1.678 0-2.105-.218a2 2 0 0 1-.874-.874C14 7.48 14 6.92 14 5.8V3M9 14l2 2m-7 5v-2.5l7.5-7.5l2.5 2.5L6.5 21z\"/>',
      '<path fill=\"currentColor\" d=\"M8 18.75H6.5c-.69 0-1.25-.56-1.25-1.25v-12c0-.69.56-1.25 1.25-1.25h3.75V9c0 .41.34.75.75.75h4.8c.1.29.37.5.7.5c.41 0 .75-.34.75-.75V9a.78.78 0 0 0-.22-.53l-5.5-5.5a.78.78 0 0 0-.53-.22H6.5c-1.52 0-2.75 1.23-2.75 2.75v12c0 1.52 1.23 2.75 2.75 2.75H8c.41 0 .75-.34.75-.75s-.34-.75-.75-.75m3.75-13.44l2.94 2.94h-2.94zm7.86 6.06c-.38-.38-.94-.61-1.52-.62c-.6-.03-1.17.2-1.55.59l-6.39 6.4c-.13.13-.2.29-.22.47l-.18 2.23c-.02.22.06.44.22.59c.14.14.33.22.53.22h.07l2.25-.21a.74.74 0 0 0 .46-.22l6.39-6.4c.8-.79.77-2.22-.06-3.05m-1 1.99l-6.2 6.21l-1.09.1l.08-1.06l6.2-6.21c.1-.1.28-.14.46-.15c.2 0 .38.07.49.18c.24.23.27.72.06.93\"/>',
      '<g fill=\"none\" stroke=\"currentColor\" stroke-linejoin=\"round\" stroke-width=\"1.5\"><path d=\"M13 20.827V22h1.173c.41 0 .614 0 .799-.076c.184-.076.328-.221.618-.51l4.823-4.825c.273-.273.41-.41.483-.556c.139-.28.139-.61 0-.89c-.073-.147-.21-.283-.483-.556s-.41-.41-.556-.483a1 1 0 0 0-.89 0c-.147.073-.284.21-.557.483l-4.823 4.824c-.29.289-.434.434-.51.618s-.077.388-.077.798Z\"/><path stroke-linecap=\"round\" d=\"M19 11s0-1.57-.152-1.937s-.441-.657-1.02-1.235l-4.736-4.736c-.499-.499-.748-.748-1.058-.896a2 2 0 0 0-.197-.082C11.514 2 11.161 2 10.456 2c-3.245 0-4.868 0-5.967.886a4 4 0 0 0-.603.603C3 4.59 3 6.211 3 9.456V14c0 3.771 0 5.657 1.172 6.828C5.235 21.892 6.886 21.99 10 22m2-19.5V3c0 2.828 0 4.243.879 5.121C13.757 9 15.172 9 18 9h.5\"/></g>',
      '<path fill=\"currentColor\" d=\"M4 0C1.8 0 0 1.8 0 4v17c0 2.2 1.8 4 4 4h8.188v-.188l.5-1.812H4c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h6.313c.7.2.687 1.1.687 2v3c0 .6.4 1 1 1h3c1 0 2 0 2 1v8l2-2V8c0-1.1-.988-2.112-2.688-3.813c-.3-.2-.512-.487-.812-.687c-.2-.3-.488-.513-.688-.813C13.113.988 12.1 0 11 0zm19.344 14.094c-.275 0-.55.112-.75.312l-1.188 1.188l3 3l1.188-1.188c.4-.4.4-1 0-1.5l-1.5-1.5a1.07 1.07 0 0 0-.75-.312m-3.032 2.5l-4.718 5c-.1 0-.188.118-.188.218l-1.094 3.594c-.1.1-.006.306.094.407s.181.093.281.093h.126l3.593-1.093c.1 0 .088-.025.188-.125l4.906-4.875zM16 22.094l1.5.312l.313 1.594l-2 .5l-.407-.406z\"/>',
      '<path fill=\"currentColor\" d=\"m20.71 16.71l-2.42-2.42a1 1 0 0 0-1.42 0l-3.58 3.58a1 1 0 0 0-.29.71V21a1 1 0 0 0 1 1h2.42a1 1 0 0 0 .71-.29l3.58-3.58a1 1 0 0 0 0-1.42M16 20h-1v-1l2.58-2.58l1 1Zm-6 0H6a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h5v3a3 3 0 0 0 3 3h3v1a1 1 0 0 0 2 0V8.94a1.3 1.3 0 0 0-.06-.27v-.09a1 1 0 0 0-.19-.28l-6-6a1 1 0 0 0-.28-.19a.3.3 0 0 0-.09 0L12.06 2H6a3 3 0 0 0-3 3v14a3 3 0 0 0 3 3h4a1 1 0 0 0 0-2m3-14.59L15.59 8H14a1 1 0 0 1-1-1ZM8 14h6a1 1 0 0 0 0-2H8a1 1 0 0 0 0 2m0-4h1a1 1 0 0 0 0-2H8a1 1 0 0 0 0 2m2 6H8a1 1 0 0 0 0 2h2a1 1 0 0 0 0-2\"/>',
      '<g fill=\"none\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"4\"><path d=\"M10 44h28a2 2 0 0 0 2-2V14H30V4H10a2 2 0 0 0-2 2v36a2 2 0 0 0 2 2M30 4l10 10\"/><path d=\"m21 35l10-10l-4-4l-10 10v4z\"/></g>',
      '<g fill=\"currentColor\" fill-rule=\"evenodd\" clip-rule=\"evenodd\"><path d=\"M22.471 11.098c-.24-.38-.72-.39-1.17-.33a9.85 9.85 0 0 0-5.005 2.382a6.74 6.74 0 0 0-2.913 5.845a5.7 5.7 0 0 0 .39 2.192a21 21 0 0 0-1.771 2.512c0 .23.29.42.62.21a45 45 0 0 0 3.303-3.843a43 43 0 0 0 2.433-4.074a.3.3 0 0 0-.5-.32c-3.874 5.114-3.324 4.404-3.754 5.004a4 4 0 0 1 0-.5a6 6 0 0 1 1.611-5.295c2.002-2.002 4.915-3.093 5.735-3.003c0 3.153 0 2.853-.07 3.353l-1.541 1.001c-.18.1-.63.22-.76.6c-.221.661.59.722 1.12 1.252c-1.27.74-1.431.5-1.821.78a.58.58 0 0 0-.23.791q.474.459 1 .861c-2.682 2.252-3.433 1.472-3.883 1.772a.35.35 0 0 0 .17.64c2.002.32 4.604-2.001 4.694-2.232c.16-.42-.33-.75-.79-1.17a18 18 0 0 0 1.941-.892a.55.55 0 0 0 .12-.91l-.82-.731c1.13-.62 1.701-.92 1.901-1.471c.12-.3.31-3.934-.01-4.424\"/><path d=\"M11.061 18.995c-7.467.11-4.294.12-7.557-.27c-.49-.05-.71-.42-.85-.851c-.26-.851-.19-1.001-.07-9.339a19.7 19.7 0 0 1 .21-5.004c.25-1.001 0-1.381 1.42-1.361c0 .34-.13 1.631-.1 1.851c.09.761.841.65 1.132.73c1.521.361 2.092-.78 2.002-2.371c.476.143.984.143 1.46 0c0 .11-.1 1.381-.07 1.561c.09.76.832.64 1.132.72c1.501.361 2.072-.74 2.002-2.301c.68.2.73.17 1.731-.06c0 .1-.08 1.381-.06 1.501a.69.69 0 0 0 .52.63c1.602.431 2.543 0 2.593-1.73q.504.012 1 .09c.241 0 .441.08.461.28l.37 6.936a.301.301 0 0 0 .527.246a.3.3 0 0 0 .064-.246c.44-2.352.44-4.765 0-7.117c-.24-1-1.321-1-2.382-.91a5.5 5.5 0 0 0-.54-1.612a1.43 1.43 0 0 0-2.052.14a2.9 2.9 0 0 0-.4 1.001a3.3 3.3 0 0 0-2.002.15a3.2 3.2 0 0 0-.32-1.16a1.44 1.44 0 0 0-2.103.15a2.8 2.8 0 0 0-.35.85a3.3 3.3 0 0 0-1.722.12a3.2 3.2 0 0 0-.32-1.07a1.15 1.15 0 0 0-1.19-.371c-.802.12-1.102.67-1.282 1.451a2.33 2.33 0 0 0-1.562.25c-.51.34-.54 1.061-.68 1.522a20.4 20.4 0 0 0-.51 5.164c-.19 4.695-.14 3.193-.21 6.696c0 1.902 0 4.334 2.061 4.484c3.343.25.12.37 7.657-.05a.35.35 0 1 0-.01-.7m3.383-17.256c.08-1.491 1-1.12 1.061-.83c.117.737.1 1.49-.05 2.221c-.16.551-.44.42-1.001.41q.04-.9-.01-1.8M9.84 1.03c.2-.4.78-.13.86-.16a6.2 6.2 0 0 1 0 2.402c-.09.3-.27.51-.65.4h-.36c0-.12.06-.25.06-.3a5.6 5.6 0 0 1 .09-2.342m-4.494.05c.2-.4.78-.13.86-.16c.151.79.151 1.601 0 2.392c-.09.3-.27.52-.65.4h-.36c0-.12.06-.25.06-.3a5.6 5.6 0 0 1 .09-2.332\"/><path d=\"M15.135 8.245a.38.38 0 0 0 .06-.54c-.19-.31-5.675-.721-8.338-.611c-3.003.2-2.572.7-2.092.81c1.041.321 10.35.361 10.37.341m-3.133 3.103c-.31-.08-2.743-.21-3.203-.21s-3.843.1-4.004.48a.28.28 0 0 0 .06.24c.607.22 1.247.335 1.892.34c1.752.123 3.511.08 5.255-.13c.41 0 .54-.59 0-.72m-6.926 4.644a11.5 11.5 0 0 0 4.584.08a.34.34 0 0 0 0-.48a8.6 8.6 0 0 0-2.903-.42c-2.292.14-2.762.64-1.681.82\"/></g>',
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
    els.composeLink.innerHTML = '<svg width="21" height="21" viewBox="0 0 24 24" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' + icons[idx] + '</svg>';
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
