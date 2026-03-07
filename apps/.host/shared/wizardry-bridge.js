(function () {
  if (window.wizardry && window.wizardry.rpc && window.wizardry.subscribe && window.wizardry.unsubscribe) {
    return;
  }

  window.__wizardry_callbacks = window.__wizardry_callbacks || {};
  window.__wizardry_subscriptions = window.__wizardry_subscriptions || {};

  function nextId() {
    return Math.random().toString(36).slice(2);
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

  window.wizardry = {
    rpc: function (method, params) {
      return new Promise(function (resolve, reject) {
        // Fast path: bridge.exec is served by the desktop command bridge.
        if (method === 'bridge.exec' && params && Array.isArray(params.argv)) {
          execCommand(params.argv).then(resolve, reject);
          return;
        }

        var id = nextId();
        window.__wizardry_callbacks[id] = function (payload) {
          if (payload && payload.error) {
            reject(new Error(payload.error.message || 'rpc error'));
            return;
          }

          // Legacy native hosts return {stdout, stderr, exit_code, error}.
          if (payload && typeof payload.exit_code !== 'undefined') {
            resolve(payload);
            return;
          }

          resolve(payload && payload.result ? payload.result : payload);
        };

        if (!post({ type: 'rpc', id: id, method: method, params: params || {} })) {
          setTimeout(function () {
            window.__wizardry_callbacks[id]({
              error: {
                code: -32603,
                message: 'native bridge unavailable or method unsupported'
              }
            });
          }, 0);
        }
      });
    },

    subscribe: function (eventName, fn) {
      var token = nextId();
      window.__wizardry_subscriptions[token] = { event: eventName, fn: fn };
      post({ type: 'subscribe', token: token, event: eventName });
      return token;
    },

    unsubscribe: function (token) {
      delete window.__wizardry_subscriptions[token];
      post({ type: 'unsubscribe', token: token });
    },

    // Canonical desktop command bridge.
    exec: function (argv) {
      if (!Array.isArray(argv)) {
        return Promise.reject(new Error('argv must be an array'));
      }
      return execCommand(argv);
    }
  };

  window.__wizardry_emit = function (eventName, payload) {
    Object.keys(window.__wizardry_subscriptions).forEach(function (token) {
      var sub = window.__wizardry_subscriptions[token];
      if (sub && sub.event === eventName) {
        sub.fn(payload);
      }
    });
  };
})();
