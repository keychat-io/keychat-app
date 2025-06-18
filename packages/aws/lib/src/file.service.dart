import 'dart:io' show File;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;
import 'package:app/controller/setting.controller.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';

class FileEncryptInfo {
  late Uint8List output;
  late String iv;
  late String suffix;
  late String key;
  late String hash; // sha256
  late String sourceName;
  String? ecashToken;
  String? url;
  int size = 0;
  FileEncryptInfo(
      {required this.key,
      required this.output,
      required this.iv,
      required this.suffix,
      required this.hash,
      required this.sourceName});
  FileEncryptInfo.fromJson(Map<String, dynamic> json) {
    output = json['output'];
    iv = json['iv'];
    suffix = json['suffix'];
    key = json['key'];
    hash = json['hash'];
    sourceName = json['sourceName'] ?? json['hash'];
  }
  Map<String, dynamic> toJson() {
    return {
      'iv': iv,
      'suffix': suffix,
      'key': key,
      'hash': hash,
      'sourceName': sourceName,
    };
  }
}

class FileService {
  static Future<File> decryptFile(
      {required File input,
      required File output,
      required String key,
      required String iv}) async {
    final encrypter = Encrypter(AES(Key.fromBase64(key), mode: AESMode.ctr));

    final encryptedBytes = Encrypted(await input.readAsBytes());
    final decryptedBytes =
        encrypter.decryptBytes(encryptedBytes, iv: IV.fromBase64(iv));
    await output.writeAsBytes(decryptedBytes);
    return output;
  }

  static Future<FileEncryptInfo> encryptFile(File input) async {
    final iv = IV.fromSecureRandom(16);
    final salt = SecureRandom(16).bytes;
    final key =
        Key.fromUtf8(Random(16).nextInt(10).toString()).stretch(32, salt: salt);
    final encrypter = Encrypter(AES(key, mode: AESMode.ctr));
    String fileName = input.path.split('/').last;
    final encryptedBytes = encrypter
        .encryptBytes(Uint8List.fromList(await input.readAsBytes()), iv: iv);
    return FileEncryptInfo.fromJson({
      'output': encryptedBytes.bytes,
      'iv': iv.base64,
      'key': key.base64,
      'suffix': fileName.contains('.') ? fileName.split('.').last : '',
      'hash': calculateFileHash(encryptedBytes.bytes),
      'sourceName': fileName,
    });
  }

  static String calculateFileHash(List<int> fileBytes) {
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  // check text is image
  static isImage(String text) {
    final regex = RegExp(
        r'(https?://\S+\.(?:jpg|bmp|gif|ico|pcx|jpeg|tif|png|raw))',
        caseSensitive: false);
    return regex.hasMatch(text);
  }

  static Future<Map> getUploadParams(
      {required String cashu,
      required int length,
      required String sha256}) async {
    try {
      final dio = Dio();
      final headers = {'Content-type': 'application/json'};
      String url = Get.find<SettingController>().getHttpDefaultFileApi();
      final response = await dio.post(
        url,
        data: {
          'cashu': cashu,
          'length': length,
          'sha256': sha256,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioException catch (e, s) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        logger.e(e.response?.data, stackTrace: s);
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        logger.e(e.message, stackTrace: s);
        throw Exception('Fetch_upload_params_failed: ${e.message ?? ''}');
      }
    }
    throw Exception('Fetch upload params failed');
  }
}
