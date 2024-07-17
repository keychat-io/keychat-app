import 'dart:io' show File;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:app/app.dart' show getGetxController, logger;
import 'package:keychat_ecash/ecash_controller.dart';

import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import './enum/acl.dart';
import './utils.dart';

import './policy.dart';
import 'file.service.dart';

/// Convenience class for uploading files to AWS S3
class AwsS3 {
  late String accessKey;

  /// AWS secret key
  late String secretKey;

  /// The name of the S3 storage bucket to upload  to
  late String bucket;

  /// Upload a file, returning the file's public URL on success.
  ///
  /// The AWS region. Must be formatted correctly, e.g. us-west-1
  late String region;
  String? host;

  /// Access control list enables you to manage access to bucket and objects
  /// For more information visit [https://docs.aws.amazon.com/AmazonS3/latest/userguide/acl-overview.html]
  ACL acl = ACL.public_read;

  /// If set to true, https is used instead of http. Default is true.
  bool useSSL = true;

  AwsS3({
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    required this.region,
  });

  Future<Map<String, dynamic>> uploadBytes({
    /// The file to upload
    required List<int> fileBytes,

    /// The key to save this file as. Will override destDir and filename if set.
    String? key,

    /// The path to upload the file to (e.g. "uploads/public"). Defaults to the root "directory"
    String destDir = '',

    /// The filename to upload as. If null, defaults to the given file's current filename.
    String? filename,

    /// The content-type of file to upload. defaults to binary/octet-stream.
    String contentType = 'binary/octet-stream',

    /// Additional metadata to be attached to the upload
    Map<String, String>? metadata,
    void Function(int, int)? onSendProgress,
  }) async {
    var httpStr = 'http';
    if (useSSL) {
      httpStr += 's';
    }
    Map<String, dynamic> result = {};
    final endpoint = host ?? '$httpStr://$bucket.s3.$region.amazonaws.com';
    String uploadKey;

    if (key != null) {
      uploadKey = key;
    } else {
      uploadKey = sha1.convert(fileBytes).toString();
    }

    final length = fileBytes.length;
    result['size'] = length;
    // final metadataParams = _convertMetadataToParams(metadata);

    final policy = Policy.fromS3PresignedPost(
      uploadKey,
      bucket,
      accessKey,
      15,
      length,
      acl,
      region: region,
    );

    final signingKey =
        SigV4.calculateSigningKey(secretKey, policy.datetime, region, 's3');
    final signature = SigV4.calculateSignature(signingKey, policy.encode());

    Map<String, dynamic> fields = {};
    fields['key'] = policy.key;
    fields['acl'] = aclToString(acl);
    fields['X-Amz-Credential'] = policy.credential;
    fields['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    fields['X-Amz-Date'] = policy.datetime;
    fields['Policy'] = policy.encode();
    fields['X-Amz-Signature'] = signature;
    fields['Content-Type'] = contentType;

    final dio = Dio();

    final formData = FormData.fromMap({
      ...fields,
      'file': MultipartFile.fromBytes(fileBytes, filename: uploadKey),
    });

    final response = await dio.post(endpoint,
        data: formData,
        options: Options(
          headers: {
            Headers.contentLengthHeader: length, // Set the content-length.
          },
        ),
        onSendProgress: onSendProgress);
    if (response.statusCode == 204) {
      result['url'] = '$endpoint/$uploadKey';
      return result;
    }
    throw Exception('File_upload_faild');
  }

  Future<FileEncryptInfo> encryptAndUpload(File input,
      {void Function(int, int)? onSendProgress}) async {
    FileEncryptInfo res = await FileService.encryptFile(input);
    Map<String, dynamic> result = await uploadBytes(
        fileBytes: res.output, onSendProgress: onSendProgress);
    res.url = result['url'];
    res.size = result['size'];
    return res;
  }

  Future<FileEncryptInfo> encryptAndUploadByRelay(File input,
      {void Function(int, int)? onSendProgress}) async {
    FileEncryptInfo res = await FileService.encryptFile(input);
    int length = res.output.length;
    String? ecashToken = await getGetxController<EcashController>()
        ?.getFileUploadEcashToken(length);

    Map<dynamic, dynamic> uploadParams = await FileService.getUploadParams(
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
        logger.e(e.message, stackTrace: s);
        throw Exception('File_upload_faild: ${e.message ?? ''}');
      }
    }

    throw Exception('File_upload_faild');
  }
}
