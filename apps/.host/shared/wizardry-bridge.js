(function () {
  if (window.wizardry && typeof window.wizardry.exec === 'function') {
    return;
  }

  window.__wizardry_callbacks = window.__wizardry_callbacks || {};

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

  window.wizardry = window.wizardry || {};
  window.wizardry.exec = execCommand;
})();
