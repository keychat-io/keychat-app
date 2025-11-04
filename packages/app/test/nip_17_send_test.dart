import 'dart:math';

import 'package:keychat/constants.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/nostr-core/nostr_nip4_req.dart';
import 'package:test/test.dart';
import 'package:web_socket_client/web_socket_client.dart';

// const String relay = 'wss://nos.lol';
const String relay = 'wss://backup.keychat.io';

void main() {
  test('NIP17-send', () async {
    Future task(WebSocket textSocketHandler) async {
      final nip17Event = NostrEventModel.partial(
        id: '2886780f7349afc1344047524540ee716f7bdc1b64191699855662330bf235d8',
        pubkey:
            '8f8a7ec43b77d25799281207e1a47f7a654755055788f7482653f9c9661c6d51',
        createdAt: 1703128320,
        kind: 1059,
        tags: [
          [
            'p',
            '918e2da906df4ccd12c8ac672d8335add131a4cf9d27ce42b3bb3625755f0788',
          ],
        ],
        content:
            'AsqzdlMsG304G8h08bE67dhAR1gFTzTckUUyuvndZ8LrGCvwI4pgC3d6hyAK0Wo9gtkLqSr2rT2RyHlE5wRqbCOlQ8WvJEKwqwIJwT5PO3l2RxvGCHDbd1b1o40ZgIVwwLCfOWJ86I5upXe8K5AgpxYTOM1BD+SbgI5jOMA8tgpRoitJedVSvBZsmwAxXM7o7sbOON4MXHzOqOZpALpS2zgBDXSAaYAsTdEM4qqFeik+zTk3+L6NYuftGidqVluicwSGS2viYWr5OiJ1zrj1ERhYSGLpQnPKrqDaDi7R1KrHGFGyLgkJveY/45y0rv9aVIw9IWF11u53cf2CP7akACel2WvZdl1htEwFu/v9cFXD06fNVZjfx3OssKM/uHPE9XvZttQboAvP5UoK6lv9o3d+0GM4/3zP+yO3C0NExz1ZgFmbGFz703YJzM+zpKCOXaZyzPjADXp8qBBeVc5lmJqiCL4solZpxA1865yPigPAZcc9acSUlg23J1dptFK4n3Tl5HfSHP+oZ/QS/SHWbVFCtq7ZMQSRxLgEitfglTNz9P1CnpMwmW/Y4Gm5zdkv0JrdUVrn2UO9ARdHlPsW5ARgDmzaxnJypkfoHXNfxGGXWRk0sKLbz/ipnaQP/eFJv/ibNuSfqL6E4BnN/tHJSHYEaTQ/PdrA2i9laG3vJti3kAl5Ih87ct0w/tzYfp4SRPhEF1zzue9G/16eJEMzwmhQ5Ec7jJVcVGa4RltqnuF8unUu3iSRTQ+/MNNUkK6Mk+YuaJJs6Fjw6tRHuWi57SdKKv7GGkr0zlBUU2Dyo1MwpAqzsCcCTeQSv+8qt4wLf4uhU9Br7F/L0ZY9bFgh6iLDCdB+4iABXyZwT7Ufn762195hrSHcU4Okt0Zns9EeiBOFxnmpXEslYkYBpXw70GmymQfJlFOfoEp93QKCMS2DAEVeI51dJV1e+6t3pCSsQN69Vg6jUCsm1TMxSs2VX4BRbq562+VffchvW2BB4gMjsvHVUSRl8i5/ZSDlfzSPXcSGALLHBRzy+gn0oXXJ/447VHYZJDL3Ig8+QW5oFMgnWYhuwI5QSLEyflUrfSz+Pdwn/5eyjybXKJftePBD9Q+8NQ8zulU5sqvsMeIx/bBUx0fmOXsS3vjqCXW5IjkmSUV7q54GewZqTQBlcx+90xh/LSUxXex7UwZwRnifvyCbZ+zwNTHNb12chYeNjMV7kAIr3cGQv8vlOMM8ajyaZ5KVy7HpSXQjz4PGT2/nXbL5jKt8Lx0erGXsSsazkdoYDG3U',
        sig:
            'a3c6ce632b145c0869423c1afaff4a6d764a9b64dedaf15f170b944ead67227518a72e455567ca1c2a0d187832cecbde7ed478395ec4c95dd3e71749ed66c480',
      );

      textSocketHandler.send(nip17Event.serialize());
    }

    await connectWebSocket(task);
    await Future.delayed(const Duration(seconds: 10));
  });

  test('NIP17-receive', () async {
    Future task(WebSocket textSocketHandler) async {
      final req = NostrReqModel(
        reqId: 'a${Random().nextInt(900000)}',
        pubkeys: [
          '918e2da906df4ccd12c8ac672d8335add131a4cf9d27ce42b3bb3625755f0788',
        ],
        kinds: [EventKinds.nip17],
        since: DateTime.fromMillisecondsSinceEpoch(1703128310 * 1000),
      );
      textSocketHandler.send(req.toString());
    }

    await connectWebSocket(task);
    await Future.delayed(const Duration(seconds: 10));
  });
}

// Connect to websocket
Future<void> connectWebSocket(
  Future Function(WebSocket textSocketHandler) handleTask,
) async {
  final socket = WebSocket(Uri.parse('ws://localhost:8080'));

  // Listen to messages from the server.
  socket.messages.listen((message) {
    // Handle incoming messages.
  });

  await socket.connection.firstWhere((state) => state is Connected);

  handleTask(socket);
}
