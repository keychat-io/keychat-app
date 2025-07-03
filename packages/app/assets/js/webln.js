if (!window.webln) {
  const webln = {
    _isEnabled: false,

    async enable() {
      if (this._isEnabled) {
        console.log('WebLN: Already enabled.');
        return { enabled: true };
      }

      console.log('WebLN: enable() called. Simulating user approval...');

      return new Promise((resolve) => {
        setTimeout(() => {
          this._isEnabled = true;
          console.log('WebLN: User approved. Enabled.');
          resolve({ enabled: true });
        }, 100);
      });
    },

    getInfo: async function () {
      if (!this._isEnabled) {
        console.warn(
          'WebLN: getInfo() called but not enabled. Returning dummy info.'
        );
      }
      var res = await window.flutter_inappwebview.callHandler(
        'keychat-webln',
        'getInfo'
      );
      console.log('getInfo:', res);
      return res;
    },
    signMessage: async function (message) {
      var res = await window.flutter_inappwebview.callHandler(
        'keychat-webln',
        'signMessage',
        message
      );
      // Returns SignMessageResponse interface
      console.log('signMessage:', res);
      return res;
    },
    verifyMessage: async function (message, signature) {
      var res = await window.flutter_inappwebview.callHandler(
        'keychat-webln',
        'verifyMessage',
        message,
        signature
      );
      // Returns VerifyMessageResponse interface
      console.log('verifyMessage:', res);
      return res;
    },
    sendPayment: async function (paymentRequest) {
      var res = await window.flutter_inappwebview.callHandler(
        'keychat-webln',
        'sendPayment',
        paymentRequest
      );
      console.log('sendPayment:', res);
      return res;
    },
    makeInvoice: async function (invoiceRequest) {
      var res = await window.flutter_inappwebview.callHandler(
        'keychat-webln',
        'makeInvoice',
        invoiceRequest
      );
      console.log('makeInvoice:', res);
      return res;
    },
  };

  Object.defineProperty(window, 'webln', {
    value: webln,
    writable: false,
    configurable: false,
  });

  console.log('WebLN plugin injected successfully!');
  console.log(window.webln);
} else {
  console.log('WebLN already exists, skipping injection.');
}
