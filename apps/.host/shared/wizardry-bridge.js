/*
 * Emission material notice:
 * - Repo-internal Wizardry use follows OWL 3.1.
 * - Generated blank projects may use this file under AGPL-3.0-or-later with the Wizardry Addendum.
 * - See /LICENSE plus /licenses/AGPL-3.0-or-later.txt and /licenses/WIZARDRY_ADDENDUM.md.
 */
(function () {
  window.__wizardry_callbacks = window.__wizardry_callbacks || {};

  function nextId() {
    return Math.random().toString(36).slice(2);
  }

  function nativeTransportAvailable() {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wizardry) {
      return true;
    }

    if (window.WizardryBridge && typeof window.WizardryBridge.postMessage === 'function') {
      return true;
    }

    return false;
  }

  function post(message) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.wizardry) {
      window.webkit.messageHandlers.wizardry.postMessage(message);
      return true;
    }

    if (window.WizardryBridge && typeof window.WizardryBridge.postMessage === 'function') {
      window.WizardryBridge.postMessage(JSON.stringify(message));
      return true;
    }

    return false;
  }

  function execCommand(argv) {
    if (!Array.isArray(argv)) {
      return Promise.reject(new Error('argv must be an array'));
    }
    return new Promise(function (resolve) {
      var id = nextId();
      window.__wizardry_callbacks[id] = function (payload) {
        resolve(payload || {
          stdout: '',
          stderr: '',
          exit_code: 0,
          error: null
        });
      };

      if (!post({ id: id, command: argv })) {
        setTimeout(function () {
          window.__wizardry_callbacks[id]({
            stdout: '',
            stderr: 'native bridge unavailable',
            exit_code: 1,
            error: null
          });
        }, 0);
      }
    });
  }

  function postRpc(method, params) {
    return new Promise(function (resolve) {
      var id = nextId();
      window.__wizardry_callbacks[id] = function (payload) {
        resolve(payload || {});
      };

      if (!post({ id: id, type: 'rpc', method: method, params: params || {} })) {
        setTimeout(function () {
          window.__wizardry_callbacks[id]({
            error: {
              code: -32000,
              message: 'native bridge unavailable'
            }
          });
        }, 0);
      }
    });
  }

  async function rpcBridge(method, payload) {
    if (method === 'bridge.exec') {
      var argv = payload;
      if (payload && typeof payload === 'object' && Array.isArray(payload.argv)) {
        argv = payload.argv;
      }
      return execCommand(argv);
    }

    var response = await postRpc(method, payload || {});
    if (response && response.error && !response.result && typeof response.exit_code === 'undefined') {
      return response;
    }
    return response && Object.prototype.hasOwnProperty.call(response, 'result') ? response.result : response;
  }

  window.wizardry = window.wizardry || {};
  if (typeof window.wizardry.exec !== 'function') {
    window.wizardry.exec = execCommand;
  }
  if (typeof window.wizardry.rpc !== 'function') {
    window.wizardry.rpc = rpcBridge;
  }
  if (typeof window.wizardry.nativeAvailable !== 'function') {
    window.wizardry.nativeAvailable = nativeTransportAvailable;
  }
})();
