if (typeof window.nostr === 'undefined') {
  window.nostr = {
    nip04: {},
    nip44: {},
  };
}

function generateUniqueId() {
  return Math.random().toString(36).substring(2, 15);
}

window.print = function () {
  console.error('Printing is disabled in this application');
  return false;
};

window.addEventListener('flutterInAppWebViewPlatformReady', function (event) {
  console.log('flutterInAppWebViewPlatformReady');
  // const args = [1, true, ['bar', 5], { foo: 'baz' }];
  // window.flutter_inappwebview.callHandler('keychat', ...args);
});

window.nostr.getPublicKey = async function () {
  var res = await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'getPublicKey'
  );
  console.log('getPublicKey:', res);
  return res;
};

window.nostr.onAccountChanged = async function (newPublicKey) {
  var res = await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'onAccountChanged',
    newPublicKey
  );
  return res;
};

window.nostr.signEvent = async function (event) {
  var res = await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'signEvent',
    event
  );
  console.log('signEvent:', res);
  return JSON.parse(res);
};

window.nostr.getRelays = async function () {
  const res = await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'getRelays'
  );
  var map = {};
  res.forEach((relay) => {
    map[relay] = { read: true, write: true };
  });
  console.log('getRelays:', JSON.stringify(map));
  return map;
};

window.nostr.nip04.encrypt = async function (pubkey, plaintext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'nip04Encrypt',
    pubkey,
    plaintext
  );
};

window.nostr.nip04.decrypt = async function (pubkey, ciphertext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'nip04Decrypt',
    pubkey,
    ciphertext
  );
};

window.nostr.nip44.encrypt = async function (pubkey, plaintext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'nip44Encrypt',
    pubkey,
    plaintext
  );
};

window.nostr.nip44.decrypt = async function (pubkey, ciphertext) {
  return await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'nip44Decrypt',
    pubkey,
    ciphertext
  );
};

window.pageFailedToRefresh = async function () {
  return await window.flutter_inappwebview.callHandler(
    'keychat-nostr',
    'pageFailedToRefresh'
  );
};

window.nostr.test = async function () {
  // console.log('nostr.test');
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
// window.nostr.test();

// download
window.nostr.fetchBlob = async function (blobUrl) {
  console.log('fetchBlob called with:', blobUrl);
  try {
    // Use fetch API - more modern and cleaner
    const response = await fetch(blobUrl);
    const blob = await response.blob();
    
    // Convert blob to base64
    const reader = new FileReader();
    reader.onloadend = function() {
      const base64data = reader.result;
      const base64ContentArray = base64data.split(",");
      const mimeType = base64ContentArray[0].match(/[^:\s*]\w+\/[\w-+\d.]+(?=[;| ])/)[0];
      const decodedFile = base64ContentArray[1];
      console.log('Blob MIME type:', mimeType);
      window.flutter_inappwebview.callHandler(
        'keychat-nostr',
        'blobFileDownload',
        decodedFile,
        mimeType
      );
    };
    
    reader.onerror = function(error) {
      console.error('Error reading blob:', error);
    };
    
    reader.readAsDataURL(blob);
  } catch (error) {
    console.error('Error fetching blob:', error);
  }
}
