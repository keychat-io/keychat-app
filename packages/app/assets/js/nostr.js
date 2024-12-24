if (typeof window.nostr === 'undefined') {
  window.nostr = {
    nip04: {},
    nip44: {},
  };
}

function generateUniqueId() {
  return Math.random().toString(36).substring(2, 15);
}

window.addEventListener('flutterInAppWebViewPlatformReady', function (event) {
  console.log('flutterInAppWebViewPlatformReady');
  const args = [1, true, ['bar', 5], { foo: 'baz' }];
  window.flutter_inappwebview.callHandler('keychat', ...args);
});

window.nostr.getPublicKey = async function () {
  return await window.flutter_inappwebview.callHandler(
    'keychat',
    'getPublicKey'
  );
};

window.nostr.signEvent = async function (event) {
  var res = await window.flutter_inappwebview.callHandler(
    'keychat',
    'signEvent',
    event
  );
  return JSON.parse(res);
};

window.nostr.getRelays = async function () {
  const res = await window.flutter_inappwebview.callHandler(
    'keychat',
    'getRelays'
  );
  var map = {};
  res.forEach((relay) => {
    map[relay] = { read: true, write: true };
  });
  return map;
};

window.nostr.nip04.encrypt = async function (pubkey, plaintext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat',
    'nip04Encrypt',
    pubkey,
    plaintext
  );
};

window.nostr.nip04.decrypt = async function (pubkey, ciphertext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat',
    'nip04Decrypt',
    pubkey,
    ciphertext
  );
};

window.nostr.nip44.encrypt = async function (pubkey, plaintext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat',
    'nip44Encrypt',
    pubkey,
    plaintext
  );
};

window.nostr.nip44.decrypt = async function (pubkey, ciphertext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat',
    'nip44Decrypt',
    pubkey,
    ciphertext
  );
};

window.nostr.main = async function () {
  console.log('nostr.main');
  // const args = [1, true, ['bar', 5], { foo: 'baz' }];
  // const res = await window.flutter_inappwebview.callHandler('keychat', ...args);
  // console.log('res', res);
  // const pubkey = await window.nostr.getPublicKey();
  // console.log('pubkey', pubkey);
  // const res = await window.nostr.signEvent({
  //   created_at: 1735021788,
  //   kind: 4,
  //   tags: [
  //     ['744bc6815ead8ae5db97a1f425ee8aead700a0ebd7ea9968704aee3e3f026f27'],
  //   ],
  //   content: 'hello world',
  // });
  // const res = await window.nostr.getRelays();
  // console.log('getRelays:', JSON.stringify(res));
};
window.nostr.main();
