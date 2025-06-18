import 'dart:io' show File;
import 'dart:typed_data';

// import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:app/app.dart' show Utils, logger;
import 'package:keychat_ecash/ecash_controller.dart';
import 'file.service.dart';

/// Convenience class for uploading files to AWS S3
class AwsS3 {
  static AwsS3? _instance;
  static AwsS3 get instance => _instance ??= AwsS3._();
  // Avoid self instance
  AwsS3._();

  Future<FileEncryptInfo> encryptAndUploadByRelay(File input,
      {void Function(int, int)? onSendProgress}) async {
    FileEncryptInfo res = await FileService.instance.encryptFile(input);
    int length = res.output.length;
    String? ecashToken = await Utils.getGetxController<EcashController>()
        ?.getFileUploadEcashToken(length);

    Map<dynamic, dynamic> uploadParams =
        await FileService.instance.getUploadParams(
      cashu: ecashToken ?? '',
      length: length,
      sha256: res.hash,
    );

    String result = await uploadToAWS(
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
      void Function(int p1, int p2)? onSendProgress,
      required String filename,
      required Map<dynamic, dynamic> uploadParams}) async {
    final dio = Dio();
    logger.i('upload params: $uploadParams');
    String endpoint = uploadParams['url']!;
    Map<String, dynamic> headers = uploadParams['headers']!;
    headers["Content-Type"] = "multipart/form-data";
    try {
      final response = await dio.put(endpoint,
          data: Stream.fromIterable(fileBytes.map((e) => [e])),
          options: Options(headers: headers),
          onSendProgress: onSendProgress);

      if (response.statusCode == 200) {
        return uploadParams['access_url']!;
      }
    } on DioException catch (e, s) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        logger.e(e.response?.data, stackTrace: s);
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        logger.e(e.message ?? e.toString(), stackTrace: s);
        throw Exception('File_upload_faild1: ${e.message ?? e.toString()}');
      }
    }

    throw Exception('File_upload_faild2');
  }
}
