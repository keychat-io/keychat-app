import 'dart:io' show File;
import 'dart:typed_data';

// import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:app/app.dart' show Utils, logger;
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:app/service/file.service.dart';

/// Convenience class for uploading files to AWS S3
class AwsS3 {
  // Avoid self instance
  AwsS3._();
  static AwsS3? _instance;
  static AwsS3 get instance => _instance ??= AwsS3._();

  Future<FileEncryptInfo> encryptAndUploadByRelay(File input,
      {void Function(int, int)? onSendProgress}) async {
    final res = await FileService.instance.encryptFile(input, base64Hash: true);
    final length = res.output.length;
    final ecashToken = await Utils.getGetxController<EcashController>()
        ?.getFileUploadEcashToken(length);

    final uploadParams = await FileService.instance.getUploadParams(
      cashu: ecashToken ?? '',
      length: length,
      sha256: res.hash,
    );

    final result = await uploadToAWS(
        uploadParams: uploadParams,
        fileBytes: res.output,
        filename: res.hash,
        onSendProgress: onSendProgress);
    res.url = result;
    res.ecashToken = ecashToken;
    res.size = res.output.length;
    return res;
  }

  Future<String> uploadToAWS(
      {required Uint8List fileBytes,
      required String filename,
      required Map<dynamic, dynamic> uploadParams,
      void Function(int p1, int p2)? onSendProgress}) async {
    final dio = Dio();
    logger.i('upload params: $uploadParams');
    final endpoint = uploadParams['url']! as String;
    final headers = uploadParams['headers']! as Map<String, dynamic>;
    headers['Content-Type'] = 'multipart/form-data';
    try {
      final response = await dio.put(endpoint,
          data: Stream.fromIterable(fileBytes.map((e) => [e])),
          options: Options(headers: headers),
          onSendProgress: onSendProgress);

      if (response.statusCode == 200) {
        return uploadParams['access_url']! as String;
      }
    } on DioException catch (e, s) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        logger.e(e.response?.data, stackTrace: s);
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        logger.e(e.message ?? e.toString(), stackTrace: s);
        throw Exception(e.message ?? e.toString());
      }
    }

    throw Exception('File_upload_failed2');
  }
}
