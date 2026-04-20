import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR code gzip+base64 compression', () {
    // Simulates the compression pipeline used by QRUserModel.toShortStringForQrcode
    final source = <String, dynamic>{
      'name': 'test',
      'relay': 'wss://relay.keychat.io',
      'pubkey':
          '87f222f8da3888119f37a2b9ebe9164d7013cec53f7c5973e1bd441c0eb8e088',
      'curve25519PkHex':
          '0540e9faa04b0f2e9e3edd9de0a33d426bf5dd4b413a0ba6e9f00c1f4e16a56415',
      'onetimekey':
          '31a93f8df1fcfed37457316fae4efbdfe682424bbcfab1f06e1ff93580a7ebaa',
      'signedId': 2047876722,
      'signedPublic':
          '056d9e5bad900026f38d7f5eaaf4e0b1c5cd15b9e35e3d67647afa5471dec00069',
      'signedSignature':
          '3ca4ff0d0eb48cc050812c7ba65c76f43b2e59c6407f3fc28444582488cd312760fe9dda326e34bc3d4b42d7b53e180adc063724269a5b7058030a0b720b508a',
      'prekeyId': 1409136357,
      'prekeyPubkey':
          '053e4e119b33510fcf6d77a4f42618471b50cb3763fe7e0e9382449ee427b38f0e',
      'time': 1714300259730,
    };

    test('compress -> decompress roundtrip preserves all fields', () {
      // Compress
      var data = '';
      for (final entry in source.entries) {
        if (entry.key == 'name') {
          data += '"${entry.value}",';
        } else {
          data += '${entry.value},';
        }
      }
      final compressedData = gzip.encode(utf8.encode(data));
      final base64Str = base64Encode(compressedData);

      // Decompress
      final restoredData =
          utf8.decode(gzip.decode(base64Decode(base64Str)));
      final values = restoredData.split(',');

      final restored = <String, dynamic>{
        'name': values[0].replaceAll('"', ''),
        'relay': values[1],
        'pubkey': values[2],
        'curve25519PkHex': values[3],
        'onetimekey': values[4],
        'signedId': int.parse(values[5]),
        'signedPublic': values[6],
        'signedSignature': values[7],
        'prekeyId': int.parse(values[8]),
        'prekeyPubkey': values[9],
        'time': int.parse(values[10]),
      };

      for (final key in source.keys) {
        expect(restored[key], equals(source[key]), reason: 'Field $key mismatch');
      }
    });

    test('compressed output is smaller than original', () {
      var data = '';
      for (final entry in source.entries) {
        data += '${entry.value},';
      }
      final compressedData = gzip.encode(utf8.encode(data));
      final base64Str = base64Encode(compressedData);

      expect(base64Str.length, lessThan(data.length));
    });
  });
}
